# Apollo.ps1
# Apollo script: launches Playnite and/or Steam Big Picture based on global frontend config

Import-Module "$PSScriptRoot\SharedLibrary.psm1"

Write-ConsoleLog "Apollo frontend launch initiated"
$Frontend = Get-ConsoleFrontend

try {
    if ($Frontend -eq "Playnite") {
        Start-Process "$env:ProgramFiles (x86)\Steam\steam.exe" -ArgumentList "-start steam://open/bigpicture"
        Start-Sleep -Seconds 5

        Minimize-SteamWindow

        & "$env:LOCALAPPDATA\Playnite\Playnite.FullscreenApp.exe"
        Start-Sleep -Seconds 10
        nircmd.exe win activate process "Playnite.FullscreenApp.exe"
    } elseif ($Frontend -eq "Steam") {
        Start-Process "$env:ProgramFiles (x86)\Steam\steam.exe" -ArgumentList "-start steam://open/bigpicture"
    }

    Write-ConsoleLog "Apollo frontend launch completed ($Frontend)"
} catch {
    Write-ConsoleLog "Apollo frontend launch failed: $_" -Level ERROR
}
