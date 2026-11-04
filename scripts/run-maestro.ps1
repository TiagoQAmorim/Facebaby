# Executa a suíte Maestro (Facebaby + Maestro) no emulador/dispositivo Android.
param(
    [ValidateSet("smoke", "regression", "all")]
    [string]$Suite = "smoke",
    [string]$Email = $env:MAESTRO_TEST_EMAIL,
    [string]$Password = $env:MAESTRO_TEST_PASSWORD
)

$ErrorActionPreference = "Stop"
$MaestroDir = Join-Path $PSScriptRoot "..\.maestro"

if (-not (Get-Command maestro -ErrorAction SilentlyContinue)) {
    Write-Error "Maestro CLI não encontrado. Instale: https://docs.maestro.dev/getting-started/installing-maestro"
}

$envArgs = @()
if ($Email) { $envArgs += "-e"; $envArgs += "MAESTRO_TEST_EMAIL=$Email" }
if ($Password) { $envArgs += "-e"; $envArgs += "MAESTRO_TEST_PASSWORD=$Password" }

function Invoke-Flows([string[]]$Flows) {
    foreach ($flow in $Flows) {
        Write-Host ">> maestro test $flow" -ForegroundColor Cyan
        & maestro test @envArgs $flow
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}

switch ($Suite) {
    "smoke" {
        Invoke-Flows @(
            (Join-Path $MaestroDir "flows\smoke_welcome.yaml"),
            (Join-Path $MaestroDir "flows\smoke_login_screen.yaml")
        )
    }
    "regression" {
        if (-not $Email -or -not $Password) {
            Write-Error "Defina MAESTRO_TEST_EMAIL e MAESTRO_TEST_PASSWORD (ou -Email / -Password) para regression_login_and_tabs."
        }
        Invoke-Flows @(
            (Join-Path $MaestroDir "flows\regression_login_and_tabs.yaml")
        )
    }
    "all" {
        & $PSCommandPath -Suite smoke
        if ($Email -and $Password) {
            & $PSCommandPath -Suite regression -Email $Email -Password $Password
        } else {
            Write-Warning "Pulando regression_login_and_tabs (credenciais não definidas)."
        }
    }
}

Write-Host "Maestro: suíte '$Suite' concluída." -ForegroundColor Green
