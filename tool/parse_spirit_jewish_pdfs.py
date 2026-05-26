#!/usr/bin/env python3
"""Extrai frases numeradas dos PDFs para JSON (pt, en, es, fr, de, it)."""
import json
import re
import sys
from pathlib import Path

from pypdf import PdfReader

PDF_DIR = Path(
    r"C:\Users\Dell\Downloads\Frases_Espiritas_e_Judias_Revisado_300_6_idiomas"
)
OUT_SPIRIT = Path(__file__).resolve().parent.parent / "assets/data/family_spiritist_content.json"
OUT_JEWISH = Path(__file__).resolve().parent.parent / "assets/data/family_jewish_content.json"

LANG_MAP = {
    "PT-BR": "pt",
    "EN": "en",
    "ES": "es",
    "FR": "fr",
    "DE": "de",
    "IT": "it",
}

LINE_RE = re.compile(r"^\s*(\d+)\.\s*(.+?)\s*$")


def lang_from_name(name: str) -> str | None:
    for suffix, code in LANG_MAP.items():
        if f"_{suffix}.pdf" in name or name.endswith(f"{suffix}.pdf"):
            return code
    return None


def extract_phrases(pdf_path: Path) -> list[str]:
    reader = PdfReader(str(pdf_path))
    text = "\n".join((p.extract_text() or "") for p in reader.pages)
    phrases: list[str] = []
    for line in text.splitlines():
        m = LINE_RE.match(line.strip())
        if not m:
            continue
        body = m.group(2).strip()
        if body:
            phrases.append(body)
    return phrases


def build_json(prefix: str) -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for pdf in sorted(PDF_DIR.glob(f"{prefix}_*.pdf")):
        lang = lang_from_name(pdf.name)
        if not lang:
            print(f"skip {pdf.name}", file=sys.stderr)
            continue
        phrases = extract_phrases(pdf)
        out[lang] = phrases
        print(f"{pdf.name}: {len(phrases)} phrases -> {lang}", file=sys.stderr)
    return out


def main() -> None:
    spirit = build_json("Frases_Espiritas_Revisado")
    jewish = build_json("Frases_Judias_Revisado")
    OUT_SPIRIT.write_text(
        json.dumps(spirit, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    OUT_JEWISH.write_text(
        json.dumps(jewish, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {OUT_SPIRIT} ({sum(len(v) for v in spirit.values())} total)")
    print(f"Wrote {OUT_JEWISH} ({sum(len(v) for v in jewish.values())} total)")


if __name__ == "__main__":
    main()
