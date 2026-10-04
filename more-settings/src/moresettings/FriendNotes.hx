package moresettings;

import moresettings.GameAccess as G;
import moresettings.AppearanceUi as Ui;

class FriendNotes {
    public static var enabled(default, null) = false;
    static var callbacks = new haxe.ds.ObjectMap<Dynamic, {old:Dynamic, callback:Void->Void}>();
    static var store = new FriendNotesStore("hlx/config/more-settings/friend-notes.json");

    public static function configure(value:Bool):Void {
        if (enabled == value) return;
        enabled = value;
        refresh();
    }

    static function friendView(object:Dynamic):Dynamic {
        while (object != null && !G.isA(object, "ui.win.FriendView")) object = G.field(object, "parent");
        return object;
    }
    static function identity(card:Dynamic):{owner:String, friend:String} {
        var me = G.call("ui.BaseElement", "get_myPlayer", card);
        var info = G.field(card, "pInfo");
        var player = G.field(info, "player");
        var uid = G.text(G.field(player, "uid"));
        if (uid == "") uid = G.text(G.field(info, "uid"));
        return {owner: G.text(G.field(me, "uid")), friend: uid};
    }

    /** Runs after native init, when the gear's existing actions are complete. */
    public static function attach(card:Dynamic):Void {
        if (!enabled || friendView(card) == null) return;
        var id = identity(card);
        if (id.owner == "" || id.friend == "" || id.owner == id.friend) return;
        var button = G.field(card, "settingsBtn");
        if (button == null) return;
        var note = store.get(id.owner, id.friend);
        var action:Dynamic = {
            name: note == "" ? "Add note" : "Edit note",
            extraAction: true,
            reason: () -> G.enumeration("EReason", "Ok"),
            action: () -> { try edit(card) catch (e:Dynamic) SocialHooks.report(e); }
        };
        var actions = G.field(button, "boundActions");
        var index = 0;
        var sendMessage = G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "icon"), "byId"), ["SendMessage"]);
        var sendName = G.text(G.field(sendMessage, "name"));
        var existing = G.array(actions);
        for (i in 0...existing.length) if (G.text(G.field(existing[i], "name")) == sendName) { index = i + 1; break; }
        G.call("ui.UIElement", "bindAction", button, [action, null]);
        actions = G.field(button, "boundActions");
        // Pop the native virtual value, not a reinterpretation of the array.
        var inserted = G.call("hl.types.ArrayObj", "pop", actions);
        G.call("hl.types.ArrayObj", "insert", actions, [index, inserted]);
        if (note != "") decorate(card, note);
    }

    static function edit(card:Dynamic):Void {
        if (!enabled || G.field(card, "removed") == true) return;
        var id = identity(card);
        var ui = G.call("ui.BaseElement", "get_baseUI", card);
        if (ui == null || id.owner == "" || id.friend == "") return;
        var info = G.field(card, "pInfo");
        var name = G.text(G.field(info, "name"), "friend");
        var note = store.get(id.owner, id.friend);
        var dialog = G.call("ui.BaseUI", "displayTextInputDialog", ui, [
            note == "" ? "Add friend note" : "Edit friend note",
            Ui.escape('Note for $name (30 characters maximum). Leave empty to remove.'), note,
            (text:String) -> {
                if (!enabled || identity(card).owner != id.owner) return;
                try { store.set(id.owner, id.friend, text); refresh(); }
                catch (e:Dynamic) {
                    SocialHooks.report(e);
                    Ui.message(ui, "Friend note", "Could not save this note. Your previous note has been kept.");
                }
            }, null
        ]);
        var input = G.field(G.field(dialog, "input"), "input");
        G.set(input, "maxCharacters", FriendNotesStore.LIMIT);
        // Use the same readable foreground as the settings text inputs.
        Ui.style(input, "color", 0xF5F0E8);
        G.call("h2d.Text", "set_textColor", input, [0xF5F0E8]);
        var buttons = G.array(G.field(dialog, "buttons"));
        for (i in 0...buttons.length)
            G.call("ui.comp.Button", "setText", buttons[i], [i == 0 ? "Save" : "Cancel"]);
    }

    static function classChild(parent:Dynamic, name:String):Dynamic {
        for (child in Ui.children(parent)) {
            var dom = G.field(child, "dom");
            if (dom != null && G.call("domkit.Properties", "hasClass", dom, [name]) == true) return child;
        }
        return null;
    }

    static function decorate(card:Dynamic, value:String):Void {
        var header = classChild(card, "header");
        var name = header == null ? null : classChild(header, "name");
        var desc = classChild(card, "desc");
        var detail:Dynamic = null;
        if (desc != null) for (child in Ui.children(desc)) if (G.isA(child, "ui.comp.FmtText")) { detail = child; break; }
        if (header == null || name == null || detail == null) return;
        // Plain Text makes arbitrary notes literal, never XML, icons or game
        // references. Scale the detail font down so it is smaller than both
        // the name and the class/level/location text.
        var label = G.create("h2d.Text", [G.field(detail, "font"), header]);
        Ui.absolute(header, label);
        G.call("h2d.Text", "set_lineBreak", label, [false]);
        G.call("h2d.Text", "set_textColor", label, [0x5b4334]);
        G.call("ui.UIElement", "set_textTip", card, [Ui.escape(value)]);
        var old = G.field(card, "onAfterReflow");
        var previousWidth = -1;
        var fitting = false;
        var fit = () -> {
            if (fitting) return;
            fitting = true;
            try {
                var width = G.number(G.field(card, "calculatedWidth"));
                if (width <= 0) width = G.number(G.call("h2d.Flow", "get_outerWidth", card));
                var right = classChild(card, "right-cont");
                var reserved = right == null ? 50.0 : Math.max(50, G.number(G.call("h2d.Flow", "get_outerWidth", right)) + 20);
                var available = Math.max(0, width - G.number(G.field(header, "x")) - reserved - 5);
                if (G.field(label, "font") != G.field(detail, "font"))
                    G.call("h2d.Text", "set_font", label, [G.field(detail, "font")]);
                var scale = G.number(G.field(detail, "scaleX"), 1) * 0.75;
                if (G.number(G.field(label, "scaleX"), 1) != scale)
                    G.call("h2d.Object", "setScale", label, [scale]);
                var text = " - " + value;
                var textWidth = G.number(G.call("h2d.Text", "calcTextWidth", label, [text]));
                // Native party rows append labels such as "(Leader)" to the
                // name. Keep those in the header's normal flow and place the
                // note after the complete header, reserving their width too.
                var captions = [name];
                var captionWidth = 0.0;
                var spacing = G.number(G.field(header, "horizontalSpacing"), 5);
                for (child in Ui.children(header)) {
                    if (child == name || !G.isA(child, "ui.comp.FmtText") || G.field(child, "visible") == false) continue;
                    captions.push(child);
                    var bounds = G.call("h2d.Object", "getBounds", child, [child, null]);
                    captionWidth += (G.number(G.field(bounds, "xMax")) - G.number(G.field(bounds, "xMin")))
                        * G.number(G.field(child, "scaleX"), 1) + spacing;
                }
                var nameWidth = Std.int(Math.max(60, available - captionWidth - Math.min(textWidth * scale, available * 0.6)));
                if (nameWidth != previousWidth) {
                    previousWidth = nameWidth;
                    G.call("ui.comp.FmtText", "set_textMultiline", name, [false]);
                    G.call("ui.comp.FmtText", "set_useEllipsis", name, [true]);
                    G.call("ui.comp.FmtText", "set_maxWidthText", name, [nameWidth]);
                }
                var nameBounds = G.call("h2d.Object", "getBounds", name, [header, null]);
                var x = G.number(G.field(nameBounds, "xMax"));
                for (caption in captions) {
                    var bounds = G.call("h2d.Object", "getBounds", caption, [header, null]);
                    x = Math.max(x, G.number(G.field(bounds, "xMax")));
                }
                var room = Math.max(0, available - x);
                var chars = [for (c in new haxe.iterators.StringIteratorUnicode(value)) String.fromCharCode(c)];
                while (chars.length > 0 && G.number(G.call("h2d.Text", "calcTextWidth", label, [text])) * scale > room) {
                    chars.pop(); text = " - " + chars.join("") + "…";
                }
                text = chars.length == 0 ? "" : text;
                if (G.text(G.field(label, "text")) != text) G.call("h2d.Text", "set_text", label, [text]);
                var b = G.call("h2d.Object", "getBounds", label, [label, null]);
                var y = (G.number(G.field(nameBounds, "yMin")) + G.number(G.field(nameBounds, "yMax"))) / 2
                    - (G.number(G.field(b, "yMin")) + G.number(G.field(b, "yMax"))) * scale / 2;
                Ui.position(label, x, y);
            } catch (e:Dynamic) SocialHooks.report(e);
            fitting = false;
        };
        var callback = () -> { if (old != null) old(); fit(); };
        callbacks.set(card, {old: old, callback: callback});
        G.set(card, "onAfterReflow", callback);
    }

    public static function detach(card:Dynamic):Void {
        var entry = callbacks.get(card);
        if (entry == null) return;
        if (G.field(card, "onAfterReflow") == entry.callback) G.set(card, "onAfterReflow", entry.old);
        callbacks.remove(card);
    }
    public static function dispose():Void {
        for (card in [for (card in callbacks.keys()) card]) detach(card);
    }

    /** Only runs on a settings change or save; no per-frame friend-list scan. */
    static function refresh():Void {
        var ui = G.current("ui.BaseUI", "current");
        var root = G.field(ui, "root");
        if (root == null) return;
        var walk:Dynamic->Void = null;
        walk = object -> {
            if (G.isA(object, "ui.win.FriendView")) G.call("ui.UIElement", "rebuild", object);
            else for (child in Ui.children(object)) walk(child);
        };
        walk(root);
    }
}
