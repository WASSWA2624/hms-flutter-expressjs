$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Invoke-GateStep {
  param(
    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,
    [Parameter(Mandatory = $true)]
    [string]$Command,
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  Push-Location $WorkingDirectory
  try {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "$Command failed with exit code $LASTEXITCODE."
    }
  }
  finally {
    Pop-Location
  }
}

$frontend = Join-Path $repositoryRoot 'frontend'
$backend = Join-Path $repositoryRoot 'backend'

Invoke-GateStep $frontend 'flutter' @('pub', 'get')
Invoke-GateStep $frontend 'dart' @(
  'run',
  'build_runner',
  'build',
  '--delete-conflicting-outputs'
)
Invoke-GateStep $frontend 'dart' @(
  'format',
  '--set-exit-if-changed',
  '.'
)
Invoke-GateStep $frontend 'flutter' @('analyze')
Invoke-GateStep $frontend 'flutter' @('test')

Invoke-GateStep $backend 'npm' @('ci')
Invoke-GateStep $backend 'npm' @('run', 'validate:delivery')

Write-Host 'HOSSPI delivery gate passed.'
