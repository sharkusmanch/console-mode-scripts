Import-Module "$PSScriptRoot\SharedLibrary.psm1"

Write-ConsoleLog "Ultrawide mode switch initiated"
$Frontend = Get-ConsoleFrontend

try {
    Set-RTSS-Frame-Limit -configFilePath "$env:USERPROFILE\scoop\persist\rtss\Profiles\Global" -newLimit 0

    $profileSwitched = Switch-MonitorProfile -ProfileName "Ultrawide" -MaxRetries 3 -RetryDelaySeconds 2
    if (-not $profileSwitched) {
        Write-ConsoleLog "Monitor profile switch failed after retries" -Level ERROR
    }
    & "$env:ProgramFiles (x86)\Steam\steam.exe" -start steam://close/bigpicture

    Start-Sleep 3
    & "$env:ProgramFiles\LGTV Companion\LGTV Companion.exe" -of -poweroff -sethdmi1 Device1 "Living Room"

    # Send Win+D to show desktop
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait("^{ESC}")
    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.SendKeys]::SendWait("d")

    if ($Frontend -eq "Playnite") {
        & "$env:LOCALAPPDATA\Playnite\Playnite.DesktopApp.exe"
    }

    Show-ConsoleToast -Title "Desktop Mode" -Message "Switched to ultrawide mode"
    Write-ConsoleLog "Ultrawide mode switch completed successfully"
} catch {
    Write-ConsoleLog "Ultrawide mode switch failed: $_" -Level ERROR
    Show-ConsoleToast -Title "Desktop Mode" -Message "Switch failed - check logs"
}
