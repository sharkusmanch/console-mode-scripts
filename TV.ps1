Import-Module "$PSScriptRoot\SharedLibrary.psm1"

& 'C:\Program Files\LGTV Companion\LGTV Companion.exe' -of -poweron Device1 "Living Room"

Start-Sleep -Seconds 5

& "$env:ProgramFiles\LGTV Companion\LGTV Companion.exe" -screenon Device1 "Living Room" -sethdmi1

& "$env:USERPROFILE\scoop\apps\SoundVolumeView\current\SoundVolumeView.exe" /SetDefault "3- A50 Game" 3

& "$env:ProgramData\chocolatey\bin\MonitorSwitcher.exe" -load:"$env:APPDATA\MonitorSwitcher\Profiles\TV.xml"

Set-RTSS-Frame-Limit -configFilePath "$env:USERPROFILE\scoop\persist\rtss\Profiles\Global" -newLimit 120
Start-Process "$env:ProgramFiles (x86)\Steam\steam.exe" -ArgumentList "-start steam://open/bigpicture"
