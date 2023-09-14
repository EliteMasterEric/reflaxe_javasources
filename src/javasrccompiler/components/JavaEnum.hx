package javasrccompiler.components;

#if (macro || java_runtime)
import haxe.macro.Type;
import reflaxe.BaseCompiler;
import reflaxe.data.EnumOptionData;
import reflaxe.helpers.OperatorHelper;

/**
 * The component responsible for compiling Haxe enums into Java source.
 */
class JavaEnum extends JavaBase {
	/**
	 * Implementation of `JavaCompiler.compileEnumImpl`.
	 */
	public function compile(enumType:EnumType, options:Array<EnumOptionData>):Null<String> {
		return null;
	}
}
#end
