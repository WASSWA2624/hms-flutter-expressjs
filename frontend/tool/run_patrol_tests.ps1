param(
    [string]$Target = "",
    [string]$Device = "chrome",
    [switch]$FullSuite,
    [switch]$Headless = $true
)

$ErrorActionPreference = "Stop"

$FrontendRoot = Split-Path -Parent $PSScriptRoot
Set-Location $FrontendRoot

$PubCacheBin = Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"
if (Test-Path $PubCacheBin) {
    $env:Path = "$PubCacheBin;$env:Path"
}

try {
    $env:PATROL_GIT_SHA = (git -C $FrontendRoot rev-parse HEAD 2>$null)
} catch {
    $env:PATROL_GIT_SHA = ""
}

Write-Host "Running flutter pub get..."
flutter pub get

$patrolArgs = @("test", "-d", $Device, "--web-reporter", "[\"json\",\"html\",\"list\"]")

if ($Headless) {
    $patrolArgs += @("--web-headless=true")
}

$patrolArgs += @(
    "--web-results-dir=build/patrol_web_results",
    "--web-report-dir=build/patrol_web_report",
    "--web-video=retain-on-failure"
)

if ($Target) {
    $patrolArgs += @("-t", $Target)
}
elseif ($FullSuite) {
    Write-Host "Running full Patrol suite in patrol_test/"
}
else {
    $patrolArgs += @("-t", "patrol_test/smoke_test.dart")
}

Write-Host "Executing: patrol $($patrolArgs -join ' ')"
patrol @patrolArgs
