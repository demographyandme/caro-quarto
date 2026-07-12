# Changelog

All notable changes to the CARO Quarto theme. Versions match `_extension.yml`;
bump on every change so `quarto update extension` refreshes consumers.

## 1.3.5

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
