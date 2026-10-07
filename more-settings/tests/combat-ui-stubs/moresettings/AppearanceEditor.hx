package moresettings;

class AppearanceEditor {
    public static var requests = 0;
    public static function request():Void requests++;
    public static function report(error:Dynamic):Void throw error;
}
