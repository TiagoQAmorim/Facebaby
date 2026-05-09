"""One-off: add text_en to each tip in baby_daily_tips_500.json (Portuguese -> English)."""
import json
import time
from pathlib import Path

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "data" / "baby_daily_tips_500.json"
BAK = ROOT / "assets" / "data" / "baby_daily_tips_500.json.bak"


def main() -> None:
    trans = GoogleTranslator(source="pt", target="en")
    data = json.loads(SRC.read_text(encoding="utf-8"))
    tips = data["tips"]
    if not BAK.exists():
        BAK.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    for i, tip in enumerate(tips):
        if tip.get("text_en"):
            continue
        text = (tip.get("text") or "").strip()
        if not text:
            tip["text_en"] = ""
            continue
        for attempt in range(3):
            try:
                tip["text_en"] = trans.translate(text)
                break
            except Exception as e:  # noqa: BLE001
                wait = 1.5 * (attempt + 1)
                print(f"retry {i+1}/{len(tips)} after {e!r}, sleep {wait}s")
                time.sleep(wait)
        else:
            tip["text_en"] = text
        if (i + 1) % 50 == 0:
            print(f"done {i + 1}/{len(tips)}")
            SRC.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
            time.sleep(0.3)
        time.sleep(0.12)
    SRC.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print("written", SRC)


if __name__ == "__main__":
    main()
