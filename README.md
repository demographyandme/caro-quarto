# CARO Quarto Theme

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Quarto](https://img.shields.io/badge/Quarto-Extension-4287f5?logo=quarto)](https://quarto.org)

Public Quarto extension for [demographyandme.com](https://www.demographyandme.com) companion sites.

## Install

```bash
quarto add demographyandme/caro-quarto
```

## Use

In your site's `_quarto.yml`:

```yaml
format:
  html:
    theme:
      - default
      - _extensions/caro-quarto/caro.scss
    include-in-header:
      - _extensions/caro-quarto/fonts.html
      - _extensions/caro-quarto/external-links.html
    include-before-body:
      - _extensions/caro-quarto/skip-link.html
```
