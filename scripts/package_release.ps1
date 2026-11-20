<#
.SYNOPSIS
    Buduje paczke release MCME_AutonomousRomance_vX.Y.Z.zip.

.DESCRIPTION
    Kanoniczna wersja w repo (repo\scripts\package_release.ps1) - dziala
    lokalnie i w CI. Kopiuje Mods/ + bin/ do stagingu, ekstrahuje
    [Nexus Mods Changelog Snippet] z CHANGELOG.md do CHANGELOG.txt,
    podmienia warstwe dev TW3SE na stub i usuwa pliki dev-only.

.PARAMETER Version
    Tag wersji, np. v2.3.1. Domyslnie v0.0.0-local.

.PARAMETER OutDir
    Katalog wyjsciowy na zip. Domyslnie ..\releases (sibling repo).

.PARAMETER SkipPrecheck
    Pomija precheck_syntax.ps1 (CI odpala go jako osobny krok).

.EXAMPLE
    .\package_release.ps1 -Version v2.3.1
    .\package_release.ps1 -Version v0.0.0-ci -OutDir $env:TEMP\pkg -SkipPrecheck
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

$archiveName = "MCME_AutonomousRomance_$Version.zip"
$archivePath = Join-Path $OutDir $archiveName

Write-Host "=== Building Release Package: $archiveName ===" -ForegroundColor Cyan

# Fast-fail: verify syntax before packaging
$precheckScript = Join-Path $scriptDir 'precheck_syntax.ps1'
if (-not $SkipPrecheck -and (Test-Path $precheckScript)) {
    & $precheckScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Precheck syntax failed! Aborting release packaging." -ForegroundColor Red
        exit 1
    }
}

# Prepare temp staging folder (obok katalogu wyjsciowego - poza repo)
$stagingDir = Join-Path $OutDir "_staging_$Version"
if (Test-Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

# Copy Mods/ and bin/
$srcMods = Join-Path $repoDir 'Mods'
$srcBin  = Join-Path $repoDir 'bin'

if (Test-Path $srcMods) {
    Copy-Item -Path $srcMods -Destination $stagingDir -Recurse -Force
}
if (Test-Path $srcBin) {
    Copy-Item -Path $srcBin -Destination $stagingDir -Recurse -Force
}

# CHANGELOG: single source of truth is repo/CHANGELOG.md.
# Do paczki trafia wylacznie sekcja [Nexus Mods Changelog Snippet]
# (blok ```text) wyekstrahowana jako CHANGELOG.txt.
$fullChangelog = Join-Path $repoDir 'CHANGELOG.md'
$changelogOut = Join-Path $stagingDir 'Mods\modMCME_AutonomousRomance\CHANGELOG.txt'
if (-not (Test-Path $fullChangelog)) {
    Write-Host "[FAIL] brak $fullChangelog - nie ma zrodla changelogu!" -ForegroundColor Red
    exit 1
}
$changelogMd = Get-Content $fullChangelog -Raw -Encoding UTF8
if ($changelogMd -match '(?s)\[Nexus Mods Changelog Snippet\].*?```text\s*\r?\n(.*?)```') {
    Set-Content -Path $changelogOut -Value $Matches[1].Trim() -Encoding UTF8
    Write-Host "[release] CHANGELOG.txt wyekstrahowany z repo\CHANGELOG.md" -ForegroundColor Yellow
} else {
    Write-Host "[FAIL] repo\CHANGELOG.md nie zawiera sekcji [Nexus Mods Changelog Snippet] z blokiem ```text!" -ForegroundColor Red
    exit 1
}

# TW3SE dev-layer -> release stub: mod nigdy nie wymaga TW3SE u gracza.
# Dev plik z importami jest zastepowany stubem o identycznych sygnaturach
# (parzystosc pilnuje precheck_syntax.ps1).
$stubSrc = Join-Path $repoDir 'scripts\tw3se\MCM_RomanceTw3seDev.stub.ws'
$devFile = Join-Path $stagingDir 'Mods\modMCME_AutonomousRomance\content\scripts\local\romance\MCM_RomanceTw3seDev.ws'
if (Test-Path $devFile) {
    if (Test-Path $stubSrc) {
        Copy-Item -Path $stubSrc -Destination $devFile -Force
        Write-Host "[release] TW3SE dev-layer zastapiony stubem" -ForegroundColor Yellow
    } else {
        Write-Host "[FAIL] brak $stubSrc - release wymagalby TW3SE!" -ForegroundColor Red
        exit 1
    }
}

# Dev-only suite E2E (ar_test_e2e, ar_tour_scenes) - nie trafia do paczki
$e2eDevInStaging = Join-Path $stagingDir 'Mods\modMCME_AutonomousRomance\content\scripts\local\romance\MCM_RomanceE2EDev.ws'
if (Test-Path $e2eDevInStaging) {
    Remove-Item -Path $e2eDevInStaging -Force
    Write-Host "[release] MCM_RomanceE2EDev.ws usuniety z paczki (dev-only)" -ForegroundColor Yellow
}

# Opcjonalny most Unicorn - osobny ZIP (package_bridge.ps1), NIE wchodzi
# do paczki bazowej: bez modUnicornCore jego skrypty nie kompiluja sie,
# a XML sam utworzylby martwa strone menu u graczy bez mostu.
$bridgeModInStaging = Join-Path $stagingDir 'Mods\modMCME_AR_Unicorn'
$bridgeXmlInStaging = Join-Path $stagingDir 'bin\config\r4game\user_config_matrix\pc\modMCME_AR_Unicorn.xml'
if (Test-Path $bridgeModInStaging) {
    Remove-Item -Path $bridgeModInStaging -Recurse -Force
    Write-Host "[release] modMCME_AR_Unicorn wyciety (osobny release)" -ForegroundColor Yellow
}
if (Test-Path $bridgeXmlInStaging) {
    Remove-Item -Path $bridgeXmlInStaging -Force
    Write-Host "[release] modMCME_AR_Unicorn.xml wyciety (osobny release)" -ForegroundColor Yellow
}
# Plan 005 wprowadzi dlc\dlcMCME_AR_Unicorn (paczki animacji) - wycinaj
# juz teraz, zeby przyszly folder mostu nie wyciekl do paczki bazowej.
$bridgeDlcInStaging = Join-Path $stagingDir 'dlc\dlcMCME_AR_Unicorn'
if (Test-Path $bridgeDlcInStaging) {
    Remove-Item -Path $bridgeDlcInStaging -Recurse -Force
    Write-Host "[release] dlcMCME_AR_Unicorn wyciety (osobny release)" -ForegroundColor Yellow
}

# W3MM auto-merge trap: plik input.xml.txt w katalogu moda jest wstrzykiwany
# do input.xml u kazdego gracza (surowy displayName w Keybindings + ciche
# ciecie bindingu przy zapisie). Szablon dla zaawansowanych zyje jako
# input.xml.optional i przechodzi do paczki pod ta nazwa - nazwa
# auto-mergowana jest zakazana w stagingu (ci_rules.ps1 pilnuje repo).
$inputXmlTrap = Get-ChildItem -Path (Join-Path $stagingDir 'Mods') -Recurse -Filter 'input.xml.txt' -File -ErrorAction SilentlyContinue
if ($inputXmlTrap) {
    Write-Host "[FAIL] input.xml.txt w stagingu - W3MM auto-merge trap; szablon trzymaj jako input.xml.optional" -ForegroundColor Red
    exit 1
}

# Remove any unwanted files from staging
Get-ChildItem -Path $stagingDir -Recurse -Include "*.bak", "*.devbak", "*.tmp", "*~", "*.csv", "__folder_managed_by_vortex" | Remove-Item -Force

# Create ZIP
if (Test-Path $archivePath) {
    Remove-Item -Path $archivePath -Force
}

# ZIP spec (4.4.17.1) wymaga '/' w nazwach wpisow. Compress-Archive zapisuje
# '\' - Windows-owe ekstraktory (7z, Explorer) to toleruja, ale zipfile/
# shutil.unpack_archive (W3MM na Linux/Steam Deck) traktuja '\' literalnie
# i paczka pada jako "Not detected as a valid mod".
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
