LLVM=llvm-project-18.1.8.src
LLVM_BUILD_TYPE=Release
PWD:=$(shell pwd)
gen_linker_flags   = -DCMAKE_EXE_LINKER_FLAGS="$(1)" -DCMAKE_SHARED_LINKER_FLAGS="$(1)" -DCMAKE_MODULE_LINKER_FLAGS="$(1)"

clang: build
	cd build && ninja -v clang
	mkdir -p out
	cp build/bin/clang.js out/clang.js
	cp build/bin/clang.wasm out/clang.wasm

clang-format: build
	cd build && ninja -v clang-format
	mkdir -p out
	cp build/bin/clang-format.js out/clang-format.js
	cp build/bin/clang-format.wasm out/clang-format.wasm

build: Makefile 
	mkdir -p build/
	emcmake cmake -G Ninja -B build -S ${LLVM}/llvm \
		-DCMAKE_BUILD_TYPE=${LLVM_BUILD_TYPE} \
		-DLLVM_ENABLE_ASSERTIONS=ON \
		-DBUILD_SHARED_LIBS=OFF \
		-DLLVM_INCLUDE_TESTS=ON \
		-DLLVM_BUILD_TESTS=ON \
		-DLLVM_OPTIMIZED_TABLEGEN=ON \
		-DLLVM_TARGETS_TO_BUILD="X86" \
		-DLLVM_ENABLE_RTTI=ON \
		-DLLVM_ENABLE_PROJECTS="clang" \
		-DCMAKE_INSTALL_PREFIX=install \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
		$(call gen_linker_flags,-sEXPORTED_RUNTIME_METHODS=ccall$(COMMA)cwrap) \
		-DCMAKE_TOOLCHAIN_FILE=$(PWD)/emsdk/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake
	touch build

install-deps: emsdk llvm-project

emsdk:
	git clone https://github.com/emscripten-core/emsdk.git
	cd emsdk && ./emsdk install latest && ./emsdk activate latest

llvm-project:
	@echo "Downloading LLVM..."
	@wget -c https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/$(LLVM).tar.xz
	@tar -xvf $(LLVM).tar.xz
	@rm -f $(LLVM).tar.xz

nodejs:
	@echo "Downloading NodeJS..."
	@wget -c https://nodejs.org/dist/v22.4.0/node-v22.4.0.tar.xz
	@tar -xvf node-v22.4.0.tar.xz
	@rm -f node-v22.4.0.tar.xz