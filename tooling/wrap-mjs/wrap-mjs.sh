#!/bin/bash 
# This script wraps a emscripten Module into a mjs
# Usage: ./wrap-mjs.sh <input-file> <output-file>

filePath=$1
outPath=$2

echo "
var Module = (() => {
  var _scriptDir = import.meta.url;
  
  return (
function(Module) {
  Module = Module || {};
" > $outPath

cat $filePath >> $outPath

echo "
  return Module;
}
);
})();
export default Module;
" >> $outPath