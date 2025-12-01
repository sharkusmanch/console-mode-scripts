Import-Module "$PSScriptRoot\SharedLibrary.psm1"

Write-ConsoleLog "TV mode switch initiated"
$Frontend = Get-ConsoleFrontend

try {
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

        Minimize-SteamWindow

        # Wait for Playnite to be ready, then focus it
        $timeout = 30
        $elapsed = 0
        do {
            Start-Sleep -Seconds 1
            $elapsed++
            $playniteProcess = Get-Process -Name "Playnite.FullscreenApp" -ErrorAction SilentlyContinue
        } while (-not $playniteProcess -and $elapsed -lt $timeout)

        if ($playniteProcess) {
            Start-Sleep -Seconds 1
            nircmd.exe win activate process "Playnite.FullscreenApp.exe"
        } else {
            Write-ConsoleLog "Playnite did not start within $timeout seconds" -Level WARN
        }
    } elseif ($Frontend -eq "Steam") {
        Start-Process "$env:ProgramFiles (x86)\Steam\steam.exe" -ArgumentList "-start steam://open/bigpicture"
        Start-Sleep -Seconds 5
        Maximize-SteamWindow
        nircmd.exe win activate process "steam.exe"
    }

    Show-ConsoleToast -Title "TV Mode" -Message "Switched to TV mode ($Frontend)"
    Write-ConsoleLog "TV mode switch completed successfully"
} catch {
    Write-ConsoleLog "TV mode switch failed: $_" -Level ERROR
    Show-ConsoleToast -Title "TV Mode" -Message "Switch failed - check logs"
}
