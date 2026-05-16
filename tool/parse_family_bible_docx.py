#!/usr/bin/env python3
"""Parse family bible docx files into assets/data/family_christian_content.json"""
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "data" / "family_christian_content.json"

MAPPING = {
    "pt": Path(r"c:\Users\Dell\Downloads\passagens_biblicas_familia_PT_BR.docx"),
    "en": Path(r"c:\Users\Dell\Downloads\bible_verses_family_EN_US.docx"),
    "es": Path(r"c:\Users\Dell\Downloads\versiculos_biblicos_familia_ES.docx"),
    "fr": Path(r"c:\Users\Dell\Downloads\versets_bibliques_famille_FR.docx"),
    "de": Path(r"c:\Users\Dell\Downloads\bibelverse_familie_DE.docx"),
    "it": Path(r"c:\Users\Dell\Downloads\versetti_biblici_famiglia_IT.docx"),
}

VERSE_RE = re.compile(
    r"^\d+\.\s*[\"'«“]?(.*?)[\"'»”]?\s*[-–—]\s*(.+)$",
    re.DOTALL,
)


def parse_docx(fp: Path) -> list[dict]:
    with zipfile.ZipFile(fp) as z:
        xml = z.read("word/document.xml").decode("utf-8", "replace")
    text = re.sub(r"</w:p>", "\n", xml)
    text = re.sub(r"<[^>]+>", "", text)
    verses = []
    for ln in text.split("\n"):
        ln = ln.strip()
        if not ln or ln.startswith("Passagens") or ln.startswith("Bible") or ln.startswith("Eine") or ln.startswith("Une") or ln.startswith("Una") or ln.startswith("Versetti") or "collection" in ln.lower():
            continue
        m = VERSE_RE.match(ln)
        if m:
            verses.append(
                {"text": m.group(1).strip(), "reference": m.group(2).strip()}
            )
    return verses


def main() -> None:
    out: dict[str, list] = {}
    for lang, fp in MAPPING.items():
        if not fp.exists():
            print(f"missing {lang}: {fp}")
            continue
        verses = parse_docx(fp)
        out[lang] = verses
        print(f"{lang}: {len(verses)} verses")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
