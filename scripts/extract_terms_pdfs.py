"""Extract terms PDF text for inspection."""
from pathlib import Path

from pypdf import PdfReader

PDFS = [
    Path(r"c:\Users\Dell\Downloads\DE – NUTZUNGSBEDINGUNGEN.pdf"),
    Path(r"c:\Users\Dell\Downloads\PT – TERMOS DE USO.pdf"),
    Path(r"c:\Users\Dell\Downloads\EN – TERMS OF USE.pdf"),
    Path(r"c:\Users\Dell\Downloads\ES – TÉRMINOS DE USO.pdf"),
    Path(r"c:\Users\Dell\Downloads\FR - Conditions d'Utilisation FaceBaby.pdf"),
    Path(r"c:\Users\Dell\Downloads\IT - TERMINI DI UTILIZZO.pdf"),
]

OUT = Path(__file__).resolve().parent.parent / "tmp_terms_extract"

def main() -> None:
    OUT.mkdir(exist_ok=True)
    for pdf in PDFS:
        print(f"=== {pdf.name} ===")
        if not pdf.exists():
            print("NOT FOUND:", pdf)
            continue
        reader = PdfReader(str(pdf))
        text = "\n".join(page.extract_text() or "" for page in reader.pages)
        out = OUT / f"{pdf.stem}.txt"
        out.write_text(text, encoding="utf-8")
        print(f"pages={len(reader.pages)} len={len(text)} -> {out}")
        print(text[:2500])
        print()

if __name__ == "__main__":
    main()
