# Console Mode Scripts

Scripts for switching between TV/console gaming mode and desktop/ultrawide mode on Windows.

## Features

- Switch display profiles (TV vs Ultrawide monitor)
- Control LG TV power state via LGTV Companion
- Switch audio output devices
- Manage RTSS frame rate limits
- Launch/manage Playnite or Steam Big Picture

## Hotkeys

| Hotkey | Action |
|--------|--------|
| `Ctrl+Shift+Alt+T` | Switch to TV/console mode |
| `Ctrl+Shift+Alt+F` | Switch to ultrawide/desktop mode |
| `Ctrl+Shift+Alt+Q` | Exit hotkey daemon |

## Installation

Install the hotkey daemon as a scheduled task:

```powershell
.\Install-HotkeyService.ps1
```

This creates a scheduled task that:
- Starts automatically at logon
- Restarts on session unlock (survives hibernate/wake)
- Runs hidden in the background

### Manual Control

```powershell
# Start the daemon
Start-ScheduledTask -TaskName 'HotkeyDaemon'

# Stop the daemon
Stop-ScheduledTask -TaskName 'HotkeyDaemon'

# Uninstall
.\Install-HotkeyService.ps1 -Uninstall
```

## Scripts

| Script | Description |
|--------|-------------|
| `TV.ps1` | Switch to TV mode - powers on LG TV, sets audio to A50, caps framerate to 120, loads TV monitor profile, launches Playnite/Steam BP |
| `Ultrawide.ps1` | Switch to desktop mode - uncaps framerate, loads ultrawide profile, closes Big Picture, powers off TV |
| `Apollo.ps1` | Launch frontend (Playnite or Steam BP) for streaming |
| `hotkeys.ps1` | Global hotkey daemon using Win32 RegisterHotKey |
| `playnite_post_game.ps1` | Re-focus Playnite after exiting a game |
| `SharedLibrary.psm1` | Shared functions (RTSS config, frontend selection) |

## Configuration

Frontend preference (Playnite or Steam) is stored in:
```
%APPDATA%\ConsoleModeScripts\config.json
```

Set via PowerShell:
```powershell
Import-Module .\SharedLibrary.psm1
Set-ConsoleFrontend -Frontend 'Playnite'  # or 'Steam'
```

## Dependencies

- [LGTV Companion](https://github.com/JPersson77/LGTVCompanion) - LG TV control
- [MonitorSwitcher](https://www.monitorswitcher.com/) - Display profile switching
- [SoundVolumeView](https://www.nirsoft.net/utils/sound_volume_view.html) - Audio device switching
- [RTSS](https://www.guru3d.com/files-details/rtss-rivatuner-statistics-server-download.html) - Frame rate limiting
- [nircmd](https://www.nirsoft.net/utils/nircmd.html) - Window management
