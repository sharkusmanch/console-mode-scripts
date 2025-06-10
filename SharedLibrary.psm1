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

Export-ModuleMember -Function Set-RTSS-Frame-Limit
