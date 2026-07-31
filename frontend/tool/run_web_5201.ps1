[CmdletBinding()]
param(
  [string]$HostName = '0.0.0.0',
  [int]$Port = 5201,
  [string]$Device = 'chrome',
  [string]$DartDefineFile = 'env/development.json.example',
  [switch]$EnableExpressionEvaluation,
  [switch]$ResetChromeProfile,
  [switch]$WebServerOnly,
  [switch]$ChromeDebug,
  [switch]$NoWebServerFallback,
  [switch]$ReleaseOnly
)

$ErrorActionPreference = 'Stop'

$RunningOnWindows = if ($null -ne $IsWindows) {
  $IsWindows
} else {
  $env:OS -match 'Windows'
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $ProjectRoot

$ChromeProfileDir = Join-Path $ProjectRoot '.dart_tool\flutter_chrome_profile'
$ChromeProfileResetSizeMb = 150
$ChromeProfileFailureMarker = Join-Path $ChromeProfileDir '.debug_connection_failed'

function Stop-FlutterBrowserProcesses {
  param(
    [string]$ProfileDir,
    [string]$BrowserDevice
  )

  $processNames = switch ($BrowserDevice) {
    'edge' { @('msedge.exe') }
    default { @('chrome.exe') }
  }

  $escapedProfile = [regex]::Escape($ProfileDir)
  foreach ($processName in $processNames) {
    Get-CimInstance Win32_Process -Filter "Name='$processName'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -match $escapedProfile } |
      ForEach-Object {
        Write-Host "Stopping stale Flutter $processName ($($_.ProcessId))."
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
      }
  }
}

function Get-DirectorySizeMb {
  param(
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return 0
  }

  $bytes = (
    Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue |
      Measure-Object -Property Length -Sum
  ).Sum

  if (-not $bytes) {
    return 0
  }

  return [math]::Round($bytes / 1MB, 1)
}

function Reset-FlutterChromeProfile {
  param(
    [string]$ProfileDir,
    [string]$Reason
  )

  Write-Host "Resetting Flutter browser profile ($Reason)."
  Stop-FlutterBrowserProcesses -ProfileDir $ProfileDir -BrowserDevice $Device
  Start-Sleep -Milliseconds 500
  Remove-Item -LiteralPath $ProfileDir -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $ChromeProfileFailureMarker -Force -ErrorAction SilentlyContinue
}

function Set-ChromeProfileFailureMarker {
  New-Item -ItemType Directory -Force -Path $ChromeProfileDir | Out-Null
  Set-Content -LiteralPath $ChromeProfileFailureMarker -Value (Get-Date).ToString('o') -Encoding utf8
}

function Clear-ChromeProfileFailureMarker {
  Remove-Item -LiteralPath $ChromeProfileFailureMarker -Force -ErrorAction SilentlyContinue
}

function Get-FlutterWebRunArgs {
  param(
    [string]$RunDevice,
    [switch]$IncludeBrowserFlags
  )

  $args = @(
    'run',
    '-d', $RunDevice,
    "--web-hostname=$HostName",
    "--web-port=$Port",
    "--dart-define-from-file=$DartDefineFile",
    '--no-web-resources-cdn'
  )

  if (-not $EnableExpressionEvaluation) {
    $args += '--no-web-enable-expression-evaluation'
  }

  if ($IncludeBrowserFlags -and ($RunDevice -eq 'chrome' -or $RunDevice -eq 'edge')) {
    $args += @(
      "--web-browser-flag=--user-data-dir=$ChromeProfileDir",
      '--web-browser-flag=--disable-extensions',
      '--web-browser-flag=--disable-popup-blocking',
      '--web-browser-flag=--disable-background-timer-throttling',
      '--web-browser-flag=--disable-backgrounding-occluded-windows',
      '--web-browser-flag=--disable-renderer-backgrounding',
      '--web-browser-flag=--no-first-run',
      '--web-browser-flag=--no-default-browser-check',
      '--web-browser-flag=--disable-default-apps',
      '--web-browser-flag=--remote-allow-origins=*'
    )
  }

  return $args
}

function Invoke-FlutterWebRun {
  param(
    [string[]]$RunArgs,
    [string]$AppUrl = '',
    [switch]$OpenBrowserWhenReady
  )

  Write-Host ("Running: flutter {0}" -f ($RunArgs -join ' '))
  $script:browserOpenedForWebServer = $false
  & flutter @RunArgs 2>&1 | ForEach-Object {
    $line = "$_"
    Write-Host $line
    if ($OpenBrowserWhenReady -and -not $script:browserOpenedForWebServer -and $line -match 'is being served at') {
      if ($AppUrl) {
        Write-Host "Opening $AppUrl"
        Start-Process $AppUrl
      }
      $script:browserOpenedForWebServer = $true
      Write-Host 'Dev server is ready. The terminal stays open for hot reload (r/R/q); that is normal.'
    }
  }
  return $LASTEXITCODE
}

function Release-WebPort {
  $listeners = Get-PortListeners -Address $HostName -ListenPort $Port
  foreach ($processId in ($listeners | Select-Object -ExpandProperty OwningProcess -Unique)) {
    if (-not $processId -or $processId -eq $PID) {
      continue
    }

    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if ($process) {
      Write-Host "Releasing port $Port from $($process.ProcessName) ($processId)."
      Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
    }
  }
}

function Get-LocalBrowserHost {
  param(
    [string]$ListenHost
  )

  if ($ListenHost -eq '0.0.0.0' -or $ListenHost -eq '::' -or $ListenHost -eq '[::]') {
    return '127.0.0.1'
  }

  return $ListenHost
}

function Get-PreferredLanIPv4 {
  $candidates = @(
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Where-Object {
        $_.IPAddress -notlike '127.*' -and
        $_.PrefixOrigin -ne 'WellKnown' -and
        ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual')
      } |
      Sort-Object -Property InterfaceMetric |
      Select-Object -ExpandProperty IPAddress -Unique
  )

  if ($candidates.Count -gt 0) {
    return $candidates[0]
  }

  return $null
}

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

function Prepare-ForWebRunRetry {
  Stop-FlutterBrowserProcesses -ProfileDir $ChromeProfileDir -BrowserDevice $Device
  Start-Sleep -Milliseconds 500
  Release-WebPort
  Start-Sleep -Milliseconds 500
}

Stop-FlutterBrowserProcesses -ProfileDir $ChromeProfileDir -BrowserDevice $Device
Get-Job -Name 'OpenHmsWebApp' -ErrorAction SilentlyContinue | Stop-Job -PassThru | Remove-Job -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Stop-FlutterBrowserProcesses -ProfileDir $ChromeProfileDir -BrowserDevice $Device

if ($ResetChromeProfile) {
  Reset-FlutterChromeProfile -ProfileDir $ChromeProfileDir -Reason 'requested'
} elseif (Test-Path -LiteralPath $ChromeProfileFailureMarker) {
  Reset-FlutterChromeProfile -ProfileDir $ChromeProfileDir -Reason 'previous debug connection failed'
} elseif ((Get-DirectorySizeMb -Path $ChromeProfileDir) -ge $ChromeProfileResetSizeMb) {
  Reset-FlutterChromeProfile -ProfileDir $ChromeProfileDir -Reason "size >= ${ChromeProfileResetSizeMb}MB"
}

New-Item -ItemType Directory -Force -Path $ChromeProfileDir | Out-Null

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

Write-Host 'Generating localizations...'
flutter gen-l10n
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$l10nOutput = Join-Path $ProjectRoot 'lib\l10n\app_localizations.dart'
if (-not (Test-Path -LiteralPath $l10nOutput)) {
  throw "flutter gen-l10n did not produce $l10nOutput. Check lib/l10n/app_en.arb and l10n.yaml."
}

$useWebServer = $WebServerOnly -or (
  -not $ChromeDebug -and
  -not $PSBoundParameters.ContainsKey('Device') -and
  $RunningOnWindows -and
  $Device -eq 'chrome'
)

if ($useWebServer) {
  if (-not $WebServerOnly -and -not $ChromeDebug) {
    Write-Host 'Using web-server on Windows (pass -ChromeDebug for Chrome hot reload).'
  }
  $runDevice = 'web-server'
  $includeBrowserFlags = $false
  $localBrowserHost = Get-LocalBrowserHost -ListenHost $HostName
  $appUrl = "http://${localBrowserHost}:${Port}/"
  Write-Host "The app will be served at $appUrl"
  if ($HostName -eq '0.0.0.0' -or $HostName -eq '::' -or $HostName -eq '[::]') {
    $lanIp = Get-PreferredLanIPv4
    if ($lanIp) {
      Write-Host "Same Wi-Fi phone/tablet URL: http://${lanIp}:${Port}/"
      Write-Host 'In development, API_BASE_URL localhost is rewritten to that LAN host automatically.'
    } else {
      Write-Host "Listening on all interfaces ($HostName). Open http://<pc-lan-ip>:${Port}/ on your phone."
    }
  }
  Write-Host 'The browser opens automatically when Flutter prints that the app is being served.'
} else {
  $appUrl = ''
  $runDevice = $Device
  $includeBrowserFlags = $true
}

$flutterArgs = Get-FlutterWebRunArgs -RunDevice $runDevice -IncludeBrowserFlags:$includeBrowserFlags
$exitCode = Invoke-FlutterWebRun -RunArgs $flutterArgs -AppUrl $appUrl -OpenBrowserWhenReady:$useWebServer

if ($exitCode -ne 0 -and -not $WebServerOnly -and -not $ResetChromeProfile) {
  Write-Host 'Browser debug connection failed. Resetting profile and retrying once...'
  Reset-FlutterChromeProfile -ProfileDir $ChromeProfileDir -Reason 'debug connection failed'
  Prepare-ForWebRunRetry
  New-Item -ItemType Directory -Force -Path $ChromeProfileDir | Out-Null
  $exitCode = Invoke-FlutterWebRun -RunArgs $flutterArgs -AppUrl $appUrl -OpenBrowserWhenReady:$useWebServer
}

if ($exitCode -ne 0 -and -not $WebServerOnly -and -not $NoWebServerFallback) {
  Write-Host "Chrome debug still failed. Falling back to web-server at http://$((Get-LocalBrowserHost -ListenHost $HostName)):${Port}/"
  Write-Host 'Hot reload/debugger attachment are unavailable in this mode.'
  Prepare-ForWebRunRetry
  $appUrl = "http://$((Get-LocalBrowserHost -ListenHost $HostName)):${Port}/"
  $fallbackArgs = Get-FlutterWebRunArgs -RunDevice 'web-server'
  $exitCode = Invoke-FlutterWebRun -RunArgs $fallbackArgs -AppUrl $appUrl -OpenBrowserWhenReady
}

if ($exitCode -eq 0) {
  Clear-ChromeProfileFailureMarker
} elseif (-not $WebServerOnly) {
  Set-ChromeProfileFailureMarker
}

exit $exitCode
