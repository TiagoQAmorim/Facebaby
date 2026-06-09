#!/usr/bin/env python3
"""Convert FaceBaby terms PDFs into per-locale asset files."""
from __future__ import annotations

import re
from pathlib import Path

from pypdf import PdfReader

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "terms"

PDF_JOBS: list[tuple[Path, str, str]] = [
    (
        Path(r"c:\Users\Dell\Downloads\PT – TERMOS DE USO.pdf"),
        "terms_pt_BR.txt",
        "FaceBaby — Termos de Uso",
    ),
    (
        Path(r"c:\Users\Dell\Downloads\EN – TERMS OF USE.pdf"),
        "terms_en_US.txt",
        "FaceBaby — Terms of Use",
    ),
    (
        Path(r"c:\Users\Dell\Downloads\ES – TÉRMINOS DE USO.pdf"),
        "terms_es_ES.txt",
        "FaceBaby — Términos de Uso",
    ),
    (
        Path(r"c:\Users\Dell\Downloads\FR - Conditions d'Utilisation FaceBaby.pdf"),
        "terms_fr_FR.txt",
        "FaceBaby — Conditions d'Utilisation",
    ),
    (
        Path(r"c:\Users\Dell\Downloads\DE – NUTZUNGSBEDINGUNGEN.pdf"),
        "terms_de_DE.txt",
        "FaceBaby — Nutzungsbedingungen",
    ),
    (
        Path(r"c:\Users\Dell\Downloads\IT - TERMINI DI UTILIZZO.pdf"),
        "terms_it_IT.txt",
        "FaceBaby — Termini di Utilizzo",
    ),
]

SECTION_RE = re.compile(
    r"^\d+\.\s+[A-ZÀ-ŸÄÖÜÑÍÉÓÚÀÈÌÒÙÂÊÎÔÛÇÃÕА-Я0-9\"«]",
)
DEFINITION_LABEL_RE = re.compile(
    r"^[A-Za-zÀ-ÿÄÖÜäöüßÑñÍÉÓÚÀÈÌÒÙÂÊÎÔÛÇÃÕА-Я0-9\"«][^:\n]{0,36}:\s*\S",
)


def is_definition_line(line: str) -> bool:
    s = line.strip()
    if not DEFINITION_LABEL_RE.match(s):
        return False
    label = s.split(":", 1)[0].strip()
    if len(label.split()) > 3:
        return False
    lower = label.lower()
    list_intro_markers = (
        "incluir", "include", "incluy", "comprend", "beinhalten", "includono",
        "podem", "may", "poder", "puede", "peut", "kann", "può", "compromete",
        "agree", "reconhece", "acknowledg", "substitu", "replace", "proibido",
        "forbidden", "armazen", "store", "critério", "discretion", "contra",
        "against", "responsável por", "responsible for", "encaminh", "direct",
        "disposições", "provisions", "critério", "discretion",
    )
    if any(marker in lower for marker in list_intro_markers):
        return False
    return True
META_RE = re.compile(
    r"(Última atualização|Last Updated|Última actualización|"
    r"Ultimo aggiornamento|Dernière mise à jour|Letzte Aktualisierung)",
    re.I,
)
TITLE_BANNER_RE = re.compile(
    r"^FACEBABY\s+[—\-–]",
    re.I,
)
SUBSECTION_TITLE_RE = re.compile(
    r"^(Plano Gratuito|Plano Premium Mensal|Plano Premium Anual|"
    r"Free Plan|Monthly Premium Plan|Annual Premium Plan|"
    r"Plan Gratuito|Plan Premium Mensual|Plan Premium Anual|"
    r"Plan Gratuit|Plan Premium Mensuel|Plan Premium Annuel|"
    r"Kostenloser Plan|Monatliches Premium-Abo|Jährliches Premium-Abo|"
    r"Piano Gratuito|Piano Premium Mensile|Piano Premium Annuale)$",
    re.I,
)
LIST_EXIT_RE = re.compile(
    r"^(FaceBaby|O FaceBaby|Os |As |O usuário|A versão|Estes Termos|"
    r"Ao utilizar|Ao participar|Dúvidas|Todos os direitos|É proibido|"
    r"Na máxima|Em qualquer|By using|Users retain|The user|The latest|"
    r"Continued use|Questions regarding|For any health|FaceBaby may|"
    r"FaceBaby is|FaceBaby does|FaceBaby could|Current prices|"
    r"Cancellations|Other authorized|Payments may|Information provided|"
    r"Without prior|Users may|Promotions|Les présentes|L'utilisateur|"
    r"Der Nutzer|Die Nutzung|El usuario|La continuidad|Qualora l'utente|"
    r"Manutenção preventiva|Maintenance|"
    r"Interrupções de serviço|Service interruptions|Problemas decorrentes|"
    r"Problems arising|Legislações locais|Equivalent local|Legislaciones locales|"
    r"Não existe|A responsabilidade|As informações|"
    r"sem autorização|without prior|sans autorisation|ohne vorherige|"
    r"sin autorización|senza autorizzazione)",
    re.I,
)
TAIL_SPLIT_RE = re.compile(
    r"\.\s+(O FaceBaby|FaceBaby|O usuário|Os preços|Em qualquer|Na máxima|"
    r"A responsabilidade|Não existe|As informações|Dúvidas|Todos os direitos|"
    r"The user|Users |By using|For any|It is prohibited|Continued use|"
    r"Information provided|Les informations|Die Nutzung|El usuario|L'utente|"
    r"La continuidad|Qualora l'utente|Der Nutzer|Le informazioni|"
    r"La responsabilità|Il FaceBaby|La versione|Ao utilizar o FaceBaby|"
    r"A responsabilidade total|FaceBaby's total liability|"
    r"O usuário é incentivado|Users are encouraged|"
    r"Não existe garantia|Continuous or uninterrupted|"
    r"FaceBaby has no control|FaceBaby não possui controle|"
    r"Legislações locais|Equivalent local|Legislaciones locales|"
    r"sem autorização|without prior|sans autorisation|ohne vorherige|"
    r"sin autorización|senza autorizzazione)",
    re.I,
)


def extract_pdf_text(path: Path) -> str:
    reader = PdfReader(str(path))
    return "\n".join(page.extract_text() or "" for page in reader.pages)


def normalize_spaces(text: str) -> str:
    text = re.sub(r"\s+,", ",", text)
    text = re.sub(r"\s+\.", ".", text)
    text = re.sub(r"\s+;", ";", text)
    text = re.sub(r"\s{2,}", " ", text)
    return text.strip()


def is_noise_line(line: str) -> bool:
    s = line.strip()
    if not s:
        return False
    if re.fullmatch(r"\d{1,2}", s):
        return True
    if re.fullmatch(r"•\s*", s):
        return True
    if TITLE_BANNER_RE.match(s):
        return True
    return False


def join_wrapped_lines(raw_lines: list[str]) -> list[str]:
    out: list[str] = []
    buf: list[str] = []

    def flush() -> None:
        nonlocal buf
        if not buf:
            return
        out.append(normalize_spaces(" ".join(buf)))
        buf = []

    for line in raw_lines:
        s = line.strip()
        if not s:
            flush()
            continue
        if is_noise_line(s):
            flush()
            continue
        if SECTION_RE.match(s):
            flush()
            out.append(s)
            continue
        if SUBSECTION_TITLE_RE.match(s):
            flush()
            out.append(s)
            continue
        if is_definition_line(s):
            flush()
            buf = [s]
            continue
        if buf and is_definition_line(buf[0]):
            buf.append(s)
            continue
        if buf and SECTION_RE.match(buf[0]):
            flush()
            buf = [s]
            continue
        if s.endswith(";"):
            buf.append(s)
            flush()
            continue
        buf.append(s)
    flush()
    return out


def split_list_tail(text: str) -> tuple[str, str | None]:
    match = TAIL_SPLIT_RE.search(text)
    if not match:
        return text, None
    return text[: match.start() + 1].strip(), text[match.start(1) :].strip()


def expand_semicolon_lists(lines: list[str]) -> list[str]:
    out: list[str] = []
    for line in lines:
        s = line.strip()
        if (
            SECTION_RE.match(s)
            or is_definition_line(s)
            or SUBSECTION_TITLE_RE.match(s)
        ):
            out.append(s)
            continue
        if ";" not in s:
            out.append(s)
            continue

        if ":" in s and not is_definition_line(s):
            colon = s.index(":")
            intro = s[: colon + 1].strip()
            rest = s[colon + 1 :].strip()
            items = [part.strip() for part in rest.split(";") if part.strip()]
            if len(items) >= 2:
                out.append(intro)
                last, tail = split_list_tail(items[-1])
                for item in items[:-1]:
                    out.append(item if item.endswith(";") else f"{item};")
                out.append(last)
                if tail:
                    out.append(tail)
                continue

        items = [part.strip() for part in s.split(";") if part.strip()]
        if len(items) >= 2 and all(len(item) < 90 for item in items):
            last, tail = split_list_tail(items[-1])
            for item in items[:-1]:
                out.append(item if item.endswith(";") else f"{item};")
            out.append(last)
            if tail:
                out.append(tail)
            continue

        out.append(s)
    return out


def to_bullet(line: str) -> tuple[list[str], bool]:
    item = line.strip()
    if item.endswith(";"):
        item = item[:-1].strip()
    last, tail = split_list_tail(item)
    if tail:
        if last.endswith("."):
            last = last[:-1].strip()
        return [f"• {last}", tail], False
    if item.endswith("."):
        item = item[:-1].strip()
    return [f"• {item}"], True


def convert_list_items(lines: list[str]) -> list[str]:
    out: list[str] = []
    in_list = False

    def emit_intro_and_items(intro: str, items_text: str) -> None:
        nonlocal in_list
        in_list = True
        out.append(intro)
        parts = [part.strip() for part in items_text.split(";") if part.strip()]
        for index, part in enumerate(parts):
            lines, keep_list = to_bullet(part)
            out.extend(lines)
            if not keep_list:
                in_list = False

    for line in lines:
        s = line.strip()
        if not s:
            in_list = False
            out.append("")
            continue
        if SECTION_RE.match(s):
            in_list = False
            out.append(s)
            continue
        if META_RE.search(s) and not SECTION_RE.match(s):
            in_list = False
            out.append(s)
            continue
        if SUBSECTION_TITLE_RE.match(s):
            in_list = False
            out.append(s)
            continue

        if ";" in s and ":" in s and not is_definition_line(s):
            semi = s.index(";")
            colon = s.rfind(":", 0, semi)
            if colon >= 0:
                intro = s[: colon + 1].strip()
                items_text = s[colon + 1 :].strip()
                emit_intro_and_items(intro, items_text)
                continue

        if s.endswith(":") and not is_definition_line(s):
            in_list = True
            out.append(s)
            continue

        if in_list:
            if LIST_EXIT_RE.match(s) and not s.endswith(";"):
                in_list = False
                out.append(s)
                continue
            if s[0].islower() and not s.endswith(";") and len(s) > 60:
                in_list = False
                out.append(s)
                continue
            if re.search(r"\.\s+(O |The |FaceBaby|Users |Não existe|It is |Les |Die |El |L')", s):
                last, tail = split_list_tail(s)
                if tail:
                    bullet_lines, _ = to_bullet(last)
                    out.extend(bullet_lines)
                    out.append(tail)
                    in_list = False
                    continue
            lines, keep_list = to_bullet(s)
            out.extend(lines)
            in_list = keep_list
            continue

        out.append(s)
    return out


def post_process_lines(lines: list[str]) -> list[str]:
    out: list[str] = []
    for line in lines:
        s = line.strip()
        if (
            not s
            or s.startswith("• ")
            or SECTION_RE.match(s)
            or is_definition_line(s)
            or SUBSECTION_TITLE_RE.match(s)
            or META_RE.search(s)
        ):
            out.append(line)
            continue
        if out and out[-1].strip().startswith("• "):
            if re.search(r"\.\s+(O |The |FaceBaby|Users |Não |It |Les |Die |El |L')", s):
                last, tail = split_list_tail(s)
                if tail:
                    bullet_lines, _ = to_bullet(last)
                    out.extend(bullet_lines)
                    out.append(tail)
                    continue
            if len(s) <= 90 and not s.startswith("O FaceBaby"):
                bullet_lines, _ = to_bullet(s)
                out.extend(bullet_lines)
                continue
        out.append(line)
    return out


def format_document(lines: list[str], title: str) -> str:
    meta = ""
    body: list[str] = []
    for line in lines:
        if META_RE.search(line) and not SECTION_RE.match(line):
            meta = line.strip()
        else:
            body.append(line)

    parts: list[str] = [title]
    if meta:
        parts.append(meta)

    formatted_body: list[str] = []
    for line in body:
        if not line:
            formatted_body.append("")
            continue
        if SECTION_RE.match(line):
            formatted_body.append("")
            formatted_body.append(line)
        elif is_definition_line(line):
            formatted_body.append("")
            formatted_body.append(line)
        elif SUBSECTION_TITLE_RE.match(line):
            formatted_body.append("")
            formatted_body.append(line)
        else:
            formatted_body.append(line)

    text = "\n".join(parts + [""] + formatted_body)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip() + "\n"


def process_pdf(pdf: Path, title: str) -> str:
    raw = extract_pdf_text(pdf)
    lines = join_wrapped_lines(raw.splitlines())
    lines = expand_semicolon_lists(lines)
    lines = convert_list_items(lines)
    lines = post_process_lines(lines)
    return format_document(lines, title)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for pdf, filename, title in PDF_JOBS:
        if not pdf.exists():
            raise SystemExit(f"PDF not found: {pdf}")
        out_text = process_pdf(pdf, title)
        out_path = OUT_DIR / filename
        out_path.write_text(out_text, encoding="utf-8")
        print(f"Wrote {filename} ({len(out_text)} chars) from {pdf.name}")


if __name__ == "__main__":
    main()
