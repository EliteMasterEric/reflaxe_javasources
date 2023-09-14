package javasrccompiler.components;

import haxe.macro.Context;
#if (macro || cs_runtime)

import haxe.macro.Expr;
import haxe.macro.Type;

import reflaxe.compiler.EverythingIsExprSanitizer;
import reflaxe.helpers.OperatorHelper;

using reflaxe.helpers.NameMetaHelper;
using reflaxe.helpers.SyntaxHelper;
using reflaxe.helpers.TypedExprHelper;

/**
 * The component responsible for compiling Haxe
 * typed expressions into C#.
**/
class JavaExpression extends JavaBase {
	/**
		Calls `compiler.compileExpressionOrError`.
	**/
	function _compileExpression(e: TypedExpr):String {
		return compiler.compileExpressionOrError(e);
	}

	/**
	 * Implementation of `JavaCompiler.compileExpressionImpl`.
	 */
	public function compile(expr: TypedExpr, topLevel: Bool):Null<String> {
		switch(expr.expr) {
			case TConst(constant): return compileConstant(constant);
			case TLocal(v): return compiler.compileVarName(v.name, expr);
			case TIdent(s): return compiler.compileVarName(s, expr);
			case TArray(e1, e2): return  '${_compileExpression(e1)}[${_compileExpression(e2)}]';
			case TUnop(op, postFix, e): return compileUnop(op, e, postFix);
			case TBinop(op, e1, e2): return compileBinop(op, e1, e2);
			case TField(e, fa): return compileFieldAccess(e, fa);
			case TTypeExpr(m): return compiler.compileModuleType(m);

			case TBreak: return 'break';
			case TContinue: return 'continue';

			case TThrow(subExpr): return 'throw ${_compileExpression(subExpr)}';
			case TReturn(maybeExpr): return (maybeExpr != null) ? 'return ${_compileExpression(maybeExpr)}' : 'return';

			case TParenthesis(e):
				if(!EverythingIsExprSanitizer.isBlocklikeExpr(e)) {
					return '(${_compileExpression(e)})';
				} else {
					return _compileExpression(e);
				}

			case TObjectDecl(fields):
				// TODO: Anonymous structure expression?
				return 'TObjectDecl()';

			case TArrayDecl(el):
				// TODO: Array expression?
				// result = "new type[] {" + el.map(e -> _compileExpression(e)).join(", ") + "}";
				return null;

			case TCall(e, el):
				// Check for @:nativeFunctionCode (built-in Reflaxe feature)
				final nfc = compiler.compileNativeFunctionCodeMeta(e, el);
				if(nfc != null) {
					return nfc;
				} else {
					final arguments = el.map(e -> _compileExpression(e)).join(", ");
					return '${_compileExpression(e)}($arguments)';
				}

			case TNew(classTypeRef, _, el):
				// Check for @:nativeFunctionCode (built-in Reflaxe feature)
				final nfc = compiler.compileNativeFunctionCodeMeta(expr, el);
				if(nfc != null) {
					return nfc;
				} else {
					final args = el.map(e -> _compileExpression(e)).join(', ');
					final className = compiler.compileClassName(classTypeRef.get());
					return 'new $className($args)';
				}

			case TFunction(tfunc):
				// TODO: Lambda?
				return null;

			case TVar(tvar, maybeExpr):
				var result = compiler.compileType(tvar.t, expr.pos) + " " + compiler.compileVarName(tvar.name, maybeExpr);

				// Not guaranteed to have expression, be careful!
				if(maybeExpr != null) {
					final e = _compileExpression(maybeExpr);
					result += ' = $e';
				}

				return result;
				
			case TBlock(expressionList):
				// TODO: Should we still generate even if empty?
				if(expressionList.length > 0) {
					return '{\n ${toIndentedScope(expr)} \n}';
				}
				return null;
				
			case TFor(tvar, iterExpr, blockExpr):
				// TODO: When is TFor even provided (usually converted to TWhile)?
				// Will C# foreach work?
				var result = "foreach(var " + tvar.name + " in " + _compileExpression(iterExpr) + ") {\n";
				result += toIndentedScope(blockExpr);
				result += "\n}";
				return result;

			case TIf(condExpr, ifContentExpr, elseExpr): return compileIf(condExpr, ifContentExpr, elseExpr);

			case TWhile(condExpr, blockExpr, normalWhile):
				final csExpr = _compileExpression(condExpr);
				if(normalWhile) {
					var result = 'while($csExpr) {\n';
					result += toIndentedScope(blockExpr);
					result += '\n}';
					return result;
				} else {
					var result = 'do {\n';
					result += toIndentedScope(blockExpr);
					result += '} while($csExpr);';
					return result;
				}

			case TSwitch(switchedExpr, cases, edef):
				// Haxe only generates `TSwitch` for switch statements only using numbers (I think?).
				// So this should be safe to translate directly to C# switch.
				var result = 'switch(${_compileExpression(switchedExpr)}) {\n';
				for(c in cases) {
					result += '\n';
					for(v in c.values) {
						result += "\tcase" + _compileExpression(v) + ':\n';
					}
					result += toIndentedScope(c.expr).tab();
					result += "\t\tbreak;";
				}
				if(edef != null) {
					result += '\n';
					result += '\tdefault:\n';
					result += toIndentedScope(edef).tab();
					result += '\t\tbreak;';
				}
				return result;

			case TTry(e, catches):
				var result = 'try {\n';
				result += toIndentedScope(e);
				result += '\n}';
				// TODO: Might need to guarantee Haxe exception type?
				// Use PlatformConfig
				for(c in catches) {
					result += 'catch(${compiler.compileFunctionArgument(c.v.t, c.v.name, expr.pos, false, null)}) {\n';
					result += toIndentedScope(c.expr);
					result += '\n}';
				}
				return result;

			case TCast(subExpr, maybeModuleType):
				var result = _compileExpression(subExpr);

				// Not guaranteed to have module, be careful!
				if(maybeModuleType != null) {
					result = "(" + result + " as " + compiler.compileModuleType(maybeModuleType) + ")";
				}
				return result;

			case TMeta(metadataEntry, subExpr): 
				// TODO: Handle expression meta?
				// Only works if `-D retain-untyped-meta` is enabled.
				return _compileExpression(subExpr);

			case TEnumParameter(subExpr, enumField, index):
				// TODO
				// Given an expression that is an instance of an enum,
				// generate the Java code to extract a value from this enum.
				return null;

			case TEnumIndex(subExpr):
				// TODO
				// Given an expression that is an instance of an enum,
				// generate the Java code to extract its index.
				return '';

			default:
				return null;
		}
	}

	/**
		Generate a block scope from an expression.

		If the typed expression is `TypedExprDef.TBlock`, then each
		sub-expression is compiled on a new line.

		Otherwise, the expression is compiled normally.

		Each line of the output is preemptively tabbed.
	**/
	function toIndentedScope(e: TypedExpr): String {
		var el = switch(e.expr) {
			case TBlock(el): el;
			case _: [e];
		}

		return (el.length == 0) ? '' : compiler.compileExpressionsIntoLines(el).tab();
	}

	/**
	 * Generate an expression given a `TConstant` (from `TypedExprDef.TConst`).
	 */
	function compileConstant(constant: TConstant): String {
		return switch(constant) {
			case TInt(i): Std.string(i);
			case TFloat(s): s;
			case TString(s): compileString(s);
			case TBool(b): b ? 'true' : 'false';
			case TNull: 'null';
			case TThis: 'this';
			case TSuper: 'super';
		}
	}

	/**
	 * Generate the String literal for Java given its contents.
	 */
	function compileString(stringContent: String): String {
		return '"' + StringTools.replace(StringTools.replace(stringContent, '\\', '\\\\'), '"', '\\"') + '"';
	}

	/**
	 * Generate an expression given a `Binop` (binary operation) and two typed expressions (from `TypedExprDef.TBinop`).
	 */
	function compileBinop(op: Binop, e1: TypedExpr, e2: TypedExpr): String {
		var csExpr1 = _compileExpression(e1);
		var csExpr2 = _compileExpression(e2);
		final operatorStr = OperatorHelper.binopToString(op);
		return csExpr1 + ' ' + operatorStr + ' ' + csExpr2;
	}

	/**
	 * Generate an expression given a `Unop` (unary operation) and typed expression (from `TypedExprDef.TUnop`).
	 */
	function compileUnop(op: Unop, e: TypedExpr, isPostfix: Bool): String {
		final csExpr = _compileExpression(e);
		final operatorStr = OperatorHelper.unopToString(op);
		return isPostfix ? (csExpr + operatorStr) : (operatorStr + csExpr);
	}

	/**
	 * Generate an expression given a `FieldAccess` and typed expression (from `TypedExprDef.TField`).
	 */
	function compileFieldAccess(e: TypedExpr, fa: FieldAccess):String {
		final nameMeta: NameAndMeta = switch(fa) {
			case FInstance(_, _, classFieldRef): classFieldRef.get();
			case FStatic(_, classFieldRef): classFieldRef.get();
			case FAnon(classFieldRef): classFieldRef.get();
			case FClosure(_, classFieldRef): classFieldRef.get();
			case FEnum(_, enumField): enumField;
			case FDynamic(s): { name: s, meta: null };
		}

		return if(nameMeta.hasMeta(":native")) {
			nameMeta.getNameOrNative();
		} else {
			final name = compiler.compileVarName(nameMeta.getNameOrNativeName());

			// Check if a special field access and intercept.
			switch(fa) {
				case FStatic(clsRef, cfRef): {
					final cf = cfRef.get();
					final className = compiler.compileClassName(clsRef.get());
					// TODO: generate static access
					// return ...
				}
				case FEnum(_, enumField): {
					// TODO: generate enum access
					// return ...
				}
				case _:
			}

			final csExpr = _compileExpression(e);

			// Check if a special field access that requires the compiled expression.
			switch(fa) {
				case FAnon(classFieldRef): {
					// TODO: generate anon struct access
					// return ...
				}
				case _:
			}

			csExpr + "." + name;
		}
	}

	/**
	 * Compile an `if` statement given a conditional expression, if content expression, and else content expression.
	 */
	function compileIf(condExpr: TypedExpr, ifContentExpr: TypedExpr, elseExpr: Null<TypedExpr>):String {
		var result = 'if(${_compileExpression(condExpr.unwrapParenthesis())}) {\n';
		result += toIndentedScope(ifContentExpr);
		if(elseExpr != null) {
			switch(elseExpr.expr) {
				case TIf(condExpr2, ifContentExpr2, elseExpr2): {
					// The body of the else expression is another if statement.
					result += '\n} else ${compileIf(condExpr2, ifContentExpr2, elseExpr2)}';
				}
				case _: {
					result += '\n} else {\n';
					result += toIndentedScope(elseExpr);
					result += '\n}';
				}
			}
		} else {
			result += '\n}';
		}
		return result;
	}
}
#end