# Console Mode Scripts

Scripts for switching between TV/console gaming mode and desktop/ultrawide mode on Windows.

## Features

- Switch display profiles (TV vs Ultrawide monitor)
- Control LG TV power state via LGTV Companion
- Switch audio output devices
- Manage RTSS frame rate limits
- Launch/manage Playnite or Steam Big Picture
- System tray icon with controller status indicator
- Toast notifications on mode switch
- Configurable hotkeys
- Controller auto-detection (triggers TV mode when controller connects)
- Single-instance enforcement (prevents duplicate daemons)
- Dependency validation on startup
- Error logging

## Hotkeys (Default)

| Hotkey | Action |
|--------|--------|
| `Ctrl+Shift+Alt+T` | Switch to TV/console mode |
| `Ctrl+Shift+Alt+F` | Switch to ultrawide/desktop mode |
| `Ctrl+Shift+Alt+Q` | Exit daemon |

Hotkeys can be customized in the config file (see Configuration section).

## Installation

Install the combined daemon (hotkeys + controller monitoring) as a scheduled task:

```powershell
.\ConsoleDaemon.ps1 -Install
Start-ScheduledTask -TaskName 'ConsoleDaemon'
```

This creates a scheduled task that:
- Starts automatically at logon
- Restarts on session unlock (survives hibernate/wake)
- Runs hidden in the background
- Shows a system tray icon with controller status

### Manual Control

```powershell
# Start the daemon
Start-ScheduledTask -TaskName 'ConsoleDaemon'

# Stop the daemon
Stop-ScheduledTask -TaskName 'ConsoleDaemon'

# Check status
.\Status.ps1

# Uninstall
.\ConsoleDaemon.ps1 -Uninstall
```

## System Tray

When running, the daemon shows a green icon in the system tray:
- **Green square** = Running, controller disconnected
- **Green square + blue dot** = Running, controller connected

Right-click menu:
- Status indicator
- Controller connection status
- Manual TV/Ultrawide mode triggers
- Open log file
- Open config file
- Exit

## Scripts

| Script | Description |
|--------|-------------|
| `ConsoleDaemon.ps1` | Combined daemon with hotkeys, controller monitoring, and tray icon |
| `TV.ps1` | Switch to TV mode - powers on LG TV, waits for display, sets audio, caps framerate, launches frontend |
| `Ultrawide.ps1` | Switch to desktop mode - uncaps framerate, loads ultrawide profile, powers off TV |
| `Apollo.ps1` | Launch frontend (Playnite or Steam BP) for streaming |
| `playnite_post_game.ps1` | Re-focus Playnite after exiting a game |
| `Status.ps1` | Display daemon status, config, and recent logs |
| `SharedLibrary.psm1` | Shared functions (window management, logging, config, validation) |

### Legacy Scripts

These are kept for backward compatibility but `ConsoleDaemon.ps1` is recommended:

| Script | Description |
|--------|-------------|
| `hotkeys.ps1` | Standalone hotkey daemon |
| `ControllerMonitor.ps1` | Standalone controller monitor |
| `Install-HotkeyService.ps1` | Legacy installer for hotkeys.ps1 |

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
  },
  "ControllerVidPid": "054C*0DF2",
  "ControllerDebounceSeconds": 30,
  "ControllerPollSeconds": 3,
  "ControllerEnabled": true
}
```

### Available Modifiers
- `Ctrl` (or `Control`)
- `Shift`
- `Alt`
- `Win`

### Controller Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `ControllerVidPid` | VID/PID pattern to match | `054C*0DF2` |
| `ControllerDebounceSeconds` | Cooldown between triggers | `30` |
| `ControllerPollSeconds` | Polling interval | `3` |
| `ControllerEnabled` | Enable/disable monitoring | `true` |

Common controller VID/PIDs:
- DualSense Edge: `054C*0DF2`
- DualSense: `054C*0CE6`
- Xbox Wireless: `045E*02E0`

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

Missing dependencies are logged as warnings on startup.

## Troubleshooting

### Hotkeys not working
1. Run `.\Status.ps1` to check if daemon is running
2. Check the log file for errors
3. Ensure no other app has registered the same hotkeys
4. Restart the daemon: `Stop-ScheduledTask -TaskName 'ConsoleDaemon'; Start-ScheduledTask -TaskName 'ConsoleDaemon'`

### Daemon not starting after hibernate
The scheduled task has a session unlock trigger that should restart it. If issues persist:
1. Check Task Scheduler for errors
2. Manually start: `Start-ScheduledTask -TaskName 'ConsoleDaemon'`

### Controller not detected
1. Check the VID/PID in config matches your controller
2. Run `.\Status.ps1` to see controller status
3. Check log file for controller monitoring messages

### TV display switch fails
The script waits up to 30 seconds for the TV to be detected as a display before switching profiles. If your TV takes longer to wake, check the logs for timing info.

### Toast notifications not showing
Windows toast notifications require the app to be registered. If notifications fail, they're silently logged instead.
