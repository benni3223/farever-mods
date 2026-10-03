import moresettings.SocialCommands;
import moresettings.SocialChat;
import moresettings.FriendNotes;
import moresettings.FriendNotesStore;
import moresettings.SettingsData;
import moresettings.GameAccess as G;
import moresettings.SocialHooks;

class SocialTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw why + ': expected $expected, got $actual';
    }
    static function main():Void {
        parse(); notes(); chat(); menu();
        Sys.println('Social: $checks checks passed.');
    }
    static function parse():Void {
        eq(SocialCommands.parse("party", "Hello"), null, "existing command remains native");
        var parsed = SocialCommands.parse("W", '  "Friend With Spaces"   Hello there! ');
        eq(parsed.player, "Friend With Spaces", "quoted names");
        eq(parsed.message, "Hello there!", "whisper body");
        eq(parsed.error, "", "case-insensitive command");
        eq(SocialCommands.parse("w", "Thorcules").message, "", "open whisper without message");
        for (args in ["", '"unfinished', '"quoted"suffix', "Name unexpected"]) {
            eq(SocialCommands.parse("invite", args).error != "", true, "invalid invite has usage error");
        }
        eq(SocialCommands.parse("leave", "extra").error != "", true, "leave validates arguments");
        eq(SocialCommands.parse("invite", "Magé").player, "Magé", "accented name unchanged");
        eq(SocialCommands.connectionMessage("PlayerConnected"), true, "connected hidden");
        eq(SocialCommands.connectionMessage("PlayerDisconnected"), true, "disconnected hidden");
        for (id in ["PlayerFriendAdded", "PlayerGroup_AlreadyIn", "ErrorDefault"])
            eq(SocialCommands.connectionMessage(id), false, "other notifications unchanged");
        eq(SettingsData.defaults().enableMissingSlashCommands, false, "social changes opt-in");
    }
    static function notes():Void {
        eq(FriendNotesStore.clean("  Friend from Discord  "), "Friend from Discord", "trim saved note");
        eq(FriendNotesStore.clean("a\nb\tc"), "a b c", "single-line notes");
        eq(FriendNotesStore.clean("123456789012345678901234567890EXTRA"), "123456789012345678901234567890", "30-character limit");
        eq(FriendNotesStore.clean("Magé <3 [party] $gold"), "Magé <3 [party] $gold", "literal special characters saved");
        var emoji = [for (_ in 0...31) "😀"].join("");
        eq([for (c in new haxe.iterators.StringIteratorUnicode(FriendNotesStore.clean(emoji))) c].length, 30, "Unicode character limit");
        var dir = 'tests/social-tmp-${Std.random(1000000000)}';
        var path = dir + "/notes.json";
        var store = new FriendNotesStore(path);
        eq(store.get("me", "friend"), "", "new store empty");
        store.set("me", "friend", "Discord");
        store.set("other", "friend", "Raid");
        store = new FriendNotesStore(path);
        eq(store.get("me", "friend"), "Discord", "survives restart");
        eq(store.get("other", "friend"), "Raid", "isolated by local account");
        eq(store.get("me", "other-friend"), "", "uses friend UID, not name");
        store.set("me", "friend", "   ");
        eq(new FriendNotesStore(path).get("me", "friend"), "", "empty save deletes note");
        sys.io.File.saveContent(path, "broken JSON");
        var failed = false;
        try new FriendNotesStore(path).set("me", "friend", "new") catch (_:Dynamic) failed = true;
        eq(failed, true, "corrupt file cannot silently lose existing notes");
        eq(sys.io.File.getContent(path), "broken JSON", "corrupt original preserved");
        for (p in sys.FileSystem.readDirectory(dir)) sys.FileSystem.deleteFile(dir + "/" + p);
        sys.FileSystem.deleteDirectory(dir);
    }
    static function player(uid:String, name:String):Dynamic return {uid:uid,__uid:uid+"-network",name:name,removed:false};
    static function chat():Void {
        var me:Dynamic = player("me", "My Name");
        var local:Dynamic = player("local", "Thorcules");
        me.layer = {players:{array:[me,local]}};
        me.group = {players:{array:[me]}};
        me.whispers = {};
        me.friendList = {friends:[{uid:"remote",metadata:{heroName:"Magé",connected:true}},
            {uid:"offline",metadata:{heroName:"Offline",connected:false}}]};
        G.me = me;
        var box:Dynamic = {chatClient:{},errors:[],focused:true,channel:"public"};
        SocialChat.clear(); SocialChat.closeAfterSend = true;
        SocialChat.begin(box);
        eq(SocialChat.run(box,SocialCommands.parse("w", "Magé")), null, "bare whisper consumes command");
        eq(box.channel.args[0], "remote", "native whisper uses UID");
        SocialChat.finish(box);
        eq(box.focused, true, "bare whisper keeps focus");
        SocialChat.begin(box);
        eq(SocialChat.run(box,SocialCommands.parse("w", "Magé Hello")), "Hello", "only message sent through native path");
        SocialChat.sent(box.chatClient,{text:"Hello"}); SocialChat.finish(box);
        eq(box.focused, false, "whisper submission closes editor");
        box.focused = true;
        SocialChat.begin(box); SocialChat.sent(box.chatClient,{text:"ordinary message"}); SocialChat.finish(box);
        eq(box.focused,false,"normal sends close editor");
        box.focused=true; SocialChat.closeAfterSend=false;
        SocialChat.begin(box); SocialChat.sent(box.chatClient,{text:"ordinary message"}); SocialChat.finish(box);
        eq(box.focused,true,"disabled preserves native focus");
        SocialChat.closeAfterSend=true;
        for (args in ["Missing", "Offline"]) {
            SocialChat.begin(box); var channel = box.channel;
            eq(SocialChat.run(box,SocialCommands.parse("w",args+" private text")),null,"failed whisper consumed");
            eq(box.channel,channel,"failed whisper does not change channel");
            SocialChat.finish(box); eq(box.focused,true,"failed command retains typing focus");
        }
        G.calls=[]; SocialChat.begin(box);
        SocialChat.run(box,SocialCommands.parse("invite","Thorcules")); SocialChat.finish(box);
        var invites=G.calls.filter(c -> c.name=="invitePlayer");
        eq(invites.length,1,"one native local invite");
        eq(invites[0].args[0],"local-network","native network ID for local player");
        G.calls=[]; SocialChat.begin(box);
        SocialChat.run(box,SocialCommands.parse("invite","Magé")); SocialChat.finish(box);
        eq(G.calls.filter(c -> c.name=="sendInviteGroup")[0].args[0],"remote","cross-area friend invite via whispers");
        G.reason="NotAllowed"; G.calls=[];
        SocialChat.run(box,SocialCommands.parse("invite","Thorcules"));
        eq(G.calls.filter(c -> c.name=="invitePlayer").length,0,"party permissions preserved"); G.reason="Ok";
        G.calls=[]; SocialChat.run(box,SocialCommands.parse("leave",""));
        eq(G.calls.filter(c -> c.name=="requestLeave").length,0,"solo leave rejected");
        me.group.players.array.push(local); SocialChat.run(box,SocialCommands.parse("leave",""));
        eq(G.calls.filter(c -> c.name=="requestLeave").length,1,"native party leave");
        SocialChat.remember({sender:{uid:"chat-only",name:"Someone"}});
        eq(SocialChat.run(box,SocialCommands.parse("w","Someone")),null,"chat sender recognized");
        eq(box.channel.args[0],"chat-only","recent chat resolves UID");
        SocialChat.remember({sender:{uid:"duplicate",name:"Someone"}});
        var channel=box.channel;
        SocialChat.run(box,SocialCommands.parse("w","Someone secret"));
        eq(box.channel,channel,"ambiguous name never guesses recipient");
        SocialChat.clear(); G.calls=[];
        SocialChat.run(box,SocialCommands.parse("w","Someone secret"));
        eq(G.calls.filter(c -> c.name=="setChannel").length,0,"session change clears cached identities");
    }
    static function node(type:String, parent:Dynamic, classes:Array<String>):Dynamic {
        var n:Dynamic={type:type,parent:parent,dom:{classes:classes},children:[],rebuilds:0};
        if (parent!=null) parent.children.push(n); return n;
    }
    static function menu():Void {
        var root=node("root",null,[]); G.ui={root:root};
        var view=node("ui.win.FriendView",root,[]);
        var card=node("ui.win.PlayerCard",view,[]);
        card.pInfo={uid:"friend",player:null,name:"Lionsden"}; card.settingsBtn={boundActions:[
            {name:"Send message"},{name:"Invite to party"},{name:"Remove friend"}]};
        var dir = 'tests/social-menu-tmp-${Std.random(1000000000)}';
        var path = dir + "/notes.json";
        @:privateAccess FriendNotes.store = new FriendNotesStore(path);
        FriendNotes.configure(false); FriendNotes.attach(card);
        eq(card.settingsBtn.boundActions.length,3,"disabled menu unchanged");
        FriendNotes.configure(true); FriendNotes.attach(card);
        eq(card.settingsBtn.boundActions.length,4,"one note action added");
        eq(card.settingsBtn.boundActions[1].name,"Add note","inserted after Send message");
        eq(card.settingsBtn.boundActions[2].name,"Invite to party","native order preserved");
        var action:Dynamic = card.settingsBtn.boundActions[1]; action.action();
        eq(G.dialog.input.input.maxCharacters,30,"editor limit configured");
        eq(G.dialog.buttons[0].text,"Save","save explicit");
        eq(G.dialog.buttons[1].text,"Cancel","cancel available");
        eq(sys.FileSystem.exists(path), false, "opening/canceling editor does not save");
        G.saved("Friend from Discord");
        eq(new FriendNotesStore(path).get("me", "friend"), "Friend from Discord", "dialog save persists note");
        var rebuilt = node("ui.win.PlayerCard", view, []);
        rebuilt.pInfo = card.pInfo; rebuilt.settingsBtn = {boundActions:[{name:"Send message"},{name:"Invite to party"},{name:"Remove friend"}]};
        rebuilt.calculatedWidth = 340; rebuilt.x = 0.0;
        var header = node("flow", rebuilt, ["header"]); header.x = 25.0;
        var name = node("ui.comp.FmtText", header, ["name"]); name.text = "Lionsden";
        var desc = node("flow", rebuilt, ["desc"]);
        var detail = node("ui.comp.FmtText", desc, []); detail.font = {}; detail.scaleX = 1.0;
        var nativeReflows = 0;
        var original = () -> nativeReflows++;
        rebuilt.onAfterReflow = original;
        FriendNotes.attach(rebuilt);
        var actions:Array<Dynamic> = rebuilt.settingsBtn.boundActions;
        eq(actions[1].name,"Edit note","existing note can be edited");
        rebuilt.onAfterReflow();
        var label:Dynamic = header.children[header.children.length-1];
        eq(label.text," - Friend from Discord","hyphen and note after name");
        eq(label.scaleX,0.75,"note smaller than detail text");
        eq(label.x,56.0,"note follows rendered name");
        G.calls=[]; rebuilt.onAfterReflow();
        eq(G.calls.filter(c -> c.name=="set_text" || c.name=="set_font" || c.name=="setScale" || c.name=="set_maxWidthText").length,0,"stable layout does not invalidate itself");
        name.text="AnExtremelyLongCharacterName"; rebuilt.calculatedWidth=180; rebuilt.onAfterReflow();
        var displayed:String = label.text;
        eq(displayed.indexOf("…")>=0 || displayed=="",true,"narrow rows truncate note instead of covering gear");
        eq(rebuilt.textTip,"Friend from Discord","full text available on hover");
        FriendNotes.detach(rebuilt);
        eq(rebuilt.onAfterReflow,original,"rebuild/removal restores original callback");
        actions[1].action(); eq(G.dialog.input.input.text,"Friend from Discord","editor prefills existing note");
        G.saved(""); eq(new FriendNotesStore(path).get("me","friend"),"","saving empty removes note");
        FriendNotes.configure(false);
        eq(view.rebuilds,4,"toggles and saves refresh existing list");
        eq(SocialHooks.errors.length,0,"no UI adapter errors");
        for (p in sys.FileSystem.readDirectory(dir)) sys.FileSystem.deleteFile(dir+"/"+p);
        sys.FileSystem.deleteDirectory(dir);
    }
}
