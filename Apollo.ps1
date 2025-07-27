# Apollo.ps1
# Apollo script: launches Playnite and/or Steam Big Picture based on -Mode argument

param(
    [ValidateSet("Playnite", "Steam")]
    [string]$Mode = "Playnite"
)

if ($Mode -eq "Playnite") {
    Start-Process "$env:ProgramFiles (x86)\Steam\steam.exe" -ArgumentList "-start steam://open/bigpicture"
    Start-Sleep -Seconds 5

    $steamWindow = Get-Process | Where-Object { $_.MainWindowTitle -like "*Steam*" } | Select-Object -First 1
    if ($steamWindow) {
        Add-Type '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);' -Name Win32 -Namespace Native
        $hwnd = $steamWindow.MainWindowHandle
        [Native.Win32]::ShowWindowAsync($hwnd, 6)  # 6 = Minimize
    }

    & "$env:LOCALAPPDATA\Playnite\Playnite.FullscreenApp.exe"
    Start-Sleep -Seconds 10
    nircmd.exe win activate process "Playnite.FullscreenApp.exe"
} elseif ($Mode -eq "Steam") {
    Start-Process "$env:ProgramFiles (x86)\Steam\steam.exe" -ArgumentList "-start steam://open/bigpicture"
}
