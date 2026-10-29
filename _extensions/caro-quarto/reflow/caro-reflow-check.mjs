// caro-reflow-check.mjs — CARO's page gate, run by the fleet's CI on every built
// site. One Chromium pass over every page at each width checks two things:
//
// 1. Reflow (audit K-04/G-01, E2-09, W3-13): every page must be no wider than the
//    viewport. A page whose document.documentElement.scrollWidth is above
//    window.innerWidth scrolls sideways, or a phone zooms the whole page out (WCAG
//    2.2 SC 1.4.10 Reflow, whose reference width is 320 CSS px). A page that
//    overflows is named with its width and the widest element that sticks out past
//    the viewport.
// 2. Requests (WS6): no page may load anything from a host other than the served
//    site, except a host named with --allow-host (repeatable; exact host name, e.g.
//    the documented analytics). Every request the page makes while it is open is
//    recorded, its iframes' included (a viewer's own scripts count), from the
//    navigation until the next page is opened; so is every resource the page's
//    frames reference (img, script, iframe, source, link rel=stylesheet/preload/
//    icon/preconnect, ...) that a lazy load had not yet requested. A request to a
//    host the network cannot reach is still recorded, so the audit also works
//    offline. Each one outside the site is named with its page, width and URL.
//
// Vendored with the theme, like caro-post-render.sh, so every fleet site (the main
// site and each companion, whose CI cannot reach the private main site) runs the
// same gate. It serves the site itself, at / or, with --slug, at /<slug>/ (as GitHub
// Pages serves a companion), and loads every .html file outside site_libs/.
// Exit 0: no page overflows or loads from a host it may not; 1: at least one does
// (each is listed); 2: usage or setup error (including Playwright or its Chromium
// missing).
//
// Usage: node caro-reflow-check.mjs <site-dir> [--slug name] [--allow-host host ...]
//        [width ...] (default widths 320 375 1280). Playwright is pinned in
//        package.json beside this file: copy this folder out of the site (so
//        node_modules never lands in the theme), `npm ci --ignore-scripts` there,
//        then `npx --no-install playwright install --with-deps chromium`.

import { readdirSync, statSync, existsSync, createReadStream } from "node:fs";
import http from "node:http";
import path from "node:path";

function die(msg) {
  console.error(`caro-reflow-check: ${msg}`);
  process.exit(2);
}

const args = process.argv.slice(2);
let slug = "";
const slugAt = args.indexOf("--slug");
if (slugAt >= 0) {
  slug = (args[slugAt + 1] || "").replace(/^\/+|\/+$/g, "");
  if (!slug || /[^A-Za-z0-9._-]/.test(slug)) die(`bad --slug: ${args[slugAt + 1] || "(none)"}`);
  args.splice(slugAt, 2);
}
const allowed = new Set();
for (let at; (at = args.indexOf("--allow-host")) >= 0; args.splice(at, 2)) {
  const host = (args[at + 1] || "").toLowerCase();
  if (!/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/.test(host)) die(`bad --allow-host: ${args[at + 1] || "(none)"}`);
  allowed.add(host);
}
const [siteArg, ...widthArgs] = args;
const WIDTHS = widthArgs.length ? widthArgs.map(Number) : [320, 375, 1280];

if (!siteArg) die("usage: caro-reflow-check.mjs <site-dir> [--slug name] [--allow-host host ...] [width ...]");
if (WIDTHS.some((w) => !Number.isInteger(w) || w <= 0)) die(`bad width in: ${widthArgs.join(" ")}`);
const site = path.resolve(siteArg);
if (!existsSync(site) || !statSync(site).isDirectory()) die(`no such site folder: ${site}`);

let chromium;
try {
  ({ chromium } = await import("playwright"));
} catch {
  die("Playwright is not installed (npm ci --ignore-scripts in a copy of this folder)");
}
if (!existsSync(chromium.executablePath())) die("Playwright's Chromium is missing (npx --no-install playwright install --with-deps chromium)");

function pages(dir) {
  const out = [];
  const walk = (d) => {
    for (const n of readdirSync(d)) {
      const p = path.join(d, n);
      if (statSync(p).isDirectory()) { if (n !== "site_libs") walk(p); }
      else if (n.endsWith(".html")) out.push(path.relative(dir, p).split(path.sep).join("/"));
    }
  };
  walk(dir);
  return out.sort();
}

const list = pages(site);
if (!list.length) die(`no .html pages under ${site}`);

// A static server laid out as GitHub Pages serves the site: at /<slug>/ for a
// companion (anything else answers 404), at / otherwise.
const TYPES = { ".html": "text/html", ".css": "text/css", ".js": "text/javascript", ".mjs": "text/javascript",
  ".json": "application/json", ".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg",
  ".webp": "image/webp", ".woff2": "font/woff2", ".woff": "font/woff", ".csv": "text/csv" };
const prefix = slug ? `/${slug}` : "";
const server = http.createServer((req, res) => {
  let url;
  try { url = decodeURIComponent(new URL(req.url, "http://x").pathname); } catch { res.writeHead(400); return res.end(); }
  if (url.includes("\0")) { res.writeHead(400); return res.end(); }
  if (prefix && url !== prefix && !url.startsWith(`${prefix}/`)) { res.writeHead(404); return res.end(); }
  let file = path.resolve(site, "." + url.slice(prefix.length));
  if (file !== site && !file.startsWith(site + path.sep)) { res.writeHead(403); return res.end(); }
  if (existsSync(file) && statSync(file).isDirectory()) file = path.join(file, "index.html");
  if (!existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { "content-type": TYPES[path.extname(file)] || "application/octet-stream" });
  createReadStream(file).pipe(res);
});

// The resources a frame references, requested or not yet (a lazy image below the
// fold): run in every frame of the page after it is measured.
const REFERENCED = () => {
  const out = [];
  const add = (v) => { if (v) try { out.push(new URL(v.trim(), document.baseURI).href); } catch { /* not a URL */ } };
  const srcset = (v) => (v || "").split(",").forEach((c) => add(c.trim().split(/\s+/)[0]));
  for (const el of document.querySelectorAll("img, source, input[type=image]")) { add(el.getAttribute("src")); srcset(el.getAttribute("srcset")); }
  for (const el of document.querySelectorAll("script[src], iframe[src], frame[src], embed[src], audio[src], video[src], track[src]")) add(el.getAttribute("src"));
  for (const el of document.querySelectorAll("video[poster]")) add(el.getAttribute("poster"));
  for (const el of document.querySelectorAll("object[data]")) add(el.getAttribute("data"));
  const LOADS = /(^|\s)(stylesheet|icon|apple-touch-icon|mask-icon|manifest|preload|modulepreload|prefetch|preconnect|dns-prefetch)(\s|$)/i;
  for (const el of document.querySelectorAll("link[href]")) if (LOADS.test(el.getAttribute("rel") || "")) add(el.getAttribute("href"));
  return out;
};

let browser, setupError;
const wide = [];
const outside = [];          // { rel, width, url, how } requests the site may not make
const allowedSeen = new Map(); // allowed host -> number of requests
try {
  await new Promise((ok, no) => server.once("error", no).listen(0, "127.0.0.1", ok));
  const siteHost = `127.0.0.1:${server.address().port}`;
  const base = `http://${siteHost}${prefix}`;
  // A URL's host when it is fetched from outside the served site, else null.
  const foreign = (u) => {
    let url;
    try { url = new URL(u); } catch { return null; }
    if (!/^(https?|wss?):$/.test(url.protocol) || url.host === siteHost) return null;
    return url.hostname.toLowerCase();
  };
  browser = await chromium.launch();
  for (const width of WIDTHS) {
    const context = await browser.newContext({ viewport: { width, height: 900 }, reducedMotion: "reduce" });
    // Context-wide, so every frame's requests (an iframe's included) are seen.
    let requested = [];
    context.on("request", (r) => requested.push(r.url()));
    const page = await context.newPage();
    const audit = async (rel) => {
      let referenced = [];
      for (const frame of page.frames()) {
        try { referenced = referenced.concat(await frame.evaluate(REFERENCED)); } catch { /* a frame that failed or went away */ }
      }
      const seen = new Set();
      for (const [urls, how] of [[requested, "requested"], [referenced, "referenced, not yet requested"]]) {
        for (const url of urls) {
          const host = foreign(url);
          if (!host || seen.has(url)) continue;
          seen.add(url);
          if (allowed.has(host)) allowedSeen.set(host, (allowedSeen.get(host) || 0) + 1);
          else outside.push({ rel, width, url, host, how });
        }
      }
      requested = [];
    };
    let previous = null;
    for (const rel of list) {
      if (previous !== null) await audit(previous);
      previous = rel;
      await page.goto(`${base}/${rel}`, { waitUntil: "load", timeout: 60000 });
      const m = await page.evaluate(async () => {
        await document.fonts.ready;
        const viewW = window.innerWidth;
        const scrollW = document.documentElement.scrollWidth;
        let culprit = null;
        if (scrollW > viewW) {
          // The element reaching furthest right; on a tie the first in document
          // order, which is the outermost (a table rather than its last cell).
          // Content inside a box that clips or scrolls (overflow-x not visible)
          // does not widen the page, so it is not blamed.
          const clipped = new Map();
          const inClip = (el) => {
            const p = el.parentElement;
            if (!p || p === document.body) return false;
            if (!clipped.has(p)) clipped.set(p, getComputedStyle(p).overflowX !== "visible" || inClip(p));
            return clipped.get(p);
          };
          let right = viewW;
          for (const el of document.body.querySelectorAll("*")) {
            const r = Math.round(el.getBoundingClientRect().right + window.scrollX);
            if (r > right && !inClip(el)) {
              right = r;
              const cls = typeof el.className === "string" ? el.className.trim().split(/\s+/).filter(Boolean).slice(0, 3) : [];
              const text = (el.textContent || "").trim().replace(/\s+/g, " ").slice(0, 40);
              culprit = `${el.tagName}${el.id ? "#" + el.id : ""}${cls.map((c) => "." + c).join("")}` +
                `${text ? ` "${text}"` : ""} right edge ${r}px`;
            }
          }
        }
        return { viewW, scrollW, culprit };
      });
      const ok = m.scrollW <= m.viewW;
      if (!ok) wide.push({ rel, width, ...m });
      console.log(`${ok ? "ok  " : "WIDE"} ${String(width).padStart(4)}px  scrollWidth ${String(m.scrollW).padStart(4)}  ${rel}`);
    }
    if (previous !== null) await audit(previous);
    await context.close();
  }
} catch (e) {
  setupError = e;
} finally {
  if (browser) await browser.close();
  server.close();
}
if (setupError) die(setupError.message);

const allowedNote = allowed.size
  ? ` but the allowed ${[...allowed].sort().map((h) => `${h} (${allowedSeen.get(h) || 0} request(s))`).join(", ")}`
  : "";
if (wide.length) {
  console.error(`caro-reflow-check: ${wide.length} page/width pair(s) wider than the viewport:`);
  for (const w of wide) console.error(`  ${w.rel}: ${w.scrollW}px at ${w.width}px (widest: ${w.culprit || "none found"})`);
}
if (outside.length) {
  const hosts = [...new Set(outside.map((o) => o.host))].sort();
  console.error(`caro-reflow-check: ${outside.length} request(s) to a host other than the site (${hosts.join(", ")}; --allow-host names one the site may use):`);
  for (const o of outside) console.error(`  ${o.rel} at ${o.width}px: ${o.url} (${o.how})`);
  if (allowed.size) console.error(`caro-reflow-check: not counted:${allowedNote.replace(/^ but/, "")}`);
}
if (wide.length || outside.length) process.exit(1);
console.log(`caro-reflow-check: ok (${list.length} page(s) x ${WIDTHS.length} width(s): ${WIDTHS.join(", ")} px${slug ? `, served at /${slug}/` : ""}); ` +
  `requests outside the site: none${allowedNote}`);
