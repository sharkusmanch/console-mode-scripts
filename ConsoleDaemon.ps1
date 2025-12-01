# ConsoleDaemon.ps1
# Combined daemon for hotkeys and controller monitoring with system tray

param(
    [switch]$Install,
    [switch]$Uninstall
)

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

Import-Module (Join-Path $scriptDir "SharedLibrary.psm1") -Force

$taskName = 'ConsoleDaemon'

if ($Install) {
    # Remove existing tasks
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName 'HotkeyDaemon' -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName 'ControllerMonitor' -Confirm:$false -ErrorAction SilentlyContinue

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""

    $triggerLogon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -DontStopOnIdleEnd `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -MultipleInstances IgnoreNew

    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggerLogon -Settings $settings -Principal $principal -Description 'Console mode daemon - hotkeys and controller monitoring'

    # Add SessionUnlock trigger
    $taskService = New-Object -ComObject Schedule.Service
    $taskService.Connect()
    $task = $taskService.GetFolder('\').GetTask($taskName)
    $definition = $task.Definition
    $triggers = $definition.Triggers
    $unlockTrigger = $triggers.Create(11)
    $unlockTrigger.StateChange = 8
    $unlockTrigger.UserId = $env:USERNAME
    $unlockTrigger.Enabled = $true
    $taskService.GetFolder('\').RegisterTaskDefinition($taskName, $definition, 4, $null, $null, 3) | Out-Null

    Write-Host "Console daemon installed (replaces HotkeyDaemon and ControllerMonitor)"
    Write-Host "Start with: Start-ScheduledTask -TaskName '$taskName'"
    return
}

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Console daemon uninstalled."
    return
}

# ==========================
# Main Daemon
# ==========================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-ConsoleLog "Console daemon starting"

# Single instance check
if (-not (Enter-SingleInstance -Name "ConsoleDaemon")) {
    Write-ConsoleLog "Another instance is already running, exiting" -Level WARN
    exit 1
}

# Validate dependencies
Test-Dependencies | Out-Null
Test-MonitorProfiles | Out-Null

# Rotate logs on startup
Invoke-LogRotation -MaxLines 1000 -MaxSizeKB 1024

$tvScript = Join-Path $scriptDir "TV.ps1"
$uwScript = Join-Path $scriptDir "Ultrawide.ps1"

# ==========================
# Load Configuration
# ==========================

$hotkeyConfig = Get-HotkeyConfig

# Controller config
$configPath = Get-ConsoleConfigPath
$controllerVidPid = "054C*0DF2"
$controllerDebounce = 30
$controllerPollSeconds = 3
$controllerEnabled = $true

try {
    $cfg = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json
    if ($cfg.PSObject.Properties['ControllerVidPid']) {
        $controllerVidPid = $cfg.ControllerVidPid
    }
    if ($cfg.PSObject.Properties['ControllerDebounceSeconds']) {
        $controllerDebounce = [int]$cfg.ControllerDebounceSeconds
    }
    if ($cfg.PSObject.Properties['ControllerPollSeconds']) {
        $controllerPollSeconds = [int]$cfg.ControllerPollSeconds
    }
    if ($cfg.PSObject.Properties['ControllerEnabled']) {
        $controllerEnabled = [bool]$cfg.ControllerEnabled
    }
} catch {}

# ==========================
# Hotkey Setup
# ==========================

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class HotkeyNative {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
"@

$ModifierMap = @{
    'Alt' = 0x0001
    'Ctrl' = 0x0002
    'Control' = 0x0002
    'Shift' = 0x0004
    'Win' = 0x0008
}

$HOTKEY_TV = 1
$HOTKEY_UW = 2
$HOTKEY_QUIT = 99

function Get-ModifierValue {
    param([array]$Modifiers)
    $value = 0
    foreach ($mod in $Modifiers) {
        if ($ModifierMap.ContainsKey($mod)) {
            $value = $value -bor $ModifierMap[$mod]
        }
    }
    return $value
}

function Get-HotkeyDescription {
    param($Config)
    $mods = ($Config.Modifiers | ForEach-Object { $_ }) -join '+'
    return "$mods+$($Config.Key)"
}

$tvMods = Get-ModifierValue -Modifiers $hotkeyConfig.TV.Modifiers
$tvKey = [System.Windows.Forms.Keys]::($hotkeyConfig.TV.Key)
$uwMods = Get-ModifierValue -Modifiers $hotkeyConfig.Ultrawide.Modifiers
$uwKey = [System.Windows.Forms.Keys]::($hotkeyConfig.Ultrawide.Key)
$quitMods = Get-ModifierValue -Modifiers $hotkeyConfig.Quit.Modifiers
$quitKey = [System.Windows.Forms.Keys]::($hotkeyConfig.Quit.Key)

# ==========================
# Create Form and Tray Icon
# ==========================

$form = New-Object System.Windows.Forms.Form
$form.ShowInTaskbar = $false
$form.WindowState = 'Minimized'
$form.FormBorderStyle = 'None'
$form.Size = New-Object System.Drawing.Size(0, 0)
$form.Opacity = 0
$form.Text = "ConsoleDaemon"

# Create system tray icon
$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Visible = $true
$trayIcon.Text = "Console Mode Daemon"

# Create icon - green square with controller indicator
$bitmap = New-Object System.Drawing.Bitmap(16, 16)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.FillRectangle([System.Drawing.Brushes]::LimeGreen, 2, 2, 12, 12)
$graphics.DrawRectangle([System.Drawing.Pens]::DarkGreen, 2, 2, 11, 11)
$graphics.Dispose()
$trayIcon.Icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())

# Controller state tracking
$script:controllerConnected = $false
$script:lastTriggerTime = [DateTime]::MinValue

# Update tray icon based on controller state
function Update-TrayIcon {
    $bitmap = New-Object System.Drawing.Bitmap(16, 16)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    if ($script:controllerConnected) {
        # Green with blue dot = controller connected
        $graphics.FillRectangle([System.Drawing.Brushes]::LimeGreen, 2, 2, 12, 12)
        $graphics.DrawRectangle([System.Drawing.Pens]::DarkGreen, 2, 2, 11, 11)
        $graphics.FillEllipse([System.Drawing.Brushes]::DodgerBlue, 9, 9, 5, 5)
    } else {
        # Green = running, no controller
        $graphics.FillRectangle([System.Drawing.Brushes]::LimeGreen, 2, 2, 12, 12)
        $graphics.DrawRectangle([System.Drawing.Pens]::DarkGreen, 2, 2, 11, 11)
    }

    $graphics.Dispose()
    $trayIcon.Icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
}

# ==========================
# Context Menu
# ==========================

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$menuStatus = New-Object System.Windows.Forms.ToolStripMenuItem
$menuStatus.Text = "Status: Running"
$menuStatus.Enabled = $false
$contextMenu.Items.Add($menuStatus) | Out-Null

$menuController = New-Object System.Windows.Forms.ToolStripMenuItem
$menuController.Text = "Controller: Checking..."
$menuController.Enabled = $false
$contextMenu.Items.Add($menuController) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$menuTV = New-Object System.Windows.Forms.ToolStripMenuItem
$menuTV.Text = "TV Mode ($(Get-HotkeyDescription $hotkeyConfig.TV))"
$menuTV.Add_Click({ Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tvScript`"" -WindowStyle Hidden })
$contextMenu.Items.Add($menuTV) | Out-Null

$menuUW = New-Object System.Windows.Forms.ToolStripMenuItem
$menuUW.Text = "Ultrawide Mode ($(Get-HotkeyDescription $hotkeyConfig.Ultrawide))"
$menuUW.Add_Click({ Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$uwScript`"" -WindowStyle Hidden })
$contextMenu.Items.Add($menuUW) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$menuLogs = New-Object System.Windows.Forms.ToolStripMenuItem
$menuLogs.Text = "Open Log File"
$menuLogs.Add_Click({
    $logPath = Get-ConsoleLogPath
    if (Test-Path $logPath) {
        Start-Process notepad.exe -ArgumentList $logPath
    } else {
        [System.Windows.Forms.MessageBox]::Show("No log file found.", "Console Mode", "OK", "Information")
    }
})
$contextMenu.Items.Add($menuLogs) | Out-Null

$menuConfig = New-Object System.Windows.Forms.ToolStripMenuItem
$menuConfig.Text = "Open Config"
$menuConfig.Add_Click({
    $configPath = Get-ConsoleConfigPath
    Start-Process notepad.exe -ArgumentList $configPath
})
$contextMenu.Items.Add($menuConfig) | Out-Null

$menuReload = New-Object System.Windows.Forms.ToolStripMenuItem
$menuReload.Text = "Reload Config"
$menuReload.Add_Click({
    $script:configLastModified = $null  # Force reload on next check
    Write-ConsoleLog "Manual config reload requested"
})
$contextMenu.Items.Add($menuReload) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$menuExit = New-Object System.Windows.Forms.ToolStripMenuItem
$menuExit.Text = "Exit ($(Get-HotkeyDescription $hotkeyConfig.Quit))"
$menuExit.Add_Click({ $form.Close() })
$contextMenu.Items.Add($menuExit) | Out-Null

$trayIcon.ContextMenuStrip = $contextMenu

# ==========================
# Log Rotation Timer (hourly check)
# ==========================

$logRotationTimer = New-Object System.Windows.Forms.Timer
$logRotationTimer.Interval = 3600000  # 1 hour

$logRotationTimer.Add_Tick({
    Invoke-LogRotation -MaxLines 1000 -MaxSizeKB 1024
})

# ==========================
# Config File Watcher
# ==========================

$script:configLastModified = $null
$configCheckTimer = New-Object System.Windows.Forms.Timer
$configCheckTimer.Interval = 5000  # Check every 5 seconds

$configCheckTimer.Add_Tick({
    try {
        $cfgPath = Get-ConsoleConfigPath
        if (Test-Path $cfgPath) {
            $lastWrite = (Get-Item $cfgPath).LastWriteTime
            if ($null -eq $script:configLastModified) {
                $script:configLastModified = $lastWrite
            } elseif ($lastWrite -ne $script:configLastModified) {
                $script:configLastModified = $lastWrite
                Write-ConsoleLog "Config file changed, reloading..."

                # Reload controller config
                try {
                    $newCfg = Get-Content -LiteralPath $cfgPath -Raw -ErrorAction Stop | ConvertFrom-Json
                    if ($newCfg.PSObject.Properties['ControllerVidPid']) {
                        $script:controllerVidPid = $newCfg.ControllerVidPid
                    }
                    if ($newCfg.PSObject.Properties['ControllerDebounceSeconds']) {
                        $script:controllerDebounce = [int]$newCfg.ControllerDebounceSeconds
                    }
                    if ($newCfg.PSObject.Properties['ControllerPollSeconds']) {
                        $newPoll = [int]$newCfg.ControllerPollSeconds
                        if ($newPoll -ne $controllerPollSeconds) {
                            $controllerTimer.Interval = $newPoll * 1000
                        }
                    }
                    if ($newCfg.PSObject.Properties['ControllerEnabled']) {
                        $newEnabled = [bool]$newCfg.ControllerEnabled
                        if ($newEnabled -and -not $controllerTimer.Enabled) {
                            $controllerTimer.Start()
                            $menuController.Text = "Controller: Checking..."
                        } elseif (-not $newEnabled -and $controllerTimer.Enabled) {
                            $controllerTimer.Stop()
                            $menuController.Text = "Controller: Disabled"
                        }
                    }
                    Write-ConsoleLog "Config reloaded successfully"
                    Show-ConsoleToast -Title "Console Daemon" -Message "Configuration reloaded"
                } catch {
                    Write-ConsoleLog "Failed to reload config: $_" -Level ERROR
                }
            }
        }
    } catch {
        # Ignore file access errors during check
    }
})

# ==========================
# Controller Polling Timer
# ==========================

# Make controller config script-scoped for reload
$script:controllerVidPid = $controllerVidPid
$script:controllerDebounce = $controllerDebounce

$controllerTimer = New-Object System.Windows.Forms.Timer
$controllerTimer.Interval = $controllerPollSeconds * 1000

$controllerTimer.Add_Tick({
    try {
        $isConnected = Test-ControllerConnected -VidPid $script:controllerVidPid

        # Update menu text
        $menuController.Text = "Controller: $(if ($isConnected) { 'Connected' } else { 'Disconnected' })"

        # Detect connection event
        if ($isConnected -and -not $script:controllerConnected) {
            $now = Get-Date
            $elapsed = ($now - $script:lastTriggerTime).TotalSeconds

            if ($elapsed -ge $script:controllerDebounce) {
                $script:lastTriggerTime = $now
                Write-ConsoleLog "Controller connected - triggering TV mode"
                Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tvScript`"" -WindowStyle Hidden
            } else {
                Write-ConsoleLog "Controller connected but debounce active ($([int]$elapsed)s < $($script:controllerDebounce)s)"
            }
        }

        # Update state and icon
        if ($isConnected -ne $script:controllerConnected) {
            $script:controllerConnected = $isConnected
            Update-TrayIcon
        }
    } catch {
        Write-ConsoleLog "Controller poll error: $_" -Level ERROR
    }
})

# ==========================
# Form Events
# ==========================

$form.Add_Load({
    # Register hotkeys
    $r1 = [HotkeyNative]::RegisterHotKey($form.Handle, $HOTKEY_TV, $tvMods, [uint32]$tvKey)
    $r2 = [HotkeyNative]::RegisterHotKey($form.Handle, $HOTKEY_UW, $uwMods, [uint32]$uwKey)
    $r3 = [HotkeyNative]::RegisterHotKey($form.Handle, $HOTKEY_QUIT, $quitMods, [uint32]$quitKey)

    if (-not $r1) { Write-ConsoleLog "Failed to register TV hotkey" -Level ERROR }
    if (-not $r2) { Write-ConsoleLog "Failed to register Ultrawide hotkey" -Level ERROR }
    if (-not $r3) { Write-ConsoleLog "Failed to register Quit hotkey" -Level ERROR }

    if ($r1 -and $r2 -and $r3) {
        Write-ConsoleLog "All hotkeys registered successfully"
    }

    # Initial controller state
    $script:controllerConnected = Test-ControllerConnected -VidPid $controllerVidPid
    $menuController.Text = "Controller: $(if ($script:controllerConnected) { 'Connected' } else { 'Disconnected' })"
    Update-TrayIcon

    if ($controllerEnabled) {
        Write-ConsoleLog "Controller monitoring enabled (VID/PID: $controllerVidPid)"
        $controllerTimer.Start()
    } else {
        Write-ConsoleLog "Controller monitoring disabled"
        $menuController.Text = "Controller: Disabled"
    }

    # Start auxiliary timers
    $logRotationTimer.Start()
    $configCheckTimer.Start()

    Write-ConsoleLog "Console daemon ready"
})

$form.Add_FormClosing({
    Write-ConsoleLog "Console daemon shutting down"

    $controllerTimer.Stop()
    $logRotationTimer.Stop()
    $configCheckTimer.Stop()

    [HotkeyNative]::UnregisterHotKey($form.Handle, $HOTKEY_TV) | Out-Null
    [HotkeyNative]::UnregisterHotKey($form.Handle, $HOTKEY_UW) | Out-Null
    [HotkeyNative]::UnregisterHotKey($form.Handle, $HOTKEY_QUIT) | Out-Null

    $trayIcon.Visible = $false
    $trayIcon.Dispose()

    Exit-SingleInstance -Name "ConsoleDaemon"
})

# ==========================
# Message Filter for Hotkeys
# ==========================

$messageFilter = @"
using System;
using System.Windows.Forms;

public class HotkeyMessageFilter : IMessageFilter {
    public event Action<int> HotkeyPressed;
    private const int WM_HOTKEY = 0x0312;

    public bool PreFilterMessage(ref Message m) {
        if (m.Msg == WM_HOTKEY) {
            int id = m.WParam.ToInt32();
            if (HotkeyPressed != null) {
                HotkeyPressed(id);
            }
            return true;
        }
        return false;
    }
}
"@
Add-Type -ReferencedAssemblies 'System.Windows.Forms' -TypeDefinition $messageFilter

$filter = New-Object HotkeyMessageFilter
$filter.add_HotkeyPressed({
    param($id)
    switch ($id) {
        $HOTKEY_TV {
            Write-ConsoleLog "TV hotkey pressed"
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tvScript`"" -WindowStyle Hidden
        }
        $HOTKEY_UW {
            Write-ConsoleLog "Ultrawide hotkey pressed"
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$uwScript`"" -WindowStyle Hidden
        }
        $HOTKEY_QUIT {
            $form.Close()
        }
    }
})

[System.Windows.Forms.Application]::AddMessageFilter($filter)
[System.Windows.Forms.Application]::Run($form)
