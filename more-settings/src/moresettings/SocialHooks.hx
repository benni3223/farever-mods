package moresettings;

import hlx.runtime.HlxPrefixResult;
import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

class SocialHooks {
    static var hideConnections = false;
    static var reported:Map<String, Bool> = [];

    public static function configure(config:MoreSettingsConfig):Void {
        hideConnections = config.hideFriendConnectionNotifications;
        SocialChat.commandsEnabled = config.enableMissingSlashCommands;
        SocialChat.closeAfterSend = config.sendingMessageClosesChat;
        try FriendNotes.configure(config.enableFriendNotes) catch (e:Dynamic) report(e);
    }
    public static function dispose():Void { SocialChat.clear(); FriendNotes.dispose(); }
    public static function report(error:Dynamic):Void {
        var message = Std.string(error);
        if (reported.exists(message)) return;
        reported[message] = true;
        trace("[More Settings] Social: " + message);
    }

    @:hlx.postfix(lib.Input.isPressed)
    static function noteChatPressed(key:String, result:Bool):Bool {
        try return FriendNotes.chatPressed(key, result) catch (e:Dynamic) report(e);
        return result;
    }

    @:hlx.prefix(ui.hud.ChatBox.receiveMessage)
    static function filterConnectionMessage(instance:Dynamic, message:Dynamic):HlxPrefixResult<Void> {
        // sendSystemMessage is a server-only stub in the client. Server RPCs
        // enter ChatClient history directly, then the UI polls that history.
        // Filter the structured notification ID before creating a chat row;
        // never suppress friend state updates or match arbitrary player text.
        if (hideConnections && SocialCommands.connectionMessage(G.text(G.field(message, "notify")))) return Skip;
        return Continue;
    }

    @:hlx.prefix(ui.hud.ChatBox.handleCommand)
    static function command(instance:Dynamic, command:String, args:Dynamic):HlxPrefixResult<String> {
        if (!SocialChat.commandsEnabled) return Continue;
        var parsed = SocialCommands.parse(command, [for (value in G.array(args)) G.text(value)].join(" "));
        if (parsed == null) return Continue;
        try return SkipWith(SocialChat.run(instance, parsed)) catch (e:Dynamic) {
            report(e);
            try SocialChat.error(instance, "Could not complete this chat command.") catch (_:Dynamic) {}
            return SkipWith(null); // Never leak a failed private command into public chat.
        }
    }

    @:hlx.prefix(ui.hud.ChatBox.processMessage)
    static function beforeSend(instance:Dynamic, text:String):HlxPrefixResult<Void> {
        SocialChat.begin(instance);
        return Continue;
    }
    @:hlx.postfix(ui.hud.ChatBox.processMessage)
    static function afterSend(instance:Dynamic, text:String, result:Void):Void {
        try SocialChat.finish(instance) catch (e:Dynamic) report(e);
    }
    @:hlx.postfix(st.player.ChatClient.sendMessage)
    static function sent(instance:Dynamic, message:Dynamic, result:Void):Void SocialChat.sent(instance, message);
    @:hlx.postfix(st.player.ChatClient.localReceiveMessage)
    static function whisperEcho(instance:Dynamic, message:Dynamic, result:Void):Void SocialChat.sent(instance, message);

    @:hlx.postfix(ui.hud.ChatBox.receiveMessage)
    static function received(instance:Dynamic, message:Dynamic, result:Void):Void {
        try SocialChat.remember(message) catch (e:Dynamic) report(e);
    }
    @:hlx.prefix(ui.win.PlayerCard.init)
    static function beforeCardInit(instance:Dynamic):HlxPrefixResult<Void> {
        FriendNotes.detach(instance);
        return Continue;
    }
    @:hlx.prefix(ui.UIElement.onRemove)
    static function removed(instance:Dynamic):HlxPrefixResult<Void> {
        FriendNotes.detach(instance);
        return Continue;
    }
    @:hlx.postfix(ui.win.PlayerCard.init)
    static function friendCard(instance:Dynamic, result:Void):Void {
        try FriendNotes.attach(instance) catch (e:Dynamic) report(e);
    }
}
