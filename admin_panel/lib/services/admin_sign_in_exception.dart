/// Erro de login do painel com mensagem amigável para o utilizador.
class AdminSignInException implements Exception {
  const AdminSignInException(this.message);

  final String message;

  @override
  String toString() => message;
}
