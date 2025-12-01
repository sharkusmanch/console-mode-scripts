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

# ==========================
# Dependency Validation
# ==========================

function Test-Dependencies {
    $dependencies = @(
        @{ Name = "LGTV Companion"; Path = "$env:ProgramFiles\LGTV Companion\LGTV Companion.exe" }
        @{ Name = "MonitorSwitcher"; Path = "$env:ProgramData\chocolatey\bin\MonitorSwitcher.exe" }
        @{ Name = "SoundVolumeView"; Path = "$env:USERPROFILE\scoop\apps\SoundVolumeView\current\SoundVolumeView.exe" }
        @{ Name = "nircmd"; Path = (Get-Command nircmd.exe -ErrorAction SilentlyContinue).Source }
    )

    $missing = @()
    foreach ($dep in $dependencies) {
        if (-not $dep.Path -or -not (Test-Path $dep.Path -ErrorAction SilentlyContinue)) {
            $missing += $dep.Name
        }
    }

    if ($missing.Count -gt 0) {
        Write-ConsoleLog "Missing dependencies: $($missing -join ', ')" -Level WARN
        return $false
    }
    return $true
}

function Test-MonitorProfiles {
    $profiles = @(
        @{ Name = "TV"; Path = "$env:APPDATA\MonitorSwitcher\Profiles\TV.xml" }
        @{ Name = "Ultrawide"; Path = "$env:APPDATA\MonitorSwitcher\Profiles\Ultrawide.xml" }
    )

    $missing = @()
    foreach ($profile in $profiles) {
        if (-not (Test-Path $profile.Path -ErrorAction SilentlyContinue)) {
            $missing += $profile.Name
        }
    }

    if ($missing.Count -gt 0) {
        Write-ConsoleLog "Missing monitor profiles: $($missing -join ', ')" -Level WARN
        return $false
    }
    return $true
}

# ==========================
# Single Instance Mutex + PID File
# ==========================

$script:Mutex = $null

function Get-DaemonPidPath {
    param([string]$Name)
    return (Join-Path (Get-ConsoleConfigDirectory) "$Name.pid")
}

function Test-OrphanedDaemon {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    $pidPath = Get-DaemonPidPath -Name $Name
    if (Test-Path $pidPath) {
        $oldPid = Get-Content $pidPath -ErrorAction SilentlyContinue
        if ($oldPid) {
            $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
            if ($proc) {
                # Process exists - check if it's actually our daemon
                try {
                    $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $oldPid" -ErrorAction SilentlyContinue
                    if ($wmi -and $wmi.CommandLine -like "*$Name*") {
                        return @{ IsOrphaned = $false; Pid = [int]$oldPid; Process = $proc }
                    }
                } catch {}
            }
            # PID file exists but process is gone or different - orphaned
            return @{ IsOrphaned = $true; Pid = [int]$oldPid; Process = $null }
        }
    }
    return @{ IsOrphaned = $false; Pid = $null; Process = $null }
}

function Clear-OrphanedDaemons {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    # Kill any PowerShell processes running this daemon
    $killed = 0
    Get-WmiObject Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.CommandLine -like "*$Name*" -and $_.ProcessId -ne $PID) {
            try {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                $killed++
            } catch {}
        }
    }

    # Clean up PID file
    $pidPath = Get-DaemonPidPath -Name $Name
    if (Test-Path $pidPath) {
        Remove-Item $pidPath -Force -ErrorAction SilentlyContinue
    }

    return $killed
}

function Enter-SingleInstance {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    $mutexName = "Global\ConsoleModeScripts_$Name"
    $createdNew = $false

    # First check for orphaned processes
    $orphanCheck = Test-OrphanedDaemon -Name $Name
    if ($orphanCheck.IsOrphaned) {
        Write-ConsoleLog "Found orphaned PID file, cleaning up..." -Level WARN
        $killed = Clear-OrphanedDaemons -Name $Name
        if ($killed -gt 0) {
            Write-ConsoleLog "Killed $killed orphaned daemon process(es)"
        }
        Start-Sleep -Seconds 1
    } elseif ($orphanCheck.Process) {
        # Valid running process exists
        Write-ConsoleLog "$Name is already running (PID: $($orphanCheck.Pid))" -Level WARN
        return $false
    }

    try {
        $script:Mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
        if (-not $createdNew) {
            # Mutex held but no valid PID - likely a zombie mutex, try to clean up
            Write-ConsoleLog "Mutex held but no valid process found, attempting cleanup..." -Level WARN
            $killed = Clear-OrphanedDaemons -Name $Name
            Start-Sleep -Seconds 2

            # Try again
            $script:Mutex.Dispose()
            $script:Mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
            if (-not $createdNew) {
                Write-ConsoleLog "$Name is already running" -Level WARN
                return $false
            }
        }

        # Write PID file
        $pidPath = Get-DaemonPidPath -Name $Name
        Set-Content -LiteralPath $pidPath -Value $PID -Encoding UTF8

        return $true
    } catch {
        Write-ConsoleLog "Failed to create mutex for $Name`: $_" -Level ERROR
        return $false
    }
}

function Exit-SingleInstance {
    param([string]$Name = "ConsoleDaemon")

    # Remove PID file
    $pidPath = Get-DaemonPidPath -Name $Name
    if (Test-Path $pidPath) {
        Remove-Item $pidPath -Force -ErrorAction SilentlyContinue
    }

    if ($script:Mutex) {
        try {
            $script:Mutex.ReleaseMutex()
            $script:Mutex.Dispose()
        } catch {}
        $script:Mutex = $null
    }
}

# ==========================
# Controller Detection
# ==========================

function Test-ControllerConnected {
    param(
        [string]$VidPid = "054C*0DF2"
    )
    $device = Get-PnpDevice -Class 'HIDClass' -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InstanceId -like "*$VidPid*" -and
            $_.FriendlyName -like "*game controller*"
        }
    return ($null -ne $device)
}

# ==========================
# Monitor Profile Switching
# ==========================

function Switch-MonitorProfile {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 2
    )

    $profilePath = "$env:APPDATA\MonitorSwitcher\Profiles\$ProfileName.xml"
    $monitorSwitcher = "$env:ProgramData\chocolatey\bin\MonitorSwitcher.exe"

    if (-not (Test-Path $profilePath)) {
        Write-ConsoleLog "Monitor profile not found: $profilePath" -Level ERROR
        return $false
    }

    Add-Type -AssemblyName System.Windows.Forms
    $targetDisplayCount = if ($ProfileName -eq 'TV') { 2 } else { 1 }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-ConsoleLog "Switching to $ProfileName profile (attempt $attempt/$MaxRetries)"

        & $monitorSwitcher -load:"$profilePath"

        # Wait and verify
        Start-Sleep -Seconds $RetryDelaySeconds

        $currentCount = [System.Windows.Forms.Screen]::AllScreens.Count
        $primaryScreen = [System.Windows.Forms.Screen]::PrimaryScreen

        # For TV mode, check if we have the expected display count
        # For Ultrawide, just verify the switch happened
        if ($ProfileName -eq 'TV') {
            if ($currentCount -ge $targetDisplayCount) {
                Write-ConsoleLog "Monitor profile switch successful (displays: $currentCount)"
                return $true
            }
        } else {
            # For ultrawide, give it a moment and assume success if no error
            Write-ConsoleLog "Monitor profile switch completed (displays: $currentCount)"
            return $true
        }

        if ($attempt -lt $MaxRetries) {
            Write-ConsoleLog "Profile switch may have failed, retrying..." -Level WARN
            Start-Sleep -Seconds 1
        }
    }

    Write-ConsoleLog "Monitor profile switch failed after $MaxRetries attempts" -Level ERROR
    return $false
}

# ==========================
# Log Rotation
# ==========================

function Invoke-LogRotation {
    param(
        [int]$MaxLines = 1000,
        [int]$MaxSizeKB = 1024
    )

    $logPath = Get-ConsoleLogPath
    if (-not (Test-Path $logPath)) { return }

    $logFile = Get-Item $logPath
    $sizeKB = $logFile.Length / 1KB

    # Rotate if over size limit
    if ($sizeKB -gt $MaxSizeKB) {
        Write-ConsoleLog "Log rotation triggered (size: $([math]::Round($sizeKB, 2)) KB)"

        # Keep last N lines
        $lines = Get-Content $logPath -Tail $MaxLines
        Set-Content $logPath -Value $lines -Encoding UTF8

        Write-ConsoleLog "Log rotated, kept last $MaxLines lines"
    }
}

Export-ModuleMember -Function Set-RTSS-Frame-Limit, Get-ConsoleConfigDirectory, Get-ConsoleConfigPath, Initialize-ConsoleConfig, Get-ConsoleFrontend, Set-ConsoleFrontend, Get-ConsoleMode, Set-ConsoleMode, Initialize-WindowManagement, Minimize-SteamWindow, Maximize-SteamWindow, Set-WindowForeground, Get-ConsoleLogPath, Write-ConsoleLog, Show-ConsoleToast, Get-HotkeyConfig, Set-HotkeyConfig, Test-Dependencies, Test-MonitorProfiles, Get-DaemonPidPath, Test-OrphanedDaemon, Clear-OrphanedDaemons, Enter-SingleInstance, Exit-SingleInstance, Test-ControllerConnected, Switch-MonitorProfile, Invoke-LogRotation
