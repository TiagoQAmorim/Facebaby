/// ID do cliente OAuth **Web** (termina em `.apps.googleusercontent.com`).
/// Necessário no iOS para obter `id_token` estável junto ao Firebase Auth.
///
/// Override em build: `--dart-define=GOOGLE_WEB_CLIENT_ID=...`
const String kGoogleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

/// Fallback do Firebase/Google Cloud (tipo Web) — usado quando o dart-define não vem no build iOS.
const String kGoogleWebClientIdFallback =
    '91181989163-f76eh355cm8i29q23knbil93tseig8hv.apps.googleusercontent.com';

bool get hasGoogleWebClientId =>
    kGoogleWebClientId.isNotEmpty &&
    kGoogleWebClientId.contains('.apps.googleusercontent.com');

/// Cliente Web efectivo para [GoogleSignIn.serverClientId].
String get effectiveGoogleWebClientId =>
    hasGoogleWebClientId ? kGoogleWebClientId : kGoogleWebClientIdFallback;
