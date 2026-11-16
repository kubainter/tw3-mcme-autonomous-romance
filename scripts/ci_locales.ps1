<#
.SYNOPSIS
    Spojnosc lokalizacji miedzy plikami *.w3strings.csv.

.DESCRIPTION
    Kanon lokalizacji: en, pl, de, es, esmx (regula 13 AGENTS.md - RU jest
    zewnetrzny, nigdy nie tworzymy ru.w3strings.csv).
    Format wiersza: id|key(hex)|key(str)|text ; linie ';' to komentarze.

    Sprawdza:
      - kazdy kanoniczny plik csv istnieje - blad
      - zaden plik nie ma zduplikowanego id - blad
      - zbior id jest identyczny we wszystkich pieciu plikach (brak klucza
        w danym jezyku = brakujace tlumaczenie) - blad
      - to samo id ma identyczny key(str) we wszystkich plikach - blad

.EXAMPLE
    .\ci_locales.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $RepoRoot) {
    $cand = Split-Path -Parent $scriptRoot
    if (Test-Path (Join-Path $cand 'Mods\modMCME_AutonomousRomance\content\en.w3strings.csv')) { $RepoRoot = $cand }
    else { $RepoRoot = (Get-Location).Path }
}
$contentDir = Join-Path $RepoRoot 'Mods\modMCME_AutonomousRomance\content'

$locales = @('en', 'pl', 'de', 'es', 'esmx')
$totalErrors = 0
$totalWarnings = 0
function Report([string]$File, [string]$Severity, [string]$Msg) {
    if ($Severity -eq 'ERROR') { Write-Host "$File : ERROR  $Msg" -ForegroundColor Red;  $script:totalErrors++ }
    else                       { Write-Host "$File : WARN   $Msg" -ForegroundColor Yellow; $script:totalWarnings++ }
}

# loc -> @{ id -> keystr }
$tables = @{}
$lineCounts = @{}
foreach ($loc in $locales) {
    $path = Join-Path $contentDir "$loc.w3strings.csv"
    if (-not (Test-Path $path)) {
        Report "$loc.w3strings.csv" 'ERROR' 'brak kanonicznego pliku lokalizacji'
        continue
    }
    $t = @{}
    $dup = @{}
    foreach ($ln in [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)) {
        if ($ln.TrimStart().StartsWith(';') -or -not $ln.Contains('|')) { continue }
        $cols = $ln -split '\|'
        $id = $cols[0].Trim()
        $key = if ($cols.Count -ge 3) { $cols[2].Trim() } else { '' }
        if ($t.ContainsKey($id)) {
            Report "$loc.w3strings.csv" 'ERROR' "zduplikowane id $id (key '$key')"
            $dup[$id] = $true
        } else {
            $t[$id] = $key
        }
    }
    $tables[$loc] = $t
    $lineCounts[$loc] = $t.Count
}

if ($tables.Count -eq $locales.Count) {
    # identyczny zbior id + zgodne key(str)
    $en = $tables['en']
    foreach ($id in $en.Keys) {
        foreach ($loc in $locales) {
            if ($loc -eq 'en') { continue }
            $t = $tables[$loc]
            if (-not $t.ContainsKey($id)) {
                Report "$loc.w3strings.csv" 'ERROR' "brak id $id (en key '$($en[$id])') - brakujace tlumaczenie"
            } elseif ($t[$id] -ne $en[$id]) {
                Report "$loc.w3strings.csv" 'ERROR' "id ${id}: key(str) '$($t[$id])' != en '$($en[$id])' - rozjazd kluczy"
            }
        }
    }
    # id obecne w innych plikach, a nieobecne w en
    foreach ($loc in $locales) {
        if ($loc -eq 'en') { continue }
        foreach ($id in $tables[$loc].Keys) {
            if (-not $en.ContainsKey($id)) {
                Report "$loc.w3strings.csv" 'ERROR' "id $id istnieje tylko w $loc - brak w en (key '$($tables[$loc][$id])')"
            }
        }
    }
}

$counts = ($locales | ForEach-Object { "${_}=$($lineCounts[$_])" }) -join ', '
Write-Host ''
if ($totalErrors -eq 0) {
    Write-Host "[OK] LOCALES: $counts - zgodne" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] LOCALES: $counts - $totalErrors bledow" -ForegroundColor Red
    exit 1
}
