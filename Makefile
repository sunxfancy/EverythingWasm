LLVM=llvm-project-18.1.8.src
PYTHON_VERSION=3.12.4
PYTHON=Python-$(PYTHON_VERSION)
BROTLI=brotli-v1.1.0

BUILD_TYPE=Release
PWD=$(shell pwd)
gen_linker_flags=-DCMAKE_EXE_LINKER_FLAGS="$(1)" -DCMAKE_SHARED_LINKER_FLAGS="$(1)" -DCMAKE_MODULE_LINKER_FLAGS="$(1)"
COMMA=,
SRC=/src

DOCKER_RUN=docker run -it --rm  -v "$(PWD):/src" -w /src --user `id -u`  everything_wasm


ifeq ($(INSIDE_DOCKER),)

.PHONY: all clang clang-format python clean help
all: build/clang build/clang-format 

clang: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
clang-format: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
python: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
configure/%: .target/docker
	$(DOCKER_RUN) make INSIDE_DOCKER=1 $@
upstream/%:  .target/docker
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

clang: configure/llvm
	@cd build/llvm && ninja -v clang
	@mkdir -p out
	@cp build/llvm/bin/clang.js out/clang.js
	@cp build/llvm/bin/clang.wasm out/clang.wasm

clang-format: configure/llvm
	@cd build/llvm && ninja -v clang-format
	@mkdir -p out
	@cp build/llvm/bin/clang-format.js out/clang-format.js
	@cp build/llvm/bin/clang-format.wasm out/clang-format.wasm

configure/llvm: .target/configure/llvm
.target/configure/llvm: Makefile .target/upstream/llvm-project
	@echo "Configuring LLVM..."
	@mkdir -p build/llvm
	@CXXFLAGS="-Dwait4=__syscall_wait4" \
	LDFLAGS="\
		-s ALLOW_MEMORY_GROWTH=1 \
		-s EXPORTED_FUNCTIONS=_main,_free,_malloc \
		-s EXPORTED_RUNTIME_METHODS=FS,PROXYFS,ERRNO_CODES,allocateUTF8,ccall,cwrap \
		-lproxyfs.js \
        --js-library=$(SRC)/emlib/fsroot.js \
	" emcmake cmake -G Ninja \
		-B build/llvm \
		-S upstream/${LLVM}/llvm \
		-DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
		-DLLVM_ENABLE_ASSERTIONS=ON \
		-DBUILD_SHARED_LIBS=OFF \
		-DLLVM_INCLUDE_TESTS=ON \
		-DLLVM_BUILD_TESTS=ON \
		-DLLVM_OPTIMIZED_TABLEGEN=ON \
		-DLLVM_TARGETS_TO_BUILD="WebAssembly" \
		-DLLVM_ENABLE_RTTI=ON \
		-DLLVM_ENABLE_PROJECTS="clang" \
		-DCMAKE_INSTALL_PREFIX=install \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
		-DCMAKE_TOOLCHAIN_FILE=${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake && \
		mkdir -p .target/configure && touch .target/configure/llvm

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
	CONFIG_SITE=$(SRC)/build/python/Tools/wasm/config.site-wasm32-emscripten \
	LIBSQLITE3_CFLAGS=" " \
	BZIP2_CFLAGS=" " \
	LDFLAGS="\
		-s ALLOW_MEMORY_GROWTH=1 \
		-s EXPORTED_FUNCTIONS=_main,_free,_malloc \
		-s EXPORTED_RUNTIME_METHODS=FS,PROXYFS,ERRNO_CODES,allocateUTF8 \
		-lproxyfs.js \
		--js-library=$(SRC)/emlib/fsroot.js \
	" emconfigure $(SRC)/build/python/configure -C \
		--host=wasm32-unknown-emscripten \
		--build=`$(SRC)/build/python/config.guess` \
		--with-emscripten-target=browser \
		--disable-wasm-dynamic-linking \
		--with-suffix=".mjs" \
		--disable-wasm-preload \
		--enable-wasm-js-module \
		--with-build-python=$(SRC)/build/python-native/python
	mkdir -p .target/configure && touch .target/configure/python

configure/brotli: .target/configure/brotli
.target/configure/brotli: Makefile .target/upstream/brotli
	@CFLAGS="-flto" \
	LDFLAGS="\
		-flto \
		-s ALLOW_MEMORY_GROWTH=1 \
		-s EXPORTED_FUNCTIONS=_main,_free,_malloc \
		-s EXPORTED_RUNTIME_METHODS=FS,PROXYFS,ERRNO_CODES,allocateUTF8 \
		-lproxyfs.js \
		--js-library=$(SRC)/emlib/fsroot.js \
	" emcmake cmake -G Ninja \
		-B build/brotli \
		-S upstream/$(BROTLI) \
		-DCMAKE_BUILD_TYPE=Release
	mkdir -p .target/configure && touch .target/configure/brotli

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
		&& tar -xvf $(BROTLI).tar.gz \
		&& rm -f $(BROTLI).tar.gz
	@mkdir -p .target/upstream && touch .target/upstream/brotli


endif
