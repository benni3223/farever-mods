import bettermodsettings.ActionButton;
import bettermodsettings.ActionButtonQueue;

class ActionButtonTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }

    static function main():Void {
        var plain = new ActionButton("example", {key: "run"});
        check(plain.topic == "better-mod-settings/action/example/run", "topic scoped to mod and button key");
        check(plain.label == "run" && plain.buttonText == "run", "missing text falls back to key");
        check(plain.colour == "default" && !plain.warningEnabled, "default colour and no warning");
        for (colour in ["default", "green", "red", "blue", "", null]) {
            var b = new ActionButton("example", {key: "run", colour: colour});
            check(b.colour == (colour == "green" || colour == "red" ? colour : "default"), "unknown colours use native default");
        }
        var descriptor:Dynamic = haxe.Json.parse('{"key":"reset","label":"Reset presets","buttonText":"Reset","colour":"red","warning":{"enabled":true,"warningText":"Delete all presets?"}}');
        var before = haxe.Json.stringify(descriptor);
        var warned = new ActionButton("example", descriptor);
        check(warned.warningEnabled && warned.warningText == "Delete all presets?", "nested warning parsed");
        check(warned.label == "Reset presets" && warned.buttonText == "Reset", "label and button text independent");
        check(haxe.Json.stringify(descriptor) == before, "reading descriptor is non-mutating");
        for (warning in [{enabled: true}, {enabled: true, warningText: ""}, {enabled: true, warningText: null}]) {
            var b = new ActionButton("example", {key: "reset", warning: warning});
            check(b.warningText == "Are you sure you want to continue?", "empty warning has useful fallback");
        }
        for (warning in [null, {}, {enabled: false}, {enabled: "true"}, {warningText: "Unused"}])
            check(!new ActionButton("example", {key: "run", warning: warning}).warningEnabled, "only boolean true enables warning");

        var queue = new ActionButtonQueue();
        check(queue.request(plain) == 0, "unwarned click queues directly");
        check(queue.takeNotifications().join(",") == plain.topic, "one notification per click");
        check(queue.takeNotifications().length == 0, "notification consumed once");
        var token = queue.request(warned);
        check(token > 0 && queue.takeNotifications().length == 0, "warning never executes on initial click");
        check(queue.request(warned) == -1 && queue.request(plain) == -1, "modal blocks additional button clicks");
        queue.complete(token + 1, true);
        check(queue.pending != null && queue.takeNotifications().length == 0, "unrelated callback cannot confirm");
        queue.complete(token, false);
        check(queue.pending == null && queue.takeNotifications().length == 0, "Cancel or Escape publishes nothing");
        queue.complete(token, true);
        check(queue.takeNotifications().length == 0, "late confirmation after cancel ignored");
        var next = queue.request(warned);
        queue.complete(token, true);
        check(queue.pending.token == next, "old popup cannot confirm newer popup");
        queue.complete(next, true);
        queue.complete(next, true);
        check(queue.takeNotifications().join(",") == warned.topic, "Continue publishes exactly once");
        token = queue.request(warned);
        queue.reset();
        next = queue.request(warned);
        queue.complete(token, true);
        check(queue.pending.token == next && queue.takeNotifications().length == 0, "disposed session callback ignored");
        queue.complete(next, false);
        queue.request(plain);
        queue.request(new ActionButton("another-mod", {key: "run"}));
        check(queue.takeNotifications().join(",") == plain.topic + ",better-mod-settings/action/another-mod/run", "mod routing and click order preserved");
        queue.request(plain);
        queue.reset();
        check(queue.takeNotifications().length == 0, "disposal drops queued actions");
        trace("Action button checks passed: " + checks);
    }
}
