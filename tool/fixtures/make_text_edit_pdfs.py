"""Creates the PDFs used by test/pdf/text_edit_core_test.dart.

Run from the repo root (needs reportlab, fontTools and LibreOffice):
    python3 tool/fixtures/make_text_edit_pdfs.py /usr/share/fonts/truetype
"""
import os
import subprocess
import sys
import tempfile

from fontTools.ttLib import TTFont
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont as RLFont
from reportlab.pdfgen import canvas

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "test", "fixtures", "pdf")


def find(root, name):
    for d, _, files in os.walk(root):
        if name in files:
            return os.path.join(d, name)
    raise SystemExit(name)


def receipt():
    c = canvas.Canvas(os.path.join(OUT, "receipt_helvetica.pdf"), pagesize=A4)
    c.setFont("Helvetica-Bold", 18)
    c.drawString(72, 770, "RENT RECEIPT")
    c.setFont("Helvetica", 12)
    c.drawString(72, 730, "Received from: Rahul Sharma")
    # One line drawn as two objects with a gap: grouped into one run.
    c.drawString(72, 710, "Amount:")
    c.drawString(122, 710, "Rs. 15,000")
    c.drawString(400, 710, "Paid")  # far right: separate run, limits growth
    c.setFillColorRGB(0.8, 0, 0)
    c.drawString(72, 690, "Due date: 5 April 2026")
    c.saveState()
    c.translate(300, 400)
    c.rotate(90)
    c.setFillColorRGB(0, 0, 0)
    c.drawString(0, 0, "Rotated note")
    c.restoreState()
    c.save()


def calibri_named(fonts):
    # A Calibri-named subset font (built from Carlito, which has Calibri's
    # metrics) so the "metric twin" path can be tested without Calibri.
    src = find(fonts, "Carlito-Regular.ttf")
    f = TTFont(src)
    for rec in f["name"].names:
        if rec.nameID in (1, 4, 16):
            rec.string = "Calibri"
        if rec.nameID == 6:
            rec.string = "Calibri"
    tmp = os.path.join(tempfile.mkdtemp(), "Calibri.ttf")
    f.save(tmp)
    pdfmetrics.registerFont(RLFont("Calibri", tmp))
    c = canvas.Canvas(os.path.join(OUT, "letter_calibri.pdf"), pagesize=A4)
    c.setFont("Calibri", 12)
    c.drawString(72, 760, "Dear Rahul Sharma,")
    c.drawString(72, 740, "Your joining date is 1 April 2026.")
    c.save()


def libreoffice_letter():
    html = os.path.join(tempfile.mkdtemp(), "letter_libreoffice.html")
    with open(html, "w") as h:
        h.write(
            "<html><body style=\"font-family:Carlito; font-size:12pt\">"
            "<h2 style=\"font-family:'Liberation Serif'\">Offer of Employment</h2>"
            "<p>Dear Rahul Sharma,</p>"
            "<p>We are pleased to offer you the position of Software Engineer at Acme "
            "Technologies Pvt Ltd, starting on 1 April 2026, with an annual salary of "
            "Rs. 12,00,000.</p><p>Please sign and return this letter by 15 March 2026.</p>"
            "<p>Regards,<br>Priya Mehta<br>HR Manager</p></body></html>"
        )
    subprocess.run(["soffice", "--headless", "--convert-to", "pdf", "--outdir", OUT, html],
                   check=True, capture_output=True, timeout=180)


def canva_like(fonts):
    """Design-tool style page: every text object sits inside a Form XObject
    (Canva and similar tools do this), one of them in a nested form, with a
    transformed form matrix."""
    src = find(fonts, "Carlito-Regular.ttf")
    pdfmetrics.registerFont(RLFont("CarlitoEmb", src))
    c = canvas.Canvas(os.path.join(OUT, "form_xobject_resume.pdf"), pagesize=A4)
    # Inner form, used inside the outer one.
    c.beginForm("Badge")
    c.setFillColorRGB(0.1, 0.6, 0.7)
    c.rect(0, 0, 220, 22, fill=1, stroke=0)
    c.setFillColorRGB(1, 1, 1)
    c.setFont("Helvetica-Bold", 11)
    c.drawString(8, 7, "SUPPORT AGENT (FINANCE)")
    c.endForm()
    c.beginForm("Page")
    c.setFillColorRGB(0, 0, 0)
    c.setFont("Helvetica-Bold", 24)
    c.drawString(0, 700, "ASHA VERMA")
    c.saveState()
    c.translate(0, 660)
    c.doForm("Badge")
    c.restoreState()
    c.setFont("CarlitoEmb", 12)
    c.drawString(0, 620, "Education: Delhi Public School")
    c.drawString(0, 600, "Skills: Customer care, Excel")
    # Letter-spaced heading written one letter per text object, word spaces
    # inside the objects ("M "), the way Canva writes it.
    c.setFont("Helvetica", 11)
    x = 0
    for ch in ["T", "E", "A", "M ", "L", "E", "A", "D"]:
        c.drawString(x, 570, ch)
        x += pdfmetrics.stringWidth(ch, "Helvetica", 11) + 2.5
    c.endForm()
    c.setFillColorRGB(0.95, 0.95, 0.95)
    c.rect(0, 0, A4[0], A4[1], fill=1, stroke=0)
    c.saveState()
    c.translate(60, 40)
    c.doForm("Page")
    c.restoreState()
    c.showPage()
    c.save()


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    receipt()
    calibri_named(sys.argv[1])
    libreoffice_letter()
    canva_like(sys.argv[1])
    for f in sorted(os.listdir(OUT)):
        print(f, os.path.getsize(os.path.join(OUT, f)))
