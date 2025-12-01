Import-Module "$PSScriptRoot\SharedLibrary.psm1"
if ((Get-ConsoleMode) -ne 'Playnite') { return }

$steamWindow = Get-Process | Where-Object { $_.MainWindowTitle -like "*Steam*" } | Select-Object -First 1
if ($steamWindow) {
    Add-Type '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);' -Name Win32 -Namespace Native
    $hwnd = $steamWindow.MainWindowHandle
    [Native.Win32]::ShowWindowAsync($hwnd, 6)  # 6 = Minimize
}

# & "$env:LOCALAPPDATA\Playnite\Playnite.FullscreenApp.exe"
Start-Sleep -Seconds 10

# Check which Playnite app is running and focus it
$fullscreenProcess = Get-Process -Name "Playnite.FullscreenApp" -ErrorAction SilentlyContinue
$desktopProcess = Get-Process -Name "Playnite.DesktopApp" -ErrorAction SilentlyContinue

if ($fullscreenProcess) {
    # Focus Fullscreen App
    try {
        nircmd.exe win activate process "Playnite.FullscreenApp.exe"
    }
    catch {
        Add-Type '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);' -Name Win32Focus -Namespace Native
        [Native.Win32Focus]::SetForegroundWindow($fullscreenProcess.MainWindowHandle)
    }
} elseif ($desktopProcess) {
    # Focus Desktop App
    try {
        nircmd.exe win activate process "Playnite.DesktopApp.exe"
    }
    catch {
        Add-Type '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);' -Name Win32Focus -Namespace Native
        [Native.Win32Focus]::SetForegroundWindow($desktopProcess.MainWindowHandle)
    }
} else {
    # Neither is running, try to start Desktop App as fallback
    try {
        Start-Process "Playnite.DesktopApp.exe"
    }
    catch {
        Start-Process "$env:LOCALAPPDATA\Playnite\Playnite.DesktopApp.exe"
    }
}
