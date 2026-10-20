# DBeaver GeoJSON Exporter Builder for Windows (PowerShell)
$ErrorActionPreference = "Stop"

$ProjectDir = (Get-Item $PSScriptRoot).Parent.FullName
$BuildDir = Join-Path $ProjectDir "bin"
$DistDir = Join-Path $ProjectDir "dist"
$JarName = "io.github.dbeaver.export.geojson_1.0.1.jar"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "    DBeaver GeoJSON Exporter Builder      " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Candidate locations for DBeaver installation on Windows
$CandidateDirs = @(
    $env:DBEAVER_HOME,
    "$env:ProgramFiles\DBeaver",
    "${env:ProgramFiles(x86)}\DBeaver",
    "$env:LOCALAPPDATA\Programs\DBeaver"
)

$DBeaverPluginsDir = $null
foreach ($dir in $CandidateDirs) {
    if ($dir -and (Test-Path (Join-Path $dir "plugins"))) {
        $DBeaverPluginsDir = Join-Path $dir "plugins"
        break
    }
}

if (-not $DBeaverPluginsDir) {
    Write-Error "Error: DBeaver plugins directory not found. Please set the DBEAVER_HOME environment variable to your DBeaver installation folder."
    exit 1
}

Write-Host "-> Using DBeaver libraries from: $DBeaverPluginsDir" -ForegroundColor Green

if (Test-Path $BuildDir) { Remove-Item -Recurse -Force $BuildDir }
if (Test-Path $DistDir) { Remove-Item -Recurse -Force $DistDir }
New-Item -ItemType Directory -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Path $DistDir | Out-Null

# Assemble dynamic classpath
$Jars = Get-ChildItem -Path $DBeaverPluginsDir -Filter "*.jar" -Recurse | Select-Object -ExpandProperty FullName
$Classpath = $Jars -join ";"

Write-Host "-> Compiling Java sources..." -ForegroundColor Green
$SourceFile = Join-Path $ProjectDir "src\io\github\dbeaver\export\geojson\GeoJsonDataExporter.java"
& javac -cp $Classpath -d $BuildDir $SourceFile

Write-Host "-> Packaging OSGi bundle JAR..." -ForegroundColor Green
$ManifestFile = Join-Path $ProjectDir "META-INF\MANIFEST.MF"
$TargetJar = Join-Path $DistDir $JarName
& jar cfm $TargetJar $ManifestFile -C $BuildDir . -C $ProjectDir plugin.xml -C $ProjectDir icons

Write-Host "=== Build Successful! ===" -ForegroundColor Cyan
Write-Host "Artifact generated: $TargetJar"
Write-Host ""
Write-Host "To install on local Windows DBeaver instance, run:"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1"
Write-Host "Then launch DBeaver with: dbeaver -clean"
