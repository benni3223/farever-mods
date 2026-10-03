package moresettings;
class SocialHooks {
    public static var errors:Array<String> = [];
    public static function report(error:Dynamic):Void errors.push(Std.string(error));
}
