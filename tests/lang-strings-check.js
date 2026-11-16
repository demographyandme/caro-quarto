#!/usr/bin/env node
// Check that the theme's reader-facing strings follow the page language (Node
// only, no browser).
//
//   node tests/lang-strings-check.js
//
// external-links.html has a Portuguese new-tab cue and recognises a link that
// already says, in either language, that it opens a new tab. Quarto (1.11 and
// later) renders the skip link in the page's language; skip-link.html only moves
// focus to the content in place, which this checks too.
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ext = path.join(__dirname, "..", "_extensions", "caro-quarto");
const fail = (msg) => { console.error(`lang-strings-check: ${msg}`); process.exit(1); };

const skip = fs.readFileSync(path.join(ext, "skip-link.html"), "utf8");
if (/<a\b/.test(skip)) fail("skip-link.html renders a link of its own beside Quarto's #quarto-skip-link");
const scripts = [...skip.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
if (!scripts.length) fail("skip-link.html has no script");
{
  let handler = null;
  let focused = false;
  let prevented = false;
  const main = { attrs: {}, hasAttribute(n) { return n in this.attrs; }, setAttribute(n, v) { this.attrs[n] = v; }, focus() { focused = true; } };
  const link = { id: "quarto-skip-link" };
  const document = {
    addEventListener(type, fn) { if (type === "click") handler = fn; },
    getElementById: (id) => (id === "quarto-document-content" ? main : null),
  };
  for (const code of scripts) vm.runInNewContext(code, { document });
  if (!handler) fail("skip-link.html adds no click handler");
  handler({ target: { closest: (sel) => (sel === "a#quarto-skip-link" ? link : null) }, preventDefault() { prevented = true; } });
  if (!prevented || !focused || main.attrs.tabindex !== "-1") fail("a click on #quarto-skip-link does not move focus to #quarto-document-content in place");
}

const links = fs.readFileSync(path.join(ext, "external-links.html"), "utf8");
if (!links.includes('pt: "(abre em nova aba)"')) fail("external-links.html has no Portuguese new-tab cue");
const hasCue = links.match(/var HAS_CUE = (\/.*\/[a-z]*);/);
if (!hasCue) fail("external-links.html: HAS_CUE not found");
const re = vm.runInNewContext(hasCue[1]);
for (const s of ["Paper (opens in a new tab)", "Artigo (abre em nova aba)"]) {
  if (!re.test(s)) fail(`HAS_CUE does not recognise "${s}"`);
}
console.log("lang-strings-check: ok (new-tab cue follows the page language; skip-link.html moves focus in place)");
