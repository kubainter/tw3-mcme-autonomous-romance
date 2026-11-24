<#
.SYNOPSIS
    Buduje paczke release mostu: MCME_AR_Unicorn_vX.Y.Z.zip.

.DESCRIPTION
    Osobny, opcjonalny release mostu Unicorn dla MCME Autonomous Romance.
    Pakuje WYLACZNIE Mods\modMCME_AR_Unicorn + jego strone MCM
    (bin\config\r4game\user_config_matrix\pc\modMCME_AR_Unicorn.xml)
    oraz generuje README.txt z wymaganiami i known-issues.

    Most jest celowo WYCIETY z package_release.ps1 (paczka bazowa):
    bez modUnicornCore jego skrypty nie kompiluja sie, a sam XML
    utworzylby martwa strone menu u graczy bez mostu.

    Stringi menu mostu (option_*/panel_*/preset_*) zyja w binarkach
    w3strings PACZKI BAZOWEJ - bridge zip nie potrzebuje wlasnych.

.PARAMETER Version
    Tag wersji, np. v1.0.0. Domyslnie v0.0.0-local.

.PARAMETER OutDir
    Katalog wyjsciowy na zip. Domyslnie ..\releases (sibling repo).

.PARAMETER SkipPrecheck
    Pomija precheck_syntax.ps1 (precheck obejmuje pliki mostu).

.EXAMPLE
    .\package_bridge.ps1 -Version v1.0.0
    .\package_bridge.ps1 -Version v0.0.0-ci -SkipPrecheck
#>
[CmdletBinding()]
param(
    [string]$Version = "v0.0.0-local",
    [string]$OutDir,
    [switch]$SkipPrecheck
)

$ErrorActionPreference = 'Stop'

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$repoDir   = Split-Path -Parent $scriptDir
if (-not $OutDir) { $OutDir = Join-Path $repoDir '..\releases' }
$OutDir = (Resolve-Path (New-Item -ItemType Directory -Path $OutDir -Force)).Path

$archiveName = "MCME_AR_Unicorn_$Version.zip"
$archivePath = Join-Path $OutDir $archiveName

Write-Host "=== Building Bridge Package: $archiveName ===" -ForegroundColor Cyan

# Fast-fail: precheck obejmuje tez pliki mostu
$precheckScript = Join-Path $scriptDir 'precheck_syntax.ps1'
if (-not $SkipPrecheck -and (Test-Path $precheckScript)) {
    & $precheckScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Precheck syntax failed! Aborting bridge packaging." -ForegroundColor Red
        exit 1
    }
}

# Prepare temp staging folder
$stagingDir = Join-Path $OutDir "_staging_bridge_$Version"
if (Test-Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

# Copy ONLY the bridge mod folder
$srcBridgeMod = Join-Path $repoDir 'Mods\modMCME_AR_Unicorn'
if (-not (Test-Path $srcBridgeMod)) {
    Write-Host "[FAIL] brak $srcBridgeMod - most nie istnieje w repo!" -ForegroundColor Red
    exit 1
}
Copy-Item -Path $srcBridgeMod -Destination (Join-Path $stagingDir 'Mods\modMCME_AR_Unicorn') -Recurse -Force

# Copy ONLY the bridge MCM page xml (strona Mods.MCMEUnicorn)
$xmlRel = 'bin\config\r4game\user_config_matrix\pc\modMCME_AR_Unicorn.xml'
$srcXml = Join-Path $repoDir $xmlRel
if (-not (Test-Path $srcXml)) {
    Write-Host "[FAIL] brak $srcXml - strona MCM mostu nie istnieje!" -ForegroundColor Red
    exit 1
}
New-Item -ItemType Directory -Path (Split-Path (Join-Path $stagingDir $xmlRel) -Parent) -Force | Out-Null
Copy-Item -Path $srcXml -Destination (Join-Path $stagingDir $xmlRel) -Force

# README.txt jedzie z mod-dir (single source of truth, jak CHANGELOG.md).
# Wczesniejsza wersja skryptu generowala wlasny README - dublowal tresc
# i wyprzedzal sie za stanem kodu.
$required = @(
    'Mods\modMCME_AR_Unicorn\README.txt',
    'Mods\modMCME_AR_Unicorn\content\scripts\local\MCM_AR_Unicorn.ws',
    'Mods\modMCME_AR_Unicorn\content\scripts\local\MCM_AR_UnicornPacks.ws',
    'Mods\modMCME_AR_Unicorn\tw3se\init.lua',
    'bin\config\r4game\user_config_matrix\pc\modMCME_AR_Unicorn.xml'
)
foreach ($rel in $required) {
    if (-not (Test-Path (Join-Path $stagingDir $rel))) {
        Write-Host "[FAIL] brak w staging: $rel" -ForegroundColor Red
        exit 1
    }
}

# Remove any unwanted files from staging
Get-ChildItem -Path $stagingDir -Recurse -Include "*.bak", "*.devbak", "*.tmp", "*~", "*.csv", "__folder_managed_by_vortex" | Remove-Item -Force

# Create ZIP (entries with '/' separators - W3MM/Steam Deck safe)
if (Test-Path $archivePath) {
    Remove-Item -Path $archivePath -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($archivePath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $files = Get-ChildItem -Path $stagingDir -Recurse -File
    foreach ($file in $files) {
        $entryName = $file.FullName.Substring($stagingDir.Length).TrimStart('\', '/').Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $file.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $zip.Dispose()
}

# Cleanup staging
Remove-Item -Path $stagingDir -Recurse -Force

Write-Host "[SUCCESS] Archive created: $archivePath" -ForegroundColor Green
Write-Host "File size: $((Get-Item $archivePath).Length / 1KB) KB" -ForegroundColor Green
