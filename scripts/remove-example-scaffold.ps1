$ErrorActionPreference = 'Stop'

$ProjectRoot = Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..')

$PathsToDelete = @(
  'frontend/lib/features/example',
  'frontend/test/features/example',
  'frontend/lib/core/storage/database/tables/example_resource_cache_entries.dart'
)

foreach ($RelativePath in $PathsToDelete) {
  $FullPath = Join-Path -Path $ProjectRoot -ChildPath $RelativePath
  if (Test-Path -LiteralPath $FullPath) {
    Remove-Item -LiteralPath $FullPath -Recurse -Force
    Write-Host "Removed $RelativePath"
  } else {
    Write-Host "Skipped missing $RelativePath"
  }
}
