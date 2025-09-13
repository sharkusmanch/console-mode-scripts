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

Export-ModuleMember -Function Set-RTSS-Frame-Limit, Get-ConsoleConfigDirectory, Get-ConsoleConfigPath, Initialize-ConsoleConfig, Get-ConsoleFrontend, Set-ConsoleFrontend, Get-ConsoleMode, Set-ConsoleMode
