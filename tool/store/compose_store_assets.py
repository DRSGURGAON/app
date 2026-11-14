"""Builds Google Play store assets from app screenshots.

Usage (from the repo root, after rendering screenshots with
`SHOTS_STORE=1 SHOTS_LANG=<en|hi> SHOTS_DIR=<dir>/<en|hi> flutter test tool/screenshots/screenshots_test.dart`):

    python3 tool/store/compose_store_assets.py <dir>

Writes store/screenshots/<locale>/NN.jpg (1080x1920, caption + screen) and
store/feature_graphic.png (1024x500). Needs Pillow with raqm (Hindi shaping).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS = os.path.join(ROOT, "assets", "fonts")
TOP = (0x1B, 0x2F, 0x9E)
BOTTOM = (0x07, 0x10, 0x3A)

SHOTS = [
    ("01-home", "Your documents, encrypted on your phone", "आपके दस्तावेज़, आपके फ़ोन पर एन्क्रिप्टेड"),
    ("03-vault", "Organised by category, folder and tag", "श्रेणी, फ़ोल्डर और टैग से व्यवस्थित"),
    ("04-details", "Expiry dates and reminders", "समाप्ति तारीख और रिमाइंडर"),
    ("06-tools", "PDF tools that work offline", "बिना इंटरनेट चलने वाले PDF टूल्स"),
    ("07-reminders", "Never miss a renewal", "कोई रिन्यूअल न छूटे"),
    ("11-lock", "PIN and fingerprint lock", "PIN और फ़िंगरप्रिंट लॉक"),
    ("10-onboarding", "No account. No cloud. No ads.", "न खाता, न क्लाउड, न विज्ञापन"),
    ("21-premium-plans", "Premium: merge, split and sign PDFs", "प्रीमियम: PDF जोड़ें, अलग करें, साइन करें"),
]


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        c = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def font(hindi, size):
    name = "NotoSansDevanagari-700.ttf" if hindi else "Sora-700.ttf"
    return ImageFont.truetype(os.path.join(FONTS, name), size, layout_engine=ImageFont.Layout.RAQM)


def is_deva(ch):
    return "\u0900" <= ch <= "\u097F"


def runs(text, size):
    """Splits text into (string, font) runs: Devanagari in Noto, the rest in Sora."""
    out = []
    for ch in text:
        deva = is_deva(ch) or (ch == " " and out and out[-1][1])
        if out and out[-1][1] == deva:
            out[-1][0] += ch
        else:
            out.append([ch, deva])
    return [(t, font(d, size)) for t, d in out]


def width(draw, text, size):
    return sum(draw.textlength(t, font=f) for t, f in runs(text, size))


def draw_line(draw, x, y, text, size, fill):
    for t, f in runs(text, size):
        draw.text((x, y), t, font=f, fill=fill)
        x += draw.textlength(t, font=f)


def wrap(draw, text, size, max_width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if width(draw, trial, size) <= max_width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    # Avoid a lonely last word: move one word down when it balances better.
    if len(lines) == 2 and len(lines[1].split()) == 1 and len(lines[0].split()) > 2:
        head = lines[0].split()
        lines = [" ".join(head[:-1]), head[-1] + " " + lines[1]]
    return lines


def compose(shot_path, caption, hindi, out):
    W, H = 1080, 1920
    canvas = gradient(W, H)
    draw = ImageDraw.Draw(canvas)
    size = 60 if hindi else 64
    y = 110
    for line in wrap(draw, caption, size, W - 160):
        draw_line(draw, (W - width(draw, line, size)) / 2, y, line, size, "white")
        y += 92
    shot = Image.open(shot_path).convert("RGB")
    sw = 780
    sh = int(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    top = max(y + 50, 360)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw, sh), radius=48, fill=255)
    shadow = Image.new("RGBA", (sw + 80, sh + 80), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((40, 50, sw + 40, sh + 40), radius=56, fill=(0, 0, 0, 140))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas.paste(shadow, ((W - sw) // 2 - 40, top - 40), shadow)
    canvas.paste(shot, ((W - sw) // 2, top), mask)
    # The screen runs off the bottom edge, like a phone held up.
    os.makedirs(os.path.dirname(out), exist_ok=True)
    canvas.save(out, quality=92, optimize=True)


def feature_graphic(out):
    W, H = 1024, 500
    canvas = gradient(W, H)
    icon = Image.open(os.path.join(ROOT, "docs", "brand", "icon-512.png")).convert("RGBA").resize((300, 300), Image.LANCZOS)
    mask = Image.new("L", (300, 300), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 300, 300), radius=72, fill=255)
    canvas.paste(icon, (90, 100), mask)
    draw = ImageDraw.Draw(canvas)
    draw.text((450, 150), "DocSafe", font=font(False, 96), fill="white")
    draw.text((452, 270), "Your documents. Your privacy.", font=font(False, 34), fill=(0xC9, 0xD2, 0xFF))
    draw.text((452, 318), "One secure place.", font=font(False, 34), fill=(0xC9, 0xD2, 0xFF))
    canvas.save(out, optimize=True)


def main():
    shots_dir = sys.argv[1]
    for locale, lang, us in [("en-IN", "en", False), ("en-GB", "en", False), ("en-US", "en", True), ("hi-IN", "hi", False)]:
        for i, (name, en, hi) in enumerate(SHOTS, 1):
            caption = hi if lang == "hi" else (en.replace("Organised", "Organized") if us else en)
            compose(os.path.join(shots_dir, lang, name + ".png"), caption, lang == "hi",
                    os.path.join(ROOT, "store", "screenshots", locale, f"{i:02d}.jpg"))
    feature_graphic(os.path.join(ROOT, "store", "feature_graphic.png"))
    Image.open(os.path.join(ROOT, "docs", "brand", "icon-512.png")).save(os.path.join(ROOT, "store", "icon-512.png"))


if __name__ == "__main__":
    main()
