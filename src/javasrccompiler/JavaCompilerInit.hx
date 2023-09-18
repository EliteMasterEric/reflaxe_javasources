package javasrccompiler;

#if (macro || java_runtime)
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.ReflectCompiler;

class JavaCompilerInit {
	public static function Start() {
		#if !eval
		Sys.println('JavaCompilerInit.Start can only be called from a macro context.');
		return;
		#end

		#if (haxe_ver < "4.3.0")
		Sys.println('Reflaxe/javasrc requires Haxe version 4.3.0 or greater.');
		return;
		#end

		ReflectCompiler.AddCompiler(new JavaCompiler(), {
			// If one module contains multiple classes, they will be output to separate files.
			fileOutputType: FilePerClass,
			// The file extension for Java source files.
			fileOutputExtension: '.java',
			// The compiler definition used to determine the output directory.
			outputDirDefineName: 'javasrc-output',
			// Only used in SingleFile fileOutputType.
			// defaultOutputFilename: 'Main.java',
			// A list of type paths that will be ignored and not generated.
			// For example, ignoring `haxe.iterators.ArrayIterator` and
			// generating to the target's native for-loop.
			ignoreTypes: [],
			// A list of variable names that cannot be used in the output.
			// These will automatically be renamed to resolve the conflict.
			reservedVarNames: reservedNames(),
			// Define the function used to directly inject unsafe native code.
			// See https://haxe.org/manual/target-syntax.html
			targetCodeInjectionName: '__java__',
			// If true, enforces @:nullSafety on all sources compiled to the target.
			enforceNullTyping: false,
			// If true, typedefs will be unwrapped before being processed and generated.
			unwrapTypedefs: true,
			// Whether "Everything is an Expression" is normalized.
			// Expressions are automatically split up where needed.
			normalizeEIE: true,

			// Can you redeclare variables of the same name in the same scope?
			preventRepeatVars: true,

			// Whether variables captured by lambdas are wrapped in an Array.
			// Useful as certain targets can't capture and modify a value unless stored by reference.
			wrapLambdaCaptureVarsInArray: false,

			// Whether to convert null coalescence to an if statement.
			convertNullCoal: false,

			// Convert the unary increment and decrement operators to their binop equivalents.
			convertUnopIncrement: false,

			// Whether to convert functions referenced by value into a lambda expression.
			wrapFunctionReferences: ExternOnly,

			// When wrapFunctionReferences is set to NativeMetaOnly, these are the metadata names
			// that will be used to determine if a function should be wrapped.
			wrapFunctionMetadata: [
				':native',
				':nativeFunctionCode'
			],

			// If true, only the module containing the "main" function and any classes it references will be compiled.
			smartDCE: true,

			// If true, std modules must be explicitly added during compilation.
			dynamicDCE: false,

			// List of metadata added to std classes, used by SmartDCE.
			customStdMeta: [],

			// If true, a map of ModuleTypes mapped by relevance to the implementation
			// will be provided. Useful when generating import statements.
			trackUsedTypes: true,

			// If true, the ClassHierarchyTracker will be initialized and enabled.
			trackClassHierarchy: true,

			// If true, any old output files which were not regenerated will be deleted.
			deleteOldOutput: true,

			// If false, throw an error if a function without a body is encountered.
			ignoreBodilessFunctions: false,

			// If true, externs are not passed to the JavaCompiler.
			ignoreExterns: true, 

			// If true, properties with no "real" value (both getter and setter are overridden)
			// will not be passed to the JavaCompiler.
			ignoreNonPhysicalFields: true,

			// If true, automatically handle metadata for classes, enums, and class fields.
			allowMetaMetadata: true,

			// The format used for native metadata (allowMetaMetadata).
			autoNativeMetaFormat: '@{}',

			// A list of metadata unique to the target, allowing Reflaxe to validate it.
			metadataTemplates: metadataTemplates(),
		});
	}

	/**
	 * Returns the full list of reserved names in Java.
	 */
	static function reservedNames() {
		// Thank you, Github Copilot.
		return [
			"abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class",
			"const", "continue", "default", "do", "double", "else", "enum", "extends", "false",
			"final", "finally", "float", "for", "goto", "if", "implements", "import", "instanceof",
			"int", "interface", "long", "native", "new", "null", "package", "private", "protected",
			"public", "return", "short", "static", "strictfp", "super", "switch", "synchronized",
			"this", "throw", "throws", "transient", "true", "try", "void", "volatile", "while"
		];
	}

	/**
	 * Returns the list of metadata templates used by the JavaCompiler.
 	 */
	static function metadataTemplates():Array<MetadataTemplate> {
		return [];
	}
}

typedef MetadataTemplate = {
	meta: haxe.macro.Compiler.MetadataDescription,
	disallowMultiple: Bool,
	paramTypes: Null<Array<reflaxe.BaseCompiler.MetaArgumentType>>,
	compileFunc: Null<(MetadataEntry, Array<String>) -> Null<String>>
};

#end
