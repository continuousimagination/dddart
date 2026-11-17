// dart2js targets a browser-like global for async scheduling. This shim supplies
// that global in Node; it is not a DOM, IndexedDB, or browser compatibility test.
globalThis.self = globalThis;
require(require('node:path').resolve(process.argv[2]));
