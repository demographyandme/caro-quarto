#!/usr/bin/env python3
"""Build CARO's self-hosted web fonts from the upstream sources.

For each face: instance the variable axes to the weights the fleet draws, then
split the character set in three woff2 files declared with `unicode-range`; a
browser fetches a file only for a page that contains one of its characters:

  core — Latin-1, combining marks, general punctuation, and the arrows and
         minus body text uses on most pages; in practice every page downloads it.
  latn — Latin Extended, IPA, spacing modifiers (names with diacritics,
         dict-hero IPA).
  sym  — Greek, letterlike symbols, sub/superscripts, other arrows, math,
         geometric shapes, dingbats (the formulas in running text).

Coverage is the union of what the previous build shipped and what the fleet's
pages were found to use (census), limited to what the source actually has, so
no page loses a glyph it had and pages regain the glyphs the old subset dropped.

Writes <out>/<Face>-{core,latn,sym}.woff2 and <out>/fonts.css.
Deterministic: the same sources give the same bytes (checked by --check-rebuild).

Usage:
  python3 scripts/build-fonts.py --sources DIR --out DIR [--census census.json] [--check-rebuild]
  python3 scripts/build-fonts.py --from-git 13826c3 --out DIR ...   # sources from caro-quarto history

Sources: Literata 3.103, Newsreader 1.003, Fira Sans 4.106, Spline Sans Mono 1.004
(OFL), as committed in 13826c3 and removed in 0b05d6c.
"""
import argparse, hashlib, io, json, os, subprocess, sys, tempfile

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

# (output face, source file, CSS family, style, weight descriptor, wght instance range or None)
FACES = [
    ("Literata",               "Literata-var.ttf",               "Literata",         "normal", "300 700", (300, 700)),
    ("Literata-Italic",        "Literata-Italic-var.ttf",        "Literata",         "italic", "300 700", (300, 700)),
    ("Newsreader",             "Newsreader-var.ttf",             "Newsreader",       "normal", "400 700", (400, 700)),
    ("FiraSans-Regular",       "FiraSans-Regular.otf",           "Fira Sans",        "normal", "400",     None),
    ("FiraSans-Italic",        "FiraSans-Italic.otf",            "Fira Sans",        "italic", "400",     None),
    ("FiraSans-SemiBold",      "FiraSans-SemiBold.otf",          "Fira Sans",        "normal", "600",     None),
    ("FiraSans-Bold",          "FiraSans-Bold.otf",              "Fira Sans",        "normal", "700",     None),
    ("SplineSansMono",         "SplineSansMono-var.ttf",         "Spline Sans Mono", "normal", "400 700", (400, 700)),
    ("SplineSansMono-Italic",  "SplineSansMono-Italic-var.ttf",  "Spline Sans Mono", "italic", "400 700", (400, 700)),
]

# Downloaded by every page. Combining marks (U+0300-036F) stay in core so the
# mark feature can place an accent on a Latin-1 base in decomposed text: base
# and mark must come from the same file for GPOS mark attachment to apply.
CORE = set(range(0x20, 0x7F)) | set(range(0xA0, 0x100)) | set(range(0x0300, 0x0370)) | set(range(0x2000, 0x2070)) | {
    0x0D, 0x131, 0x152, 0x153, 0x2C6, 0x2DA, 0x2DC, 0x2074, 0x20AC, 0x2122,
    0x2190, 0x2191, 0x2192, 0x2193, 0x2212, 0x2215, 0xFEFF, 0xFFFD}

# Blocks the two extension files draw from when the source has them.
LATN_BLOCKS = [(0x0100, 0x024F), (0x0250, 0x02AF), (0x02B0, 0x02FF), (0x0300, 0x036F), (0x1E00, 0x1EFF), (0xFB00, 0xFB06)]
SYM_BLOCKS = [(0x0370, 0x03FF), (0x2070, 0x209F), (0x20A0, 0x20CF), (0x2100, 0x214F), (0x2190, 0x21FF),
              (0x2200, 0x22FF), (0x25A0, 0x25FF), (0x2700, 0x27BF)]

def in_blocks(cp, blocks):
    return any(a <= cp <= b for a, b in blocks)

def part_of(cp):
    if cp in CORE: return "core"
    if in_blocks(cp, SYM_BLOCKS): return "sym"
    return "latn"                      # Latin Extended and anything else the previous build covered

PARTS = ("core", "latn", "sym")

def roundtrip(font):
    b = io.BytesIO(); font.flavor = None; font.save(b); b.seek(0)
    return TTFont(b)

def woff2_bytes(font):
    font.recalcTimestamp = False       # keep head.modified from the source: same input, same bytes
    font.flavor = "woff2"
    b = io.BytesIO(); font.save(b, reorderTables=True)
    return b.getvalue()

def subset_to(font, cps):
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.name_languages = ["*"]
    opts.notdef_outline = True
    opts.glyph_names = False
    opts.hinting = False           # woff2 on the web: unhinted, as the previous build
    s = subset.Subsetter(opts)
    s.populate(unicodes=sorted(cps))
    s.subset(font)
    return font

def css_range(cps):
    cps = sorted(cps); out = []; start = prev = cps[0]
    for c in cps[1:]:
        if c == prev + 1: prev = c; continue
        out.append((start, prev)); start = prev = c
    out.append((start, prev))
    return ", ".join(f"U+{a:04X}" if a == b else f"U+{a:04X}-{b:04X}" for a, b in out)

def load_census_needs(path):
    """Code points each CSS family is asked for on the fleet's pages."""
    needs = {}
    if not path:
        return needs
    census = json.load(open(path, encoding="utf-8"))
    for frames in census.values():
        for fr in frames:
            for el in fr["own"]:
                fam = el["family"].split(",")[0].strip().strip('"')
                needs.setdefault(fam, set()).update(ord(c) for c in el["high"])
    return needs

def build(sources, out, previous, needs):
    os.makedirs(out, exist_ok=True)
    report, css = [], [CSS_HEADER]
    for face, src, family, style, weight, wght in FACES:
        path = os.path.join(sources, src)
        font = TTFont(path)
        src_cmap = set(font.getBestCmap())
        modified = font["head"].modified
        if wght:
            font = roundtrip(instancer.instantiateVariableFont(font, {"wght": wght}))
        prev_file = os.path.join(previous, PREV_NAMES.get(face, "")) if previous else None
        prev_cmap = set(TTFont(prev_file).getBestCmap()) if prev_file and os.path.exists(prev_file) else set()
        want = prev_cmap | needs.get(family, set()) | {cp for cp in src_cmap if in_blocks(cp, LATN_BLOCKS + SYM_BLOCKS)}
        cover = want & src_cmap
        parts = {p: {cp for cp in cover if part_of(cp) == p} for p in PARTS}
        sizes = {}
        for part, cps in parts.items():
            if not cps: continue
            f = subset_to(roundtrip(font), cps)
            f["head"].modified = modified                   # deterministic bytes
            data = woff2_bytes(f)
            name = f"{face}-{part}.woff2"
            open(os.path.join(out, name), "wb").write(data)
            sizes[part] = len(data)
            fmt = "woff2-variations" if wght else "woff2"
            css.append(FACE_CSS.format(family=family, file=name, fmt=fmt, weight=weight, style=style, range=css_range(cps)))
        lost = sorted(prev_cmap - cover)
        report.append({"face": face, "source": src, "cover": len(cover), "counts": {p: len(c) for p, c in parts.items()},
                       "bytes": sizes, "previous_bytes": os.path.getsize(prev_file) if prev_cmap else None,
                       "lost_vs_previous": [f"U+{c:04X}" for c in lost],
                       "unavailable_needed": sorted(f"U+{c:04X} {chr(c)}" for c in needs.get(family, set()) - src_cmap if c > 0xFF)})
    open(os.path.join(out, "fonts.css"), "w", encoding="utf-8").write("\n".join(css))
    json.dump(report, open(os.path.join(out, "build-report.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return report

PREV_NAMES = {"Literata": "Literata-var.woff2", "Literata-Italic": "Literata-Italic-var.woff2",
              "Newsreader": "Newsreader-var.woff2", "FiraSans-Regular": "FiraSans-Regular.woff2",
              "FiraSans-Italic": "FiraSans-Italic.woff2", "FiraSans-SemiBold": "FiraSans-SemiBold.woff2",
              "FiraSans-Bold": "FiraSans-Bold.woff2", "SplineSansMono": "SplineSansMono-var.woff2",
              "SplineSansMono-Italic": "SplineSansMono-Italic-var.woff2"}

CSS_HEADER = """/* CARO self-hosted typography — generated by scripts/build-fonts.py; do not edit.
   Literata (serif text, opsz 7-72 via font-optical-sizing), Newsreader (display:
   h1 and dict-word), Fira Sans (UI and IPA), Spline Sans Mono (mono chrome). All OFL.
   Self-hosting keeps the OpenType features (smcp/onum/pnum/tnum/lnum) that the
   Google Fonts CSS API strips. Variable faces are instanced to the weights the
   fleet draws. Each face is split in three: core (Latin-1, punctuation, common
   symbols), Latin Extended and IPA, and symbols (Greek, arrows, sub/superscripts,
   math, shapes); a page fetches only the files whose unicode-range it uses.
   url()s resolve relative to this file. */
"""

FACE_CSS = """@font-face {{
  font-family: "{family}";
  src: url("{file}") format("{fmt}");
  font-weight: {weight};
  font-style: {style};
  font-display: swap;
  unicode-range: {range};
}}"""

def digest(d):
    h = hashlib.sha256()
    for n in sorted(os.listdir(d)):
        if n.endswith((".woff2", ".css")):
            h.update(n.encode()); h.update(open(os.path.join(d, n), "rb").read())
    return h.hexdigest()

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--sources"); ap.add_argument("--from-git")
    ap.add_argument("--out", required=True)
    ap.add_argument("--previous", default=os.path.join(REPO, "fonts"), help="the currently shipped fonts/ (coverage floor)")
    ap.add_argument("--census"); ap.add_argument("--check-rebuild", action="store_true")
    a = ap.parse_args()
    tmp = None
    if a.from_git:
        tmp = tempfile.mkdtemp(prefix="caro-font-src-")
        names = subprocess.run(["git", "-C", REPO, "ls-tree", "--name-only", a.from_git, "fonts/"],
                               check=True, capture_output=True, text=True).stdout.split()
        for n in names:
            if n.endswith((".ttf", ".otf")):
                data = subprocess.run(["git", "-C", REPO, "show", f"{a.from_git}:{n}"], check=True, capture_output=True).stdout
                open(os.path.join(tmp, os.path.basename(n)), "wb").write(data)
        a.sources = tmp
    if not a.sources:
        sys.exit("give --sources or --from-git")
    needs = load_census_needs(a.census)
    report = build(a.sources, a.out, a.previous, needs)
    for r in report:
        prev = f"{r['previous_bytes']/1024:6.1f}K" if r["previous_bytes"] else "   -   "
        parts = "  ".join(f"{p} {r['bytes'][p]/1024:5.1f}K" for p in PARTS if p in r["bytes"])
        print(f"{r['face']:22s} was {prev}  {parts}  lost {len(r['lost_vs_previous'])}"
              f"  not in source: {' '.join(r['unavailable_needed']) or '-'}")
    if any(r["lost_vs_previous"] for r in report):
        sys.exit("error: a face lost code points the previous build covered")
    if a.check_rebuild:
        again = tempfile.mkdtemp(prefix="caro-font-rebuild-")
        build(a.sources, again, a.previous, needs)
        if digest(again) != digest(a.out):
            sys.exit("error: rebuild is not byte-identical")
        print("rebuild byte-identical")

if __name__ == "__main__":
    main()
