package dpsmeter;

/** Interpreter boundary: record actual notification output without native UI. */
class NativeKillPopups {
    public var rows:Array<{id:String, message:String, category:String, count:Int, goal:Int}> = [];
    public function new(config:MeterConfig.MeterSettings) {}
    public function show(id:String, message:String, category:String, count:Int, goal:Int, now:Float, recordId:Int = 0):Void
        rows.push({id: id, message: message, category: category, count: count, goal: goal});
    public function clear():Void rows = [];
    public function update(active:Bool, now:Float):Void {}
    public function recordResult(result:BossRecords.BossRecordResponse, now:Float):Void {}
}
