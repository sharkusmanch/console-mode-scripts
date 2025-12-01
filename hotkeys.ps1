Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Resolve script directory and paths
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

# Import shared library
Import-Module (Join-Path $scriptDir "SharedLibrary.psm1") -Force

$tv = Join-Path $scriptDir "TV.ps1"
$uw = Join-Path $scriptDir "Ultrawide.ps1"

Write-ConsoleLog "Hotkey daemon starting"

# Import native hotkey functions
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

# Modifier constants
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

# Load hotkey config
$hotkeyConfig = Get-HotkeyConfig

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

# Parse config
$tvMods = Get-ModifierValue -Modifiers $hotkeyConfig.TV.Modifiers
$tvKey = [System.Windows.Forms.Keys]::($hotkeyConfig.TV.Key)
$uwMods = Get-ModifierValue -Modifiers $hotkeyConfig.Ultrawide.Modifiers
$uwKey = [System.Windows.Forms.Keys]::($hotkeyConfig.Ultrawide.Key)
$quitMods = Get-ModifierValue -Modifiers $hotkeyConfig.Quit.Modifiers
$quitKey = [System.Windows.Forms.Keys]::($hotkeyConfig.Quit.Key)

# Create hidden form to receive hotkey messages
$form = New-Object System.Windows.Forms.Form
$form.ShowInTaskbar = $false
$form.WindowState = 'Minimized'
$form.FormBorderStyle = 'None'
$form.Size = New-Object System.Drawing.Size(0, 0)
$form.Opacity = 0
$form.Text = "HotkeyDaemon"

# Create system tray icon
$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Visible = $true
$trayIcon.Text = "Console Mode Hotkeys"

# Create a simple icon (green square for running)
$bitmap = New-Object System.Drawing.Bitmap(16, 16)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.FillRectangle([System.Drawing.Brushes]::LimeGreen, 2, 2, 12, 12)
$graphics.DrawRectangle([System.Drawing.Pens]::DarkGreen, 2, 2, 11, 11)
$graphics.Dispose()
$trayIcon.Icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())

# Create context menu
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$menuStatus = New-Object System.Windows.Forms.ToolStripMenuItem
$menuStatus.Text = "Status: Running"
$menuStatus.Enabled = $false
$contextMenu.Items.Add($menuStatus) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$menuTV = New-Object System.Windows.Forms.ToolStripMenuItem
$menuTV.Text = "TV Mode ($(Get-HotkeyDescription $hotkeyConfig.TV))"
$menuTV.Add_Click({ Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tv`"" -WindowStyle Hidden })
$contextMenu.Items.Add($menuTV) | Out-Null

$menuUW = New-Object System.Windows.Forms.ToolStripMenuItem
$menuUW.Text = "Ultrawide Mode ($(Get-HotkeyDescription $hotkeyConfig.Ultrawide))"
$menuUW.Add_Click({ Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$uw`"" -WindowStyle Hidden })
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

$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$menuExit = New-Object System.Windows.Forms.ToolStripMenuItem
$menuExit.Text = "Exit ($(Get-HotkeyDescription $hotkeyConfig.Quit))"
$menuExit.Add_Click({ $form.Close() })
$contextMenu.Items.Add($menuExit) | Out-Null

$trayIcon.ContextMenuStrip = $contextMenu

# Register hotkeys once form handle exists
$form.Add_Load({
    $r1 = [HotkeyNative]::RegisterHotKey($form.Handle, $HOTKEY_TV, $tvMods, [uint32]$tvKey)
    $r2 = [HotkeyNative]::RegisterHotKey($form.Handle, $HOTKEY_UW, $uwMods, [uint32]$uwKey)
    $r3 = [HotkeyNative]::RegisterHotKey($form.Handle, $HOTKEY_QUIT, $quitMods, [uint32]$quitKey)

    if (-not $r1) { Write-ConsoleLog "Failed to register TV hotkey" -Level ERROR }
    if (-not $r2) { Write-ConsoleLog "Failed to register Ultrawide hotkey" -Level ERROR }
    if (-not $r3) { Write-ConsoleLog "Failed to register Quit hotkey" -Level ERROR }

    if ($r1 -and $r2 -and $r3) {
        Write-ConsoleLog "All hotkeys registered successfully"
    }
})

# Clean up on close
$form.Add_FormClosing({
    Write-ConsoleLog "Hotkey daemon shutting down"
    [HotkeyNative]::UnregisterHotKey($form.Handle, $HOTKEY_TV) | Out-Null
    [HotkeyNative]::UnregisterHotKey($form.Handle, $HOTKEY_UW) | Out-Null
    [HotkeyNative]::UnregisterHotKey($form.Handle, $HOTKEY_QUIT) | Out-Null
    $trayIcon.Visible = $false
    $trayIcon.Dispose()
})

# Message filter for hotkey events
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
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tv`"" -WindowStyle Hidden
        }
        $HOTKEY_UW {
            Write-ConsoleLog "Ultrawide hotkey pressed"
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$uw`"" -WindowStyle Hidden
        }
        $HOTKEY_QUIT {
            $form.Close()
        }
    }
})

[System.Windows.Forms.Application]::AddMessageFilter($filter)
[System.Windows.Forms.Application]::Run($form)
