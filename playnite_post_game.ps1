Import-Module "$PSScriptRoot\SharedLibrary.psm1"
if ((Get-ConsoleMode) -ne 'Playnite') { return }

Write-ConsoleLog "Post-game Playnite refocus initiated"

try {
    Minimize-SteamWindow

    Start-Sleep -Seconds 10

    # Check which Playnite app is running and focus it
    $fullscreenProcess = Get-Process -Name "Playnite.FullscreenApp" -ErrorAction SilentlyContinue
    $desktopProcess = Get-Process -Name "Playnite.DesktopApp" -ErrorAction SilentlyContinue

    if ($fullscreenProcess) {
        # Focus Fullscreen App
        $focused = $false
        try {
            nircmd.exe win activate process "Playnite.FullscreenApp.exe"
            $focused = $true
        } catch {
            $focused = Set-WindowForeground -Handle $fullscreenProcess.MainWindowHandle
        }
        if ($focused) {
            Write-ConsoleLog "Focused Playnite Fullscreen"
        }
    } elseif ($desktopProcess) {
        # Focus Desktop App
        $focused = $false
        try {
            nircmd.exe win activate process "Playnite.DesktopApp.exe"
            $focused = $true
        } catch {
            $focused = Set-WindowForeground -Handle $desktopProcess.MainWindowHandle
        }
        if ($focused) {
            Write-ConsoleLog "Focused Playnite Desktop"
        }
    } else {
        # Neither is running, try to start Desktop App as fallback
        Write-ConsoleLog "No Playnite process found, starting Desktop App" -Level WARN
        try {
            Start-Process "Playnite.DesktopApp.exe"
        } catch {
            Start-Process "$env:LOCALAPPDATA\Playnite\Playnite.DesktopApp.exe"
        }
    }
} catch {
    Write-ConsoleLog "Post-game refocus failed: $_" -Level ERROR
}
