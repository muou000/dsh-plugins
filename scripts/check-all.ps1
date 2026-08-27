[CmdletBinding()]
param(
  [string[]] $Plugin
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$modulesFile = Join-Path $workspaceRoot '.gitmodules'

if (-not (Test-Path -LiteralPath $modulesFile)) {
  throw "Missing .gitmodules at $modulesFile"
}

$pathRows = & git -C $workspaceRoot config --file $modulesFile --get-regexp '^submodule\..*\.path$'
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to read submodule paths from .gitmodules.'
}

$requested = @{}
foreach ($name in $Plugin) {
  $requested[$name] = $true
}

$failures = [System.Collections.Generic.List[string]]::new()
$checked = 0
$workspacePrefix = $workspaceRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

foreach ($row in $pathRows) {
  $parts = $row -split '\s+', 2
  if ($parts.Count -ne 2) {
    throw "Invalid submodule path row: $row"
  }

  $relativePath = $parts[1]
  if ($requested.Count -gt 0 -and -not $requested.ContainsKey($relativePath)) {
    continue
  }

  $pluginRoot = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot $relativePath))
  if (-not $pluginRoot.StartsWith($workspacePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Submodule path escapes the workspace: $relativePath"
  }

  if (-not (Test-Path -LiteralPath (Join-Path $pluginRoot '.git'))) {
    $failures.Add("$relativePath is not initialized; run git submodule update --init --recursive")
    continue
  }

  $packageFile = Join-Path $pluginRoot 'package.json'
  if (-not (Test-Path -LiteralPath $packageFile)) {
    $failures.Add("$relativePath has no package.json")
    continue
  }

  $package = Get-Content -LiteralPath $packageFile -Raw | ConvertFrom-Json
  if (-not $package.scripts.check) {
    $failures.Add("$relativePath has no scripts.check entry")
    continue
  }

  Write-Host "Checking $relativePath"
  Push-Location -LiteralPath $pluginRoot
  try {
    & pnpm run check
    if ($LASTEXITCODE -ne 0) {
      $failures.Add("$relativePath check failed with exit code $LASTEXITCODE")
    }
  }
  finally {
    Pop-Location
  }
  $checked += 1
}

if ($requested.Count -gt 0 -and $checked -eq 0 -and $failures.Count -eq 0) {
  throw "No configured submodule matched: $($Plugin -join ', ')"
}

if ($failures.Count -gt 0) {
  foreach ($failure in $failures) {
    Write-Error $failure -ErrorAction Continue
  }
  exit 1
}

Write-Host "All $checked plugin checks passed."
