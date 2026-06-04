#!/usr/bin/env python3
"""Split FaceBaby privacy PDF extract into per-locale asset files.

Regenerate extract from PDF (requires pypdf):
  python -c "from pypdf import PdfReader; from pathlib import Path; p=Path('path/to/FaceBaby_Privacy_Policy.pdf'); print(''.join(PdfReader(p).pages[i].extract_text() or '' for i in range(len(PdfReader(p).pages))), end='', file=open('_privacy_extract.txt','w',encoding='utf-8'))"
Then run this script.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXTRACT = ROOT / "_privacy_extract.txt"
OUT_DIR = ROOT / "assets" / "privacy"

SECTIONS = [
    (
        "privacy_pt_BR.txt",
        r"^\s*POLÍTICA DE PRIVACIDADE - FACEBABY\s*$",
        r"^\s*FACEBABY PRIVACY POLICY\s*$",
        "FaceBaby — Política de Privacidade",
    ),
    (
        "privacy_en_US.txt",
        r"^\s*FACEBABY PRIVACY POLICY\s*$",
        r"^\s*POLÍTICA DE PRIVACIDAD - FACEBABY\s*$",
        "FaceBaby — Privacy Policy",
    ),
    (
        "privacy_es_ES.txt",
        r"^\s*POLÍTICA DE PRIVACIDAD - FACEBABY\s*$",
        r"^\s*INFORMATIVA SULLA PRIVACY - FACEBABY\s*$",
        "FaceBaby — Política de Privacidad",
    ),
    (
        "privacy_it_IT.txt",
        r"^\s*INFORMATIVA SULLA PRIVACY - FACEBABY\s*$",
        r"^\s*POLITIQUE DE CONFIDENTIALITÉ - FACEBABY\s*$",
        "FaceBaby — Informativa sulla Privacy",
    ),
    (
        "privacy_fr_FR.txt",
        r"^\s*POLITIQUE DE CONFIDENTIALITÉ - FACEBABY\s*$",
        r"^\s*DATENSCHUTZERKLÄRUNG - FACEBABY\s*$",
        "FaceBaby — Politique de Confidentialité",
    ),
    (
        "privacy_de_DE.txt",
        r"^\s*DATENSCHUTZERKLÄRUNG - FACEBABY\s*$",
        None,
        "FaceBaby — Datenschutzerklärung",
    ),
]

PAGE_NOISE = re.compile(
    r"^FaceBaby Privacy Policy - Page \d+\s*$|^ FACEBABY\s*$|^ Privacy Policy / .*$|^ PT-BR \| EN-US \| ES \| IT \| FR \| DE\s*$|^ Multilingual document with the same structure.*$",
    re.I,
)


def clean_body(raw: str, title: str) -> str:
    lines: list[str] = []
    for line in raw.splitlines():
        s = line.strip()
        if not s:
            lines.append("")
            continue
        if PAGE_NOISE.match(s):
            continue
        # Drop duplicate banner line inside section.
        if s.upper().startswith("POLÍTICA DE PRIVACIDADE - FACEBABY"):
            continue
        if s.upper().startswith("FACEBABY PRIVACY POLICY") and "Last updated" not in s:
            continue
        if s.upper().startswith("POLÍTICA DE PRIVACIDAD - FACEBABY"):
            continue
        if s.upper().startswith("INFORMATIVA SULLA PRIVACY - FACEBABY"):
            continue
        if s.upper().startswith("POLITIQUE DE CONFIDENTIALITÉ - FACEBABY"):
            continue
        if s.upper().startswith("DATENSCHUTZERKLÄRUNG - FACEBABY"):
            continue
        lines.append(line.rstrip())

    body = "\n".join(lines).strip()
    # Collapse 3+ blank lines.
    body = re.sub(r"\n{3,}", "\n\n", body)

    # First content line is usually "PT-BR - Última atualização..." — keep as meta after title.
    meta = ""
    rest = body
    lines = body.splitlines()
    if lines and re.search(
        r"Última atualização|Last updated|Última actualización|Ultimo aggiornamento|Dernière mise à jour|Letzte Aktualisierung",
        lines[0],
    ):
        meta = lines[0].strip()
        rest = "\n".join(lines[1:]).strip()

    parts = [title]
    if meta:
        parts.append(meta)
    if rest:
        parts.append(rest)
    return "\n\n".join(parts).strip() + "\n"


def main() -> None:
    text = EXTRACT.read_text(encoding="utf-8")
    for filename, start_pat, end_pat, title in SECTIONS:
        start = re.search(start_pat, text, re.I | re.M)
        if not start:
            raise SystemExit(f"Start marker not found: {start_pat}")
        end = len(text)
        if end_pat:
            end_m = re.search(end_pat, text[start.end() :], re.I | re.M)
            if end_m:
                end = start.end() + end_m.start()
        chunk = text[start.start() : end]
        out = clean_body(chunk, title)
        path = OUT_DIR / filename
        path.write_text(out, encoding="utf-8")
        print(f"Wrote {path.name} ({len(out)} chars)")


if __name__ == "__main__":
    main()
