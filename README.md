# CARO Quarto Theme

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Quarto](https://img.shields.io/badge/Quarto-Extension-4287f5?logo=quarto)](https://quarto.org)

Shared Quarto HTML theme for [demographyandme.com](https://www.demographyandme.com)
and its research / visual-demography companion sites. Archival cream + crimson
palette, a closed typographic scale, self-hosted webfonts, and WCAG-AA chrome.

## Install

```bash
quarto add demographyandme/caro-quarto
```

This copies `_extensions/caro-quarto/` (the theme SCSS + header includes). The
theme also ships **self-hosted webfonts** in the repo's [`fonts/`](fonts/)
directory — copy that directory to your site root too (the demographyandme fleet
vendors the extension and `fonts/` together; see [Maintaining](#maintaining)).

## Use

Complete `_quarto.yml` wiring — **all four blocks are required**; omitting
`css: fonts/fonts.css` loads the theme without its fonts (text falls back to
Georgia/system):

```yaml
project:
  resources:
    - fonts/                       # serve the woff2 files to _site/fonts/

format:
  html:
    css: fonts/fonts.css           # @font-face for Literata/Newsreader/Fira/Spline
    theme:
      - default
      - _extensions/caro-quarto/caro.scss
      # - styles.scss              # optional per-site override layer, after caro
    include-in-header:
      - _extensions/caro-quarto/fonts.html          # empty stub (kept for compat)
      - _extensions/caro-quarto/external-links.html # off-site links → new tab
    include-before-body:
      - _extensions/caro-quarto/skip-link.html      # WCAG skip-to-content
```

Research/visual companions additionally set `body-classes: research-companion`
(single-column reading model). Pages that embed a visual-companion viewer
include `_extensions/caro-quarto/viewer-autoresize.html` (the parent side of the
iframe auto-resize handshake).

## Typography

Self-hosted OFL families (upstream builds — the Google Fonts CSS API strips the
OpenType features below, so we host our own; see [`fonts/fonts.css`](fonts/fonts.css)):

| Role | Family | Notes |
|------|--------|-------|
| Serif body / references / headings | **Literata** (variable, opsz 7–72) | old-style + tabular figures, small caps |
| Display (h1, dict-hero headword) | **Newsreader** (variable, opsz 6–72) | high-contrast display cut |
| UI / sans / IPA | **Fira Sans** | broad IPA coverage for dict-hero phonetics |
| Mono (chrome, code) | **Spline Sans Mono** (variable) | purpose-built UI mono |

**Type scale.** Every `font-size` in the theme references one token from a
closed modular ladder in [`_extensions/caro-quarto/_caro-tokens.scss`](_extensions/caro-quarto/_caro-tokens.scss)
(`$fs-micro … $fs-giant`, base `$fs-body`, root `$fs-root`). Nothing uses an
ad-hoc size. To resize the whole system uniformly, change `$fs-root` alone.
The consuming main site enforces this with `test-type-scale.R`, which fails CI
on any literal size **and** on any reading-content role assigned a heading tier.

## Structure

`caro.scss` imports the partials in cascade order:

| Partial | Concern |
|---------|---------|
| `_caro-tokens.scss` | colors, font stacks, the `$fs-*` type ladder (`scss:defaults`) |
| `_caro-root.scss` | `:root` — master root size + spacing/measure custom properties |
| `_caro-typography.scss` | OpenType features (old-style/tabular figures, small caps, ligatures) |
| `_caro-reading-frame.scss` | wide frame vs readable text-measure |
| `_caro-interactive-tables.scss` | `#data` companion tables (`.phe-*` / `.dtb-*` prefixes) + `#trends` charts |
| `_caro-page-chrome.scss` | navbar, footer, headings, dict-hero, skip-link, print styles |
| `_caro-components.scss` | project/media cards, footer social nav, 404, badges |
| `_caro-a11y.scss` | `prefers-reduced-motion` / `prefers-contrast` |

Header includes: `fonts.html` (empty compat stub), `external-links.html`,
`skip-link.html`, `viewer-autoresize.html`.

## Maintaining

**Bump `_extension.yml` `version:` on every change.** Companions refresh via
`quarto update extension demographyandme/caro-quarto`, which compares versions
and **skips the download when the version is unchanged** — an unbumped edit
silently leaves the fleet on stale vendored copies. Then re-vendor the committed
copy into each consumer (the `scripts/vendoring.sh` helper copies the extension
tree; the `fonts/` directory is vendored alongside it).

See [CHANGELOG.md](CHANGELOG.md) for version history.
