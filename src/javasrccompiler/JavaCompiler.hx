package javasrccompiler;

// Make sure this code only exists at compile-time.
#if (macro || java_runtime)
// Import relevant Haxe macro types.
import haxe.macro.Expr;
import haxe.macro.Type;

// Import Reflaxe types
import reflaxe.PluginCompiler;
import reflaxe.data.ClassFuncData;
import reflaxe.data.ClassVarData;
import reflaxe.data.EnumOptionData;

// Import javasrc types
import javasrccompiler.components.JavaClass;
import javasrccompiler.components.JavaEnum;
import javasrccompiler.components.JavaExpression;
import javasrccompiler.components.JavaType;

using StringTools;

/**
 * The class used to compile the Haxe AST into your target language's code. 
 * This must extend from `BaseCompiler`. `PluginCompiler<T>` is a child class
 * that provides the ability for people to make plugins for your compiler.
 */
class JavaCompiler extends PluginCompiler<JavaCompiler> {
  public static final DEFAULT_PACKAGE = 'haxe.root';

  static final BootFilename = "Main.java";

	/**
	 * Handles implementation of `compileClassImpl`.
	 */
	public var classComp(default, null):JavaClass;

	/**
	 * Handles implementation of `compileEnumImpl`.
	 */
	public var enumComp(default, null):JavaEnum;

	/**
	 * Handles implementation of `compileExpressionImpl`.
	 */
	public var exprComp(default, null):JavaExpression;

	/**
	 * Handles implementation of `compileType`, `compileModuleType`, and `compileClassName`.
	 */
	public var typeComp(default, null):JavaType;

	public function new() {
		super();
		createComponents();
	}

	/**
	 * Constructs all the components of the compiler.
	 * See the `javasrccompiler.components` package for more info.
	 */
	inline function createComponents() {
		// Bypass Haxe null-safety not allowing `this` usage.
		@:nullSafety(Off) var self:JavaCompiler = this;

		classComp = new JavaClass(self);
		enumComp = new JavaEnum(self);
		exprComp = new JavaExpression(self);
		typeComp = new JavaType(self);
	}

	public override function onCompileStart() {
		setupMainFunction();
	}

	function setupMainFunction() {
		final mainExpr = getMainExpr();
		if (mainExpr != null) {
			final javaCode:String = compileExpressionOrError(mainExpr);
			appendToExtraFile(BootFilename, haxeBootContent(javaCode));
		}
	}

	/**
		Returns the content generated for the `HaxeBoot.cs`.

		TODO:
			Store `args` to use with `Sys.args()` later.
	**/
	function haxeBootContent(csCode: String) {
		return StringTools.trim('
package haxe.root;

class HaxeBoot {
	static void Main(string[] args) {
		${csCode};
	}
}
		');
	}

	/**
	 * Required for adding semicolons at the end of each line. Overridden from Reflaxe.
	 */
	override function formatExpressionLine(expr:String):String {
		return '$expr;';
	}

	/**
	 * Called at the end of compilation.
	 */
	public override function onCompileEnd() {}

	/**
	 * Generate the Java output given the Haxe class information.
	 * Given the haxe.macro.ClassType and its variables and fields, return the output String.
	 * If `null` is returned, the class is ignored and nothing is compiled for it.
	 */
	public function compileClassImpl(classType: ClassType, varFields: Array<ClassVarData>, funcFields: Array<ClassFuncData>): Null<String> {
		return classComp.compile(classType, varFields, funcFields);
	}

	/**
	 * Generate the Java output given the Haxe enum information.
	 */
	public function compileEnumImpl(enumType:EnumType, options:Array<EnumOptionData>):Null<String> {
		return enumComp.compile(enumType, options);
	}

	// ---

	/**
	 * Generates the Java type from `haxe.macro.Type`.
	 * A `Position` is provided so compilation errors can be reported to it.
	 */
	public function compileType(type:Type, pos:Position):String {
		final result = typeComp.compile(type, pos);
		if (result == null) {
			throw 'Type could not be generated: ${Std.string(type)}';
		}
		return result;
	}

	/**
	 * Generate Java output for `ModuleType` used in an expression
	 * (i.e. for cast or static access).
	 */
	public function compileModuleType(m:ModuleType):String {
		return typeComp.compileModuleExpression(m);
	}

	/**
	 * Get the name of the `ClassType` as it should appear in
	 * the Java output.
	 */
	public function compileClassName(classType:ClassType):String {
		return typeComp.compileClassName(classType);
	}

	// ---

	/**
	 * Generate the Java output for a function argument.
	 * Note: it's possible for an argument to be optional but not have an `expr`.
	 */
	public function compileFunctionArgument(t:Type, name:String, pos:Position, optional:Bool, expr:Null<TypedExpr> = null) {
		var result = '${compileType(t, pos)} ${compileVarName(name)}';
		if (expr != null) {
			result += ' = ${compileExpression(expr)}';
		} else {
			// TODO: ensure type is nullable
			if (optional) {
				result += ' = null';
			}
		}
		return result;
	}

	/**
	 * Generate the Java output given the Haxe typed expression (`TypedExpr`).
	 */
	public function compileExpressionImpl(expr:TypedExpr, topLevel:Bool):Null<String> {
		return exprComp.compile(expr, topLevel);
	}

	/**
	 * Remove blank white space at the end of each line,
	 * and trim empty lines.
	 */
	public function cleanWhiteSpaces(s:String):String {
		// Temporary workaround.

		// TODO: edit reflaxe SyntaxHelper.tab() so that it
		// doesn't add spaces/tabs to empty lines when indenting
		// a block, and make this method not needed anymore

		final lines = s.split('\n');
		for (i in 0...lines.length) {
			lines[i] = StringTools.rtrim(lines[i]);
		}
		return lines.join('\n');
	}
}
#end
