import BoxProcess from "./BoxProcess.mjs";
import ClangModule from "../out/clang.js";

const tool_mapping = {
    "clang++": "clang",
    "clang": "clang",
};

export default class ClangProcess extends BoxProcess {
    constructor(opts) {
        super(ClangModule, { ...opts, tool_mapping });
    }
};
