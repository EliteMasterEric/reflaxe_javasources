package javasrccompiler.util;

#if macro
class VersionUtil {
    public static function getHaxeVersion():String {
        return haxe.macro.Context.definedValue("haxe_ver");
    }
}
#end