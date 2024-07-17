import EmProcess from "./EmProcess.mjs";
import WasmLDModule from "../out/wasm-ld.js";

export default class WasmLDProcess extends EmProcess {
    constructor(opts) {
        super(WasmLDModule, { ...opts, tool_mapping });
    }
};
