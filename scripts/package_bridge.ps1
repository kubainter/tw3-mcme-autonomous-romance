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

# README.txt z wymaganiami i known-issues (wersja jezyka: EN jak baza)
$readmePath = Join-Path $stagingDir 'Mods\modMCME_AR_Unicorn\README.txt'
$readme = @"
MCME Autonomous Romance - Unicorn Bridge $Version
==================================================

OPTIONAL add-on. Requires ALL of:
  1. MCME Autonomous Romance (base mod, v2.3.3+)
  2. Unicorn framework (modUnicornCore) installed and working
  3. MCME companions spawned - Unicorn scenes run on the companion
     entities themselves. MCME naughty scene packs are only needed
     for the native fallback path, not for Unicorn scenes.

Without Unicorn Core this package WILL FAIL SCRIPT COMPILATION
by design - do not install it on its own.

INSTALL
-------
Extract into the game root so that:
  Mods\modMCME_AR_Unicorn\...          lands in your Mods folder
  bin\config\...\modMCME_AR_Unicorn.xml lands in bin\config

WHAT IT DOES
------------
Routes MCME Tier 4 intimate scenes through the Unicorn engine instead
of the native .w2scene cutscenes: randomized scene selection with
anti-repeat, per-NPC tag preferences, undressing, solver behavior,
voice/effects. Native scenes remain the complete fallback.

SETTINGS (Mods menu -> "Autonomous Romance - Unicorn")
----------------------------------------------------
  Backend mode:
    0 = Off (native scenes only)
    1 = Prefer Unicorn, native fallback  [default]
    2 = Unicorn only (no fallback)
    3 = Mixed / random
  Allow rougher scene tags: adds Aggressive/Bound/Yoke tags to the pool
    (Forced and Humiliation are always excluded).

KNOWN ISSUES
------------
  - DISABLE XeSS/DLSS frame generation for Unicorn scenes. Frame
    generation caused reproducible D3D12 crashes (2/2 crashes enabled,
    3/3 clean runs disabled). This matches the Unicorn author's own
    warning about upscaler/FG switching.
  - Approach pathing: an NPC held in an idle sync-pose can fail the
    8s approach timeout. Trigger while she is following you.
"@
Set-Content -Path $readmePath -Value $readme -Encoding UTF8
Write-Host "[bridge] README.txt wygenerowany" -ForegroundColor Yellow

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
