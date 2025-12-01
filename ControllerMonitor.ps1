# ControllerMonitor.ps1
# Monitors for DualSense Edge controller connection and triggers TV mode

param(
    [switch]$Install,
    [switch]$Uninstall
)

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

Import-Module (Join-Path $scriptDir "SharedLibrary.psm1") -Force

$taskName = 'ControllerMonitor'

if ($Install) {
    # Remove existing task if present
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

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

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggerLogon -Settings $settings -Principal $principal -Description 'Monitor for controller connection to trigger TV mode'

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

    Write-Host "Controller monitor installed. Start with: Start-ScheduledTask -TaskName '$taskName'"
    return
}

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Controller monitor uninstalled."
    return
}

# ==========================
# Main Monitor Logic
# ==========================

Write-ConsoleLog "Controller monitor starting"

# Load config for controller settings
$configPath = Get-ConsoleConfigPath

# DualSense Edge: VID 054C, PID 0DF2
# We detect via HID device with this VID/PID being present
$controllerVidPid = "054C*0DF2"
$debounceSeconds = 30
$pollIntervalSeconds = 3

try {
    $cfg = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json
    if ($cfg.PSObject.Properties['ControllerVidPid']) {
        $controllerVidPid = $cfg.ControllerVidPid
    }
    if ($cfg.PSObject.Properties['ControllerDebounceSeconds']) {
        $debounceSeconds = [int]$cfg.ControllerDebounceSeconds
    }
    if ($cfg.PSObject.Properties['ControllerPollSeconds']) {
        $pollIntervalSeconds = [int]$cfg.ControllerPollSeconds
    }
} catch {}

Write-ConsoleLog "Monitoring for HID device VID/PID: $controllerVidPid (poll: ${pollIntervalSeconds}s, debounce: ${debounceSeconds}s)"

$tvScript = Join-Path $scriptDir "TV.ps1"
$lastTriggerTime = [DateTime]::MinValue
$wasConnected = $false

# Check if controller is currently connected via HID game controller presence
function Test-ControllerConnected {
    param([string]$VidPid)
    # Look for HID game controller with matching VID/PID that is currently present
    $device = Get-PnpDevice -Class 'HIDClass' -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InstanceId -like "*$VidPid*" -and
            $_.FriendlyName -like "*game controller*"
        }
    return ($null -ne $device)
}

# Initial state check
$wasConnected = Test-ControllerConnected -VidPid $controllerVidPid
Write-ConsoleLog "Initial controller state: $(if ($wasConnected) { 'Connected' } else { 'Disconnected' })"

# Polling loop
while ($true) {
    try {
        $isConnected = Test-ControllerConnected -VidPid $controllerVidPid

        # Detect connection event (was disconnected, now connected)
        if ($isConnected -and -not $wasConnected) {
            $now = Get-Date
            $elapsed = ($now - $lastTriggerTime).TotalSeconds

            if ($elapsed -ge $debounceSeconds) {
                $lastTriggerTime = $now
                Write-ConsoleLog "Controller connected - triggering TV mode"
                Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tvScript`"" -WindowStyle Hidden
            } else {
                Write-ConsoleLog "Controller connected but debounce active ($([int]$elapsed)s < ${debounceSeconds}s)"
            }
        }

        $wasConnected = $isConnected
    } catch {
        Write-ConsoleLog "Controller monitor error: $_" -Level ERROR
    }

    Start-Sleep -Seconds $pollIntervalSeconds
}
