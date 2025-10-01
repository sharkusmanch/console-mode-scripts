Import-Module "$PSScriptRoot\SharedLibrary.psm1"

$Frontend = Get-ConsoleFrontend

# Try multiple power-on commands in case one fails
& "$env:ProgramFiles\LGTV Companion\LGTV Companion.exe" -poweron Device1 "Living Room"
Start-Sleep -Seconds 2
& "$env:ProgramFiles\LGTV Companion\LGTV Companion.exe" -screenon Device1 "Living Room" -sethdmi1

& "$env:USERPROFILE\scoop\apps\SoundVolumeView\current\SoundVolumeView.exe" /SetDefault "3- A50 Game" 3

Start-Sleep -Seconds 3

Set-RTSS-Frame-Limit -configFilePath "$env:USERPROFILE\scoop\persist\rtss\Profiles\Global" -newLimit 120

& "$env:ProgramData\chocolatey\bin\MonitorSwitcher.exe" -load:"$env:APPDATA\MonitorSwitcher\Profiles\TV.xml"

if ($Frontend -eq "Playnite") {
    # Start Playnite first since it takes longer to load
    & "$env:LOCALAPPDATA\Playnite\Playnite.FullscreenApp.exe"

    # While Playnite is starting, launch Steam Big Picture
    Start-Process "$env:ProgramFiles (x86)\Steam\steam.exe" -ArgumentList "-start steam://open/bigpicture"
    Start-Sleep -Seconds 5

    $steamWindow = Get-Process | Where-Object { $_.MainWindowTitle -like "*Steam*" } | Select-Object -First 1
    if ($steamWindow) {
        Add-Type '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);' -Name Win32 -Namespace Native
        $hwnd = $steamWindow.MainWindowHandle
        [Native.Win32]::ShowWindowAsync($hwnd, 6)  # 6 = Minimize
    }

    # Wait for Playnite to be ready, then focus it
    $timeout = 30  # Maximum wait time in seconds
    $elapsed = 0
    do {
        Start-Sleep -Seconds 1
        $elapsed++
        $playniteProcess = Get-Process -Name "Playnite.FullscreenApp" -ErrorAction SilentlyContinue
    } while (-not $playniteProcess -and $elapsed -lt $timeout)

    if ($playniteProcess) {
        # Give it one more second to fully initialize the window
        Start-Sleep -Seconds 1
        nircmd.exe win activate process "Playnite.FullscreenApp.exe"
    } else {
        Write-Host "Warning: Playnite did not start within $timeout seconds"
    }
} elseif ($Frontend -eq "Steam") {
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
