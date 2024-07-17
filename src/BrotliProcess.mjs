import EmProcess from "./EmProcess.mjs";
import BrotliModule from "../out/brotli.js";

export default class BrotliProcess extends EmProcess {
    constructor(opts) {
        console.log("BrotliProcess.constructor");
        super(BrotliModule, { ...opts })
    }
};
