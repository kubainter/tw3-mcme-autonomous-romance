<#
.SYNOPSIS
    Repo rules lint - enforcable zelazne reguly z AGENTS.md bez uruchamiania gry.

.DESCRIPTION
    Sprawdza reguly, ktorych precheck_syntax.ps1 nie obejmuje:
      - StringToName() w kodzie .ws (funkcja nie istnieje w silniku Remastered) - blad
      - .Find( / .IndexOf( na kolekcjach - heurystyka reguly 10 AGENTS.md - ostrzezenie
        (.Contains jest udowodnione dzialajace w Remastered, nie flagujemy)
      - obecnosc ru.w3strings.csv (RU obsluguje zewnetrzny mod - zakaz w repo) - blad
      - regresja rename: MCME_AR.input.settings.txt nie moze wrocic - blad
      - RegisterListener na vanilla akcji 'SwordSheathe' w .ws (rejestracja na pare
        (obiekt, akcja) ZASTEPUJE natywny handler gry i zabija sheathing, W3-TIK-021) - blad
        (linie komentarza // sa pomijane)
      - input.settings.txt nie moze nadpisywac IK_C - consent dziala przez polling - blad
      - input.xml.optional musi deklarowac Var actions="MCM_AR_Consent",
        a input.xml.txt (auto-merge W3MM) nie moze istniec - blad
      - CHANGELOG.md musi miec sekcje [Nexus Mods Changelog Snippet] z blokiem ```text - blad
      - najnowszy naglowek wersji w CHANGELOG musi parsowac jako semver - blad
      - badge Version-vX.Y.Z w README.md musi pasowac do najnowszego naglowka CHANGELOG - blad
      - pliki tymczasowe/niechciane w drzewie (*.bak, *.tmp, *~, vortex marker) - blad

.EXAMPLE
    .\ci_rules.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $RepoRoot) {
    $cand = Split-Path -Parent $scriptRoot
    if (Test-Path (Join-Path $cand 'Mods\modMCME_AutonomousRomance')) { $RepoRoot = $cand }
    else { $RepoRoot = (Get-Location).Path }
}
$RepoRoot = (Resolve-Path $RepoRoot).Path

$modRoot  = Join-Path $RepoRoot 'Mods\modMCME_AutonomousRomance'
$wsDir    = Join-Path $modRoot 'content\scripts'
$content  = Join-Path $modRoot 'content'

$totalErrors = 0
$totalWarnings = 0
function Report([string]$File, [string]$Severity, [string]$Msg) {
    if ($Severity -eq 'ERROR') { Write-Host "$File : ERROR  $Msg" -ForegroundColor Red;  $script:totalErrors++ }
    else                       { Write-Host "$File : WARN   $Msg" -ForegroundColor Yellow; $script:totalWarnings++ }
}

# --- .ws: StringToName (ERROR), .Find/.IndexOf (WARN) ---
$wsFiles = Get-ChildItem $wsDir -Recurse -Filter '*.ws' -File -ErrorAction SilentlyContinue
foreach ($f in $wsFiles) {
    $rel = $f.FullName.Substring($RepoRoot.Length).TrimStart('\')
    # strip // comments to avoid flagging mentions in comments
    $raw = [System.IO.File]::ReadAllText($f.FullName)
    $code = [regex]::Replace($raw, '(?m)//[^\r\n]*', '')
    foreach ($m in [regex]::Matches($code, 'StringToName\s*\(')) {
        $ln = ($raw.Substring(0, $m.Index) -split "`n").Count
        Report "${rel}:$ln" 'ERROR' 'StringToName() nie istnieje w silniku Remastered - porownuj przez StrLower(NameToString(nam))'
    }
    foreach ($m in [regex]::Matches($code, '\.(?:Find|IndexOf)\s*\(')) {
        $ln = ($raw.Substring(0, $m.Index) -split "`n").Count
        Report "${rel}:$ln" 'WARN' 'metoda kolekcji .Find/.IndexOf - sprawdz czy typ ja wspiera (regula 10 AGENTS.md)'
    }
    # Anti-regresja sheathing (W3-TIK-021): listener na vanilla akcji 'SwordSheathe'
    # ZASTEPUJE natywny handler gry (playerInput.ws OnCommSheatheAny) i zabija C.
    # Linie komentarza (// ...) sa pomijane - w kodzie zyja komentarze objasniajace zakaz.
    $lineNo = 0
    foreach ($line in ($raw -split "\r?\n")) {
        $lineNo++
        if ($line -match '^\s*//') { continue }
        if ($line -match "RegisterListener\s*\([^)]*'SwordSheathe'") {
            Report "${rel}:$lineNo" 'ERROR' "RegisterListener na vanilla akcji 'SwordSheathe' zabija sheathing - obserwuj ja pollingiem (W3-TIK-021)"
        }
    }
}

# --- zakaz ru.w3strings.csv ---
if (Test-Path (Join-Path $content 'ru.w3strings.csv')) {
    Report 'content\ru.w3strings.csv' 'ERROR' 'RU obsluguje zewnetrzny mod - zakaz csv RU w repo (regula 13)'
}

# --- regresja rename'u input fragmentu ---
if (Test-Path (Join-Path $modRoot 'MCME_AR.input.settings.txt')) {
    Report 'Mods\modMCME_AutonomousRomance\MCME_AR.input.settings.txt' 'ERROR' 'prefixed input fragment wrocil - uzywamy input.settings.txt'
}
$inputFrag = Join-Path $modRoot 'input.settings.txt'
if (-not (Test-Path $inputFrag)) {
    Report 'Mods\modMCME_AutonomousRomance\input.settings.txt' 'ERROR' 'brak input.settings.txt w rootcie moda'
} else {
    $frag = [System.IO.File]::ReadAllText($inputFrag)
    # Consent dziala przez polling vanilla SwordSheathe - fragment NIE moze dotykac
    # IK_C w zadnym kontekscie (stara skladnia krotki "IK_C" z dwiema akcjami byla
    # nieprawidlowa: gra normalizowala ja do pierwszej akcji).
    if ($frag -match 'IK_C=') {
        Report 'Mods\modMCME_AutonomousRomance\input.settings.txt' 'ERROR' 'fragment nadpisuje IK_C - consent dziala przez polling SwordSheathe, nie przez binding (W3-TIK-021)'
    }
}

# --- input.xml: akcja MCM_AR_Consent widoczna w Options -> Keybindings ---
# Szablon zyje jako input.xml.optional (reczne wklejenie do input.xml).
# Nazwa input.xml.txt jest zakazana w drzewie moda: W3MM auto-merguje
# *.xml.txt do input.xml u kazdego gracza -> surowy displayName
# "Consent (MCME AR)" w Keybindings + ciche ciecie bindingu przy zapisie.
$inputXml = Join-Path $modRoot 'input.xml.optional'
if (-not (Test-Path $inputXml)) {
    Report 'Mods\modMCME_AutonomousRomance\input.xml.optional' 'ERROR' 'brak input.xml.optional - MCM_AR_Consent nie pojawi sie w Keybindings'
} else {
    $xml = [System.IO.File]::ReadAllText($inputXml)
    if ($xml -notmatch 'builder="Input"' -or $xml -notmatch 'actions="MCM_AR_Consent"') {
        Report 'Mods\modMCME_AutonomousRomance\input.xml.optional' 'ERROR' 'input.xml.optional nie deklaruje Var actions="MCM_AR_Consent" z builder="Input"'
    }
}
if (Test-Path (Join-Path $modRoot 'input.xml.txt')) {
    Report 'Mods\modMCME_AutonomousRomance\input.xml.txt' 'ERROR' 'input.xml.txt wrocil - W3MM auto-merge trap; szablon trzymaj jako input.xml.optional'
}

# --- CHANGELOG: snippet section + semver header ---
$changelog = Join-Path $RepoRoot 'CHANGELOG.md'
if (-not (Test-Path $changelog)) {
    Report 'CHANGELOG.md' 'ERROR' 'brak CHANGELOG.md - packaging wymaga snippetu'
} else {
    $md = [System.IO.File]::ReadAllText($changelog, [System.Text.Encoding]::UTF8)
    if ($md -notmatch '(?s)\[Nexus Mods Changelog Snippet\].*?```text\s*\r?\n(.*?)```') {
        Report 'CHANGELOG.md' 'ERROR' 'brak sekcji [Nexus Mods Changelog Snippet] z blokiem ```text - package_release.ps1 tego wymaga'
    }
    if ($md -match '(?m)^## \[(\d+\.\d+\.\d+)\]') {
        # ok - pierwszy naglowek wersji parsuje; badge README nie moze dryfowac
        $changelogVer = $Matches[1]
        $readmePath   = Join-Path $RepoRoot 'README.md'
        if (Test-Path $readmePath) {
            $readmeMd = [System.IO.File]::ReadAllText($readmePath, [System.Text.Encoding]::UTF8)
            if ($readmeMd -notmatch [regex]::Escape("Version-v$changelogVer-")) {
                Report 'README.md' 'ERROR' "badge Version-v$changelogVer nie pasuje do najnowszego naglowka CHANGELOG - sync wersji"
            }
        }
    } else {
        Report 'CHANGELOG.md' 'ERROR' 'brak parsowalnego naglowka wersji ## [X.Y.Z] - release workflow czyta tag z niego'
    }
}

# --- niechciane pliki w drzewie repo ---
$junk = Get-ChildItem $RepoRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\\.git\\' -and ($_.Name -match '\.(bak|devbak|tmp)$' -or $_.Name -match '~$' -or $_.Name -eq '__folder_managed_by_vortex') }
foreach ($j in $junk) {
    Report $j.FullName.Substring($RepoRoot.Length).TrimStart('\') 'ERROR' 'plik tymczasowy/niechciany w repo'
}

Write-Host ''
if ($totalErrors -eq 0) {
    Write-Host "[OK] RULES: 0 bledow, $totalWarnings ostrzezen" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] RULES: $totalErrors bledow, $totalWarnings ostrzezen" -ForegroundColor Red
    exit 1
}
