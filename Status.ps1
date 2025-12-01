# Status.ps1 - Check daemon status and display info

Import-Module "$PSScriptRoot\SharedLibrary.psm1" -Force

Write-Host "Console Mode Scripts - Status" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# Check for ConsoleDaemon (preferred) or legacy daemons
$taskNames = @('ConsoleDaemon', 'HotkeyDaemon', 'ControllerMonitor')
$foundTask = $false

foreach ($taskName in $taskNames) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
        if (-not $foundTask) {
            Write-Host "Scheduled Tasks:" -ForegroundColor Yellow
        }
        $stateColor = if ($task.State -eq 'Running') { 'Green' } else { 'Gray' }
        Write-Host "  $taskName" -NoNewline
        Write-Host " [$($task.State)]" -ForegroundColor $stateColor
        if ($taskInfo.LastRunTime) {
            Write-Host "    Last Run:  $($taskInfo.LastRunTime)"
        }
        $foundTask = $true
    }
}

if (-not $foundTask) {
    Write-Host "Scheduled Tasks: NONE INSTALLED" -ForegroundColor Red
    Write-Host "  Run: .\ConsoleDaemon.ps1 -Install"
}

Write-Host ""

# Check daemon processes
Write-Host "Running Processes:" -ForegroundColor Yellow
$daemonPatterns = @('ConsoleDaemon', 'hotkeys', 'ControllerMonitor')
$foundProcess = $false

Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
    $proc = $_
    try {
        $wmiProc = Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue
        foreach ($pattern in $daemonPatterns) {
            if ($wmiProc.CommandLine -like "*$pattern*") {
                Write-Host "  $pattern" -NoNewline -ForegroundColor Green
                Write-Host " (PID: $($proc.Id))"
                $foundProcess = $true
                break
            }
        }
    } catch {}
}

if (-not $foundProcess) {
    Write-Host "  No daemon processes running" -ForegroundColor Red
}

Write-Host ""

# Controller status
Write-Host "Controller:" -ForegroundColor Yellow
$controllerConnected = Test-ControllerConnected
if ($controllerConnected) {
    Write-Host "  Status:      Connected" -ForegroundColor Green
} else {
    Write-Host "  Status:      Disconnected" -ForegroundColor Gray
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

# Dependency check
Write-Host "Dependencies:" -ForegroundColor Yellow
$deps = Test-Dependencies
$profiles = Test-MonitorProfiles
if ($deps -and $profiles) {
    Write-Host "  All dependencies found" -ForegroundColor Green
} else {
    Write-Host "  Check log for missing dependencies" -ForegroundColor Yellow
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
