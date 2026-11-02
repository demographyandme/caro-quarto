#!/usr/bin/env node
// Check for viewer-autoresize.html's visibility messages (Node only, no browser).
//
//   node tests/viewer-autoresize-check.js
//
// Runs the script against a stub DOM with two viewer iframes and a stub
// IntersectionObserver, then reports one iframe leaving the screen and the other
// entering it. Each message must reach the iframe its entry names: with one
// observer per iframe sharing a loop variable, every message went to the last
// iframe and the first one never paused.
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const html = fs.readFileSync(path.join(__dirname, "..", "_extensions", "caro-quarto", "viewer-autoresize.html"), "utf8");
const code = html.replace(/^\s*<script>/, "").replace(/<\/script>\s*$/, "");

function iframe(name) {
  const posted = [];
  return { name, dataset: {}, style: {}, posted, contentWindow: { postMessage: (m) => posted.push(m) } };
}
const frames = [iframe("first"), iframe("second")];
const observers = [];
class StubObserver {
  constructor(cb) { this.cb = cb; this.targets = []; observers.push(this); }
  observe(t) { this.targets.push(t); }
}
const window = { addEventListener() {}, IntersectionObserver: StubObserver };
const document = {
  readyState: "complete",
  querySelectorAll: () => frames,
  addEventListener() {},
};
vm.runInNewContext(code, { window, document, IntersectionObserver: StubObserver, getComputedStyle: () => ({}) });

const fail = (msg) => { console.error(`viewer-autoresize-check: ${msg}`); process.exit(1); };
const observed = observers.flatMap((o) => o.targets);
if (observed.length !== 2) fail(`expected both iframes observed, got ${observed.length}`);
for (const o of observers) {
  o.cb(o.targets.map((t) => ({ target: t, isIntersecting: t.name === "second" })));
}
const [first, second] = frames;
if (first.posted.length !== 1 || first.posted[0].visible !== false) fail(`the first iframe got ${JSON.stringify(first.posted)}, expected one {visible: false}`);
if (second.posted.length !== 1 || second.posted[0].visible !== true) fail(`the second iframe got ${JSON.stringify(second.posted)}, expected one {visible: true}`);
console.log("viewer-autoresize-check: ok (each visibility message reaches its own iframe)");
