function Set-RTSS-Frame-Limit {
    param (
        [string]$configFilePath,
        [int]$newLimit
    )

    # Check if the file exists
    if (Test-Path $configFilePath) {
        # Read the entire content of the file
        $configContent = Get-Content $configFilePath -Raw

        # Capture the old limit first, before replacing
        $oldLimit = 0
        if ($configContent -match 'Limit=(\d+)') {
            $oldLimit = [int]$Matches[1]
        } else {
            Write-Host "No existing frame limit found in the config file, assuming it is unlimited."
            return 0
        }

        # Find and replace the line that sets the frame rate limit
        $configContent = $configContent -replace 'Limit=\d+', "Limit=$newLimit"

        # Write the updated content back to the file
        Set-Content $configFilePath -Value $configContent

        Write-Host "Frame rate limit updated to $newLimit in $configFilePath."
        return $oldLimit
    } else {
        Write-Host "Global file not found at $configFilePath, please correct the path in settings.json."
        return $null
    }
}

# ==========================
# Centralized User Config
# ==========================

function Get-ConsoleConfigDirectory {
    # Use per-user roaming AppData for config storage
    return (Join-Path $env:APPDATA "ConsoleModeScripts")
}

function Get-ConsoleConfigPath {
    return (Join-Path (Get-ConsoleConfigDirectory) "config.json")
}

function Initialize-ConsoleConfig {
    $dir = Get-ConsoleConfigDirectory
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $path = Get-ConsoleConfigPath
    if (-not (Test-Path -LiteralPath $path)) {
        # New configs use "Frontend" key for clarity
        $default = @{ Frontend = 'Steam' } | ConvertTo-Json -Depth 3
        Set-Content -LiteralPath $path -Value $default -Encoding UTF8
    }
    return $path
}

function Get-ConsoleFrontend {
    param()
    $path = Initialize-ConsoleConfig
    try {
        $raw = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
        $cfg = $raw | ConvertFrom-Json -ErrorAction Stop
        # Prefer Frontend, but fall back to older Mode key for backward compat
        $frontend = if ($null -ne $cfg.PSObject.Properties['Frontend']) { $cfg.Frontend } else { $cfg.Mode }
        if ($frontend -in @('Playnite','Steam')) { return [string]$frontend }
    } catch {
        # Fall through to default below
    }
    # If config missing/invalid, default to Steam
    return 'Steam'
}

function Set-ConsoleFrontend {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Playnite','Steam')]
        [string]$Frontend
    )
    $path = Initialize-ConsoleConfig
    # Preserve other keys if any
    $cfg = @{}
    try {
        $raw = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
        $cfg = $raw | ConvertFrom-Json -ErrorAction Stop | ConvertTo-Json -Depth 5 | ConvertFrom-Json
    } catch {}
    $cfg | Add-Member -NotePropertyName Frontend -NotePropertyValue $Frontend -Force
    $json = $cfg | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $path -Value $json -Encoding UTF8
    return $Frontend
}

# Legacy wrappers for backward compatibility
function Get-ConsoleMode { Get-ConsoleFrontend }
function Set-ConsoleMode {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Playnite','Steam')]
        [string]$Mode
    )
    Set-ConsoleFrontend -Frontend $Mode
}

# ==========================
# Window Management
# ==========================

function Initialize-WindowManagement {
    if (-not ([System.Management.Automation.PSTypeName]'Native.Win32Window').Type) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;

namespace Native {
    public static class Win32Window {
        [DllImport("user32.dll")]
        public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        public const int SW_MINIMIZE = 6;
        public const int SW_MAXIMIZE = 3;
        public const int SW_RESTORE = 9;
    }
}
'@
    }
}

function Minimize-SteamWindow {
    Initialize-WindowManagement
    $steamWindow = Get-Process | Where-Object { $_.MainWindowTitle -like "*Steam*" } | Select-Object -First 1
    if ($steamWindow -and $steamWindow.MainWindowHandle -ne [IntPtr]::Zero) {
        [Native.Win32Window]::ShowWindowAsync($steamWindow.MainWindowHandle, [Native.Win32Window]::SW_MINIMIZE) | Out-Null
        return $true
    }
    return $false
}

function Maximize-SteamWindow {
    Initialize-WindowManagement
    $steamWindow = Get-Process | Where-Object { $_.MainWindowTitle -like "*Steam*" } | Select-Object -First 1
    if ($steamWindow -and $steamWindow.MainWindowHandle -ne [IntPtr]::Zero) {
        [Native.Win32Window]::ShowWindowAsync($steamWindow.MainWindowHandle, [Native.Win32Window]::SW_MAXIMIZE) | Out-Null
        return $true
    }
    return $false
}

function Set-WindowForeground {
    param([IntPtr]$Handle)
    Initialize-WindowManagement
    if ($Handle -ne [IntPtr]::Zero) {
        [Native.Win32Window]::SetForegroundWindow($Handle) | Out-Null
        return $true
    }
    return $false
}

# ==========================
# Logging
# ==========================

function Get-ConsoleLogPath {
    return (Join-Path (Get-ConsoleConfigDirectory) "daemon.log")
}

function Write-ConsoleLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )
    $dir = Get-ConsoleConfigDirectory
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $logPath = Get-ConsoleLogPath
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

# ==========================
# Toast Notifications
# ==========================

function Show-ConsoleToast {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Message
    )
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $template = @"
<toast>
    <visual>
        <binding template="ToastText02">
            <text id="1">$Title</text>
            <text id="2">$Message</text>
        </binding>
    </visual>
</toast>
"@
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Console Mode Scripts")
        $notifier.Show($toast)
    } catch {
        # Fallback: silent fail, just log
        Write-ConsoleLog "Toast notification failed: $_" -Level WARN
    }
}

# ==========================
# Hotkey Configuration
# ==========================

function Get-HotkeyConfig {
    $path = Initialize-ConsoleConfig
    try {
        $raw = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
        $cfg = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($null -ne $cfg.PSObject.Properties['Hotkeys']) {
            return $cfg.Hotkeys
        }
    } catch {}
    # Return defaults
    return @{
        TV = @{ Modifiers = @('Ctrl', 'Shift', 'Alt'); Key = 'T' }
        Ultrawide = @{ Modifiers = @('Ctrl', 'Shift', 'Alt'); Key = 'F' }
        Quit = @{ Modifiers = @('Ctrl', 'Shift', 'Alt'); Key = 'Q' }
    }
}

function Set-HotkeyConfig {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Hotkeys
    )
    $path = Initialize-ConsoleConfig
    $cfg = @{}
    try {
        $raw = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
        $cfg = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $cfg = [PSCustomObject]@{}
    }
    $cfg | Add-Member -NotePropertyName Hotkeys -NotePropertyValue $Hotkeys -Force
    $json = $cfg | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $path -Value $json -Encoding UTF8
}

Export-ModuleMember -Function Set-RTSS-Frame-Limit, Get-ConsoleConfigDirectory, Get-ConsoleConfigPath, Initialize-ConsoleConfig, Get-ConsoleFrontend, Set-ConsoleFrontend, Get-ConsoleMode, Set-ConsoleMode, Initialize-WindowManagement, Minimize-SteamWindow, Maximize-SteamWindow, Set-WindowForeground, Get-ConsoleLogPath, Write-ConsoleLog, Show-ConsoleToast, Get-HotkeyConfig, Set-HotkeyConfig
