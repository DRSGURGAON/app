"""Builds Google Play foldable screenshots from app screenshots.

Render the screens first at foldable sizes, for each language (en, hi):

    SHOTS_SIZE=2200x2200 SHOTS_LANG=en SHOTS_DIR=<dir>/square/en flutter test tool/screenshots/screenshots_test.dart
    SHOTS_SIZE=2400x1800 ...                   SHOTS_DIR=<dir>/wide/en  ...
    SHOTS_SIZE=1080x1728 ...                   SHOTS_DIR=<dir>/outer/en ...

then:

    python3 tool/store/compose_foldable.py <dir>

Writes store/screenshots_foldable/<locale>/NN-<ratio>.jpg:
1:1 and 4:3 of the unfolded inner screen, 10:16 of the outer screen (portrait).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose_store_assets import ROOT, draw_line, gradient, width, wrap  # noqa: E402

# (file name, ratio label, canvas size, source folder, screen, English caption, Hindi caption)
SHOTS = [
    ("01-1x1", (2048, 2048), "square", "01-home",
     "Your documents, encrypted on your phone", "आपके दस्तावेज़, आपके फ़ोन पर एन्क्रिप्टेड"),
    ("02-4x3", (2048, 1536), "wide", "06-tools",
     "PDF tools that work offline", "बिना इंटरनेट चलने वाले PDF टूल्स"),
    ("03-10x16", (1200, 1920), "outer", "01-home",
     "Scan, organise and find documents fast", "दस्तावेज़ स्कैन करें, व्यवस्थित रखें, जल्दी खोजें"),
    ("04-4x3", (2048, 1536), "wide", "07-reminders",
     "Never miss a renewal", "कोई रिन्यूअल न छूटे"),
    ("05-1x1", (2048, 2048), "square", "03-vault",
     "Organised by category, folder and tag", "श्रेणी, फ़ोल्डर और टैग से व्यवस्थित"),
    ("06-10x16", (1200, 1920), "outer", "11-lock",
     "PIN and fingerprint lock", "PIN और फ़िंगरप्रिंट लॉक"),
]

LOCALES = [("en-IN", "en"), ("en-US", "en"), ("en-GB", "en"), ("hi-IN", "hi")]


def compose(src, size, caption):
    w, h = size
    canvas = gradient(w, h)
    draw = ImageDraw.Draw(canvas)
    fsize = int(min(w, h) * 0.05)
    lines = wrap(draw, caption, fsize, w * 0.86)
    y = int(h * 0.04)
    for line in lines:
        draw_line(draw, (w - width(draw, line, fsize)) / 2, y, line, fsize, "white")
        y += int(fsize * 1.3)
    top = y + int(h * 0.025)
    shot = Image.open(src).convert("RGB")
    avail_w, avail_h = w * 0.9, h - top - h * 0.04
    scale = min(avail_w / shot.width, avail_h / shot.height)
    shot = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)
    x = (w - shot.width) // 2
    radius = int(min(shot.size) * 0.03)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, *shot.size], radius, fill=255)
    shadow = Image.new("L", (shot.width + 80, shot.height + 80), 0)
    ImageDraw.Draw(shadow).rounded_rectangle([40, 40, shot.width + 40, shot.height + 40], radius, fill=140)
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas.paste((0, 0, 0), (x - 40, top - 28), shadow)
    canvas.paste(shot, (x, top), mask)
    return canvas


def main(src_dir):
    for locale, lang in LOCALES:
        out = os.path.join(ROOT, "store", "screenshots_foldable", locale)
        os.makedirs(out, exist_ok=True)
        for name, size, folder, screen, en, hi in SHOTS:
            src = os.path.join(src_dir, folder, lang, screen + ".png")
            caption = hi if lang == "hi" else en
            if locale == "en-US":
                caption = caption.replace("Organised", "Organized").replace("organise", "organize")
            img = compose(src, size, caption)
            img.save(os.path.join(out, name + ".jpg"), quality=90)
    print("ok")


if __name__ == "__main__":
    main(sys.argv[1])
