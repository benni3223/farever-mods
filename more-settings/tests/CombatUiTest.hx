import moresettings.MinionHealthBars;
import moresettings.BarbershopButton;
import moresettings.SettingsData;
import moresettings.AppearanceEditor;
import moresettings.GameAccess as G;

class CombatUiTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, label:String):Void {
        checks++;
        if (actual != expected) throw label + ": expected " + expected + ", got " + actual;
    }
    static function bar(unit:Dynamic, parentType = "ui.hud.FoeWidget", visible = true):Dynamic
        return {unit:unit, visible:visible, removed:false, parent:{type:parentType, parent:null, callbacks:new Array<Float->Void>()}};
    static function unit(layer:Dynamic, owner:Dynamic, enemy = false):Dynamic
        return {type:"ent.Foe", summonOwner:owner, enemy:enemy, layer:layer, removed:false};

    static function minions():Void {
        MinionHealthBars.clear(); MinionHealthBars.configure(false);
        var layer:Dynamic = {};
        G.hero = {layer:layer};
        var own = bar(unit(layer, G.hero));
        var ally = bar(unit(layer, {}));
        var enemy = bar(unit(layer, {}, true));
        var ordinary = bar(unit(layer, null));
        var otherZone = bar(unit({}, G.hero));
        var player = bar({type:"ent.Hero", layer:layer}, "ui.hud.HeroWidget");
        var boss = bar(unit(layer, {}), "ui.hud.BossInfo");
        var initiallyHidden = bar(unit(layer, {}), "ui.hud.FoeWidget", false);
        for (b in [own, ally, enemy, ordinary, otherZone, player, boss, initiallyHidden]) MinionHealthBars.attach(b);
        eq(own.visible, true, "disabled keeps own summon bar");
        eq(own.parent.callbacks.length, 1, "updates live on the widget, not the hidden child");
        MinionHealthBars.configure(true);
        eq(own.visible, false, "hides own minion health");
        eq(ally.visible, false, "hides allied minion health");
        for (b in [enemy, ordinary, otherZone, player, boss]) eq(b.visible, true, "unrelated health bars stay native");
        eq(player.parent.callbacks.length, 0, "no callback on player bars");
        eq(boss.parent.callbacks.length, 0, "no callback on boss HUD");
        G.call("ui.UIElement", "set_visible", own, [true]);
        eq(own.visible, false, "native visibility refresh cannot reveal a filtered bar");
        G.call("ui.UIElement", "set_visible", ally, [false]);
        MinionHealthBars.configure(false);
        eq(own.visible, true, "disabling restores native visible bar");
        eq(ally.visible, false, "disabling respects a later native hide");
        eq(initiallyHidden.visible, false, "disabling never reveals an originally hidden bar");
        G.call("ui.UIElement", "set_visible", ally, [true]);
        MinionHealthBars.configure(true);
        own.unit.enemy = true;
        @:privateAccess MinionHealthBars.refresh(own, true);
        eq(own.visible, true, "hostility change restores the enemy bar");
        ally.unit.summonOwner = null;
        @:privateAccess MinionHealthBars.refresh(ally, true);
        eq(ally.visible, true, "no-longer-summoned unit restores its bar");
        own.unit.enemy = false;
        @:privateAccess MinionHealthBars.refresh(own, true);
        eq(own.visible, false, "friendly again hides its bar");
        MinionHealthBars.clear();
        eq(own.visible, true, "session cleanup restores tracked visibility");
        MinionHealthBars.configure(false);
    }

    static function barber():Void {
        BarbershopButton.clear(); AppearanceEditor.requests = 0;
        var panel:Dynamic = {children:new Array<Dynamic>()}; panel.dom = {obj:panel};
        var helmet:Dynamic = {slot:"Slot_Head", parent:{}, bounds:{xMin:55.0,xMax:115.0,yMin:150.0,yMax:210.0}};
        var page:Dynamic = {unit:G.hero, scene:{parent:panel}, buttons:{items:[helmet]}, removed:false,
            callbacks:new Array<Float->Void>()};
        BarbershopButton.attach(page);
        var children:Array<Dynamic> = panel.children;
        eq(children.length, 1, "one native button added");
        var button = children[0];
        eq(button.text, "Barbershop", "requested label");
        eq(button.props.isAbsolute, true, "button does not move the model or appearance slots");
        eq(button.minWidth, 140, "button width fits the whitespace");
        eq(button.x, 15.0, "button centered over helmet and inset from edge");
        eq(button.y, 92.0, "button above helmet with a gap");
        eq(G.relativeTo == panel, true, "native panel coordinates used for UI scaling");
        var click:Void->Void = button.onClick; click();
        eq(AppearanceEditor.requests, 1, "click requests the existing editor");
        helmet.bounds.xMin = 75; helmet.bounds.xMax = 135; helmet.bounds.yMin = 200;
        var callbacks:Array<Float->Void> = page.callbacks;
        for (callback in callbacks) callback(0.016);
        eq(button.x, 35.0, "native layout changes move the anchor");
        eq(button.y, 142.0, "anchor follows vertical changes");
        page.unit = {};
        for (callback in callbacks) callback(0.016);
        click();
        eq(button.visible, false, "not offered for another player's appearance");
        eq(AppearanceEditor.requests, 1, "stale button cannot edit another character");
        page.unit = G.hero; page.callbacks = [];
        BarbershopButton.attach(page);
        eq(children.length, 1, "rebuild replaces rather than duplicates the button");
        click();
        eq(AppearanceEditor.requests, 1, "replaced button action is inert");
        BarbershopButton.forget(page);
        var nextClick:Void->Void = children[0].onClick; nextClick();
        eq(AppearanceEditor.requests, 1, "removed page action is inert");
        BarbershopButton.clear();
    }

    static function descriptor():Void {
        var config = SettingsData.defaults();
        eq(config.disableDamageNumbers, false, "damage hiding opt-in");
        eq(config.hideAlliedMinionHealthBars, false, "minion bar hiding opt-in");
        var descriptor:Dynamic = haxe.Json.parse(sys.io.File.getContent("configFormats.json"));
        var rows:Array<Dynamic> = descriptor.configs;
        var keys = [for (row in rows) Std.string(row.key)];
        eq(keys.indexOf("disableDamageNumbers"), keys.indexOf("fancyDamageNumbers") + 1, "damage toggle follows fancy numbers");
        var social = [for (row in rows) Std.string(row.label)].indexOf("Social");
        eq(keys[social - 1], "hideAlliedMinionHealthBars", "minion bars last in Combat");
        for (row in rows) {
            if (row.type == "title") eq(["Appearance", "Unfocused Volume", "Fast Travel Music"].indexOf(row.label), -1, "retired sections removed");
            eq(["changeAppearance", "adjustUnfocusedVolume", "backgroundVolume", "adjustFastTravelVolume", "fastTravelVolume"].indexOf(row.key), -1, "retired controls removed");
        }
    }
    static function main():Void {
        minions(); barber(); descriptor();
        trace('Combat UI: $checks checks passed.');
    }
}
