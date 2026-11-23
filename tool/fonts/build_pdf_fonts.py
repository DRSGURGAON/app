"""Builds the fallback fonts used by PDF "Edit text" (assets/pdf_fonts/).

They are metric-compatible clones of common office fonts, cut down to the
characters the app lets users type when editing English PDFs, and renamed
because the SIL OFL does not allow modified fonts to keep their original
names. Run from the repo root:  python3 tool/fonts/build_pdf_fonts.py <fonts dir>
where <fonts dir> contains the Liberation 2.x, Carlito and Caladea .ttf files
(e.g. Debian/Ubuntu packages fonts-liberation2 and fonts-crosextra-*).
"""
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

# Basic Latin, Latin-1, dashes/quotes/bullet/ellipsis, per mille, primes,
# euro, rupee, pound/yen (in Latin-1), trade mark.
UNICODES = (
    list(range(0x20, 0x7F)) + list(range(0xA0, 0x100)) + list(range(0x2010, 0x2028))
    + [0x2030, 0x2032, 0x2033, 0x20AC, 0x20B9, 0x2122]
)

FAMILIES = [
    # (new family, source file prefix, styles, metric twin of)
    ("Scanner Pro Sans", "LiberationSans", ["Regular", "Bold", "Italic", "BoldItalic"], "Arial / Helvetica"),
    ("Scanner Pro Serif", "LiberationSerif", ["Regular", "Bold", "Italic", "BoldItalic"], "Times New Roman / Times"),
    ("Scanner Pro Mono", "LiberationMono", ["Regular", "Bold"], "Courier New / Courier"),
    ("Scanner Pro Office Sans", "Carlito", ["Regular", "Bold", "Italic", "BoldItalic"], "Calibri"),
    ("Scanner Pro Office Serif", "Caladea", ["Regular", "Bold", "Italic", "BoldItalic"], "Cambria"),
]

STYLE_NAMES = {"Regular": "Regular", "Bold": "Bold", "Italic": "Italic", "BoldItalic": "Bold Italic"}


def find(src_dir, name):
    for root, _, files in os.walk(src_dir):
        if name in files:
            return os.path.join(root, name)
    raise SystemExit(f"missing {name} under {src_dir}")


def build(src_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    notices = []
    for family, prefix, styles, twin in FAMILIES:
        for style in styles:
            src = find(src_dir, f"{prefix}-{style}.ttf")
            opts = subset.Options()
            opts.layout_features = ["kern", "liga"]
            opts.hinting = False
            opts.name_IDs = ["*"]
            opts.notdef_outline = True
            font = TTFont(src)
            sub = subset.Subsetter(opts)
            sub.populate(unicodes=UNICODES)
            sub.subset(font)
            full = family if style == "Regular" else f"{family} {STYLE_NAMES[style]}"
            ps = f"{family.replace(' ', '')}-{style}"
            name = font["name"]
            for rec in list(name.names):
                if rec.nameID in (1, 3, 4, 6, 16, 17, 21, 22):
                    name.removeNames(nameID=rec.nameID)
            name.setName(family, 1, 3, 1, 0x409)
            name.setName(STYLE_NAMES[style], 2, 3, 1, 0x409)
            name.setName(f"{ps};ScannerPro", 3, 3, 1, 0x409)
            name.setName(full, 4, 3, 1, 0x409)
            name.setName(ps, 6, 3, 1, 0x409)
            out = os.path.join(out_dir, f"{ps}.ttf")
            font.save(out)
            if style == "Regular":
                copyright_text = TTFont(src)["name"].getDebugName(0)
                notices.append(f"{family} (metrics of {twin}) is a modified (subset, renamed) version of {prefix}.\n{copyright_text}")
            print(out, os.path.getsize(out))
    with open(os.path.join(out_dir, "NOTICE.txt"), "w") as f:
        f.write("Fallback fonts for PDF text editing. Licensed under the SIL Open Font License 1.1 (see OFL.txt).\n\n")
        f.write("\n\n".join(notices) + "\n")


if __name__ == "__main__":
    build(sys.argv[1], os.path.join(os.path.dirname(__file__), "..", "..", "assets", "pdf_fonts"))
