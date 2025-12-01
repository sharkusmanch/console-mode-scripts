# Console Mode Scripts

Scripts for switching between TV/console gaming mode and desktop/ultrawide mode on Windows.

## Features

- Switch display profiles (TV vs Ultrawide monitor)
- Control LG TV power state via LGTV Companion
- Switch audio output devices
- Manage RTSS frame rate limits
- Launch/manage Playnite or Steam Big Picture
- System tray icon with right-click menu
- Toast notifications on mode switch
- Configurable hotkeys
- Error logging

## Hotkeys (Default)

| Hotkey | Action |
|--------|--------|
| `Ctrl+Shift+Alt+T` | Switch to TV/console mode |
| `Ctrl+Shift+Alt+F` | Switch to ultrawide/desktop mode |
| `Ctrl+Shift+Alt+Q` | Exit hotkey daemon |

Hotkeys can be customized in the config file (see Configuration section).

## Installation

Install the hotkey daemon as a scheduled task:

```powershell
.\Install-HotkeyService.ps1
```

This creates a scheduled task that:
- Starts automatically at logon
- Restarts on session unlock (survives hibernate/wake)
- Runs hidden in the background
- Shows a system tray icon

### Manual Control

```powershell
# Start the daemon
Start-ScheduledTask -TaskName 'HotkeyDaemon'

# Stop the daemon
Stop-ScheduledTask -TaskName 'HotkeyDaemon'

# Check status
.\Status.ps1

# Uninstall
.\Install-HotkeyService.ps1 -Uninstall
```

## System Tray

When running, the daemon shows a green icon in the system tray. Right-click for:
- Status indicator
- Manual TV/Ultrawide mode triggers
- Open log file
- Open config file
- Exit

## Scripts

| Script | Description |
|--------|-------------|
| `hotkeys.ps1` | Global hotkey daemon with system tray |
| `TV.ps1` | Switch to TV mode - powers on LG TV, sets audio, caps framerate, loads TV profile, launches frontend |
| `Ultrawide.ps1` | Switch to desktop mode - uncaps framerate, loads ultrawide profile, powers off TV |
| `Apollo.ps1` | Launch frontend (Playnite or Steam BP) for streaming |
| `playnite_post_game.ps1` | Re-focus Playnite after exiting a game |
| `Status.ps1` | Display daemon status, config, and recent logs |
| `Install-HotkeyService.ps1` | Install/uninstall the scheduled task |
| `SharedLibrary.psm1` | Shared functions (window management, logging, config, notifications) |

## Configuration

Configuration is stored in:
```
%APPDATA%\ConsoleModeScripts\config.json
```

### Example config.json

```json
{
  "Frontend": "Playnite",
  "Hotkeys": {
    "TV": { "Modifiers": ["Ctrl", "Shift", "Alt"], "Key": "T" },
    "Ultrawide": { "Modifiers": ["Ctrl", "Shift", "Alt"], "Key": "F" },
    "Quit": { "Modifiers": ["Ctrl", "Shift", "Alt"], "Key": "Q" }
  }
}
```

### Available Modifiers
- `Ctrl` (or `Control`)
- `Shift`
- `Alt`
- `Win`

### Set Frontend via PowerShell

```powershell
Import-Module .\SharedLibrary.psm1
Set-ConsoleFrontend -Frontend 'Playnite'  # or 'Steam'
```

## Logging

Logs are written to:
```
%APPDATA%\ConsoleModeScripts\daemon.log
```

View logs via:
- Right-click tray icon > Open Log File
- Run `.\Status.ps1`
- Open the file directly

## Dependencies

- [LGTV Companion](https://github.com/JPersson77/LGTVCompanion) - LG TV control
- [MonitorSwitcher](https://www.monitorswitcher.com/) - Display profile switching
- [SoundVolumeView](https://www.nirsoft.net/utils/sound_volume_view.html) - Audio device switching
- [RTSS](https://www.guru3d.com/files-details/rtss-rivatuner-statistics-server-download.html) - Frame rate limiting
- [nircmd](https://www.nirsoft.net/utils/nircmd.html) - Window management

## Troubleshooting

### Hotkeys not working
1. Run `.\Status.ps1` to check if daemon is running
2. Check the log file for errors
3. Ensure no other app has registered the same hotkeys
4. Restart the daemon: `Stop-ScheduledTask -TaskName 'HotkeyDaemon'; Start-ScheduledTask -TaskName 'HotkeyDaemon'`

### Daemon not starting after hibernate
The scheduled task has a session unlock trigger that should restart it. If issues persist:
1. Check Task Scheduler for errors
2. Manually start: `Start-ScheduledTask -TaskName 'HotkeyDaemon'`

### Toast notifications not showing
Windows toast notifications require the app to be registered. If notifications fail, they're silently logged instead.
