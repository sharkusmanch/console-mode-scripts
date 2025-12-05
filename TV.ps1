Import-Module "$PSScriptRoot\SharedLibrary.psm1"

Write-ConsoleLog "TV mode switch initiated"
$Frontend = Get-ConsoleFrontend

try {
    # Get initial display count
    Add-Type -AssemblyName System.Windows.Forms
    $initialDisplayCount = [System.Windows.Forms.Screen]::AllScreens.Count
    Write-ConsoleLog "Initial display count: $initialDisplayCount"

    # Send WOL packet first via Wi-Fi interface (TV is on different VLAN)
    $tvMac = "DC:03:98:2C:FE:76"
    $localIP = "192.168.12.117"
    & "$PSScriptRoot\SendWol.ps1" -MacAddress $tvMac -LocalIP $localIP
    Start-Sleep -Seconds 2

    # Then send LGTV Companion commands
    & "$env:ProgramFiles\LGTV Companion\LGTV Companion.exe" -poweron Device1 "Living Room"
    Start-Sleep -Seconds 2
    & "$env:ProgramFiles\LGTV Companion\LGTV Companion.exe" -screenon Device1 "Living Room" -sethdmi1

    & "$env:USERPROFILE\scoop\apps\SoundVolumeView\current\SoundVolumeView.exe" /SetDefault "3- A50 Game" 3

    # Wait for TV to be detected as a display (up to 30 seconds)
    $tvTimeout = 30
    $tvElapsed = 0
    $tvDetected = $false

    Write-ConsoleLog "Waiting for TV display to be detected..."
    while ($tvElapsed -lt $tvTimeout) {
        Start-Sleep -Seconds 2
        $tvElapsed += 2
        $currentDisplayCount = [System.Windows.Forms.Screen]::AllScreens.Count

        if ($currentDisplayCount -gt $initialDisplayCount) {
            $tvDetected = $true
            Write-ConsoleLog "TV detected as display after ${tvElapsed}s (displays: $currentDisplayCount)"
            # Give it a moment to stabilize
            Start-Sleep -Seconds 2
            break
        }
    }

    if (-not $tvDetected) {
        Write-ConsoleLog "TV not detected as new display after ${tvTimeout}s, proceeding anyway" -Level WARN
    }

    Set-RTSS-Frame-Limit -configFilePath "$env:USERPROFILE\scoop\persist\rtss\Profiles\Global" -newLimit 120

    $profileSwitched = Switch-MonitorProfile -ProfileName "TV" -MaxRetries 3 -RetryDelaySeconds 2
    if (-not $profileSwitched) {
        Write-ConsoleLog "Monitor profile switch failed after retries" -Level ERROR
    }

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
