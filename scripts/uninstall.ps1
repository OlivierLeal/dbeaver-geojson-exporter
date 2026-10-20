# DBeaver GeoJSON Exporter Uninstaller for Windows (PowerShell)
$ErrorActionPreference = "Stop"

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
    Write-Error "Error: DBeaver installation folder not found."
    exit 1
}

$BundlesInfo = Join-Path $DBeaverDir "configuration\org.eclipse.equinox.simpleconfigurator\bundles.info"
$PluginTarget = Join-Path $DBeaverDir "plugins\io.github.dbeaver.export.geojson_1.0.1.jar"
$DropinsJar = Join-Path $DBeaverDir "dropins\io.github.dbeaver.export.geojson_1.0.1.jar"

Write-Host "=== Uninstalling DBeaver GeoJSON Exporter ===" -ForegroundColor Cyan

if (Test-Path $PluginTarget) {
    Write-Host "-> Removing $PluginTarget..." -ForegroundColor Green
    Remove-Item -Force $PluginTarget
}
Remove-Item -Path (Join-Path $DBeaverDir "plugins\io.github.dbeaver.export.geojson_1.0.0.jar") -Force -ErrorAction SilentlyContinue

Remove-Item -Path (Join-Path $DBeaverDir "dropins\io.github.dbeaver.export.geojson_1.0.0.jar") -Force -ErrorAction SilentlyContinue
Remove-Item -Path $DropinsJar -Force -ErrorAction SilentlyContinue

if (Test-Path $BundlesInfo) {
    $Lines = Get-Content -Path $BundlesInfo | Where-Object { $_ -notmatch "io\.github\.dbeaver\.export\.geojson" }
    Set-Content -Path $BundlesInfo -Value $Lines
    Write-Host "-> Cleaned entry from bundles.info." -ForegroundColor Green
}

Write-Host "=== Uninstallation Completed Successfully! ===" -ForegroundColor Cyan
Write-Host "Restart DBeaver with: dbeaver -clean"
