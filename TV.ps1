param(
    [ValidateSet("Playnite", "Steam")]
    [string]$Mode = "Playnite"
)

Import-Module "$PSScriptRoot\SharedLibrary.psm1"
Set-RTSS-Frame-Limit -configFilePath "$env:USERPROFILE\scoop\persist\rtss\Profiles\Global" -newLimit 120

& "$env:ProgramFiles\LGTV Companion\LGTV Companion.exe" -screenon Device1 "Living Room" -sethdmi1

& "$env:USERPROFILE\scoop\apps\SoundVolumeView\current\SoundVolumeView.exe" /SetDefault "3- A50 Game" 3

& "$env:ProgramData\chocolatey\bin\MonitorSwitcher.exe" -load:"$env:APPDATA\MonitorSwitcher\Profiles\TV.xml"

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
    Start-Sleep -Seconds 5

    $steamWindow = Get-Process | Where-Object { $_.MainWindowTitle -like "*Steam*" } | Select-Object -First 1
    if ($steamWindow) {
        Add-Type '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);' -Name Win32 -Namespace Native
        $hwnd = $steamWindow.MainWindowHandle
        [Native.Win32]::ShowWindowAsync($hwnd, 3)  # 3 = Maximize
    }
    nircmd.exe win activate process "steam.exe"
}
