import itemutilities.ItemJunkState;
import itemutilities.NativeJunk;
import itemutilities.JunkSaleQueue;
import itemutilities.JunkSaleQueue.JunkSaleItem;

class ItemJunkTest {
    static var checks = 0;
    static function check(value:Bool, why:String):Void { checks++; if (!value) throw why; }
    static function gear():Dynamic return {nativeType:"st.item.Armor", kind:"Ring", __uid:1,
        inf:{rarity:"Uncommon"}, flags:{value:0}, level:10, upgradeLevel:0,
        slots:{array:["CriticalChance"]}, infusion:null, infusionBonusStat:null};
    static function copy(value:Dynamic):Dynamic return haxe.Json.parse(haxe.Json.stringify(value));
    static function main():Void {
        var item = gear(), state = new ItemJunkState();
        var fingerprint = NativeJunk.fingerprint(item);
        state.set("db:A", "Ring", fingerprint, true);
        var future = copy(item); future.__uid = 1000;
        check(state.matches("db:A", "Ring", NativeJunk.fingerprint(future)), "identical future pickup matches across object IDs");
        check(!state.matches("db:A", "Ring", fingerprint, true), "a locked copy always stays protected");
        check(!state.matches("db:B", "Ring", fingerprint), "another character does not inherit junk choices");
        var different:Array<Dynamic> = [];
        function variant(change:Dynamic->Void):Void { var next=copy(item); change(next); different.push(next); }
        variant(x -> x.kind="OtherRing");
        variant(x -> x.level=11);
        variant(x -> x.upgradeLevel=1);
        variant(x -> x.inf.rarity="Rare");
        variant(x -> x.flags.value=1);
        variant(x -> x.flags.value=2);
        variant(x -> x.slots.array=["Fervor"]);
        variant(x -> x.slots.array=["CriticalChance", "Fervor"]);
        variant(x -> x.infusion="Power");
        variant(x -> x.infusionBonusStat="Fervor");
        for (other in different) check(!state.matches("db:A", "Ring", NativeJunk.fingerprint(other)), "different item attributes never match");
        var weapon=copy(item); weapon.nativeType="st.item.Weapon"; weapon.effects={array:[]}; weapon.rarity="Rare";
        var altered=copy(weapon); altered.rarity="Epic";
        check(NativeJunk.fingerprint(weapon)!=NativeJunk.fingerprint(altered), "instance weapon rarity matters");
        altered=copy(weapon); altered.effects.array=[{source:"RoguePoison",skill:"Poison"}];
        check(NativeJunk.fingerprint(weapon)!=NativeJunk.fingerprint(altered), "weapon effects matter");
        var rune:Dynamic={nativeType:"st.item.Mastery",kind:"Rune",inf:{},flags:{value:0},mastery:"A"};
        var runeB=copy(rune); runeB.mastery="B";
        check(NativeJunk.fingerprint(rune)!=NativeJunk.fingerprint(runeB), "different runes are distinct despite a shared item kind");
        var unknown=copy(item); unknown.nativeType="st.item.FutureGear";
        check(NativeJunk.fingerprint(unknown)==null, "unknown item subclass cannot be auto-marked");
        var incomplete=copy(item); incomplete.slots=null;
        check(NativeJunk.fingerprint(incomplete)==null && NativeJunk.fingerprint(null)==null, "incomplete replication cannot create a broad rule");
        var loaded=new ItemJunkState(); loaded.load(copy(state.saved()));
        check(loaded.matches("db:A", "Ring", NativeJunk.fingerprint(future)), "saved matching survives a login and JSON round trip");
        loaded.set("db:A", "Ring", fingerprint, false);
        check(!loaded.hasKind("db:A", "Ring") && loaded.saved().length==0, "unmarking removes the future-pickup rule too");
        loaded.load([null, {characterId:"db:A",kind:"Ring",fingerprint:"old-format"}, {characterId:10,kind:"Ring",fingerprint:fingerprint}]);
        check(loaded.saved().length==0, "malformed rules are ignored");

        var merchant={};
        var first:JunkSaleItem={item:{},uid:"1",fingerprint:fingerprint,count:1};
        var second:JunkSaleItem={item:{},uid:"2",fingerprint:fingerprint,count:2};
        var queue=new JunkSaleQueue();
        var present:Array<Dynamic>=[first.item,second.item];
        function exists(row:JunkSaleItem):Bool return present.indexOf(row.item)>=0;
        check(queue.start(merchant,[first,second]), "explicit click starts a sale batch");
        check(!queue.start(merchant,[first]), "repeat clicks cannot start overlapping batches");
        check(queue.next(merchant,0,exists,exists)==first, "first item sends once");
        check(queue.next(merchant,0.1,exists,exists)==null, "do not send another item before reply");
        queue.acknowledge(queue.requestId,true);
        check(queue.next(merchant,0.2,exists,exists)==null, "reply alone is not inventory confirmation");
        present.remove(first.item);
        check(queue.next(merchant,0.3,exists,exists)==second, "second item follows acknowledged replicated removal");
        var stale=queue.requestId-1;
        queue.acknowledge(stale,false);
        check(queue.active, "stale reply cannot reject current sale");
        present.remove(second.item);
        check(queue.next(merchant,0.4,exists,exists)==null && queue.active, "replication before reply still waits");
        queue.acknowledge(queue.requestId,true);
        queue.next(merchant,0.5,exists,exists);
        check(!queue.active && queue.sold==2 && queue.error=="", "batch completes without automatic retries");
        present=[first.item,second.item]; queue.start(merchant,[first,second]);
        check(queue.next(merchant,1,exists,row -> row==second)==second, "changed, equipped, moved, unmarked or locked snapshot is skipped by eligibility");
        queue.acknowledge(queue.requestId,false);
        check(!queue.active && queue.error!="", "server rejection stops batch");
        queue.start(merchant,[first,second]); queue.next(merchant,2,exists,exists);
        check(queue.next(merchant,7.1,exists,exists)==null && !queue.active, "timeout stops with no duplicate sell");
        queue.start(merchant,[first]); queue.next({},8,exists,exists);
        check(!queue.active, "merchant or character change sends no further requests");
        queue.start(merchant,[first]); queue.next(merchant,9,exists,exists); var old=queue.requestId;
        queue.cancel(); queue.start(merchant,[second]); queue.next(merchant,10,exists,exists);
        queue.acknowledge(old,false);
        check(queue.active, "late callback from cancelled batch cannot affect a new one");
        queue.cancel();
        check(NativeJunk.isGuildMerchant({element:{inf:{props:{npc:{unit:"WanderingMerchant"}}}}}), "guild merchant uses stable native identity");
        check(!NativeJunk.isGuildMerchant({element:{inf:{props:{npc:{unit:"TODO_MOG_Merchant"}}}}}), "glory merchant does not receive guild-only action");
        trace('Item junk: $checks checks passed');
    }
}
