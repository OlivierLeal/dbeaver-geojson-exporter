# DBeaver GeoJSON Exporter Installer for Windows (PowerShell)
# Requires Administrator privileges if DBeaver is in C:\Program Files
$ErrorActionPreference = "Stop"

$ProjectDir = (Get-Item $PSScriptRoot).Parent.FullName
$JarFile = Join-Path $ProjectDir "dist\io.github.dbeaver.export.geojson_1.0.1.jar"

$CandidateDirs = @(
    $env:DBEAVER_HOME,
    "$env:ProgramFiles\DBeaver",
    "${env:ProgramFiles(x86)}\DBeaver",
    "$env:LOCALAPPDATA\Programs\DBeaver"
)

$DBeaverDir = $null
foreach ($dir in $CandidateDirs) {
    if ($dir -and (Test-Path (Join-Path $dir "plugins"))) {
        $DBeaverDir = $dir
        break
    }
}

if (-not $DBeaverDir) {
    Write-Error "Error: DBeaver installation folder not found. Please set DBEAVER_HOME to your DBeaver installation path."
    exit 1
}

$BundlesInfo = Join-Path $DBeaverDir "configuration\org.eclipse.equinox.simpleconfigurator\bundles.info"
$PluginTarget = Join-Path $DBeaverDir "plugins\io.github.dbeaver.export.geojson_1.0.1.jar"
$BundleEntry = "io.github.dbeaver.export.geojson,1.0.1,plugins/io.github.dbeaver.export.geojson_1.0.1.jar,4,false"

if (-not (Test-Path $JarFile)) {
    Write-Error "Error: Built JAR not found at $JarFile. Please run .\scripts\build.ps1 first."
    exit 1
}

Write-Host "-> Copying plugin JAR to $PluginTarget..." -ForegroundColor Green
Copy-Item -Path $JarFile -Destination $PluginTarget -Force
Remove-Item -Path (Join-Path $DBeaverDir "plugins\io.github.dbeaver.export.geojson_1.0.0.jar") -Force -ErrorAction SilentlyContinue

# Clean legacy dropins folder if present
Remove-Item -Path (Join-Path $DBeaverDir "dropins\io.github.dbeaver.export.geojson_1.0.0.jar") -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $DBeaverDir "dropins\io.github.dbeaver.export.geojson_1.0.1.jar") -Force -ErrorAction SilentlyContinue

# Register into bundles.info
if (Test-Path $BundlesInfo) {
    Write-Host "-> Registering bundle in Equinox simpleconfigurator..." -ForegroundColor Green
    Copy-Item -Path $BundlesInfo -Destination "$BundlesInfo.bak" -Force
    $Lines = Get-Content -Path $BundlesInfo | Where-Object { $_ -notmatch "^io\.github\.dbeaver\.export\.geojson," }
    Set-Content -Path $BundlesInfo -Value $Lines
    Add-Content -Path $BundlesInfo -Value $BundleEntry
}

Write-Host "=== Installation Completed Successfully! ===" -ForegroundColor Cyan
Write-Host "Restart DBeaver with: dbeaver -clean"
