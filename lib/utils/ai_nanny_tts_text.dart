/// Normaliza texto da IA Babá antes de enviar ao TTS (mais natural e estável).
String prepareAiNannyTtsText(
  String raw, {
  int maxLen = 480,
}) {
  var text = raw.trim();
  if (text.isEmpty) return '';

  text = text.replaceAll(
    RegExp(
      r'[\u{1F300}-\u{1F9FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}'
      r'\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E0}-\u{1F1FF}]',
      unicode: true,
    ),
    '',
  );
  text = text.replaceAll(RegExp(r'[🤖✅❌⭐💜💙🍼👶•·]'), ' ');
  text = text.replaceAll(RegExp(r'\[.*?\]'), '');
  text = text.replaceAll(RegExp(r'^\d+\)\s*', multiLine: true), '');

  // Listas com bullet viram frases curtas (evita ler "ponto" em cada linha).
  text = text.replaceAllMapped(
    RegExp(r'^[•\-]\s*', multiLine: true),
    (_) => '',
  );
  text = text.replaceAll(RegExp(r'\n+'), '. ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  text = _softenForGentleNanny(text);

  if (text.length <= maxLen) return text;

  final slice = text.substring(0, maxLen);
  final lastStop = slice.lastIndexOf(RegExp(r'[.!?]\s'));
  if (lastStop > 80) return '${slice.substring(0, lastStop + 1).trim()}…';
  return '${slice.trim()}…';
}

/// Tom suave sem marcas que o TTS lê como palavras ("ponto", "vírgula").
String _softenForGentleNanny(String text) {
  var t = text;
  t = t.replaceAll('!', '.');
  t = t.replaceAll('…', '.');
  t = t.replaceAll('...', '.');
  t = t.replaceAll(RegExp(r'\.{2,}'), '.');
  t = t.replaceAll(RegExp(r'\s*\.\s*'), '. ');
  t = t.replaceAll(RegExp(r'\s*,\s*'), ', ');
  return t.trim();
}
