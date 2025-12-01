param(
    [switch]$Uninstall
)

$scriptPath = Join-Path $PSScriptRoot "hotkeys.ps1"
$taskName = 'HotkeyDaemon'

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Task '$taskName' uninstalled."
    return
}

# Remove existing task if present
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# Action: Run PowerShell hidden
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

# Trigger: At logon
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

# Settings optimized for surviving hibernate/wake
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -DontStopOnIdleEnd `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -MultipleInstances IgnoreNew

# Principal: Run as current user interactively
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

# Register the task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggerLogon -Settings $settings -Principal $principal -Description 'Global hotkey daemon for console mode switching'

# Add SessionUnlock trigger via COM (not available in New-ScheduledTaskTrigger)
$taskService = New-Object -ComObject Schedule.Service
$taskService.Connect()
$task = $taskService.GetFolder('\').GetTask($taskName)
$definition = $task.Definition

# Create SessionStateChange trigger for unlock (type 8 = SessionUnlock)
$triggers = $definition.Triggers
$unlockTrigger = $triggers.Create(11)  # 11 = SessionStateChangeTrigger
$unlockTrigger.StateChange = 8         # 8 = SessionUnlock
$unlockTrigger.UserId = $env:USERNAME
$unlockTrigger.Enabled = $true

$taskService.GetFolder('\').RegisterTaskDefinition($taskName, $definition, 4, $null, $null, 3) | Out-Null

Write-Host "Task '$taskName' installed successfully."
Write-Host ""
Write-Host "Triggers:"
Write-Host "  - At logon"
Write-Host "  - On session unlock (covers wake from hibernate)"
Write-Host ""
Write-Host "To start now:    Start-ScheduledTask -TaskName '$taskName'"
Write-Host "To uninstall:    .\Install-HotkeyService.ps1 -Uninstall"
