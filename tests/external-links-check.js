#!/usr/bin/env node
// Browser check for external-links.html (needs Node and Playwright with Chromium).
//
//   node tests/external-links-check.js <rendered _site> [--slug name] [--assert] [pages...]
//
// Serves the rendered site at http://127.0.0.1:<port>/<slug>/ (as GitHub Pages
// serves a companion at demographyandme.github.io/<slug>/), so quarto-nav.js
// rewrites hrefs to absolute URLs exactly as in production, and an unrelated
// /other-companion/ answers on the same origin. For each page (default: every
// top-level .html) it counts, outside the containers the script skips, the links
// with target=_blank by kind, and reads the accessible name of every link the
// script marked (a target="_blank" written in the page source is left alone).
// --assert exits 1 unless: the script marks no in-page or same-site link; every
// external and cross-companion link does; every marked link's name carries the
// cue exactly once. Exit 77 when Playwright or its Chromium is missing.
"use strict";

const fs = require("fs");
const http = require("http");
const path = require("path");

let playwright;
try {
  playwright = require("playwright");
  if (!fs.existsSync(playwright.chromium.executablePath())) throw new Error("no chromium");
} catch (e) {
  console.log("external-links-check: Playwright/Chromium not available, skipped");
  process.exit(77);
}

const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(name);
  if (i < 0) return null;
  const v = args[i + 1];
  args.splice(i, 2);
  return v;
};
const slug = flag("--slug") || "caro-fixture";
const assert = args.includes("--assert");
const rest = args.filter((a) => a !== "--assert");
const site = path.resolve(rest[0] || "");
if (!rest[0] || !fs.statSync(site).isDirectory()) {
  console.error("usage: external-links-check.js <_site dir> [--slug name] [--assert] [pages...]");
  process.exit(2);
}
const pages = rest.length > 1 ? rest.slice(1) : fs.readdirSync(site).filter((f) => f.endsWith(".html"));

const types = { ".html": "text/html", ".css": "text/css", ".js": "text/javascript", ".json": "application/json",
  ".svg": "image/svg+xml", ".png": "image/png", ".woff2": "font/woff2", ".csv": "text/csv" };
const server = http.createServer((req, res) => {
  const p = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (!p.startsWith("/" + slug + "/")) {
    res.writeHead(200, { "content-type": "text/html" });
    return res.end("<!doctype html><title>other</title>");
  }
  let file = path.join(site, p.slice(slug.length + 2));
  if (!file.startsWith(site)) { res.writeHead(403); return res.end(); }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, "index.html");
  if (!fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { "content-type": types[path.extname(file)] || "application/octet-stream" });
  fs.createReadStream(file).pipe(res);
});

const SKIP = ".navbar, .quarto-navbar, .nav-footer, footer.page-footer, .dropdown-menu, #quarto-margin-sidebar";

(async () => {
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const base = `http://127.0.0.1:${server.address().port}/${slug}/`;
  const browser = await playwright.chromium.launch();
  const failures = [];
  for (const name of pages) {
    const page = await browser.newPage();
    // Record the links whose target is set after parsing (by the script), so a
    // target="_blank" written in the page source is not blamed on it.
    await page.addInitScript(() => {
      window.__elcMarked = new Set();
      new MutationObserver((ms) => ms.forEach((m) => window.__elcMarked.add(m.target)))
        .observe(document, { subtree: true, attributes: true, attributeFilter: ["target"] });
    });
    await page.goto(base + (name === "index.html" ? "" : name), { waitUntil: "load" });
    const links = await page.evaluate(([skip, root]) => {
      const here = location.href.split("#")[0];
      return Array.from(document.querySelectorAll("a[href]")).map((a, i) => {
        a.setAttribute("data-elc", i);
        const u = new URL(a.href);
        let kind;
        if (a.closest(skip) || a.hasAttribute("data-skip-external")) kind = "skipped";
        else if (!/^https?:$/.test(u.protocol)) kind = "other";
        else if (u.href.split("#")[0] === here) kind = "inpage";
        else if (u.origin === location.origin && u.href.startsWith(root)) kind = "samesite";
        else if (u.origin === location.origin) kind = "cross";
        else if (/^(www\.)?demographyandme\.com$/i.test(u.hostname)) kind = "dme";
        else kind = "external";
        return { i, kind, href: a.href, blank: a.target === "_blank", marked: window.__elcMarked.has(a), card: /project-card-(link|figure)/.test(a.className),
          hidden: !!a.closest('[aria-hidden="true"]') };
      });
    }, [SKIP, base]);
    const count = {};
    for (const l of links) {
      const c = (count[l.kind] = count[l.kind] || { total: 0, blank: 0 });
      c.total++;
      if (l.blank) c.blank++;
    }
    const names = [];
    for (const l of links.filter((x) => x.marked && !x.hidden)) {
      const snap = await page.locator(`[data-elc="${l.i}"]`).ariaSnapshot();
      const m = snap.match(/link "((?:[^"\\]|\\.)*)"/);
      names.push({ href: l.href, name: m ? m[1] : snap.split("\n")[0] });
    }
    const summary = Object.entries(count).map(([k, v]) => `${k} ${v.blank}/${v.total}`).join(", ");
    console.log(`${name}: target=_blank by kind (blank/total): ${summary}`);
    names.forEach((n) => console.log(`  name: "${n.name}"  <- ${n.href}`));
    if (assert) {
      for (const l of links) {
        if ((l.kind === "inpage" || l.kind === "samesite") && l.marked && !l.card) failures.push(`${name}: ${l.kind} link opens a new tab: ${l.href}`);
        if ((l.kind === "external" || l.kind === "cross") && !l.blank) failures.push(`${name}: ${l.kind} link stays in the tab: ${l.href}`);
        if (l.kind === "dme" && l.marked && !l.card) failures.push(`${name}: demographyandme.com link opens a new tab: ${l.href}`);
      }
      for (const n of names) {
        const hits = (n.name.match(/new (tab|window)/gi) || []).length;
        if (hits !== 1) failures.push(`${name}: marked link name has the cue ${hits} times: "${n.name}" <- ${n.href}`);
      }
    }
    await page.close();
  }
  await browser.close();
  server.close();
  failures.forEach((f) => console.log("::error::external-links: " + f));
  if (failures.length) process.exit(1);
  if (assert) console.log("external-links-check: passed");
})().catch((e) => { console.error(e); process.exit(1); });
