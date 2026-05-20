# Abre o FaceBaby REAL no Chrome com janela ~tablet 10".
# Não gera imagens sozinho — use screenshot manual ou `flutter test --update-goldens`.
#
# Uso:
#   .\scripts\tablet_10inch_chrome.ps1
#   .\scripts\tablet_10inch_chrome.ps1 -Portrait

param(
    [switch]$Portrait
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if ($Portrait) {
    $w = 800
    $h = 1280
    Write-Host "Chrome ~tablet 10"" portrait ${w}x${h} — capture com Win+Shift+S"
} else {
    $w = 1280
    $h = 800
    Write-Host "Chrome ~tablet 10"" landscape ${w}x${h} — capture com Win+Shift+S"
}

flutter run -d chrome `
    --web-browser-flag="--window-size=$w,$h" `
    --web-browser-flag="--force-device-scale-factor=1" `
    --web-browser-flag="--disable-infobars"
