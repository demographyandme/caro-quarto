# Changelog

All notable changes to the CARO Quarto theme. Versions match `_extension.yml`,
and each release is tagged `v<version>`. Sites carry a committed copy of a
release; see the README's *Maintaining* section.

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
