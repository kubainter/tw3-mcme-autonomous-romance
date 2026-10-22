param(
    [string]$GameDir = "G:\GOG Galaxy\Games\The Witcher 3 Wild Hunt GOTY",
    [int]$TimeoutSeconds = 45,
    [switch]$SkipPrecheck,
    [switch]$ForceColdRestart
)

$ErrorActionPreference = "Stop"

# Faza 0: natychmiastowy pre-check skladniowy (bez uruchamiania gry)
if (-not $SkipPrecheck) {
    $precheck = Join-Path $PSScriptRoot 'precheck_syntax.ps1'
    if (Test-Path $precheck) {
        & $precheck
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Pre-check wykryl bledy - przerywam przed uruchomieniem gry." -ForegroundColor Red
            exit 1
        }
        Write-Host ""
    }
}

$exePath = Join-Path $GameDir "bin\x64_dx12\witcher3.exe"
if (-not (Test-Path $exePath)) {
    $exePath = Join-Path $GameDir "bin\x64\witcher3.exe"
}

if (-not (Test-Path $exePath)) {
    Write-Error "Nie znaleziono pliku witcher3.exe w podanym katalogu gry: $GameDir"
    exit 2
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   TEST KOMPILACJI SKRYPTOW WIEDZMINA 3 (HEADLESS VERIFY)  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Target: $exePath"

# Detekcja uruchomionego procesu gry
$runningProcesses = Get-Process -Name "witcher3" -ErrorAction SilentlyContinue

if ($runningProcesses -and -not $ForceColdRestart) {
    $pids = ($runningProcesses | ForEach-Object { $_.Id }) -join ", "
    Write-Host "[*] Wykryto aktywny proces gry witcher3.exe (PID: $pids)." -ForegroundColor Yellow

    # Sprawdz czy pipe TW3SE jest dostepny
    $tw3sePipeScript = Join-Path $PSScriptRoot "tw3se_pipe.ps1"
    $pipeAvailable = $false

    if (Test-Path $tw3sePipeScript) {
        try {
            $pingResult = & powershell -NoProfile -ExecutionPolicy Bypass -File $tw3sePipeScript -Cmd "ping" -ConnectTimeoutMs 1500 2>$null
            if ($pingResult -match "pong") {
                $pipeAvailable = $true
            }
        } catch { }
    }

    if ($pipeAvailable) {
        Write-Host "[LIVE] Named Pipe TW3SE (\\.\pipe\tw3se) jest AKTYWNY." -ForegroundColor Green
        Write-Host "[LIVE] Wykonuje bezpieczny Hot-Reload w locie (bez restartowania gry)..." -ForegroundColor Cyan

        $swLive = [System.Diagnostics.Stopwatch]::StartNew()
        $reloadOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $tw3sePipeScript -Cmd "reloadscripts force" -IdleTimeoutMs 30000 2>&1
        $reloadDuration = [math]::Round($swLive.Elapsed.TotalSeconds, 2)
        $outText = ($reloadOutput | Out-String).Trim()

        if ($outText -match "reloadscripts:\s*ok") {
            Write-Host "`n==========================================================" -ForegroundColor Green
            Write-Host "[OK] KOMPILACJA I HOT-RELOAD ZAKONCZONE SUKCESEM w ${reloadDuration}s!" -ForegroundColor Green
            Write-Host "$outText" -ForegroundColor Gray
            Write-Host "Skrypty zostaly przeladowane w dzialajacej grze bez restartu." -ForegroundColor Green
            Write-Host "==========================================================`n" -ForegroundColor Green

            # Zresetuj bezpiecznie stan sesji AR po reloadzie
            try {
                & powershell -NoProfile -ExecutionPolicy Bypass -File $tw3sePipeScript -Cmd "exec ar_devreset()" -IdleTimeoutMs 2000 2>$null | Out-Null
            } catch { }

            exit 0
        }
        elseif ($outText -match "reloadscripts:\s*failed") {
            Write-Host "`n==========================================================" -ForegroundColor Red
            Write-Host "[!] BLAD KOMPILACJI PODCZAS LIVE HOT-RELOAD:" -ForegroundColor Red
            Write-Host "$outText" -ForegroundColor Red
            Write-Host "TW3SE automatycznie przywrocilo ostatni stabilny stan skryptow (gra nie ulegla awarii)." -ForegroundColor Yellow
            Write-Host "==========================================================`n" -ForegroundColor Red
            exit 1
        }
        else {
            Write-Warning "Nietypowa odpowiedz z pipe TW3SE: $outText"
            exit 1
        }
    }
    else {
        Write-Host "[!] Wykryto uruchomiona gre (PID: $pids), ale pipe TW3SE nie odpowiada." -ForegroundColor Yellow
        Write-Host "    Aby chronic Twoja sesje gry przed utrata postepu, test_compile NIE zamknie gry automatycznie." -ForegroundColor Yellow
        Write-Host "    Jesli chcesz wymusic restart i pelny test cold-start, uzyj flagi -ForceColdRestart." -ForegroundColor Yellow
        exit 2
    }
}

if ($ForceColdRestart) {
    Write-Host "Wymuszono zamkniecie istniejacych procesow gry (-ForceColdRestart)..." -ForegroundColor Yellow
    Get-Process -Name "witcher3" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 600
}

$csharpCode = @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class WinWatcherEngine {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(IntPtr hWnd, EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, StringBuilder lParam);

    [DllImport("user32.dll", EntryPoint = "SendMessage", CharSet = CharSet.Auto)]
    public static extern int SendMessageGetTextLength(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    public const uint WM_GETTEXT = 0x000D;
    public const uint WM_GETTEXTLENGTH = 0x000E;

    public class WindowDetails {
        public IntPtr Handle;
        public string Title;
        public string ClassName;
        public string Text;
    }

    public static WindowDetails FindErrorWindow(uint targetPid) {
        WindowDetails found = null;
        EnumWindows((hWnd, lParam) => {
            uint procId;
            GetWindowThreadProcessId(hWnd, out procId);
            if (procId == targetPid) {
                var sbTitle = new StringBuilder(512);
                GetWindowText(hWnd, sbTitle, 512);
                string title = sbTitle.ToString();

                if (title.IndexOf("Script Compilation Errors", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    (title.IndexOf("Error", StringComparison.OrdinalIgnoreCase) >= 0 && title.IndexOf("Witcher", StringComparison.OrdinalIgnoreCase) >= 0)) {
                    
                    var sbClass = new StringBuilder(256);
                    GetClassName(hWnd, sbClass, 256);
                    
                    var sbAll = new StringBuilder();
                    EnumChildWindows(hWnd, (hChild, lChildParam) => {
                        int len = SendMessageGetTextLength(hChild, WM_GETTEXTLENGTH, IntPtr.Zero, IntPtr.Zero);
                        if (len > 0) {
                            var sbChild = new StringBuilder(len + 32);
                            SendMessage(hChild, WM_GETTEXT, (IntPtr)(len + 32), sbChild);
                            string txt = sbChild.ToString().Trim();
                            if (txt.Length > 0) {
                                sbAll.AppendLine(txt);
                            }
                        }
                        return true;
                    }, IntPtr.Zero);

                    found = new WindowDetails {
                        Handle = hWnd,
                        Title = title,
                        ClassName = sbClass.ToString(),
                        Text = sbAll.ToString()
                    };
                    return false;
                }
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static bool HasGameViewportStarted(uint targetPid) {
        bool started = false;
        EnumWindows((hWnd, lParam) => {
            uint procId;
            GetWindowThreadProcessId(hWnd, out procId);
            if (procId == targetPid) {
                var sbClass = new StringBuilder(256);
                GetClassName(hWnd, sbClass, 256);
                string cls = sbClass.ToString();

                var sbTitle = new StringBuilder(512);
                GetWindowText(hWnd, sbTitle, 512);
                string title = sbTitle.ToString();

                if (cls.Equals("W2ViewportClass", StringComparison.OrdinalIgnoreCase) ||
                    (title.Equals("The Witcher 3", StringComparison.OrdinalIgnoreCase) && IsWindowVisible(hWnd))) {
                    started = true;
                    return false;
                }
            }
            return true;
        }, IntPtr.Zero);
        return started;
    }
}
'@

if (-not ([System.Management.Automation.PSTypeName]'WinWatcherEngine').Type) {
    Add-Type -TypeDefinition $csharpCode
}

#$psi = New-Object System.Diagnostics.ProcessStartInfo
#$psi.FileName = $exePath
#$psi.WorkingDirectory = (Split-Path $exePath -Parent)
#$psi.UseShellExecute = $true
# Ścieżka do pliku wynikowego kompilatora REDengine
$cacheScriptFile = Join-Path $GameDir "content\content0\x64.final.redscripts"
if (Test-Path $cacheScriptFile) {
    Remove-Item -LiteralPath $cacheScriptFile -Force -ErrorAction SilentlyContinue
}
$startTimestamp = (Get-Date).ToUniversalTime()

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
$psi.WorkingDirectory = (Split-Path $exePath -Parent)
$psi.Arguments = "-nosound -nohwcursor -window -res=320x200"
$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
$psi.UseShellExecute = $true

$proc = [System.Diagnostics.Process]::Start($psi)
$targetPid = $proc.Id
Write-Host "Uruchomiono proces witcher3.exe (PID: $targetPid). Trwa weryfikacja kompilacji..." -ForegroundColor Yellow

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$resultCode = -1

try {
    while ($sw.Elapsed.TotalSeconds -lt$TimeoutSeconds) {
        Start-Sleep -Milliseconds 150

        if ($proc.HasExited) {
            Write-Host "Proces gry zakonczyl dzialanie przedwczesnie (ExitCode: $($proc.ExitCode))."
            break
        }

        # 1. Sprawdz czy jest okno bledu kompilacji (WinAPI)
        $errWin = [WinWatcherEngine]::FindErrorWindow($targetPid)
        if ($errWin) {
            # Daj 100ms na pelne wyrenderowanie tekstu w kontrolkach potomnych
            Start-Sleep -Milliseconds 100
            $errWin = [WinWatcherEngine]::FindErrorWindow($targetPid)
            Write-Host "`n========================================================" -ForegroundColor Red
            Write-Host "[!] WYKRYTO BLAD KOMPILACJI SKRYPTOW W SILNIKU GRY:" -ForegroundColor Red
            Write-Host "Tytul okna: $($errWin.Title)" -ForegroundColor Yellow
            Write-Host "Tresc bledow z kompilatora:" -ForegroundColor Red
            Write-Host $errWin.Text -ForegroundColor Red
            Write-Host "========================================================`n" -ForegroundColor Red
            $resultCode = 1
            break
        }

        # 2. SZYBKI SUKCES (HEADLESS): Silnik zapisal skompilowany x64.final.redscripts
        # Następuje to ZANIM gra zdąży otworzyć okno DirectX 12 (W2ViewportClass)!
        # UWAGA: plik jest zapisywany inkrementalnie — deklarujemy sukces dopiero gdy
        # rozmiar przestanie rosnąć I silnik zwolni uchwyt (inaczej zostawiamy obcięty
        # cache, który crashuje grę 0xc0000005 przy starcie!).
        if (Test-Path $cacheScriptFile) {
            $fileItem = Get-Item -LiteralPath $cacheScriptFile -ErrorAction SilentlyContinue
            if ($fileItem -and $fileItem.Length -gt 0 -and $fileItem.LastWriteTimeUtc -ge $startTimestamp) {
                if (-not $cachePrevSize -or $fileItem.Length -ne $cachePrevSize) {
                    $cachePrevSize = $fileItem.Length
                    $cacheStablePolls = 0
                } else {
                    $cacheStablePolls++
                }
                if ($cacheStablePolls -ge 6) {
                    # Rozmiar stabilny przez ~900ms — sprawdz czy silnik zwolnil uchwyt
                    $handleFree = $false
                    try {
                        $fs = [System.IO.File]::Open($cacheScriptFile, 'Open', 'ReadWrite', 'None')
                        $fs.Close()
                        $handleFree = $true
                    } catch { }
                    if ($handleFree) {
                        $elapsedSec = [math]::Round($sw.Elapsed.TotalSeconds, 2)
                        Write-Host "`n========================================================" -ForegroundColor Green
                        Write-Host "[OK] KOMPILACJA ZAKONCZONA SUKCESEM w ${elapsedSec}s (HEADLESS)!" -ForegroundColor Green
                        Write-Host "Wygenerowano bytecode: x64.final.redscripts ($($fileItem.Length) B) przed startem GPU." -ForegroundColor Green
                        Write-Host "========================================================`n" -ForegroundColor Green
                        $resultCode = 0
                        break
                    }
                }
            }
        }

        # 3. Fallback: Sprawdz czy gra weszla do viewportu (gdyby cache nie wymusil zapisu)
        if ([WinWatcherEngine]::HasGameViewportStarted($targetPid)) {
            $elapsedSec = [math]::Round($sw.Elapsed.TotalSeconds, 2)
            Write-Host "`n========================================================" -ForegroundColor Green
            Write-Host "[OK] KOMPILACJA ZAKONCZONA W 100% SUKCESEM w ${elapsedSec}s (0 BLEDOW)!" -ForegroundColor Green
            Write-Host "Silnik gry pomyslnie skompilowal wszystkie skrypty i zainicjalizowal W2ViewportClass." -ForegroundColor Green
            Write-Host "========================================================`n" -ForegroundColor Green
            $resultCode = 0
            break
        }
    }
}
finally {
    Write-Host "Zamykanie instancji testowej witcher3.exe (PID: $targetPid)..."
    Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
    # Poczekaj chwile na zwolnienie pamieci i uchwytow
    Start-Sleep -Milliseconds 500
}

if ($resultCode -eq 0) {
    exit 0
}
elseif ($resultCode -eq 1) {
    exit 1
}
else {
    Write-Warning "Przekroczono limit czasu ($TimeoutSeconds s) bez jednoznacznego statusu."
    exit 2
}
