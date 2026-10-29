# Changelog

All notable changes to the CARO Quarto theme. Versions match `_extension.yml`,
and each release is tagged `v<version>`. Sites carry a committed copy of a
release; see the README's *Maintaining* section.

## 1.7.0

- **The gate also fails a page that loads from another site.** The reflow gate
  (`reflow/caro-reflow-check.mjs`) records every request a page makes while it
  loads, iframes included, and reads what its frames reference (images, scripts,
  stylesheets, preloads), so a lazy image that never loaded is caught too. Any
  host other than the served site fails the page unless named with
  `--allow-host <host>` (exact host, repeatable). Still one browser pass; the
  reflow check, its output and its exit codes are unchanged. The fleet allows
  only its analytics host, plus a documented temporary exception on the main
  site.

## 1.6.0

- **No page scrolls sideways on a phone.** A long URL used as link text (the
  references and citation blocks) is one unbreakable word, and it set the page
  width on six companions: up to 602 px wide at a 320 px viewport (Brazil), and
  wpp at 1358 px even at 1280. Links in the reading column now take
  `overflow-wrap: break-word`, which breaks a word only where it would overflow
  its line. All 32 pages of the 9 sites fit at 320, 375 and 1280 px (10
  page-widths overflowed); screenshots at 768-1440 px are unchanged except where
  a link overflowed.
- **The theme ships its reflow gate.** `reflow/caro-reflow-check.mjs` (Playwright
  pinned in `reflow/package.json`) serves a rendered `_site`, under `/<slug>/`
  with `--slug`, and fails when any page is wider than the viewport at 320, 375
  or 1280 px, naming the element. The main site's build and the shared companion
  publish workflow run the vendored copy after the render, before the upload.

## 1.5.0

- **The skip link is the first Tab stop and moves focus.** Quarto puts
  `include-before-body` content inside `<main>`, after the navbar and TOC, so
  the link was Tab stop 7-12 at 1280 px and bypassed nothing; `quarto-nav.js`
  also rewrote its href, so Enter left focus on the link. The new post-render
  normalizer `caro-post-render.sh` moves it to the first child of `<body>` and
  gives `<main>` `tabindex="-1"`; `skip-link.html` moves focus on activation.
  Measured: Tab stop 1 on every page tested, focus in `<main>`, no page load.
- **Post-render normalizer.** `caro-post-render.sh <_site>` (bash + perl,
  idempotent) also: puts `fonts.css` first in `<head>` with preloads for
  Literata, Newsreader and Fira Sans core (CLS under a throttled network below
  0.05 on every page measured, from up to 0.27); defers Quarto's five classic
  head scripts; drops tippy, popper and the syntax CSS from pages with no
  consumer; strips Quarto's invalid `append-hash` and redundant `role="link"`
  (Nu checker: 52 messages to 0); carries the navbar `role="menu"` /
  `aria-label` fix the fleet already applied.
- **Links inside a site stay in the tab.** `external-links.html` decided on the
  raw href, which `quarto-nav.js` had already made absolute: on every companion
  the skip link, in-page anchors (276 on the Brazil companion) and the site's
  own files opened a new tab. It now decides on the resolved URL against the
  site root. Links it opens in a new tab announce "(opens in a new tab)" to
  assistive technology, with no visible change.
- **The reader's font-size setting applies.** `$fs-root` is `100%` (was
  `16px`): identical at the default, scales with the browser setting.
- **Real Newsreader italic.** Three `Newsreader-Italic-*` files replace the
  browser's slanted roman in the home page definition.
- **Fonts rebuild byte for byte.** `build-fonts.py` read the coverage floor
  from file names the 1.4.0 split had retired, so a rebuild without a census
  shipped Literata with no basic Latin. The floor is now the shipped
  `core/latn/sym` files plus Latin-1, `--check-rebuild` compares with `fonts/`,
  and CI rebuilds from the sources with the pinned fontTools
  (`scripts/requirements-fonts.txt`).
- **Print** leaves out the viewer iframe, which cannot split across pages,
  instead of printing a cut figure.
- `color.adjust` replaces the deprecated `darken()` (compiled CSS identical).
- **Vendoring checks its source.** `scripts/vendoring.sh` copies only from a
  CARO checkout, refuses a source and site that contain one another, and
  replaces a site's theme only after the new copy succeeded.

## 1.4.3

- **An embedded viewer's frame fits its content exactly.** `viewer-autoresize.html`
  set a viewer's iframe to the height the viewer reported, but the iframe is
  border-box with a 1px border, so it drew that border inside the height and
  left the viewer 2px short: the last pixels were clipped, and a viewer that
  measured its own frame reported the loss back and the frame crept down 2px
  per resize. It now adds the iframe's border and padding when the iframe is
  border-box. With dme-shared's matching client fix, the four visual pieces
  hold their frames to their content within 0px through a sequence of window
  widths from 375 to 1600px (`dme-shared/scripts/smoke-autoresize.mjs`).

## 1.4.2

- **Text keeps its line breaks while the fonts load.** `fonts.css` declares
  "Literata Fallback" and "Newsreader Fallback": Georgia scaled with
  `size-adjust` to each web font's measured width, with the web font's ascent
  and descent, placed right after it in the serif and display stacks. Georgia
  had run 7% narrower than Literata and up to 11% wider than Newsreader, so text
  rewrapped when the web font swapped in: the home page's dictionary definition
  gained a line on a phone (a layout shift of 0.12 in one Lighthouse run in
  three). Measured over 10 pages at 412 and 1280 px, elements move 83% less
  between fallback and web font (6,386 px in all, from 38,349), the home page on
  a phone 4 px (from 205). Generated by `build-fonts.py` (`FALLBACKS`); every
  woff2 is unchanged.

## 1.4.1

- **Companion pages fit a phone.** `.content` had `margin-inline: auto`, so as a
  grid item it sized to its content and never below that content's
  min-content: one wide table (even inside `.table-responsive`) or display
  equation widened the whole column past the viewport, and phones zoomed the
  page out (aging and Brazil laid out at 696 px on a 412 px screen; the visual
  pieces at up to 547 px). Companion `.content` now takes `width: 100%` of its
  column; static stage tables and display equations scroll inside it. Main-site
  pages are unchanged.
- On phones the title block's author and affiliation columns share the width
  (Quarto sized the author column to the longest name).
- The title block's ORCID link has a 24 px target (was the 10 px image;
  Lighthouse target-size), icon and line height unchanged.
- Correction to 1.4.0 below: font downloads fell 50%, not 40% (40% was the
  trial build).

## 1.4.0

- **Fonts rebuilt** with `scripts/build-fonts.py` from the upstream sources:
  variable faces instanced to the weights the fleet draws (Literata 300–700,
  Newsreader 400–700, Spline Sans Mono 400–700), each face split into core,
  Latin Extended/IPA and symbols files by `unicode-range`, so a page loads only
  what it uses. Across the fleet's 26 pages, font downloads fall 50% (every page
  lighter), and characters the previous subset had dropped (Greek letters,
  arrows, subscripts) draw in CARO fonts again. File names change
  (`<Face>-{core,latn,sym}.woff2`): vendor `fonts/` with the extension.
- **Interactive tables** are styled through shared `caro-table-*` and
  `caro-stage-*` classes instead of each companion's prefix, so a new
  companion needs no theme change. Brazil-only trend and error-banner rules
  moved to that companion. Dead `.phe-header-sub` rule removed.
- `.caro-icon` for inline SVG icons (footer, media cards), replacing the
  Bootstrap Icons font the footer alone loaded.
- Monospace stack falls back to Fira Sans before system fonts, for the Greek
  and arrows Spline Sans Mono lacks.

## 1.3.5 (tagged `v1.3.5`)

- Publication references (`.csl-entry`) to body size — were a UI tier, below
  the reading size and inconsistent with the same references on the home page.

## 1.3.4

- Hub project cards: `.project-card-summary` / `.project-card-body` to body
  size (were a title tier, larger than surrounding prose).
- Removed the non-user-facing `data as of … · <sha>` card provenance line.

## 1.3.3

- Scaled the whole type system down ~11% by lowering `$fs-root` 18px → 16px
  (Literata's tall x-height read large at the Arno-era root); all relationships
  preserved.

## 1.3.2

- Receded the UI layer (navbar, dropdown, sidebar TOC, table controls) to ~90%
  of body; Fira Sans's taller x-height had pushed it to ~97%.

## 1.3.1

- Nav dropdown items pinned to the UI step (were Bootstrap's 0.98rem — larger
  than the navbar and body).

## 1.3.0

- **Typography migration: Adobe Fonts → self-hosted Google-Fonts-catalog OFL.**
  Literata (body/headings), Newsreader (display), Fira Sans (UI/IPA), Spline
  Sans Mono (chrome). Subset woff2 (~1.1 MB) with OpenType features retained;
  the retired Adobe Typekit kit removed. Visual-companion viewer fonts moved to
  the self-hosted stack.
- **Closed type scale**: every `font-size` references a `$fs-*` ladder token;
  role-tuned across headings, UI, captions, and content.
- Comment/house-cleaning: dropped retired-stack narration; `$arno-*` variables
  renamed to `$serif-stack` / `$serif-display-stack`.

## 1.2.0

- SCSS quality pass: `%caro-chrome-btn` placeholder, interactive-table color
  tokens, `@media print` stylesheet, folded set-then-override borders.

## 1.1.0 (unreleased history)

- Adobe Fonts era (Arno Pro + Myriad Pro + Source Code Pro via Typekit),
  optical-size tiers, WCAG-AA skip-link / contrast / reduced-motion, JSON-LD
  and interactive-table chrome. Superseded by the 1.3.0 font migration.

## 1.0.0

- Initial Quarto extension for demographyandme.com companion sites.
