/// Sessão do app: cada cold start incrementa o serial; o chat IA é limpo na primeira abertura da aba.
abstract final class AiChatSession {
  static int _launchSerial = 0;
  static int? _chatPreparedForLaunch;

  /// Chamar uma vez em [main] após inicialização do Flutter.
  static void onAppStarted() {
    _launchSerial++;
  }

  /// True na primeira vez que a tela IA Babá abre neste launch do app.
  static bool get needsFreshChatOnOpen =>
      _chatPreparedForLaunch != _launchSerial;

  static void markChatPreparedForLaunch() {
    _chatPreparedForLaunch = _launchSerial;
  }
}
