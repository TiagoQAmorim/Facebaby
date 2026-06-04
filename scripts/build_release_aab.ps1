# Gera app-release.aab com versão do pubspec.yaml (name+version, ex.: 1.0.32+165).
# O Gradle lê flutter.versionCode/Name em android/local.properties — atualizado pelo Flutter no build.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "==> pubspec version:" -ForegroundColor Cyan
Select-String -Path "pubspec.yaml" -Pattern "^version:" | ForEach-Object { $_.Line }

Write-Host "==> flutter clean" -ForegroundColor Cyan
flutter clean

Write-Host "==> flutter pub get" -ForegroundColor Cyan
flutter pub get

Write-Host "==> flutter build appbundle --release" -ForegroundColor Cyan
flutter build appbundle --release

$out = Join-Path $PWD "build\app\outputs\bundle\release\app-release.aab"
if (Test-Path $out) {
    Write-Host ""
    Write-Host "AAB gerado:" -ForegroundColor Green
    Write-Host "  $out"
    Get-Item $out | Select-Object Name, Length, LastWriteTime
} else {
    Write-Host "AAB nao encontrado em $out" -ForegroundColor Red
    exit 1
}
