/// ID do cliente OAuth **Web** (termina em `.apps.googleusercontent.com`).
/// Opcional: use para obter `id_token` de forma estável junto ao Firebase Auth.
///
/// Obtém em: Console Google Cloud → APIs e serviços → Credenciais → ID do cliente OAuth 2.0 (tipo **Aplicativo da Web**).
///
/// Ou deixe vazio — com **SHA-1** certo no Firebase, o fluxo normalmente funciona assim mesmo.
///
/// Rode: `flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=SEU_WEB_CLIENT_ID`
const String kGoogleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

bool get hasGoogleWebClientId => kGoogleWebClientId.isNotEmpty && kGoogleWebClientId.contains('.apps.googleusercontent.com');
