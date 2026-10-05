import moresettings.CrabgantuaWarnings as W;
import moresettings.SettingsData;
import moresettings.GameAccess as G;

class CrabgantuaWarningsTest {
    static var checks = 0;
    static final lessEqual:Dynamic = {name: "native LessEqual"};
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw why + ": expected " + expected + ", got " + actual;
    }
    static function pass(name:String, write:Bool = false):Dynamic return {
        name:name, passId:name, depthTest:lessEqual, testBits:lessEqual, depthWrite:write, writeBits:write,
        nextPass:null, shaders:{nativeAnimatedShader:true}, blendSrc:"native alpha", culling:"native culling"
    };
    static function fx(p:Dynamic):Dynamic return {materials:[{passes:p}], removed:false, localTime:0.75, playSpeed:1.};
    static function area(effect:Dynamic, skill:String = "R1CrabBoss_Heroic_Avalanche"):Dynamic
        return {baseSkill:{inf:{id:skill}}, telegraphFx:effect};
    static function visibleArea(effect:Dynamic, skill:String = "R1CrabBoss_Heroic_Avalanche"):Dynamic {
        var warning = area(effect, skill);
        warning.obj = {children:[]};
        warning.range = 4.;
        return warning;
    }

    static function main():Void {
        eq(SettingsData.defaults().crabgantuaRockfallWarnings, true, "New setting is enabled by default");
        W.configure(true);
        var color = pass("beforeTonemappingAlpha", true), depth = pass("depthPrepass", true);
        var shader = color.shaders;
        color.nextPass = depth;
        var effect = fx(color), warning = area(effect);
        var unrelated = pass("beforeTonemappingAlpha");
        for (skill in ["R1CrabBoss_NayasFury", "R1CrabBoss_ChitinousExoskeleton_Spike", "AnotherBoss_Rockfall"])
            W.attach(area(fx(unrelated), skill));
        eq(unrelated.name, "beforeTonemappingAlpha", "Water and unrelated boss effects keep native rendering");
        W.attach(warning);
        eq(color.name, "overlay", "Circle is scheduled after the water and distortion stages");
        eq(color.passId, "overlay", "Native setter updates the render queue ID");
        eq(color.depthTest, G.always, "Water above the ground circle cannot reject its pixels by depth");
        eq(color.testBits, G.always, "Depth override reaches native render-state bits");
        eq(color.depthWrite, false, "Circle does not occlude later HUD/overlay objects");
        eq(color.writeBits, false, "Depth-write override reaches native render-state bits");
        eq(color.shaders, shader, "Native warning animation shader is retained, not cloned or frozen");
        eq(color.blendSrc, "native alpha", "Native blending is retained");
        eq(color.culling, "native culling", "Native mesh culling is retained");
        eq(depth.name, "depthPrepass", "Depth-only passes do not move into a colour output");
        eq(depth.depthWrite, true, "Depth-only pass properties are not modified");
        eq(effect.localTime, 0.75, "Warning timing is untouched");
        var reads = G.materialReads, writes = G.writes;
        W.sync(effect); W.attach(warning); W.sync(effect);
        eq(G.materialReads, reads, "Material traversal is once per active FX, not every frame");
        eq(G.writes, writes, "Subsequent frames do not rewrite render state");
        W.configure(false);
        eq(color.name, "beforeTonemappingAlpha", "Disabling restores the active warning's original stage");
        eq(color.passId, "beforeTonemappingAlpha", "Original queue ID restored");
        eq(color.depthTest, lessEqual, "Exact native enum identity is restored");
        eq(color.depthWrite, true, "Original depth-write preference restored");
        W.configure(true);
        eq(color.name, "overlay", "Reenabling applies to an existing warning immediately");
        W.forget(effect);
        eq(color.name, "beforeTonemappingAlpha", "Pool reset/removal restores the original stage first");
        W.sync(effect);
        eq(color.name, "beforeTonemappingAlpha", "A reused FX is not still marked as an Avalanche warning");
        W.attach(area(effect, "OtherSkill"));
        eq(color.name, "beforeTonemappingAlpha", "Pool reuse by another skill stays native");

        W.configure(false);
        var late = fx(pass("forwardAlpha")); late.materials = [];
        W.attach(area(late));
        W.configure(true);
        late.materials = [{passes:pass("forwardAlpha")}];
        W.sync(late);
        eq(late.materials[0].passes.name, "overlay", "Meshes created at first sync are picked up");
        W.configure(false);
        eq(late.materials[0].passes.name, "forwardAlpha", "Late-created mesh restores normally");

        var duplicated = pass("afterTonemappingDecal"), duplicateFx = fx(duplicated);
        duplicateFx.materials.push({passes:duplicated});
        W.attach(area(duplicateFx)); W.configure(true); W.configure(false);
        eq(duplicated.name, "afterTonemappingDecal", "Shared pass within one FX is saved and restored only once");

        var bad = pass("forwardAlpha", true), badFx = fx(bad);
        W.configure(true); G.failNextDepthTest = true;
        W.attach(area(badFx));
        eq(bad.name, "forwardAlpha", "Partial native failure rolls back the pass name");
        eq(bad.depthTest, lessEqual, "Partial failure keeps original depth state");
        eq(bad.depthWrite, true, "Partial failure keeps original depth writes");
        W.sync(badFx);
        eq(bad.name, "overlay", "An interrupted application can retry cleanly");
        W.dispose();
        eq(bad.name, "forwardAlpha", "World shutdown restores active warnings");
        eq(duplicated.name, "afterTonemappingDecal", "World shutdown restores all warnings");
        W.sync(badFx);
        eq(bad.name, "forwardAlpha", "World shutdown releases all tracking");

        var decal = pass("beforeTonemappingDecal"), decalFx = fx(decal), landing = visibleArea(decalFx);
        W.attach(landing);
        eq(decal.name, "overlay", "Colour decal stage previously missed by the filter is covered");
        eq(landing.obj.children.length, 1, "One independent boundary is attached to the landing location");
        var outline = landing.obj.children[0];
        eq(outline.children.length, 2, "Boundary has a dark backing and bright core");
        eq(outline.children[0].width, 6., "Backing uses a readable screen-space width");
        eq(outline.children[1].width, 3., "Core leaves a contrasting border visible");
        for (mesh in (cast outline.children:Array<Dynamic>)) {
            eq(mesh.material.passes.name, "overlay", "Independent boundary renders after water");
            eq(mesh.material.passes.depthTest, G.always, "Water depth cannot reject the independent boundary");
            eq(mesh.material.passes.depthWrite, false, "Boundary does not modify scene depth");
            eq(mesh.points.length, 65, "Smooth closed circle is built once");
            eq(mesh.points[0][0], mesh.points[64][0], "Closure uses exact matching x");
            eq(mesh.points[0][1], mesh.points[64][1], "Closure uses exact matching y");
            for (point in (cast mesh.points:Array<Dynamic>))
                eq(Math.abs(Math.sqrt(point[0] * point[0] + point[1] * point[1]) - 4.) < 0.00001,
                    true, "Boundary matches the native damage radius");
            eq(mesh.flushed, true, "Geometry is finalized without per-frame rebuilds");
        }
        var created = G.created.length;
        W.sync(decalFx); W.attach(landing);
        eq(G.created.length, created, "Repeated sync/attach does not allocate more outlines");
        W.configure(false);
        eq(outline.removed, true, "Disabling immediately removes the supplemental boundary");
        eq(landing.obj.children.length, 0, "Disabling leaves no scene children behind");
        eq(decal.name, "beforeTonemappingDecal", "Disabling restores the decal pass");
        W.configure(true);
        eq(landing.obj.children.length, 1, "Enabling during the warning restores the boundary");
        W.end(landing);
        eq(landing.obj.children.length, 0, "Impact removes the boundary before the native FX fades");
        W.configure(false); W.configure(true); W.sync(decalFx);
        eq(landing.obj.children.length, 0, "Toggling during the fade cannot resurrect a completed warning");
        W.forget(decalFx);
        eq(decal.name, "beforeTonemappingDecal", "FX pooling restores its native pass");
        var other = visibleArea(decalFx, "R1CrabBoss_NayasFury");
        W.attach(other);
        eq(other.obj.children.length, 0, "Water and pooled FX reused by other skills never receive a boundary");

        var lateFx = fx(pass("forwardAlpha")), lateArea = area(lateFx);
        W.attach(lateArea);
        lateArea.obj = {children:[]}; lateArea.range = 7.;
        W.sync(lateFx);
        eq(lateArea.obj.children.length, 1, "Late scene attachment retries even after materials were patched");
        eq(lateArea.obj.children[0].children[0].points[0][0], 7., "Native override radius is respected");
        W.forget(lateFx);
        eq(lateArea.obj.children.length, 0, "Unexpected FX removal also removes its outline");

        var failureFx = fx(pass("forwardAlpha")), failureArea = visibleArea(failureFx);
        G.failNextDepthTest = true;
        W.attach(failureArea);
        eq(failureArea.obj.children.length, 0, "Failed boundary construction leaves no orphan geometry");
        created = G.created.length;
        W.sync(failureFx);
        eq(G.created.length, created, "Persistent creation failures cannot allocate on every render frame");
        W.configure(false); W.configure(true);
        eq(failureArea.obj.children.length, 1, "Reenabling can retry failed boundary creation without duplicates");
        W.end({telegraphFx:null});
        W.dispose();
        eq(failureArea.obj.children.length, 0, "World shutdown removes all independent boundaries");
        W.configure(false);
        Sys.println('Crabgantua warnings: $checks checks passed.');
    }
}
