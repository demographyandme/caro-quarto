#!/usr/bin/env node
// Check that the theme's reader-facing strings follow the page language (Node
// only, no browser).
//
//   node tests/lang-strings-check.js
//
// skip-link.html's text is Portuguese on a pt-BR page and stays English on an
// en-US one; external-links.html has a Portuguese new-tab cue and recognises a
// link that already says, in either language, that it opens a new tab.
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ext = path.join(__dirname, "..", "_extensions", "caro-quarto");
const fail = (msg) => { console.error(`lang-strings-check: ${msg}`); process.exit(1); };

const skip = fs.readFileSync(path.join(ext, "skip-link.html"), "utf8");
const scripts = [...skip.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
if (!scripts.length) fail("skip-link.html has no script");
for (const [lang, want] of [["pt-BR", "Pular para o conteúdo principal"], ["en-US", "Skip to main content"]]) {
  const link = { textContent: "Skip to main content" };
  const document = {
    documentElement: { lang },
    querySelector: (sel) => (sel === "a.skip-link" ? link : null),
    getElementById: () => null,
    addEventListener() {},
  };
  for (const code of scripts) vm.runInNewContext(code, { document });
  if (link.textContent !== want) fail(`skip link on a ${lang} page reads "${link.textContent}", expected "${want}"`);
}

const links = fs.readFileSync(path.join(ext, "external-links.html"), "utf8");
if (!links.includes('pt: "(abre em nova aba)"')) fail("external-links.html has no Portuguese new-tab cue");
const hasCue = links.match(/var HAS_CUE = (\/.*\/[a-z]*);/);
if (!hasCue) fail("external-links.html: HAS_CUE not found");
const re = vm.runInNewContext(hasCue[1]);
for (const s of ["Paper (opens in a new tab)", "Artigo (abre em nova aba)"]) {
  if (!re.test(s)) fail(`HAS_CUE does not recognise "${s}"`);
}
console.log("lang-strings-check: ok (skip link and new-tab cue follow the page language)");
