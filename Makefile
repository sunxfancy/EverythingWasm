LLVM=llvm-project-18.1.8.src
PYTHON_VERSION=3.12.4
PYTHON=Python-$(PYTHON_VERSION)
BROTLI=brotli-1.1.0

PWD=$(shell pwd)
gen_linker_flags=-DCMAKE_EXE_LINKER_FLAGS="$(1)" -DCMAKE_SHARED_LINKER_FLAGS="$(1)" -DCMAKE_MODULE_LINKER_FLAGS="$(1)"
COMMA=,
SRC=/src

DOCKER_RUN=docker run -it --rm  -v "$(PWD):/src" -w /src --user `id -u`  everything_wasm
WRAP_JS=bash $(SRC)/tooling/wrap-mjs/wrap-mjs.sh

ifeq ($(INSIDE_DOCKER),)

.PHONY: all clang clang-format python clean help
all: clang wasm-ld

clang: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
clang-debug: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
clang-format: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
wasm-ld: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
wasm-ld-debug: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
python: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
brotli: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
brotli-native: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
wasm-package: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
configure/%: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
upstream/%:  .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
pack/%:  .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@

.target/docker: Dockerfile
	@docker build -t everything_wasm .
	@mkdir -p .target && touch $@

shell: .target/docker
	$(DOCKER_RUN) bash

clean:
	rm -rf build .target

dist-clean: clean
	rm -rf upstream out

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  all:          Build everything"
	@echo "  clang:        Build clang"
	@echo "  clang-format: Build clang-format"
	@echo "  clean:        Clean up"

else # following targets are run inside docker

LDFLAGS:=-s ALLOW_MEMORY_GROWTH=1 \
		-s INVOKE_RUN=0 -s EXIT_RUNTIME=0 \
		-s ASSERTIONS=1 \
		-s EXPORTED_FUNCTIONS=_main,_free,_malloc \
		-s EXPORTED_RUNTIME_METHODS=FS,PROXYFS,ERRNO_CODES,allocateUTF8,ccall,cwrap \
		-lproxyfs.js \
        --js-library=$(SRC)/emlib/fsroot.js
	

clang-install: 
	@cd build/llvm && ninja -v install
	@mkdir -p out

clang: out/clang.wasm
out/clang.wasm: .target/configure/llvm
	@cd build/llvm && ninja -v clang 
	@mkdir -p out
	@$(WRAP_JS) build/llvm/bin/clang.js out/clang.js
	@cp build/llvm/bin/clang.wasm out/clang.wasm

clang-debug: debug/clang.wasm
debug/clang.wasm: .target/configure/llvm-debug
	@cd build/llvm-debug && ninja -v clang 
	@mkdir -p debug
	@$(WRAP_JS) build/llvm-debug/bin/clang.js debug/clang.js
	@cp build/llvm-debug/bin/clang.wasm debug/clang.wasm

clang-format: out/clang-format.wasm
out/clang-format.wasm: .target/configure/llvm
	@cd build/llvm && ninja -v clang-format
	@mkdir -p out
	@cp build/llvm/bin/clang-format.js out/clang-format.js
	@cp build/llvm/bin/clang-format.wasm out/clang-format.wasm

wasm-ld: out/lld.wasm
out/lld.wasm: .target/configure/llvm
	@cd build/llvm && ninja -v lld 
	@mkdir -p out
	@$(WRAP_JS) build/llvm/bin/wasm-ld.js out/wasm-ld.js
	@cp build/llvm/bin/lld.wasm out/lld.wasm


configure/llvm: .target/configure/llvm
.target/configure/llvm: Makefile .target/upstream/llvm-project
	@echo "Configuring LLVM..."
	@mkdir -p build/llvm
	@CXXFLAGS=-Dwait4=__syscall_wait4 \
	LDFLAGS="-s ALLOW_MEMORY_GROWTH=1 \
		-s ALLOW_TABLE_GROWTH=1 -s STACK_SIZE=2MB \
		-s INITIAL_MEMORY=200MB -s MAXIMUM_MEMORY=1023MB \
		-s INVOKE_RUN=0 -s EXIT_RUNTIME=0 \
		-s ASSERTIONS=1 \
		-s EXPORTED_FUNCTIONS=_main,_free,_malloc \
		-s EXPORTED_RUNTIME_METHODS=FS,PROXYFS,ERRNO_CODES,allocateUTF8,ccall,cwrap \
		-lproxyfs.js \
		--js-library=$(SRC)/emlib/fsroot.js \
	" emcmake cmake -G Ninja \
		-B build/llvm \
		-S upstream/${LLVM}/llvm \
		-DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_DUMP=OFF \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_ENABLE_EXPENSIVE_CHECKS=OFF \
        -DLLVM_ENABLE_BACKTRACES=OFF \
        -DLLVM_BUILD_TOOLS=OFF \
        -DLLVM_ENABLE_THREADS=OFF \
        -DLLVM_BUILD_LLVM_DYLIB=OFF \
		-DBUILD_SHARED_LIBS=OFF \
		-DLLVM_INCLUDE_TESTS=OFF \
		-DLLVM_BUILD_TESTS=OFF \
		-DLLVM_OPTIMIZED_TABLEGEN=ON \
		-DLLVM_TARGETS_TO_BUILD="WebAssembly" \
		-DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" \
		-DCMAKE_INSTALL_PREFIX=$(SRC)/install/llvm \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
		-DCMAKE_TOOLCHAIN_FILE=${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake && \
		mkdir -p .target/configure && touch .target/configure/llvm


wasm-ld-debug: debug/lld.wasm
debug/lld.wasm: .target/configure/llvm-debug
	@cd build/llvm-debug && ninja -v lld 
	@mkdir -p debug
	@$(WRAP_JS) build/llvm-debug/bin/wasm-ld.js debug/wasm-ld.js
	@cp build/llvm-debug/bin/lld.wasm debug/lld.wasm


configure/llvm-debug: .target/configure/llvm-debug
.target/configure/llvm-debug: Makefile .target/upstream/llvm-project
	@echo "Configuring LLVM..."
	@mkdir -p build/llvm-debug
	@CXXFLAGS="-Dwait4=__syscall_wait4 -s SAFE_HEAP=1" \
	LDFLAGS="-s ALLOW_MEMORY_GROWTH=1 \
		-s SAFE_HEAP=1 -s STACK_OVERFLOW_CHECK=1 \
		-s INVOKE_RUN=0 -s EXIT_RUNTIME=0 \
		-s ASSERTIONS=2 \
		-s EXPORTED_FUNCTIONS=_main,_free,_malloc \
		-s EXPORTED_RUNTIME_METHODS=FS,PROXYFS,ERRNO_CODES,allocateUTF8,ccall,cwrap \
		-lproxyfs.js \
        --js-library=$(SRC)/emlib/fsroot.js \
	" emcmake cmake -G Ninja \
		-B build/llvm-debug \
		-S upstream/${LLVM}/llvm \
		-DCMAKE_BUILD_TYPE=MINSIZEREL \
        -DLLVM_ENABLE_DUMP=OFF \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_ENABLE_EXPENSIVE_CHECKS=OFF \
        -DLLVM_ENABLE_BACKTRACES=OFF \
        -DLLVM_BUILD_TOOLS=OFF \
        -DLLVM_ENABLE_THREADS=OFF \
        -DLLVM_BUILD_LLVM_DYLIB=OFF \
		-DBUILD_SHARED_LIBS=OFF \
		-DLLVM_INCLUDE_TESTS=OFF \
		-DLLVM_BUILD_TESTS=OFF \
		-DLLVM_OPTIMIZED_TABLEGEN=ON \
		-DLLVM_TARGETS_TO_BUILD="WebAssembly" \
		-DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" \
		-DCMAKE_INSTALL_PREFIX=$(SRC)/install/llvm-debug \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
		-DCMAKE_TOOLCHAIN_FILE=${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake && \
		mkdir -p .target/configure && touch .target/configure/llvm-debug


python-native: .target/build/python-native
.target/build/python-native: .target/configure/python-native
	@cd build/python-native && make -j$(nproc)
	mkdir -p .target/build && touch .target/build/python-native

configure/python-native: .target/configure/python-native
.target/configure/python-native: Makefile .target/upstream/python
	@echo "Configuring Python Native..."
	cp -r upstream/$(PYTHON) build/python-native
	cd build/python-native/ && ./configure -C 
	mkdir -p .target/configure && touch .target/configure/python-native

python: .target/build/python
.target/build/python: .target/configure/python
	@cd build/python && make -j$(nproc)
	@mkdir -p out
	@cp build/python/python.mjs out/python.mjs
	@cp build/python/python.worker.js out/python.worker.js
	@cp build/python/python.wasm out/python.wasm
	mkdir -p .target/build && touch .target/build/python

configure/python: .target/configure/python 
.target/configure/python: Makefile .target/upstream/python .target/build/python-native
	@echo "Configuring Python..."
	cp -r upstream/$(PYTHON) build/python
	cd build/python/ && \
	CXXFLAGS="-Dwait4=__syscall_wait4" \
	LDFLAGS="-s ALLOW_MEMORY_GROWTH=1 \
		-s INVOKE_RUN=0 -s EXIT_RUNTIME=0 \
		-s ASSERTIONS=1 \
		-s EXPORTED_FUNCTIONS=_main,_free,_malloc \
		-s EXPORTED_RUNTIME_METHODS=FS,PROXYFS,ERRNO_CODES,allocateUTF8,ccall,cwrap \
		-lproxyfs.js \
        --js-library=$(SRC)/emlib/fsroot.js \
	" CONFIG_SITE=$(SRC)/build/python/Tools/wasm/config.site-wasm32-emscripten \
	LIBSQLITE3_CFLAGS=" " \
	BZIP2_CFLAGS=" " \
	emconfigure $(SRC)/build/python/configure -C \
		--host=wasm32-unknown-emscripten \
		--build=`$(SRC)/build/python/config.guess` \
		--with-emscripten-target=browser \
		--disable-wasm-dynamic-linking \
		--with-suffix=".mjs" \
		--disable-wasm-preload \
		--enable-wasm-js-module \
		--with-build-python=$(SRC)/build/python-native/python
	mkdir -p .target/configure && touch .target/configure/python

brotli-native: .target/build/brotli-native
.target/build/brotli-native: .target/configure/brotli-native
	@cd build/brotli-native && ninja -v
	@mkdir -p out
	@cp build/brotli-native/brotli out/brotli
	mkdir -p .target/build && touch .target/build/brotli-native

configure/brotli-native: .target/configure/brotli-native
.target/configure/brotli-native: Makefile .target/upstream/brotli
	/usr/bin/cmake -G Ninja \
		-B build/brotli-native \
		-S upstream/$(BROTLI) \
		-DCMAKE_BUILD_TYPE=Release
	mkdir -p .target/configure && touch .target/configure/brotli-native

brotli: .target/build/brotli
.target/build/brotli: .target/configure/brotli
	@cd build/brotli && ninja -v
	@mkdir -p out
	@$(WRAP_JS) build/brotli/brotli.js out/brotli.js
	@cp build/brotli/brotli.wasm out/brotli.wasm
	mkdir -p .target/build && touch .target/build/brotli

configure/brotli: .target/configure/brotli
.target/configure/brotli: Makefile .target/upstream/brotli
	@LDFLAGS="-s ALLOW_MEMORY_GROWTH=1 \
		-s INVOKE_RUN=0 -s EXIT_RUNTIME=0 \
		-s ASSERTIONS=1 \
		-s EXPORTED_FUNCTIONS=_main,_free,_malloc \
		-s EXPORTED_RUNTIME_METHODS=FS,PROXYFS,ERRNO_CODES,allocateUTF8,ccall,cwrap \
		-lproxyfs.js \
        --js-library=$(SRC)/emlib/fsroot.js \
	" emcmake cmake -G Ninja \
		-B build/brotli \
		-S upstream/$(BROTLI) \
		-DCMAKE_BUILD_TYPE=Release
	mkdir -p .target/configure && touch .target/configure/brotli

wasm-package: .target/build/wasm-package
.target/build/wasm-package:
	c++ -std=c++20 -o out/wasm-package $(SRC)/tooling/wasm-package/wasm-package.cpp $(SRC)/tooling/wasm-utils/*.cpp
	em++ \
		-std=c++20 \
		$(LDFLAGS) \
		-lidbfs.js \
	   -o out/wasm-package.js \
	   $(SRC)/tooling/wasm-package/wasm-package.cpp $(SRC)/tooling/wasm-utils/*.cpp
	$(WRAP_JS) out/wasm-package.js out/wasm-package.mjs
	mkdir -p .target/build && touch .target/build/wasm-package

upstream/llvm-project: .target/upstream/llvm-project
.target/upstream/llvm-project:  
	@echo "Downloading LLVM..."
	@mkdir -p upstream
	@cd upstream && wget -c https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/$(LLVM).tar.xz \
		&& tar -xvf $(LLVM).tar.xz \
		&& rm -f $(LLVM).tar.xz
	@mkdir -p .target/upstream && touch .target/upstream/llvm-project

upstream/python: .target/upstream/python
.target/upstream/python: 
	@echo "Downloading Python..."
	@mkdir -p upstream
	@cd upstream && wget -c https://www.python.org/ftp/python/$(PYTHON_VERSION)/$(PYTHON).tgz \
		&& tar -xvf $(PYTHON).tgz \
		&& rm -f $(PYTHON).tgz
	@echo "Patching Python..."
	@cd upstream/$(PYTHON) && patch -p1 < $(SRC)/patches/cpython.patch && autoreconf -i
	@mkdir -p .target/upstream && touch .target/upstream/python

upstream/brotli: .target/upstream/brotli
.target/upstream/brotli: 
	@echo "Downloading Brotli..."
	@mkdir -p upstream
	@cd upstream && wget -c https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz \
		&& tar -xvf v1.1.0.tar.gz \
		&& rm -f v1.1.0.tar.gz
	@mkdir -p .target/upstream && touch .target/upstream/brotli

upstream/wasi: .target/upstream/wasi
.target/upstream/wasi: 
	@echo "Downloading WASI..."
	@mkdir -p upstream
	@cd upstream && wget -c https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-23/wasi-sdk-23.0-linux.tar.gz \
		&& tar -xvf wasi-sdk-23.0-linux.tar.gz \
		&& rm -f wasi-sdk-23.0-linux.tar.gz
	@mkdir -p .target/upstream && touch .target/upstream/wasi
	

pack/wasi: .target/pack/wasi
.target/pack/wasi: .target/upstream/wasi .target/build/wasm-package
	@echo "Packing WASI..."
	@mkdir -p out
	@rm -rf out/lib/ out/wasi-sysroot/
	@cp -r upstream/wasi-sdk-23.0/share/wasi-sysroot out/wasi-sysroot
	@cp -r upstream/wasi-sdk-23.0/lib out/lib
	@cd out && rm -rf ../out/wasi.pack && ../out/wasm-package pack ../out/wasi.pack ./wasi-sysroot ./lib
	@rm -rf out/wasi.pack.br && out/brotli -q 11 -o out/wasi.pack.br out/wasi.pack
	@mkdir -p .target/pack && touch .target/pack/wasi

endif
