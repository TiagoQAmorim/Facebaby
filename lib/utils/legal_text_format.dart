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

  // Secção numerada colada após ponto: ".2. Dados"
  t = t.replaceAllMapped(RegExp(r'\.(\d+\.\s+)'), (m) => '.\n\n${m[1]}');

  // Linha em branco antes de secções numeradas
  t = t.replaceAllMapped(
    RegExp(r'(?<=\S)\n(\d+\.\s+)'),
    (m) => '\n\n${m[1]}',
  );

  // Linha em branco após título de secção numerada
  t = t.replaceAllMapped(
    RegExp(r'^(\d+\.\s+[^\n]+)\n(?=\S)', multiLine: true),
    (m) => '${m[1]}\n\n',
  );

  // Linha em branco antes de subtítulo seguido de marcador
  t = t.replaceAllMapped(
    RegExp(r'(\n|^)([^\n]+)\n(•\s)', multiLine: true),
    (m) {
      final line = m[2]!.trim();
      if (!legalLineLooksLikeSubsectionTitle(line)) return m[0]!;
      final prefix = m[1] == '\n' ? '\n\n' : '';
      return '$prefix$line\n\n${m[3]}';
    },
  );

  // Linha em branco entre fim de lista e próximo subtítulo
  t = t.replaceAllMapped(
    RegExp(r'(•[^\n]+)\n([^\n•]+)\n(•\s)', multiLine: true),
    (m) {
      final middle = m[2]!.trim();
      if (!legalLineLooksLikeSubsectionTitle(middle)) return m[0]!;
      return '${m[1]}\n\n$middle\n\n${m[3]}';
    },
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
      lower.startsWith('pt-br') ||
      lower.startsWith('en-us') ||
      lower.startsWith('es-es') ||
      lower.startsWith('fr-fr') ||
      lower.startsWith('de-de') ||
      lower.startsWith('it-it') ||
      lower.contains('última atualização') ||
      lower.contains('ultima atualizacao') ||
      lower.startsWith('última') ||
      lower.startsWith('ultima') ||
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

bool legalLineLooksLikeNumberedSection(String line) {
  return RegExp(r'^\d+\.\s+\S').hasMatch(line.trim());
}

bool legalLineLooksLikeSubsectionTitle(String line) {
  final t = line.trim();
  if (t.length < 3 || t.length > 72) return false;
  if (legalLineLooksLikeBullet(t)) return false;
  if (legalLineLooksLikeNumberedSection(t)) return false;
  if (legalBlockLooksLikeMeta(t)) return false;
  if (t.endsWith(':') || t.endsWith('.') || t.endsWith(';')) return false;
  if (RegExp(r'^[a-zà-ÿ]').hasMatch(t)) return false;
  return true;
}
