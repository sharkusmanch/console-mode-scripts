# Status.ps1 - Check daemon status and display info

Import-Module "$PSScriptRoot\SharedLibrary.psm1" -Force

$taskName = 'HotkeyDaemon'

Write-Host "Console Mode Scripts - Status" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# Check scheduled task
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
    Write-Host "Scheduled Task:" -ForegroundColor Yellow
    Write-Host "  Name:        $taskName"
    Write-Host "  State:       $($task.State)"
    if ($taskInfo.LastRunTime) {
        Write-Host "  Last Run:    $($taskInfo.LastRunTime)"
    }
    if ($taskInfo.NextRunTime) {
        Write-Host "  Next Run:    $($taskInfo.NextRunTime)"
    }
} else {
    Write-Host "Scheduled Task: NOT INSTALLED" -ForegroundColor Red
    Write-Host "  Run Install-HotkeyService.ps1 to install"
}

Write-Host ""

# Check if daemon process is running
$daemonProcess = Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
    try {
        $_.MainWindowTitle -eq "HotkeyDaemon" -or
        ($_.CommandLine -and $_.CommandLine -like "*hotkeys.ps1*")
    } catch { $false }
}

# Alternative: check for hidden form
$hotkeyProcess = Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
    $proc = $_
    try {
        $wmiProc = Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue
        if ($wmiProc.CommandLine -like "*hotkeys.ps1*") {
            $proc
        }
    } catch {}
}

Write-Host "Daemon Process:" -ForegroundColor Yellow
if ($hotkeyProcess) {
    Write-Host "  Status:      RUNNING" -ForegroundColor Green
    Write-Host "  PID:         $($hotkeyProcess.Id)"
} else {
    Write-Host "  Status:      NOT RUNNING" -ForegroundColor Red
}

Write-Host ""

# Show current config
Write-Host "Configuration:" -ForegroundColor Yellow
$frontend = Get-ConsoleFrontend
Write-Host "  Frontend:    $frontend"

$configPath = Get-ConsoleConfigPath
Write-Host "  Config:      $configPath"

$logPath = Get-ConsoleLogPath
Write-Host "  Log:         $logPath"

if (Test-Path $logPath) {
    $logSize = (Get-Item $logPath).Length
    $logSizeKB = [math]::Round($logSize / 1KB, 2)
    Write-Host "  Log Size:    $logSizeKB KB"
}

Write-Host ""

# Show hotkey config
Write-Host "Hotkeys:" -ForegroundColor Yellow
$hotkeyConfig = Get-HotkeyConfig
foreach ($key in @('TV', 'Ultrawide', 'Quit')) {
    $hk = $hotkeyConfig.$key
    $mods = ($hk.Modifiers -join '+')
    Write-Host "  ${key}:".PadRight(14) "$mods+$($hk.Key)"
}

Write-Host ""

# Show recent log entries
if (Test-Path $logPath) {
    Write-Host "Recent Log Entries:" -ForegroundColor Yellow
    Get-Content $logPath -Tail 10 | ForEach-Object {
        if ($_ -match '\[ERROR\]') {
            Write-Host "  $_" -ForegroundColor Red
        } elseif ($_ -match '\[WARN\]') {
            Write-Host "  $_" -ForegroundColor Yellow
        } else {
            Write-Host "  $_"
        }
    }
}
