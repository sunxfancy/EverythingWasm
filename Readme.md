## Why this project?

This project is used to demonstrate how to create a playground for many different
lanugages which is hard to implement purely in client side. It contains scripts
to build all related languages (include compilers and build systems) into wasm
and run them in a in-memory file system. You can run those languages in a webpage
without any server side support.

## Online Demo


## How to build

1. Install Docker
2. Run `make` in the root directory of this project

There are a few targets in the Makefile:

- `make clang` to build clang and llvm toolchains into a single binary file
- `make clang-format` to build clang-format
- `make python` to build cpython


## Reference
https://github.com/jprendes/emception