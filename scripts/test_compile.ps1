param(
    [string]$GameDir = "G:\GOG Galaxy\Games\The Witcher 3 Wild Hunt GOTY",
    [int]$TimeoutSeconds = 45,
    [switch]$SkipPrecheck
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

# Zamknij istniejace procesy gry
Get-Process -Name "witcher3" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 600

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

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
$psi.WorkingDirectory = (Split-Path $exePath -Parent)
$psi.UseShellExecute = $true

$proc = [System.Diagnostics.Process]::Start($psi)
$targetPid = $proc.Id
Write-Host "Uruchomiono proces witcher3.exe (PID: $targetPid). Trwa weryfikacja kompilacji..." -ForegroundColor Yellow

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$resultCode = -1

try {
    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        Start-Sleep -Milliseconds 400

        if ($proc.HasExited) {
            Write-Host "Proces gry zakonczyl dzialanie przedwczesnie (ExitCode: $($proc.ExitCode))."
            break
        }

        # 1. Sprawdz czy jest okno bledu kompilacji
        $errWin = [WinWatcherEngine]::FindErrorWindow($targetPid)
        if ($errWin) {
            Write-Host "`n========================================================" -ForegroundColor Red
            Write-Host "[!] WYKRYTO BLAD KOMPILACJI SKRYPTOW W SILNIKU GRY:" -ForegroundColor Red
            Write-Host "Tytul okna: $($errWin.Title)" -ForegroundColor Yellow
            Write-Host "Tresc bledow z kompilatora:" -ForegroundColor Red
            Write-Host $errWin.Text -ForegroundColor Red
            Write-Host "========================================================`n" -ForegroundColor Red
            $resultCode = 1
            break
        }

        # 2. Sprawdz czy gra weszla do viewportu (W2ViewportClass) - oznacza to pelny sukces kompilacji
        if ([WinWatcherEngine]::HasGameViewportStarted($targetPid)) {
            Write-Host "`n========================================================" -ForegroundColor Green
            Write-Host "[OK] KOMPILACJA ZAKONCZONA W 100% SUKCESEM (0 BLEDOW)!" -ForegroundColor Green
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
