<#
.SYNOPSIS
    Weryfikuje zawartosc zbudowanej paczki release (zip) - bramka CI.

.DESCRIPTION
    Asercje na zipie z package_release.ps1:
      - wszystkie nazwy wpisow uzywaja '/' (spec ZIP, W3MM na Linux/Deck) - blad
      - wymagane wpisy istnieja (input.settings.txt, README.txt, CHANGELOG.txt,
        modMCME_AutonomousRomance.xml, MCM_RomanceCore.ws) - blad
      - zakazane wpisy nieobecne (MCME_AR.input.settings.txt, E2EDev, *.csv,
        *.stub.ws, *.bak/tmp/~, __folder_managed_by_vortex) - blad
      - MCM_RomanceTw3seDev.ws w paczce jest bajtowo stubem - blad
      - CHANGELOG.txt == snippet wyekstrahowany z CHANGELOG.md - blad
      - input.settings.txt zawiera binding MCM_AR_Consent - blad
      - sensowna liczba wpisow (>= 20) - blad

.PARAMETER ZipPath
    Sciezka do zbudowanego zipa.

.PARAMETER RepoRoot
    Korzen repo (do porownania stuba i changelogu). Domyslnie auto.

.EXAMPLE
    .\ci_verify_package.ps1 -ZipPath "$env:TEMP\pkg\MCME_AutonomousRomance_v0.0.0-ci.zip"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ZipPath,
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $scriptRoot }

$totalErrors = 0
function Report([string]$Msg) { Write-Host "FAIL  $Msg" -ForegroundColor Red; $script:totalErrors++ }
function Ok([string]$Msg)     { Write-Host "  ok  $Msg" -ForegroundColor DarkGray }

if (-not (Test-Path $ZipPath)) { Write-Host "[FAIL] brak zipa: $ZipPath" -ForegroundColor Red; exit 2 }

$zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
$entries = @{}
foreach ($e in $zip.Entries) { $entries[$e.FullName] = $e }

# --- '/' w nazwach wpisow ---
foreach ($name in $entries.Keys) {
    if ($name.Contains('\')) { Report "wpis z backslashem: $name" }
}
Ok "entries: $($entries.Count), separatory '/'"

# --- wymagane wpisy ---
$required = @(
    'Mods/modMCME_AutonomousRomance/input.settings.txt',
    'Mods/modMCME_AutonomousRomance/README.txt',
    'Mods/modMCME_AutonomousRomance/CHANGELOG.txt',
    'Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceCore.ws',
    'Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceTw3seDev.ws',
    'bin/config/r4game/user_config_matrix/pc/modMCME_AutonomousRomance.xml'
)
foreach ($r in $required) {
    if (-not $entries.ContainsKey($r)) { Report "brak wymaganego wpisu: $r" }
}

# --- zakazane wpisy ---
foreach ($name in $entries.Keys) {
    $base = Split-Path $name -Leaf
    if ($base -eq 'MCME_AR.input.settings.txt') { Report "stary prefixed fragment w paczce: $name" }
    if ($base -eq 'MCM_RomanceE2EDev.ws')       { Report "dev-only E2EDev w paczce: $name" }
    if ($base -like '*.stub.ws')                { Report "plik *.stub.ws w paczce: $name" }
    if ($base -like '*.csv')                    { Report "plik csv w paczce: $name" }
    if ($base -match '\.(bak|devbak|tmp)$' -or $base -match '~$' -or $base -eq '__folder_managed_by_vortex') {
        Report "plik niechciany w paczce: $name"
    }
}

# --- Tw3seDev == stub ---
$stubPath = Join-Path $RepoRoot 'scripts\tw3se\MCM_RomanceTw3seDev.stub.ws'
$tw3seEntry = $entries['Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceTw3seDev.ws']
if ($tw3seEntry -and (Test-Path $stubPath)) {
    $sr = New-Object IO.StreamReader($tw3seEntry.Open()); $zipTxt = $sr.ReadToEnd(); $sr.Close()
    $stubTxt = [System.IO.File]::ReadAllText($stubPath)
    if ($zipTxt -ne $stubTxt) { Report 'MCM_RomanceTw3seDev.ws w paczce != stub z scripts\tw3se' }
    else { Ok 'Tw3seDev == stub' }
}

# --- CHANGELOG.txt == snippet z CHANGELOG.md ---
$clEntry = $entries['Mods/modMCME_AutonomousRomance/CHANGELOG.txt']
$changelogMd = Join-Path $RepoRoot 'CHANGELOG.md'
if ($clEntry -and (Test-Path $changelogMd)) {
    $sr = New-Object IO.StreamReader($clEntry.Open()); $zipTxt = $sr.ReadToEnd(); $sr.Close()
    $md = [System.IO.File]::ReadAllText($changelogMd, [System.Text.Encoding]::UTF8)
    if ($md -match '(?s)\[Nexus Mods Changelog Snippet\].*?```text\s*\r?\n(.*?)```') {
        $expected = $Matches[1].Trim()
        if ($zipTxt.Trim() -ne $expected) { Report 'CHANGELOG.txt w paczce != snippet z CHANGELOG.md' }
        else { Ok 'CHANGELOG.txt == snippet' }
    } else {
        Report 'CHANGELOG.md nie ma parsowalnego snippetu (packaging powinien byl zglosic FAIL)'
    }
}

# --- input.settings.txt zawiera MCM_AR_Consent ---
$inEntry = $entries['Mods/modMCME_AutonomousRomance/input.settings.txt']
if ($inEntry) {
    $sr = New-Object IO.StreamReader($inEntry.Open()); $zipTxt = $sr.ReadToEnd(); $sr.Close()
    if ($zipTxt -notmatch 'MCM_AR_Consent') { Report 'input.settings.txt w paczce nie zawiera MCM_AR_Consent' }
    else { Ok 'input.settings.txt z bindingiem' }
}

$zip.Dispose()

if ($entries.Count -lt 20) { Report "podejrzanie malo wpisow w paczce: $($entries.Count)" }

Write-Host ''
if ($totalErrors -eq 0) {
    Write-Host "[OK] PACKAGE: $($entries.Count) wpisow, wszystkie asercje zielone" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] PACKAGE: $totalErrors naruszen" -ForegroundColor Red
    exit 1
}
