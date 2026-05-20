# Pré-visualização tablet 10"

## O que **não** fazer

Não use imagens geradas por IA como referência do FaceBaby — não são o app real.

## Capturas **reais** do código (golden tests)

Gera PNGs a partir dos widgets verdadeiros (login, cadastro inicial) em 1280×800 (paisagem) e 800×1280 (retrato):

```powershell
cd C:\Users\Dell\Documents\ninho_flutter_page_objects
flutter test --update-goldens test/tablet_golden_test.dart
```

Ficheiros gerados: `test/goldens/tablet_10/*.png`

Para validar sem atualizar:

```powershell
flutter test test/tablet_golden_test.dart
```

## App completo no Chrome (com a sua conta / dados)

```powershell
.\scripts\tablet_10inch_chrome.ps1
.\scripts\tablet_10inch_chrome.ps1 -Portrait
```

Depois use **Win+Shift+S** (ou DevTools → modo dispositivo) para capturar o ecrã **enquanto o app corre**.

## Emulador Android tablet 10"

1. Android Studio → Device Manager → Create device → **Pixel Tablet** ou **10.1" WXGA**.
2. `flutter run` no emulador.
3. Screenshot: botão câmara da barra lateral do emulador.

O portal limita o conteúdo a `maxWidth: 900` no centro; em tablet verá mais fundo (céu/nuvens) nas laterais — comportamento esperado.
