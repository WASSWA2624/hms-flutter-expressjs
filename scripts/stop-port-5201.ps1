param(
    [int]$Port = 5201
)

$connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
$processIds = $connections |
    Select-Object -ExpandProperty OwningProcess -Unique |
    Where-Object { $_ -and $_ -ne 0 }

if (-not $processIds) {
    Write-Host "No process is listening on port $Port."
    exit 0
}

foreach ($processId in $processIds) {
    try {
        $process = Get-Process -Id $processId -ErrorAction Stop
        Stop-Process -Id $processId -Force -ErrorAction Stop
        Write-Host "Terminated process '$($process.ProcessName)' (PID $processId) on port $Port."
    }
    catch {
        Write-Error "Failed to terminate PID $processId on port $Port. $($_.Exception.Message)"
        exit 1
    }
}
