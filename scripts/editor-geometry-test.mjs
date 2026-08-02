import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const source = fs.readFileSync("Chiselo/Resources/Editor/editor-geometry.js", "utf8");
const context = { window: {} };
vm.runInNewContext(source, context, { filename: "editor-geometry.js" });

const geometry = context.window.ChiseloEditorGeometry.create({ minSize: 24, snapDistance: 6 });
const plain = (value) => JSON.parse(JSON.stringify(value));

assert.deepEqual(
  plain(geometry.resizeRect({ x: 10, y: 20, w: 100, h: 80 }, "se", 20, 10, null)),
  { x: 10, y: 20, w: 120, h: 90 }
);
assert.deepEqual(
  plain(geometry.resizeRect({ x: 10, y: 20, w: 100, h: 80 }, "nw", 90, 70, null)),
  { x: 86, y: 76, w: 24, h: 24 }
);
assert.deepEqual(
  plain(geometry.resizeRect({ x: 10, y: 20, w: 100, h: 50 }, "nw", -40, -5, 2)),
  { x: -30, y: 0, w: 140, h: 70 }
);

const leftEdge = { value: () => 98, apply: () => {} };
const centerEdge = { value: () => 150, apply: () => {} };
const candidate = { value: 100, label: "guide" };
assert.equal(geometry.bestSnap([leftEdge, centerEdge], [candidate]).edge, leftEdge);
assert.equal(geometry.bestSnap([{ value: () => 107 }], [candidate]), null);

assert.equal(geometry.snapNumber(17, 8), 16);
assert.equal(geometry.distanceToRect(13, 14, { left: 10, top: 10, right: 20, bottom: 20 }), 0);
assert.equal(geometry.distanceToRect(7, 6, { left: 10, top: 10, right: 20, bottom: 20 }), 5);
assert.equal(geometry.formatTransformNumber(0), "0.05");
assert.equal(geometry.formatTransformNumber(1.23456), "1.235");
assert.equal(geometry.formatTransformNumber(50), "20");

assert.equal(geometry.rectChanged({ x: 0, y: 0, w: 10, h: 10 }, { x: 0.5, y: 0, w: 10, h: 10 }), false);
assert.equal(geometry.rectChanged({ x: 0, y: 0, w: 10, h: 10 }, { x: 0.51, y: 0, w: 10, h: 10 }), true);
assert.equal(geometry.elementArea({ w: 0, h: 10 }), 1);
assert.equal(geometry.elementArea({ w: 8, h: 7 }), 56);
assert.deepEqual(
  plain(geometry.roundedRect({ left: 12.4, top: 15.6, width: 20.4, height: 30.6 }, { left: 2, top: 5 })),
  { x: 10, y: 11, w: 20, h: 31 }
);
assert.equal(
  geometry.rectOverflowAmount({ x: -4, y: 5, w: 20, h: 20 }, { x: 0, y: 0, w: 30, h: 30 }),
  4
);
assert.deepEqual(
  plain(geometry.rectIntersection({ x: 0, y: 0, w: 10, h: 10 }, { x: 7, y: 4, w: 10, h: 3 })),
  { x: 7, y: 4, w: 3, h: 3 }
);
assert.equal(geometry.rectIntersection({ x: 0, y: 0, w: 5, h: 5 }, { x: 5, y: 0, w: 2, h: 2 }), null);
assert.equal(geometry.rectArea({ w: -2, h: 8 }), 0);

assert.throws(() => context.window.ChiseloEditorGeometry.create({ minSize: 0, snapDistance: 6 }), /minSize/);
assert.throws(() => context.window.ChiseloEditorGeometry.create({ minSize: 24, snapDistance: -1 }), /snapDistance/);

console.log("Editor geometry test OK");
