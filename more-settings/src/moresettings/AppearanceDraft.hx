package moresettings;

import moresettings.GameAccess as G;

/** A private native skin object. No replicated state is touched before commit. */
class AppearanceDraft {
    public var skin(default, null):Dynamic;
    public var hero(default, null):Dynamic;
    public var committed(default, null) = false;
    var original:Dynamic;
    var layer:Dynamic;
    var player:Dynamic;
    var originalSignature:String;

    public function new(hero:Dynamic) {
        if (!available(hero)) throw "Enter the world with your character before changing appearance.";
        this.hero = hero;
        layer = G.field(hero, "layer");
        player = G.field(hero, "ownerPlayer");
        original = G.field(hero, "skinData");
        originalSignature = signature(original);
        skin = copy(original);
    }

    public static function available(hero:Dynamic):Bool {
        return hero != null && G.field(hero, "removed") != true && G.field(hero, "layer") != null
            && G.field(G.field(hero, "ownerPlayer"), "isMe") == true && G.field(hero, "skinData") != null;
    }

    public function valid(current:Dynamic):Bool {
        return !committed && current == hero && available(current) && G.field(current, "layer") == layer
            && G.field(current, "ownerPlayer") == player;
    }

    public function commit(current:Dynamic):Void {
        if (!valid(current)) throw "Your character changed. Close this window and try again.";
        if (G.field(hero, "skinData") != original || signature(original) != originalSignature)
            throw "Your appearance changed while this window was open. Close it and try again.";
        // A fresh object invokes the native @:client property's dirty tracking.
        // The normal server HeroData.save stores hero.skinData on both clients.
        var saved = copy(skin);
        G.call("ent.Unit", "set_skinData", hero, [saved]);
        if (signature(G.field(hero, "skinData")) != signature(saved))
            throw "The game could not apply the appearance. Try Save again.";
        committed = true;
    }

    public static function copy(source:Dynamic):Dynamic {
        var result = G.staticCall("data.UnitSkinData", "getDefaultSkinData", ["BaseHero"]);
        G.staticCall("data.UnitSkinData", "copySkinData", [source, result]);
        return result;
    }

    public static function refreshHero(hero:Dynamic):Void {
        // skinData stores the persistent customization; skin selects the active
        // body model. Both are native client-owned properties. updateSkin only
        // refreshes when the model changes; explicitly refresh same-model edits
        // too (hair, gradients, shapes, and template variants).
        G.call("ent.Unit", "set_skin", hero, [G.integer(G.field(G.field(hero, "skinData"), "template"))]);
        var view = G.field(hero, "unitView");
        if (view != null) G.call("client.UnitView", "applyModelInfo", view, [G.call("ent.Unit", "getSkin", hero)]);
    }

    static function signature(source:Dynamic):String {
        var values:Array<Dynamic> = [];
        for (key in ["template", "skinColor", "eyeColor", "hairColor", "hairColorSecondary",
            "hair", "facialHair", "eyebrows", "eyes", "face", "beard"])
            values.push(G.field(source, key));
        for (shape in G.array(G.field(source, "shapes")))
            values.push({name: G.text(G.field(shape, "name")), val: G.number(G.field(shape, "val"))});
        return haxe.Json.stringify(values);
    }

    /** These are the exact player-customization filters used by character creation. */
    public static function parts(all:Array<Dynamic>, type:Int):Array<Dynamic> {
        return all.filter(p -> G.integer(G.field(p, "type"), -1) == type && (G.integer(G.field(p, "flags")) & 1) != 0);
    }
    public static function colors(all:Array<Dynamic>, mask:Int):Array<Dynamic> {
        return all.filter(g -> G.field(g, "playerCustomization") == true && (G.integer(G.field(g, "bodyParts")) & mask) != 0);
    }
}
