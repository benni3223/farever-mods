import moresettings.AppearanceDraft;
import moresettings.GameAccess as G;

class AppearanceTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, message:String):Void {
        checks++;
        if (a != b) throw message + ': expected $b, got $a';
    }
    static function rejects(action:Void->Void, message:String):Void {
        var failed = false;
        try action() catch (_:Dynamic) failed = true;
        eq(failed, true, message);
    }
    static function hero():Dynamic return {
        ownerPlayer: {isMe: true}, layer: {}, removed: false, unitView: {},
        skinData: {template: 1, skinColor: "Skin1", hair: "Hair1", hairColor: "Red", hairColorSecondary: "Gold",
            shapes: [{name: "BS_Nose1", val: 1.0}, {name: "BS_Face1", val: 0.0}]}
    };

    static function main():Void {
        var h = hero(), original:Dynamic = h.skinData;
        var d = new AppearanceDraft(h);
        eq(d.skin != original, true, "The editor gets a private skin object");
        eq(d.skin.shapes != original.shapes, true, "Shape arrays are private");
        eq(d.skin.shapes[0] != original.shapes[0], true, "Nested shape records are private");
        d.skin.template = 2; d.skin.hair = "Hair2"; d.skin.shapes[0].val = 0.5;
        eq(h.skinData.template, 1, "Body edits cannot change the live character");
        eq(h.skinData.hair, "Hair1", "Part edits cannot change the live character");
        eq(h.skinData.shapes[0].val, 1.0, "Shape edits cannot change the live character");
        eq(G.writes, 0, "Preview does not dirty replicated state");
        eq(G.bodyWrites, 0, "Preview does not change the live model index");
        d = null; // Cancel/close only discards the draft; there is no rollback setter.
        eq(h.skinData == original, true, "Cancel keeps the exact original object");
        eq(new AppearanceDraft(h).skin.hair, "Hair1", "Reopen reads saved appearance");

        d = new AppearanceDraft(h); d.skin.hair = "Hair2"; d.skin.template = 2;
        G.failCopy = true;
        rejects(() -> d.commit(h), "Preparation failure is not a partial save");
        eq(h.skinData == original, true, "Failed preparation leaves original intact");
        eq(d.committed, false, "Failed save can be retried");
        G.failCopy = false; G.ignoreWrite = true;
        rejects(() -> d.commit(h), "A rejected native setter cannot report success");
        eq(d.committed, false, "Rejected setter leaves draft open");
        G.ignoreWrite = false; d.commit(h);
        eq(G.writes, 1, "Save uses the native replicated property exactly once");
        eq(h.skinData.hair, "Hair2", "Save applies the draft");
        eq(h.skinData.hairColorSecondary, "Gold", "Untouched secondary hair color is preserved");
        eq(h.skinData != d.skin, true, "Saved state is detached from the preview");
        AppearanceDraft.refreshHero(h);
        eq(h.skin, 2, "Apply the saved body through the native model setter");
        eq(G.bodyWrites, 1, "Body setter runs only after Save");
        eq(G.refreshes, 1, "Save immediately refreshes visible customization");
        AppearanceDraft.refreshHero(h);
        eq(G.refreshes, 2, "Same-model edits also refresh; native updateSkin alone would skip them");
        d.skin.shapes[0].val = 0.2;
        eq(h.skinData.shapes[0].val, 1.0, "Late preview changes cannot mutate saved shapes");
        eq(d.valid(h), false, "A committed editor is closed");
        rejects(() -> d.commit(h), "Double activation cannot save twice");

        h = hero(); d = new AppearanceDraft(h);
        rejects(() -> d.commit(hero()), "Switching character cancels the session");
        h.layer = {}; eq(d.valid(h), false, "Changing worlds invalidates the draft");
        h = hero(); d = new AppearanceDraft(h); h.ownerPlayer = {isMe: true};
        eq(d.valid(h), false, "Replacing the player invalidates the draft");
        h = hero(); d = new AppearanceDraft(h); h.removed = true;
        rejects(() -> d.commit(h), "A removed hero cannot be updated");
        h = hero(); d = new AppearanceDraft(h); h.skinData.hair = "External";
        rejects(() -> d.commit(h), "Concurrent appearance edits cannot be overwritten");
        h = hero(); d = new AppearanceDraft(h); h.skinData.shapes[0].val = 0.25;
        rejects(() -> d.commit(h), "Concurrent nested shape edits are detected");
        h = hero(); d = new AppearanceDraft(h); h.skinData = AppearanceDraft.copy(h.skinData);
        rejects(() -> d.commit(h), "Replacing the skin invalidates an old draft");
        eq(G.writes, 1, "Rejected sessions perform no writes");
        rejects(() -> new AppearanceDraft(null), "Menu with no hero is handled");
        h = hero(); h.ownerPlayer.isMe = false;
        rejects(() -> new AppearanceDraft(h), "Another player's appearance is never editable");
        h = hero(); h.skinData.shapes = null; d = new AppearanceDraft(h); d.commit(h);
        eq(h.skinData.shapes, null, "Characters without explicit shapes can be saved");

        var parts:Array<Dynamic> = [{id: "Hair", type: 0, flags: 1}, {id: "NPC", type: 0, flags: 0},
            {id: "Brow", type: 2, flags: 3}, {id: "Beard", type: 3, flags: 1}];
        eq(AppearanceDraft.parts(parts, 0).length, 1, "NPC-only hair is excluded");
        eq(AppearanceDraft.parts(parts, 2)[0].id, "Brow", "Player flag accepts additional flags");
        eq(AppearanceDraft.parts(parts, 3)[0].id, "Beard", "Facial hair uses creation type");
        var colors:Array<Dynamic> = [{id: "Skin", bodyParts: 4, playerCustomization: true},
            {id: "HairEye", bodyParts: 3, playerCustomization: true},
            {id: "NPC", bodyParts: 7, playerCustomization: false}, {id: "Unset", bodyParts: 7}];
        eq(AppearanceDraft.colors(colors, 4).length, 1, "Only player-enabled skin gradients");
        eq(AppearanceDraft.colors(colors, 1)[0].id, "HairEye", "Hair color mask");
        eq(AppearanceDraft.colors(colors, 2)[0].id, "HairEye", "Eye color mask");

        var format:Dynamic = haxe.Json.parse(sys.io.File.getContent("configFormats.json"));
        var categories:Array<String> = [], action:Dynamic = null;
        for (entry in (cast format.configs:Array<Dynamic>)) {
            if (entry.type == "title") categories.push(entry.label);
            if (entry.key == "changeAppearance") action = entry;
        }
        eq(categories.slice(0, 3).join(","), "General,Combat,Appearance", "Appearance follows Combat");
        eq(action.type, "button", "Appearance is an action, not a saved checkbox");
        eq(action.buttonText, "Change Appearance", "Requested button label");
        eq(action.colour, "default", "Requested default button color");
        Sys.println('Appearance tests passed ($checks checks)');
    }
}
