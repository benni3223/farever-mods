package modupdatealerts;

/** Text for native FmtText labels, which parse both game markup and XML. */
class LiteralText {
    public static function escape(value:String):String {
        if (value == null) return "";
        var escaped = StringTools.htmlEscape(value);
        // BaseUI.formatTextToFmt also expands [references] and $functions().
        // Numeric entities survive that pass and decode as literal glyphs.
        return StringTools.replace(StringTools.replace(escaped, "[", "&#91;"), "$", "&#36;");
    }
}
