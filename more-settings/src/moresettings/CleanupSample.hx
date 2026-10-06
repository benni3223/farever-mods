package moresettings;

/** Main-thread counters, copied into the existing slow-frame ring without allocation. */
class CleanupSample {
    public static inline var ACTIVE = 0;
    public static inline var DISABLED = 1;
    public static inline var INACTIVE = 2;
    public static inline var FAILED = 3;
    public static inline var DRIVER_MISMATCH = 4;
    public static inline var EMPTY = 5;
    public static inline var STAGED = 6;
    public static inline var SUBMITTED = 7;
    public static inline var QUEUE_LIMIT = 8;
    public static inline var LOW_MEMORY = 9;
    public static inline var UNKNOWN_MEMORY = 10;
    public static inline var ERROR = 11;
    public static inline var PRESSURE_JOIN = 12;
    public static inline var LIFECYCLE_JOIN = 13;
    public static inline var ERROR_JOIN = 14;
    static var labels = ["active", "disabled", "inactive", "failed", "driver-mismatch", "empty",
        "staged", "submitted", "queue-limit", "low-memory", "unknown-memory", "error",
        "pressure-join", "lifecycle-join", "error-join"];

    public var events = 0;
    public var queued = 0;
    public var staged = 0;
    public var submitted = 0;
    public var pendingMax = -1;
    public var free:Float = Math.NaN;
    public var budget:Float = Math.NaN;
    public var memoryReads = 0;

    public function new() {}
    public function reset():Void {
        events = queued = staged = submitted = memoryReads = 0;
        pendingMax = -1;
        free = budget = Math.NaN;
    }
    public function event(id:Int, count:Int = 0):Void {
        events |= 1 << id;
        if (id == STAGED) staged += count;
        if (id == SUBMITTED) submitted += count;
    }
    public function queue(count:Int, pending:Int):Void {
        queued += count;
        if (pending > pendingMax) pendingMax = pending;
    }
    public function memory(free:Float, budget:Float):Void {
        this.free = free; this.budget = budget; memoryReads++;
    }
    public function copyFrom(other:CleanupSample):Void {
        events = other.events; queued = other.queued; staged = other.staged;
        submitted = other.submitted; pendingMax = other.pendingMax;
        free = other.free; budget = other.budget; memoryReads = other.memoryReads;
    }
    static function mib(bytes:Float):String return Math.isFinite(bytes) ? Std.string(Math.round(bytes / 1048576)) : "unknown";

    /** Formatting is deferred with the rest of the freeze report. */
    public function describe():String {
        var seen = [for (i in 0...labels.length) if ((events & (1 << i)) != 0) labels[i]];
        return "cleanup={events=" + (seen.length == 0 ? "unobserved" : seen.join("|"))
            + ' queued=$queued staged=$staged submitted=$submitted pending-max=' + (pendingMax < 0 ? "unknown" : Std.string(pendingMax))
            + ' memory-reads=$memoryReads last-free-MiB=' + mib(free) + " last-budget-MiB=" + mib(budget) + "}";
    }
}
