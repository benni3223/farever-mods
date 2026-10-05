package itemutilities;

import haxe.ds.ObjectMap;
import itemutilities.InspectAccess as G;
import itemutilities.InspectUi as Ui;

private class UtilityControl {
    public var owner:Dynamic;
    public var key:String;
    public var root:Dynamic;
    public var selector:Dynamic;
    public var save:Dynamic;
    public var background:Dynamic;
    public var backgroundColor:Int = -1;
    public var presetSkinCopied = false;
    public var seen:Int = -1;
    public var action:Void->Void;
    public var select:Int->Void;
    public var enabled = true;
    public var width = -1;
    public var height = -1;
    public function new(owner:Dynamic, key:String) { this.owner = owner; this.key = key; }
}

/** Native children inherit window ordering, scroll masks and hit testing. */
class NativeUtilityUi {
    static var owners = new ObjectMap<Dynamic, Map<String, UtilityControl>>();
    static var controls:Array<UtilityControl> = [];
    static var frame = 0;
    static var nextId = 0;

    public static function beginFrame():Void frame++;
    public static function endFrame():Void {
        for (entry in controls.copy()) if (entry.seen != frame) remove(entry);
    }
    public static function forget(owner:Dynamic):Void {
        var entries = owners.get(owner);
        if (entries != null) for (entry in [for (entry in entries) entry]) remove(entry);
    }
    static function remove(entry:UtilityControl):Void {
        controls.remove(entry);
        var entries = owners.get(entry.owner);
        if (entries != null) {
            entries.remove(entry.key);
            if (!entries.iterator().hasNext()) owners.remove(entry.owner);
        }
        entry.enabled = false;
        entry.action = null;
        entry.select = null;
        // A dropdown list lives outside its button; close it before detaching.
        if (entry.selector != null) G.call("ui.comp.Dropdown", "close", entry.selector, [null]);
        if (G.field(entry.root, "parent") != null) G.call("h2d.Object", "remove", entry.root);
    }
    static function get(owner:Dynamic, key:String, create:UtilityControl->Void):UtilityControl {
        var entries = owners.get(owner);
        if (entries == null) { entries = []; owners.set(owner, entries); }
        var entry = entries.get(key);
        if (entry != null && G.field(entry.root, "parent") != owner) { remove(entry); entry = null; }
        if (entry == null) {
            entry = new UtilityControl(owner, key);
            try create(entry) catch (error:Dynamic) { remove(entry); throw error; }
            // Native construction may run removal hooks, so fetch the map again.
            entries = owners.get(owner);
            if (entries == null) { entries = []; owners.set(owner, entries); }
            entries.set(key, entry);
            controls.push(entry);
        }
        entry.seen = frame;
        return entry;
    }
    static function node(kind:String, owner:Dynamic, args:Array<Dynamic>):Dynamic
        return G.field(Ui.node(kind, G.field(owner, "dom"), args, "itemUtilitiesNative" + nextId++), "obj");
    static function attach(owner:Dynamic, object:Dynamic):Void Ui.absolute(owner, object);
    static function live(entry:UtilityControl):Bool {
        if (!entry.enabled || entry.seen != frame) return false;
        var object = entry.root;
        if (G.field(object, "parent") != entry.owner || G.call("h2d.Object", "getScene", object) == null) return false;
        while (object != null) {
            if (G.field(object, "visible") == false || G.field(object, "removed") == true) return false;
            object = G.field(object, "parent");
        }
        return true;
    }
    static function place(entry:UtilityControl, rect:OverlayRect):Void {
        var w = Std.int(Math.round(rect.width)), h = Std.int(Math.round(rect.height));
        if (w != entry.width || h != entry.height) {
            Ui.size(entry.root, w, h);
            entry.width = w; entry.height = h;
        }
        if (G.field(entry.root, "x") != rect.left || G.field(entry.root, "y") != rect.top)
            Ui.position(entry.root, rect.left, rect.top);
    }

    public static function button(owner:Dynamic, key:String, pixels:OverlayRect, icon:String,
            tooltip:String, action:Void->Void, selected:Bool = false):Void {
        if (owner == null) return;
        var rect = NativeUiLayout.localRect(owner, pixels);
        if (rect == null) return;
        var entry = get(owner, key, entry -> {
            entry.root = node("button", owner, [""]);
            attach(owner, entry.root);
            Ui.padding(entry.root, 0);
            // Keep native hit testing/tooltips, but retain our darker utility
            // palette instead of the default pale button skin.
            Ui.style(entry.root, "background-alpha", 0.);
            var artwork = G.create("h2d.Object", [entry.root]);
            attach(entry.root, artwork);
            NativeUtilityIcons.smooth(artwork);
            entry.background = G.create("h2d.Graphics", [artwork]);
            var graphics = G.create("h2d.Graphics", [artwork]);
            NativeUtilityIcons.draw(graphics, icon);
            G.call("ui.UIElement", "set_onClick", entry.root, [() -> {
                if (live(entry) && entry.action != null) entry.action();
            }]);
        });
        entry.action = action;
        var resized = entry.width != Math.round(rect.width) || entry.height != Math.round(rect.height);
        place(entry, rect);
        if (resized) {
            NativeUtilityIcons.background(entry.background, entry.width, entry.height);
        }
        var pressed = G.field(entry.root, "pushed") != null;
        var hovered = G.field(entry.root, "hasHover") == true;
        var color = selected
            ? (pressed ? 0x7D5933 : hovered ? 0xAD854F : 0x946E40)
            : (pressed ? 0x524A45 : hovered ? 0x7A7069 : 0x665E59);
        if (color != entry.backgroundColor) {
            G.call("h3d.Vector4Impl", "setColor", G.field(entry.background, "color"), [color | 0xFF000000]);
            entry.backgroundColor = color;
        }
        if (G.field(entry.root, "textTip") != tooltip)
            G.call("ui.UIElement", "set_textTip", entry.root, [tooltip]);
        if (G.field(entry.root, "selected") != selected)
            G.call("ui.UIElement", "set_selected", entry.root, [selected]);
    }

    public static function badge(slot:Dynamic):Void {
        get(slot, "badge", entry -> {
            entry.root = G.create("h2d.Graphics", [slot]);
            attach(slot, entry.root);
            Ui.position(entry.root, 40, 7);
            NativeUtilityIcons.draw(entry.root, "badge");
        });
    }
    public static function lockInput(slot:Dynamic, action:Void->Void):Void {
        var entry = get(slot, "lock-input", entry -> {
            entry.root = G.create("h2d.Interactive", [48.,48.,slot,null]);
            attach(slot, entry.root);
            G.set(entry.root, "propagateEvents", false);
            G.set(entry.root, "cancelEvents", false);
            G.set(entry.root, "enableRightButton", true);
            G.call("h2d.Interactive", "set_cursor", entry.root, [G.current("hxd.Cursor", "Button")]);
            G.set(entry.root, "onClick", (event:Dynamic) -> {
                if (G.field(event, "button") == 0 && live(entry) && entry.action != null) entry.action();
            });
            // Consume item actions while allowing the parent inventory to scroll.
            G.set(entry.root, "onWheel", (event:Dynamic) -> G.set(event, "propagate", true));
        });
        entry.action = action;
    }

    public static function presets(owner:Dynamic, key:String, pixels:OverlayRect, busy:Bool, selected:Int,
            select:Int->Void, save:Void->Void):Void {
        if (owner == null) return;
        var rect = NativeUiLayout.localRect(owner, pixels);
        if (rect == null) return;
        var entry = get(owner, key, entry -> {
            entry.root = node("flow", owner, []);
            attach(owner, entry.root); Ui.padding(entry.root, 0);
            entry.selector = node("dropdown", entry.root, [false,false,"options-dropdown-list"]);
            attach(entry.root, entry.selector);
            var options = G.call("hl.types.ArrayObj", "slice", G.field(entry.selector, "items"), [0,0]);
            for (i in 0...PresetSlots.COUNT)
                G.call("hl.types.ArrayObj", "pushDyn", options, [{name:PresetSlots.label(i),value:i,icon:null,group:null}]);
            G.call("ui.comp.Dropdown", "set_options", entry.selector, [options]);
            G.set(entry.selector, "onSelectOption", (_:Dynamic) -> {
                if (live(entry) && entry.select != null) {
                    var index = G.integer(G.field(entry.selector, "selectedIndex"), -1);
                    if (PresetSlots.valid(index)) entry.select(index);
                }
            });
            entry.save = node("button", entry.root, ["Set"]);
            attach(entry.root, entry.save);
            G.call("ui.UIElement", "set_onClick", entry.save, [() -> {
                if (live(entry) && entry.action != null) entry.action();
            }]);
        });
        entry.select = select; entry.action = save;
        var resized = entry.width != Math.round(rect.width) || entry.height != Math.round(rect.height);
        place(entry, rect);
        if (resized) {
            var selectorWidth = Std.int(rect.width * PresetSlots.SELECTOR_WIDTH / PresetSlots.CONTROLS_WIDTH);
            var saveWidth = Std.int(rect.width * PresetSlots.SET_WIDTH / PresetSlots.CONTROLS_WIDTH);
            Ui.size(entry.selector, selectorWidth, entry.height);
            // Dropdown owns a separate, CSS-sized button. Sizing only the
            // wrapper leaves that button at its default 300px width, behind Set.
            Ui.padding(entry.selector, 0);
            var selectButton = G.field(entry.selector, "select");
            Ui.padding(selectButton, 0);
            for (side in ["left", "right"]) Ui.style(selectButton, "padding-" + side, 8);
            Ui.size(selectButton, selectorWidth, entry.height);
            Ui.size(entry.save, saveWidth, entry.height);
            Ui.position(entry.save, entry.width - saveWidth, 0);
        }
        if (G.field(entry.selector, "selectedIndex") != selected)
            G.call("ui.comp.Dropdown", "initSelectedIndex", entry.selector, [selected]);
        matchPresetSkin(entry);
        entry.enabled = !busy;
        if (G.field(entry.selector, "enable") == busy) G.call("ui.comp.Dropdown", "set_enable", entry.selector, [!busy]);
        if (G.field(entry.save, "enable") == busy) G.call("ui.UIElement", "set_enable", entry.save, [!busy]);
        if (busy && G.call("ui.comp.Dropdown", "isOpen", entry.selector) == true)
            G.call("ui.comp.Dropdown", "close", entry.selector, [null]);
    }

    static function matchPresetSkin(entry:UtilityControl):Void {
        if (entry.presetSkinCopied) return;
        // Wait for the native button's CSS to settle, then reuse its actual
        // nine-slice skin. This matches Set's color, corners and UI scaling.
        var tile = G.field(entry.save, "backgroundTile");
        if (tile == null || G.field(entry.save, "hasHover") == true || G.field(entry.save, "pushed") != null) return;
        Ui.style(G.field(entry.selector, "select"), "background", {
            tile:tile,
            borderL:G.integer(G.field(entry.save, "borderLeft")),
            borderR:G.integer(G.field(entry.save, "borderRight")),
            borderT:G.integer(G.field(entry.save, "borderTop")),
            borderB:G.integer(G.field(entry.save, "borderBottom"))
        });
        entry.presetSkinCopied = true;
    }

    public static function onPointerEvent(event:Dynamic):Void {
        if (controls.length == 0 || Type.enumConstructor(G.field(event, "kind")) != "EPush") return;
        var ui = G.current("ui.BaseUI", "current");
        if (ui == null) return;
        var target:Dynamic = null;
        var resolved = false;
        for (entry in controls) {
            if (entry.selector == null || G.call("ui.comp.Dropdown", "isOpen", entry.selector) != true) continue;
            if (!resolved) { target = G.call("ui.BaseUI", "getTopInteractiveElement", ui, [null]); resolved = true; }
            if (!inside(entry.selector, target) && !inside(G.field(entry.selector, "listWindow"), target))
                G.call("ui.comp.Dropdown", "close", entry.selector, [null]);
        }
    }
    public static function onWindowDisplayed(window:Dynamic):Void {
        for (entry in controls) {
            if (entry.selector == null || G.call("ui.comp.Dropdown", "isOpen", entry.selector) != true) continue;
            if (window != G.field(entry.selector, "listWindow") && !inside(window, entry.root))
                G.call("ui.comp.Dropdown", "close", entry.selector, [null]);
        }
    }
    static function inside(root:Dynamic, target:Dynamic):Bool
        return root != null && target != null && (root == target || G.call("h2d.Object", "contains", root, [target]) == true);
}
