Add-Type -AssemblyName System.Windows.Forms

Add-Type -ReferencedAssemblies 'System.Windows.Forms' @"
using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class HotkeyForm2 : Form {
    const int WM_HOTKEY = 0x0312;
    protected override void WndProc(ref Message m) {
        base.WndProc(ref m);
    }
}
public static class HotkeyNative2 {
    [DllImport("user32.dll", SetLastError=true)] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
"@

$form = New-Object HotkeyForm2
$form.ShowInTaskbar = $false
$form.Visible = $false

$MOD_ALT=1; $MOD_CONTROL=2; $MOD_SHIFT=4
$mods = $MOD_CONTROL -bor $MOD_SHIFT -bor $MOD_ALT

# Test registration
$vk = [int][System.Windows.Forms.Keys]::T
$result = [HotkeyNative2]::RegisterHotKey($form.Handle, 1, $mods, $vk)
$lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()

Write-Host "RegisterHotKey result: $result"
Write-Host "Last Win32 Error: $lastError (0 = success, 1409 = already registered)"
Write-Host "Form Handle: $($form.Handle)"
Write-Host "VK code for T: $vk"
Write-Host "Modifiers: $mods"

[HotkeyNative2]::UnregisterHotKey($form.Handle, 1) | Out-Null
$form.Close()
$form.Dispose()
