# DBeaver GeoJSON Exporter Installer for Windows (PowerShell)
# Requires Administrator privileges if DBeaver is in C:\Program Files
$ErrorActionPreference = "Stop"

$ProjectDir = (Get-Item $PSScriptRoot).Parent.FullName
$JarFile = Join-Path $ProjectDir "dist\io.github.dbeaver.export.geojson_1.0.0.jar"

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
$PluginTarget = Join-Path $DBeaverDir "plugins\io.github.dbeaver.export.geojson_1.0.0.jar"
$BundleEntry = "io.github.dbeaver.export.geojson,1.0.0,plugins/io.github.dbeaver.export.geojson_1.0.0.jar,4,false"

if (-not (Test-Path $JarFile)) {
    Write-Error "Error: Built JAR not found at $JarFile. Please run .\scripts\build.ps1 first."
    exit 1
}

Write-Host "-> Copying plugin JAR to $PluginTarget..." -ForegroundColor Green
Copy-Item -Path $JarFile -Destination $PluginTarget -Force

# Clean legacy dropins folder if present
$DropinsJar = Join-Path $DBeaverDir "dropins\io.github.dbeaver.export.geojson_1.0.0.jar"
if (Test-Path $DropinsJar) {
    Remove-Item -Force $DropinsJar
}

# Register into bundles.info
if (Test-Path $BundlesInfo) {
    $Content = Get-Content -Path $BundlesInfo -Raw
    if ($Content -notmatch "io\.github\.dbeaver\.export\.geojson") {
        Write-Host "-> Registering bundle in Equinox simpleconfigurator..." -ForegroundColor Green
        Copy-Item -Path $BundlesInfo -Destination "$BundlesInfo.bak" -Force
        Add-Content -Path $BundlesInfo -Value "`n$BundleEntry"
    } else {
        Write-Host "-> Bundle already registered in bundles.info." -ForegroundColor Yellow
    }
}

Write-Host "=== Installation Completed Successfully! ===" -ForegroundColor Cyan
Write-Host "Restart DBeaver with: dbeaver -clean"
