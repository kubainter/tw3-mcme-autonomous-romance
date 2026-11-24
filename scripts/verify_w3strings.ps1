<#
.SYNOPSIS
    Weryfikuje binarki lokalizacji .w3strings przed pakowaniem.

.DESCRIPTION
    Wykrywa binarki zakodowane jako UTF-16 (błąd, który raz trafił do
    release: gra nie parsuje pliku i renderuje hashe/krzaki zamiast
    tekstu w dymkach, HUD i MCM). Plik .w3strings nie nosi flagi
    kodowania w naglowku - jedyne niezawodne rozroznienie to stosunek
    rozmiaru binarki do sumy bajtow UTF-8 tekstow zrodlowych:
      UTF-8  -> ~1.4-1.7  (kanoniczny format ~19-21 KB przy ~307 wierszach)
      UTF-16 -> ~2.5      (gra renderuje "#hash" zamiast tekstu)

    Sprawdza:
      1. magic STSW + niepusty plik dla kazdego *.w3strings
      2. dla jezykow kanonicznych (pl/en/de/es/esmx): ratio binarka/CSV < 1.9
      3. dla fallbackow bez CSV (ar/br/.../zh): rozmiar == en.w3strings
         (sa bajtowymi kopiami en - konwencja repo)

.EXAMPLE
    .\verify_w3strings.ps1
#>
[CmdletBinding()]
param(
    [string]$ContentDir
)

$ErrorActionPreference = 'Stop'

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$repoDir   = Split-Path -Parent $scriptDir
if (-not $ContentDir) {
    $ContentDir = Join-Path $repoDir 'Mods\modMCME_AutonomousRomance\content'
}

$utf16RatioLimit = 1.9
$errors   = 0
$checked  = 0

function Test-W3StringsFile([string]$binPath, [double]$ratioLimit, [double]$ratio) {
    $bytes = [System.IO.File]::ReadAllBytes($binPath)
    if ($bytes.Length -lt 12) { return "plik obciety/pusty ($($bytes.Length) B)" }
    if ([System.Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ne 'RTSW') { return "brak magic RTSW" }
    if ($ratio -gt $ratioLimit) { return "ratio $([math]::Round($ratio,2)) > $ratioLimit -> UTF-16 (gra nie sparsuje)" }
    return $null
}

$enBin = Join-Path $ContentDir 'en.w3strings'
$enSize = (Get-Item $enBin).Length

foreach ($bin in Get-ChildItem $ContentDir -Filter '*.w3strings' | Where-Object { $_.Name -notmatch '\.csv$' }) {
    $lang = $bin.BaseName
    $csv  = "$($bin.FullName).csv"
    $checked++

    if (Test-Path $csv) {
        $textBytes = 0
        foreach ($line in [System.IO.File]::ReadLines($csv, [System.Text.Encoding]::UTF8)) {
            if ($line.StartsWith(';')) { continue }
            $f = $line -split '\|'
            if ($f.Count -ge 4) { $textBytes += [System.Text.Encoding]::UTF8.GetByteCount($f[3]) }
        }
        $ratio = if ($textBytes -gt 0) { $bin.Length / $textBytes } else { 0 }
        $err = Test-W3StringsFile $bin.FullName $utf16RatioLimit $ratio
        if ($err) { Write-Host "[FAIL] $($bin.Name): $err" -ForegroundColor Red; $errors++ }
        else { Write-Host "[OK] $($bin.Name)  ratio=$([math]::Round($ratio,2))" -ForegroundColor Green }
    } else {
        $err = Test-W3StringsFile $bin.FullName $utf16RatioLimit 0
        if ($err) { Write-Host "[FAIL] $($bin.Name): $err" -ForegroundColor Red; $errors++ }
        elseif ($bin.Length -ne $enSize) {
            Write-Host "[FAIL] $($bin.Name): fallback ma $($bin.Length) B, en ma $enSize B (oczekiwana kopia en)" -ForegroundColor Red
            $errors++
        }
        else { Write-Host "[OK] $($bin.Name)  kopia en" -ForegroundColor Green }
    }
}

if ($errors -gt 0) {
    Write-Host "`n=== verify_w3strings: $errors blad(y) w $checked plikach ===" -ForegroundColor Red
    Write-Host "Napraw: w3strings.exe --encode <csv> --output <bin> --id-space 18800 --utf8" -ForegroundColor Yellow
    exit 1
}
Write-Host "`n=== verify_w3strings: $checked plikow OK ===" -ForegroundColor Green
exit 0
