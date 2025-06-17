Import-Module "$PSScriptRoot\SharedLibrary.psm1"

Set-RTSS-Frame-Limit -configFilePath "$env:USERPROFILE\scoop\persist\rtss\Profiles\Global" -newLimit 0

& "$env:ProgramData\chocolatey\bin\MonitorSwitcher.exe" -load:"$env:APPDATA\MonitorSwitcher\Profiles\Ultrawide.xml"
& "$env:ProgramFiles (x86)\Steam\steam.exe" -start steam://close/bigpicture

Start-Sleep 3
& "$env:ProgramFiles\LGTV Companion\LGTV Companion.exe" -of -screenoff -sethdmi1 Device1 "Living Room"

& "$env:USERPROFILE\scoop\shims\autohotkey.exe" .\desktop.ahk
& "$env:LOCALAPPDATA\Playnite\Playnite.DesktopApp.exe"
