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

After `quarto render`, run the theme's HTML normalizer over the output (from the
site's post-render script or CI); it fixes what Quarto's templates emit and SCSS
cannot, for example the skip link, which Quarto places inside `<main>`:

```sh
bash _extensions/caro-quarto/caro-post-render.sh _site
```

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

A site renders the copy of the theme it **commits**: its `_quarto.yml` loads
`_extensions/caro-quarto/caro.scss` by path. That committed copy is the site's
pin. `quarto update extension demographyandme/caro-quarto` does not rewrite it
(it installs a second copy under `_extensions/demographyandme/`, which nothing
loads), so the demographyandme fleet does not run it in CI.

A release:

1. Change the theme; bump `version:` in `_extensions/caro-quarto/_extension.yml`
   and add a `CHANGELOG.md` entry.
2. If the fonts change, rebuild them from the upstream sources with the pinned
   fontTools (another version writes different bytes):

   ```bash
   python3 -m venv /tmp/fonts-venv && /tmp/fonts-venv/bin/pip install -r scripts/requirements-fonts.txt
   /tmp/fonts-venv/bin/python scripts/build-fonts.py --from-git e725422 --out /tmp/caro-fonts
   ```

   Coverage never shrinks: each face keeps every code point the committed
   `fonts/` has, plus Latin-1, plus what `--census` lists. Check the printed
   report (`lost 0`), copy the woff2 files and `fonts.css` into `fonts/`, then
   prove the commit reproduces: `--check-rebuild` (with a scratch `--out`)
   builds twice and compares the build with `fonts/` byte for byte, as CI does.
3. Commit and merge. The tag is automatic: when CI passes on `main`,
   `.github/workflows/release-tag.yml` runs `scripts/release-tag.sh --push`,
   which tags `v<version>` on the commit that set the version (the oldest one
   whose theme and fonts equal `main`'s), so a version names exact content.
   Tags never move: CI fails a change to the theme or fonts that keeps a
   version already tagged (bump the version instead).
4. Vendor into every consumer: `scripts/vendoring.sh` copies the extension tree
   and `fonts/` together. Commit in each site; nothing reaches a site until it
   is vendored and committed there.

The fleet's tests hold every site's committed theme and fonts to the tagged
release its `_extension.yml` names.

See [CHANGELOG.md](CHANGELOG.md) for version history.
