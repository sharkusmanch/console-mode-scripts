Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Resolve script directory and paths
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$tv = Join-Path $scriptDir "TV.ps1"
$uw = Join-Path $scriptDir "Ultrawide.ps1"

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

# Constants
$MOD_ALT = 0x0001
$MOD_CONTROL = 0x0002
$MOD_SHIFT = 0x0004
$WM_HOTKEY = 0x0312

$HOTKEY_TV = 1
$HOTKEY_UW = 2
$HOTKEY_QUIT = 99

# Create hidden form to receive hotkey messages
$form = New-Object System.Windows.Forms.Form
$form.ShowInTaskbar = $false
$form.WindowState = 'Minimized'
$form.FormBorderStyle = 'None'
$form.Size = New-Object System.Drawing.Size(0, 0)
$form.Opacity = 0

# Register hotkeys once form handle exists
$form.Add_Load({
    $mods = $MOD_CONTROL -bor $MOD_SHIFT -bor $MOD_ALT

    $r1 = [HotkeyNative]::RegisterHotKey($form.Handle, $HOTKEY_TV, $mods, [uint32][System.Windows.Forms.Keys]::T)
    $r2 = [HotkeyNative]::RegisterHotKey($form.Handle, $HOTKEY_UW, $mods, [uint32][System.Windows.Forms.Keys]::F)
    $r3 = [HotkeyNative]::RegisterHotKey($form.Handle, $HOTKEY_QUIT, $mods, [uint32][System.Windows.Forms.Keys]::Q)

    if (-not $r1) { Write-Host "Failed to register Ctrl+Shift+Alt+T" }
    if (-not $r2) { Write-Host "Failed to register Ctrl+Shift+Alt+F" }
    if (-not $r3) { Write-Host "Failed to register Ctrl+Shift+Alt+Q" }
})

# Clean up hotkeys on close
$form.Add_FormClosing({
    [HotkeyNative]::UnregisterHotKey($form.Handle, $HOTKEY_TV) | Out-Null
    [HotkeyNative]::UnregisterHotKey($form.Handle, $HOTKEY_UW) | Out-Null
    [HotkeyNative]::UnregisterHotKey($form.Handle, $HOTKEY_QUIT) | Out-Null
})

# Override WndProc via message filter
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
        $HOTKEY_TV  {
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tv`"" -WindowStyle Hidden
        }
        $HOTKEY_UW  {
            Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$uw`"" -WindowStyle Hidden
        }
        $HOTKEY_QUIT {
            $form.Close()
        }
    }
})

[System.Windows.Forms.Application]::AddMessageFilter($filter)
[System.Windows.Forms.Application]::Run($form)
