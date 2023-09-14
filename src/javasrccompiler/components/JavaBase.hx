package javasrccompiler.components;

#if (macro || java_runtime)
import javasrccompiler.JavaCompiler;

class JavaBase {
	var compiler: JavaCompiler;

	public function new(compiler:JavaCompiler) {
		this.compiler = compiler;
	}
}
#end