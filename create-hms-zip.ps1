param(
  [string]$OutputPath = (Join-Path $PSScriptRoot 'hms.zip')
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$archiveRoot = 'hms'
$root = $PSScriptRoot

function Get-RelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$BasePath,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $base = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\', '/')
  $fullPath = (Resolve-Path -LiteralPath $Path).Path

  if (!$fullPath.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path '$fullPath' is not under '$base'."
  }

  return $fullPath.Substring($base.Length).TrimStart('\', '/')
}

function Test-PathPart {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string[]]$Names
  )

  $parts = $RelativePath -split '[\\/]'
  foreach ($part in $parts) {
    foreach ($name in $Names) {
      if ($part.Equals($name, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
      }
    }
  }

  return $false
}

function Add-ArchiveFile {
  param(
    [Parameter(Mandatory = $true)]$Archive,
    [Parameter(Mandatory = $true)][string]$SourceRoot,
    [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
    [Parameter(Mandatory = $true)][string]$TargetFolder
  )

  $relativePath = Get-RelativePath -BasePath $SourceRoot -Path $File.FullName
  $entryName = "$archiveRoot/$TargetFolder/$relativePath" -replace '\\', '/'

  $entry = $Archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
  $entry.LastWriteTime = [System.DateTimeOffset]$File.LastWriteTime

  $fileShare = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
  $fileStream = [System.IO.File]::Open($File.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $fileShare)
  try {
    $entryStream = $entry.Open()
    try {
      $fileStream.CopyTo($entryStream)
    } finally {
      $entryStream.Dispose()
    }
  } finally {
    $fileStream.Dispose()
  }
}

function Add-FilteredFolder {
  param(
    [Parameter(Mandatory = $true)]$Archive,
    [Parameter(Mandatory = $true)][string]$SourceRoot,
    [Parameter(Mandatory = $true)][string]$TargetFolder,
    [Parameter(Mandatory = $true)][scriptblock]$IncludeFile
  )

  if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "Required folder '$SourceRoot' was not found."
  }

  Get-ChildItem -LiteralPath $SourceRoot -Recurse -Force -File |
    Where-Object { & $IncludeFile $_ $SourceRoot } |
    ForEach-Object {
      Add-ArchiveFile -Archive $Archive -SourceRoot $SourceRoot -File $_ -TargetFolder $TargetFolder
    }
}

$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if ($outputDirectory -and !(Test-Path -LiteralPath $outputDirectory -PathType Container)) {
  New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

if (Test-Path -LiteralPath $resolvedOutputPath) {
  Remove-Item -LiteralPath $resolvedOutputPath -Force
}

$archive = [System.IO.Compression.ZipFile]::Open(
  $resolvedOutputPath,
  [System.IO.Compression.ZipArchiveMode]::Create
)

try {
  $appPlannerRoot = Join-Path $root 'app-planner'
  Add-FilteredFolder -Archive $archive -SourceRoot $appPlannerRoot -TargetFolder 'app-planner' -IncludeFile {
    param($file, $sourceRoot)

    $relativePath = Get-RelativePath -BasePath $sourceRoot -Path $file.FullName
    $rootFiles = @('app-write-up.md', 'opd-flow.md', 'ipd-flow.md')

    return ($rootFiles -contains $relativePath) -or
      (Test-PathPart -RelativePath $relativePath -Names @('dev-plan'))
  }

  $backendRoot = Join-Path $root 'backend'
  Add-FilteredFolder -Archive $archive -SourceRoot $backendRoot -TargetFolder 'backend' -IncludeFile {
    param($file, $sourceRoot)

    $relativePath = Get-RelativePath -BasePath $sourceRoot -Path $file.FullName
    return !(Test-PathPart -RelativePath $relativePath -Names @('node_modules', 'logs'))
  }

  $frontendRoot = Join-Path $root 'frontend'
  Add-FilteredFolder -Archive $archive -SourceRoot $frontendRoot -TargetFolder 'frontend' -IncludeFile {
    param($file, $sourceRoot)

    $relativePath = Get-RelativePath -BasePath $sourceRoot -Path $file.FullName
    if (Test-PathPart -RelativePath $relativePath -Names @('.dart_tool', 'build')) {
      return $false
    }

    $parts = $relativePath -split '[\\/]'
    $isRootLog = $parts.Count -eq 1 -and $file.Extension.Equals('.log', [System.StringComparison]::OrdinalIgnoreCase)
    return !$isRootLog
  }
} finally {
  $archive.Dispose()
}

Write-Host "Created archive: $resolvedOutputPath"
