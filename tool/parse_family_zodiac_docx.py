#!/usr/bin/env python3
"""Extrai textos de signos (pai/mãe/bebê) dos DOCX e gera assets/data/family_zodiac_content.json."""
import json
import re
import zipfile
from pathlib import Path

EMOJI_TO_ID = {
    "♈": "aries",
    "♉": "taurus",
    "♊": "gemini",
    "♋": "cancer",
    "♌": "leo",
    "♍": "virgo",
    "♎": "libra",
    "♏": "scorpio",
    "♐": "sagittarius",
    "♑": "capricorn",
    "♒": "aquarius",
    "♓": "pisces",
}

FATHER_HEADERS = {
    "Como é o Pai",
    "How the Father Is",
    "Cómo es el Padre",
    "Wie der Vater ist",
    "Comment est le Père",
    "Com'è il Padre",
}
MOTHER_HEADERS = {
    "Como é a Mãe",
    "How the Mother Is",
    "Cómo es la Madre",
    "Wie die Mutter ist",
    "Comment est la Mère",
    "Com'è la Madre",
}
BABY_HEADERS = {
    "Como é o Bebê",
    "How the Baby Is",
    "Cómo es el Bebé",
    "Wie das Baby ist",
    "Comment est le Bébé",
    "Com'è il Bambino",
}
TRAITS_PREFIXES = (
    "Características",
    "Caracteristicas",
    "Father Traits",
    "Mother Traits",
    "Baby Traits",
    "Eigenschaften",
    "Caractéristiques",
    "Caratteristiche",
)
SKIP_LINES = {
    "Conclusão",
    "Conclusion",
    "Conclusión",
    "Conclusione",
    "Fazit",
}


def extract_docx(path: str) -> list[str]:
    z = zipfile.ZipFile(path)
    xml = z.read("word/document.xml").decode("utf-8")
    text = re.sub(r"</w:p>", "\n", xml)
    text = re.sub(r"<[^>]+>", "", text)
    return [ln.strip() for ln in text.split("\n") if ln.strip()]


def parse_lines(lines: list[str]) -> dict:
    out: dict = {}
    current_sign = None
    mode = None
    buffer: list[str] = []

    def flush():
        nonlocal buffer, mode
        if current_sign and mode and buffer:
            body = " ".join(buffer).strip()
            body = re.sub(r"\s+", " ", body)
            out.setdefault(current_sign, {})[mode] = body
        buffer = []

    for line in lines:
        if line in SKIP_LINES or line.startswith("Conclus"):
            flush()
            break

        sign_hit = None
        for emoji, sid in EMOJI_TO_ID.items():
            if emoji in line:
                sign_hit = sid
                break
        if sign_hit:
            flush()
            current_sign = sign_hit
            mode = None
            continue

        if line in FATHER_HEADERS:
            flush()
            mode = "father"
            continue
        if line in MOTHER_HEADERS:
            flush()
            mode = "mother"
            continue
        if line in BABY_HEADERS:
            flush()
            mode = "baby"
            continue

        if any(line.startswith(p) for p in TRAITS_PREFIXES):
            flush()
            mode = None
            continue

        if mode and current_sign:
            buffer.append(line)

    flush()
    return out


def main():
    root = Path(__file__).resolve().parent.parent
    files = {
        "pt": Path(r"c:\Users\Dell\Downloads\pais_maes_bebes_signos_PT-BR.docx"),
        "en": Path(r"c:\Users\Dell\Downloads\parents_babies_zodiac_EN_US.docx"),
        "es": Path(r"c:\Users\Dell\Downloads\padres_madres_bebes_signos_ES.docx"),
        "fr": Path(r"c:\Users\Dell\Downloads\parents_bebes_signes_FR.docx"),
        "de": Path(r"c:\Users\Dell\Downloads\eltern_babys_sternzeichen_DE.docx"),
        "it": Path(r"c:\Users\Dell\Downloads\genitori_bambini_segni_IT.docx"),
    }
    all_data = {}
    for lang, path in files.items():
        lines = extract_docx(str(path))
        parsed = parse_lines(lines)
        all_data[lang] = parsed
        print(lang, "signs", len(parsed), "sample aries father", (parsed.get("aries", {}).get("father", "")[:80]))

    out_path = root / "assets" / "data" / "family_zodiac_content.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(all_data, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Wrote", out_path)


if __name__ == "__main__":
    main()
