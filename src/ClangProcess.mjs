import BoxProcess from "./BoxProcess.mjs";
import ClangModule from "../out/clang.js";
import EmProcess from "./EmProcess.mjs";
// const tool_mapping = {
//     "clang++": "clang",
//     "clang": "clang",
// };

// export default class ClangProcess extends BoxProcess {
//     constructor(opts) {
//         super(ClangModule, { ...opts, tool_mapping });
//     }
// };

export default class ClangProcess extends EmProcess {
    constructor(opts) {
        // ClangModule["wasmMemory"] = new WebAssembly.Memory({
        //     "initial" : 3200,
        //     "maximum" : 25600
        // });
        super(ClangModule, { ...opts });
    }
};

