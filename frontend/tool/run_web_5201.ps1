[CmdletBinding()]
param(
  [string]$HostName = '127.0.0.1',
  [int]$Port = 5201,
  [string]$Device = 'chrome',
  [string]$DartDefineFile = 'env/development.json.example',
  [switch]$ReleaseOnly
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $ProjectRoot

function Get-PortListeners {
  param(
    [string]$Address,
    [int]$ListenPort
  )

  $connections = Get-NetTCPConnection `
    -LocalAddress $Address `
    -LocalPort $ListenPort `
    -State Listen `
    -ErrorAction SilentlyContinue

  if ($connections) {
    return $connections
  }

  return Get-NetTCPConnection `
    -LocalPort $ListenPort `
    -State Listen `
    -ErrorAction SilentlyContinue
}

$listeners = Get-PortListeners -Address $HostName -ListenPort $Port
$processIds = @(
  $listeners |
    Select-Object -ExpandProperty OwningProcess -Unique |
    Where-Object { $_ -and $_ -ne $PID }
)

foreach ($processId in $processIds) {
  $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
  if ($process) {
    Write-Host "Releasing port $Port from $($process.ProcessName) ($processId)."
    Stop-Process -Id $processId -Force
  }
}

$deadline = (Get-Date).AddSeconds(10)
do {
  Start-Sleep -Milliseconds 250
  $remainingListeners = Get-PortListeners -Address $HostName -ListenPort $Port
} while ($remainingListeners -and (Get-Date) -lt $deadline)

if ($remainingListeners) {
  $blockedBy = $remainingListeners |
    Select-Object -ExpandProperty OwningProcess -Unique |
    ForEach-Object {
      $process = Get-Process -Id $_ -ErrorAction SilentlyContinue
      if ($process) {
        "$($process.ProcessName) ($_)"
      } else {
        "PID $_"
      }
    }

  throw "Port $Port is still in use by $($blockedBy -join ', ')."
}

if ($ReleaseOnly) {
  Write-Host "Port $Port is free."
  exit 0
}

flutter run `
  -d $Device `
  --web-hostname=$HostName `
  --web-port=$Port `
  --dart-define-from-file=$DartDefineFile

exit $LASTEXITCODE
