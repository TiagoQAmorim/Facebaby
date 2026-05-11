/// Formatação de textos legais extraídos de DOCX (frases coladas, listas, contacto).
String preprocessLegalPlainText(String raw) {
  var t = raw.replaceAll('\r\n', '\n').trim();
  if (t.isEmpty) return t;

  // Ano colado a palavra: "2026Bem-vindo"
  t = t.replaceAllMapped(RegExp(r'(\d{4})([A-Za-zÀ-ÿ\u00C0-\u024F])'), (m) => '${m[1]}\n\n${m[2]}');

  // Palavra inteira colada após ponto: ".Contato" / ".FaceBaby"
  t = t.replaceAllMapped(
    RegExp(r'\.([A-ZÀ-Ÿ\u00C0-\u00DD\u0400-\u04FF][a-zà-ÿ\u0430-\u044f\u00C0-\u024F]{2,})'),
    (m) => '.\n\n${m[1]}',
  );
  // Letra inicial isolada antes de espaço: ".O usuário"
  t = t.replaceAllMapped(
    RegExp(r'\.([A-ZÀ-Ÿ\u0400-\u04FF])(?=\s)'),
    (m) => '.\n\n${m[1]}',
  );

  // Chinês / japonês: ponto ideográfico ou ocidental antes de carácter CJK
  t = t.replaceAllMapped(RegExp(r'([\.\!\?])([\u4e00-\u9fff\u3040-\u30ff])'), (m) => '${m[1]}\n\n${m[2]}');

  // "Lista:- item" ou ": - item"
  t = t.replaceAll(RegExp(r':\s*-\s*'), ':\n\n- ');

  // Itens de lista separados por "; - "
  t = t.replaceAll(RegExp(r';\s*-\s*'), ';\n- ');

  // Ponto antes de secção Contato / Contact (várias línguas)
  t = t.replaceAllMapped(
    RegExp(r'\.(\s*)(Contato|Contact|Contacts|Контакт|联系方式|連絡先)\s*:', caseSensitive: false),
    (m) => '.\n\n${m[2]}:',
  );

  // Evitar excesso de linhas em branco
  t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return t.trim();
}

bool legalBlockLooksLikeMeta(String block) {
  final s = block.trim();
  if (s.length > 240) return false;
  final lower = s.toLowerCase();
  return lower.startsWith('idioma') ||
      lower.startsWith('language') ||
      lower.startsWith('langue') ||
      lower.startsWith('langue / language') ||
      lower.startsWith('sprache') ||
      lower.startsWith('lingua') ||
      lower.startsWith('lingua / language') ||
      lower.startsWith('última') ||
      lower.startsWith('ultima') ||
      lower.startsWith('última atualização') ||
      lower.startsWith('last update') ||
      lower.startsWith('last updated') ||
      lower.startsWith('letzte') ||
      lower.startsWith('dernière') ||
      lower.startsWith('última actualización') ||
      lower.startsWith('язык') ||
      lower.startsWith('语言') ||
      lower.startsWith('言語');
}

bool legalLineLooksLikeBullet(String line) {
  final t = line.trimLeft();
  return t.startsWith('- ') || t.startsWith('• ') || t.startsWith('· ');
}
