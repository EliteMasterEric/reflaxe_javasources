# Reflaxe JavaSources

This Haxe library utilizes Reflaxe to provide a custom compilation target which generates Java sources (`.java` files).

This is intended to act as a replacement for the existing [Tier 3 Java target](https://haxe.org/documentation/introduction/compiler-targets.html), for use cases where the Tier 1 JVM target (which directly produces `.class` files) is not suitable.

## Installation and Usage

1. Download the project using Haxelib `haxelib git reflaxe_javasources https://github.com/EliteMasterEric/reflaxe_javasources`
2. Add the library to your project `-lib reflaxe_javasources`
3. Set the output folder `-D javasrc-output=out`

## Development

Clone the repository, run `haxelib run hmm install` to install dependencies.

Run `./test.sh` to build the test suite.

Run `cd ./test && haxe ./Test-Real.hxml` to build the test suite with the original Tier 3 target, for comparison.
