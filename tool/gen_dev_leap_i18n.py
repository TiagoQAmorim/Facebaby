# Generates Dart map lines for lib/i18n — run: python tool/gen_dev_leap_i18n.py
import sys

PT = [
    ("dv01", "Semana 1", "Primeira adaptação", "{baby_name} pode estar vivendo uma adaptação intensa ao novo ambiente.", "Tudo ainda é muito novo."),
    ("dv02", "Semana 2", "Mais atento", "{baby_name} pode estar começando a perceber melhor vozes e rostos.", "O vínculo emocional continua crescendo."),
    ("dv03", "Semana 3", "Mais sensível", "{baby_name} pode estar mais sensível ao ambiente.", "O cérebro continua amadurecendo rapidamente."),
    ("dv04", "Semana 4", "Pequenas interações", "{baby_name} pode estar começando a interagir mais.", "O bebê começa a criar conexões sociais."),
    ("dv05", "Semana 5", "Novas descobertas", "{baby_name} pode estar percebendo mais os próprios movimentos.", "O corpo começa a ganhar significado."),
    ("dv06", "Semana 6", "Mais conectado", "{baby_name} pode estar mais atento às emoções das pessoas.", "O vínculo emocional continua se fortalecendo."),
    ("dv07", "Semana 7–8", "Sono diferente", "{baby_name} pode estar passando por mudanças importantes no sono.", "O cérebro está amadurecendo rapidamente."),
    ("dv08", "2–3 meses", "Mais consciente", "{baby_name} pode estar percebendo mais o próprio corpo e o ambiente.", "Pequenas descobertas acontecem todos os dias."),
    ("dv09", "3–4 meses", "Muito mais interação", "{baby_name} pode estar muito mais sociável.", "O vínculo social cresce rapidamente."),
    ("dv10", "4–5 meses", "Explorando mais", "{baby_name} pode estar muito mais curioso.", "O aprendizado acontece através da experiência."),
    ("dv11", "5–6 meses", "Mais comunicação", "{baby_name} pode estar tentando interagir cada vez mais.", "A comunicação começa a ganhar força."),
    ("dv12", "6–7 meses", "Mundo maior", "{baby_name} pode estar percebendo melhor o espaço e o ambiente.", "O mundo parece cada vez maior."),
    ("dv13", "7–8 meses", "Mais apego", "{baby_name} pode estar vivendo uma fase de maior necessidade emocional.", "O vínculo emocional se fortalece."),
    ("dv14", "8–9 meses", "Muitas conexões", "{baby_name} pode estar criando novas conexões rapidamente.", "O cérebro está extremamente ativo."),
    ("dv15", "9–10 meses", "Não para quieto", "{baby_name} pode estar em uma fase de muita movimentação.", "O corpo e o cérebro trabalham juntos nessa fase."),
    ("dv16", "10–11 meses", "Tentando se comunicar", "{baby_name} pode estar observando e imitando muito mais.", "A comunicação ganha força."),
    ("dv17", "11–12 meses", "Mais autonomia", "{baby_name} pode estar tentando fazer mais coisas sozinho.", "A independência começa a aparecer."),
    ("dv18", "12–18 meses", "Muitas emoções", "{baby_name} pode estar vivendo emoções mais intensas.", "O mundo emocional está crescendo rapidamente."),
    ("dv19", "18–24 meses", "Faz de conta", "{baby_name} pode estar entrando em uma fase de imaginação intensa.", "A imaginação começa a florescer."),
    ("dv20", "2–3 anos", "Grande personalidade", "{baby_name} pode estar vivendo uma fase de muita independência e imaginação.", "A identidade da criança cresce rapidamente."),
]

EN = [
    ("dv01", "Week 1", "Early adjustment", "{baby_name} may be having an intense adjustment to the new surroundings.", "Everything is still very new."),
    ("dv02", "Week 2", "More alert", "{baby_name} may be starting to notice voices and faces a little better.", "The emotional bond keeps growing."),
    ("dv03", "Week 3", "More sensitive", "{baby_name} may be more sensitive to the environment around them.", "The brain is maturing quickly."),
    ("dv04", "Week 4", "Small interactions", "{baby_name} may be beginning to interact a bit more.", "Your baby starts building social connections."),
    ("dv05", "Week 5", "New discoveries", "{baby_name} may be noticing more of their own movements.", "Their body starts to gain meaning."),
    ("dv06", "Week 6", "More connected", "{baby_name} may be more tuned in to people's emotions.", "The emotional bond keeps strengthening."),
    ("dv07", "Weeks 7–8", "Changing sleep", "{baby_name} may be going through important sleep shifts.", "The brain is maturing quickly."),
    ("dv08", "2–3 months", "More awareness", "{baby_name} may be noticing more of their body and the world around them.", "Small discoveries happen every day."),
    ("dv09", "3–4 months", "Much more social", "{baby_name} may be much more social.", "Social bonding grows fast."),
    ("dv10", "4–5 months", "Exploring more", "{baby_name} may be much more curious.", "Learning happens through experience."),
    ("dv11", "5–6 months", "More communication", "{baby_name} may be trying to interact more and more.", "Communication is starting to take off."),
    ("dv12", "6–7 months", "A bigger world", "{baby_name} may be understanding space and the environment better.", "The world feels bigger each day."),
    ("dv13", "7–8 months", "More attachment", "{baby_name} may be in a phase of greater emotional need.", "The emotional bond strengthens."),
    ("dv14", "8–9 months", "Many connections", "{baby_name} may be wiring new connections quickly.", "The brain is very active."),
    ("dv15", "9–10 months", "On the move", "{baby_name} may be in a very active moving phase.", "Body and brain work together here."),
    ("dv16", "10–11 months", "Trying to communicate", "{baby_name} may be watching and imitating much more.", "Communication is growing stronger."),
    ("dv17", "11–12 months", "More independence", "{baby_name} may be trying to do more things alone.", "Independence is starting to show."),
    ("dv18", "12–18 months", "Big feelings", "{baby_name} may be feeling emotions more intensely.", "The emotional world grows fast."),
    ("dv19", "18–24 months", "Pretend play", "{baby_name} may be entering a phase of vivid imagination.", "Imagination starts to bloom."),
    ("dv20", "2–3 years", "A big personality", "{baby_name} may be in a phase of strong independence and imagination.", "Their sense of self grows quickly."),
]


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'")


def emit(rows, label: str) -> None:
    print(f"    // {label}")
    for bk, r, t, l, e in rows:
        print(f"    'devLeap_{bk}_range': '{esc(r)}',")
        print(f"    'devLeap_{bk}_title': '{esc(t)}',")
        print(f"    'devLeap_{bk}_lead': '{esc(l)}',")
        print(f"    'devLeap_{bk}_emotion': '{esc(e)}',")


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "both"
    if which in ("pt", "both"):
        emit(PT, "Development leap banner (PT)")
    if which in ("en", "both"):
        emit(EN, "Development leap banner (EN)")
