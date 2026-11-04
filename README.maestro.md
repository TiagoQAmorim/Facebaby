# Facebaby + Maestro

Suíte de UI em [Maestro](https://maestro.mobile.dev/) para o app **Facebaby + Maestro** (`com.facebaby.app`).

Os flows usam `Semantics.identifier` (`maestro_*`) no app para selectors estáveis em qualquer idioma.

## Pré-requisitos

1. [Maestro CLI](https://docs.maestro.dev/getting-started/installing-maestro) no PATH
2. Emulador Android ou dispositivo USB com depuração
3. APK debug ou release instalado:

```powershell
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

## Executar

```powershell
.\scripts\run-maestro.ps1 -Suite smoke
```

Login + navegação (conta de teste):

```powershell
$env:MAESTRO_TEST_EMAIL = "sua-conta@test.com"
$env:MAESTRO_TEST_PASSWORD = "********"
.\scripts\run-maestro.ps1 -Suite regression
```

Ou manualmente:

```powershell
maestro test .maestro\flows\smoke_welcome.yaml
maestro test -e MAESTRO_TEST_EMAIL=... -e MAESTRO_TEST_PASSWORD=... .maestro\flows\regression_login_and_tabs.yaml
```

## Estrutura

| Flow | Descrição |
|------|-----------|
| `flows/smoke_welcome.yaml` | Tela inicial (convidado) |
| `flows/smoke_login_screen.yaml` | Abre login e valida campos |
| `flows/regression_login_and_tabs.yaml` | Login e abas Início / Registros / Memórias / Mais |
| `flows/regression_logged_in_tabs.yaml` | Só navegação com sessão já existente |

Subflows reutilizáveis em `.maestro/subflows/`.

## iOS

Instale o build no simulador antes de rodar `maestro test` (bundle id `com.facebaby.app`).
