<#
.SYNOPSIS
    Natychmiastowy pre-check skladni plikow .ws (WitcherScript) bez uruchamiania gry.

.DESCRIPTION
    Sprawdza strukturalnie kazdy plik .ws moda:
      - balans (), [], {} z numerami linii otwierajacych
      - niezamkniete literaly "..." / '...' (string nie moze przekraczac konca linii)
      - niezamkniete komentarze blokowe /* */
      - puste / 0-bajtowe pliki (np. zepsute junction)
      - niepoprawne kodowanie UTF-8
      - brak deklaracji (class/struct/enum/state/function) - ostrzezenie
      - duplikaty nazw klas/struktow/enumow miedzy plikami - blad
      - mozliwe przypisanie w warunku if/while  ( x = y  zamiast  x == y ) - ostrzezenie
      - sciezki "dlc\...\*.w2scene" wziete z literatow vs scripts\known_scenes.txt - blad

    Nie sprawdza semantyki (nieznane metody, typy) - to robi silnik (test_compile.ps1).

.PARAMETER ScriptsDir
    Katalog ze skryptami moda. Domyslnie: ..\repo\Mods\modMCME_AutonomousRomance\content\scripts

.PARAMETER SceneListFile
    Plik z lista znanych scen (jedna sciezka w linii). Domyslnie: known_scenes.txt obok skryptu.
    Jesli nie istnieje - sprawdzanie sciezek scen jest pomijane.

.EXAMPLE
    .\precheck_syntax.ps1
#>
[CmdletBinding()]
param(
    [string]$ScriptsDir,
    [string]$SceneListFile,
    [switch]$WarningsAsErrors
)

$ErrorActionPreference = 'Stop'

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptRoot) { $scriptRoot = (Get-Location).Path }
if (-not $ScriptsDir)    { $ScriptsDir    = Join-Path $scriptRoot '..\repo\Mods\modMCME_AutonomousRomance\content\scripts' }
if (-not $SceneListFile) { $SceneListFile = Join-Path $scriptRoot 'known_scenes.txt' }

$ScriptsDir = (Resolve-Path $ScriptsDir).Path
$files = Get-ChildItem -Path $ScriptsDir -Recurse -Filter '*.ws' -File
if (-not $files) { Write-Error "Nie znaleziono zadnych plikow .ws w $ScriptsDir"; exit 2 }

$knownScenes = $null
if (Test-Path $SceneListFile) {
    $knownScenes = @{}
    Get-Content $SceneListFile | ForEach-Object {
        $s = $_.Trim(); if ($s) { $knownScenes[$s.ToLowerInvariant()] = $true }
    }
}

$totalErrors = 0
$totalWarnings = 0
$typeDefs = @{}   # typename -> @(file, line)

function Report {
    param([string]$File, [int]$Line, [string]$Severity, [string]$Msg)
    $loc = if ($Line -gt 0) { "${File}:${Line}" } else { $File }
    if ($Severity -eq 'ERROR') {
        Write-Host "$loc : ERROR  $Msg" -ForegroundColor Red
        $script:totalErrors++
    } else {
        Write-Host "$loc : WARN   $Msg" -ForegroundColor Yellow
        $script:totalWarnings++
    }
}

foreach ($file in $files) {
    $rel = $file.FullName.Substring($ScriptsDir.Length).TrimStart('\')
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)

    if ($bytes.Length -eq 0) {
        Report $rel 0 'ERROR' 'pusty plik (0 bajtow) - zepsuty junction/link?'
        continue
    }

    try {
        $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $text = $utf8.GetString($bytes)
    } catch {
        Report $rel 0 'WARN' 'plik nie jest poprawnym UTF-8 - znaki narodowe moga sie zepsuc'
        $text = [System.Text.Encoding]::Default.GetString($bytes)
    }
    # BOM (U+FEFF) lamiallby kotwice ^ w regexach deklaracji - usun
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    if ([string]::IsNullOrWhiteSpace($text)) {
        Report $rel 0 'ERROR' 'plik zawiera tylko biale znaki'
        continue
    }

    # --- skaner znakowy: komentarze, literaly, nawiasy ---
    $line = 1
    $state = 'normal'   # normal | linecomment | blockcomment | string | name
    $stackParen = New-Object 'System.Collections.Generic.List[object]'
    $stackBrace = New-Object 'System.Collections.Generic.List[object]'
    $stackBrack = New-Object 'System.Collections.Generic.List[object]'
    $strBuf = New-Object System.Text.StringBuilder
    $strLine = 0
    $codeLines = New-Object 'System.Collections.Generic.List[string]'   # tekst kodu bez komentarzy/literalow (do regexow)
    $curCode = New-Object System.Text.StringBuilder
    $scenesFound = New-Object 'System.Collections.Generic.List[object]' # @{Line; Path}

    $len = $text.Length
    for ($i = 0; $i -lt $len; $i++) {
        $c = $text[$i]
        $next = if ($i + 1 -lt $len) { $text[$i + 1] } else { "`0" }

        if ($c -eq "`n") {
            if ($state -eq 'string') { Report $rel $strLine 'ERROR' "niezamkniety literal `"`" - koniec linii" }
            if ($state -eq 'name')   { Report $rel $strLine 'ERROR' "niezamkniety literal ' - koniec linii" }
            if ($state -in 'string','name') { $state = 'normal' }
            if ($state -eq 'linecomment') { $state = 'normal' }
            $codeLines.Add($curCode.ToString()); $curCode.Clear() | Out-Null
            $line++
            continue
        }

        switch ($state) {
            'linecomment' { }
            'blockcomment' {
                if ($c -eq '*' -and $next -eq '/') { $state = 'normal'; $i++ }
            }
            'string' {
                if ($c -eq '"') {
                    $state = 'normal'
                    $lit = $strBuf.ToString()
                    if ($lit -match '\.w2scene$') {
                        $scenesFound.Add([pscustomobject]@{ Line = $strLine; Path = $lit })
                    }
                } else { $strBuf.Append($c) | Out-Null }
            }
            'name' {
                if ($c -eq "'") { $state = 'normal' }
            }
            'normal' {
                if ($c -eq '/' -and $next -eq '/') { $state = 'linecomment'; $i++ }
                elseif ($c -eq '/' -and $next -eq '*') { $state = 'blockcomment'; $i++ }
                elseif ($c -eq '"') { $state = 'string'; $strBuf.Clear() | Out-Null; $strLine = $line; $curCode.Append('"') | Out-Null }
                elseif ($c -eq "'") { $state = 'name'; $curCode.Append("'") | Out-Null }
                elseif ($c -eq '(') { $stackParen.Add($line); $curCode.Append($c) | Out-Null }
                elseif ($c -eq ')') {
                    if ($stackParen.Count -eq 0) { Report $rel $line 'ERROR' "nieoczekiwane zamkniecie ')'" }
                    else { $stackParen.RemoveAt($stackParen.Count - 1) }
                    $curCode.Append($c) | Out-Null
                }
                elseif ($c -eq '{') { $stackBrace.Add($line); $curCode.Append($c) | Out-Null }
                elseif ($c -eq '}') {
                    if ($stackBrace.Count -eq 0) { Report $rel $line 'ERROR' "nieoczekiwane zamkniecie '}'" }
                    else { $stackBrace.RemoveAt($stackBrace.Count - 1) }
                    $curCode.Append($c) | Out-Null
                }
                elseif ($c -eq '[') { $stackBrack.Add($line); $curCode.Append($c) | Out-Null }
                elseif ($c -eq ']') {
                    if ($stackBrack.Count -eq 0) { Report $rel $line 'ERROR' "nieoczekiwane zamkniecie ']'" }
                    else { $stackBrack.RemoveAt($stackBrack.Count - 1) }
                    $curCode.Append($c) | Out-Null
                }
                else { $curCode.Append($c) | Out-Null }
            }
        }
    }
    $codeLines.Add($curCode.ToString())

    if ($state -eq 'blockcomment') { Report $rel $line 'ERROR' 'niezamkniety komentarz blokowy /*' }
    foreach ($l in $stackParen) { Report $rel $l 'ERROR' "niezamkniete '(' z tej linii" }
    foreach ($l in $stackBrace) { Report $rel $l 'ERROR' "niezamkniete '{' z tej linii" }
    foreach ($l in $stackBrack) { Report $rel $l 'ERROR' "niezamkniete '[' z tej linii" }

    # --- deklaracje typow + sanacja pliku ---
    $codeText = ($codeLines -join "`n")
    $declRe = [regex]'(?m)^\s*(?:@[A-Za-z]+\s*\([^)]*\)\s*)*(class|struct|enum|exec|statemachine|state|function|quest|reward)\b'
    if (-not $declRe.IsMatch($codeText)) {
        Report $rel 0 'WARN' 'plik nie zawiera zadnej deklaracji (class/function/state/...) - celowy?'
    }
    $typeRe = [regex]'(?m)^\s*(?:statemachine\s+)?(class|struct|enum)\s+([A-Za-z_]\w*)'
    foreach ($m in $typeRe.Matches($codeText)) {
        $tn = $m.Groups[2].Value
        $ln = ($codeText.Substring(0, $m.Index) -split "`n").Count
        if ($typeDefs.ContainsKey($tn)) {
            $prev = $typeDefs[$tn]
            Report $rel $ln 'ERROR' "duplikat typu '$tn' - juz zdefiniowany w $($prev[0]):$($prev[1])"
        } else {
            $typeDefs[$tn] = @($rel, $ln)
        }
    }

    # --- mozliwe przypisanie w warunku if/while ---
    for ($li = 0; $li -lt $codeLines.Count; $li++) {
        $cl = $codeLines[$li]
        if ($cl -match '(?:^|[^\w])(if|while)\s*\(([^)]*)\)') {
            $kw = $Matches[1]; $cond = $Matches[2]
            if ($cond -match '(?<![=!<>])=(?![=])') {
                Report $rel ($li + 1) 'WARN' "mozliwe przypisanie w warunku $kw - chodzilo o '=='?"
            }
        }
    }

    # --- sciezki scen vs known_scenes.txt ---
    if ($knownScenes) {
        foreach ($sf in $scenesFound) {
            $norm = $sf.Path -replace '\\\\', '\'
            if (-not $knownScenes.ContainsKey($norm.ToLowerInvariant())) {
                Report $rel $sf.Line 'ERROR' "scena nie istnieje w bundle'ach DLC: $norm"
            }
        }
    }
}

Write-Host ''
Write-Host '==========================================================' -ForegroundColor Cyan
if ($totalErrors -eq 0 -and (-not $WarningsAsErrors -or $totalWarnings -eq 0)) {
    Write-Host "[OK] PRECHECK: $($files.Count) plikow, 0 bledow, $totalWarnings ostrzezen" -ForegroundColor Green
    Write-Host '==========================================================' -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "[FAIL] PRECHECK: $($files.Count) plikow, $totalErrors bledow, $totalWarnings ostrzezen" -ForegroundColor Red
    Write-Host '==========================================================' -ForegroundColor Cyan
    exit 1
}
