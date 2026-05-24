$ErrorActionPreference = 'Stop'

$obsoleteFiles = @(
  'frontend/lib/shared/clinical_actions/clinical_action_dialogs.dart',
  'frontend/lib/shared/clinical_actions/clinical_order_action_dialogs.dart'
)

foreach ($path in $obsoleteFiles) {
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Force
    Write-Host "Removed obsolete file: $path"
  } else {
    Write-Host "Skipped missing file: $path"
  }
}
