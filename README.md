# CARO Quarto Theme

Shared visual identity for [demographyandme.com](https://www.demographyandme.com) and its project sites.

## Design tokens

- **Body:** Crimson Pro (Garamond-class serif, screen-optimized)
- **Headings:** Libre Baskerville
- **UI/Nav:** Libre Franklin
- **Mono:** Courier Prime
- **Palette:** archival cream `#F9F8F6`, crimson accent `#8c1d40`, charcoal text `#2B2B2B`

## Install

```bash
quarto add demographyandme/caro-quarto
```

## Use

In your site's `_quarto.yml`:

```yaml
website:
  favicon: images/favicon.svg

format:
  html:
    theme:
      - default
      - _extensions/caro-quarto/caro.scss
      - styles.scss  # optional site-specific overrides
    include-in-header: _extensions/caro-quarto/fonts.html
    anchor-sections: false
    smooth-scroll: true
```

The extension provides:

| File | Role |
|------|------|
| `caro.scss` | SCSS defaults (design tokens) + common rules (typography, navbar, footer, sidebar, links, buttons) |
| `fonts.html` | Google Fonts preconnect + stylesheet for all four typefaces |

Site-specific SCSS (social icons, publication helpers, etc.) goes in a local `styles.scss` that layers on top. All `$variables` from `caro.scss` are available in subsequent SCSS files.

## Update

| Context | What to run |
|---------|-------------|
| **Local** | `quarto render` in any consumer site: `pre_render.sh` copies from `CARO_QUARTO_SRC` into `_extensions/caro-quarto/` **when that env var is set** (recommended path: this repo’s `_extensions/caro-quarto/`). |
| **GitHub Actions** | Consumer repos run `quarto update caro-quarto --no-prompt` then `quarto render` so CI pulls the latest extension from this repo without local paths. |

Manual refresh without a full site render:

```bash
quarto update caro-quarto
```
