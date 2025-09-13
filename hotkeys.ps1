Add-Type -AssemblyName System.Windows.Forms
Add-Type -ReferencedAssemblies 'System.Windows.Forms' @"
using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class HotkeyForm : Form {
    public event Action<int> HotkeyPressed;
    const int WM_HOTKEY = 0x0312;
    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY) {
            if (HotkeyPressed != null) HotkeyPressed(m.WParam.ToInt32());
        }
        base.WndProc(ref m);
    }
}
public static class HotkeyNative {
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
"@

$tv = "$env:USERPROFILE\Sync\Scripts\tv.ps1"
$uw = "$env:USERPROFILE\Sync\Scripts\Ultrawide.ps1"

$form = New-Object HotkeyForm
$form.ShowInTaskbar = $false; $form.Visible = $false; $form.WindowState = 'Minimized'

$MOD_ALT=1; $MOD_CONTROL=2; $MOD_SHIFT=4
function RegHK($id,$mods,$key){ [HotkeyNative]::RegisterHotKey($form.Handle,$id,$mods,[byte][Windows.Forms.Keys]::$key) | Out-Null }
RegHK 1 ($MOD_CONTROL -bor $MOD_SHIFT -bor $MOD_ALT) 'T'   # Ctrl+Shift+Alt+T -> TV.ps1
RegHK 2 ($MOD_CONTROL -bor $MOD_SHIFT -bor $MOD_ALT) 'F'   # Ctrl+Shift+Alt+F -> Ultrawide.ps1
RegHK 99 ($MOD_CONTROL -bor $MOD_SHIFT -bor $MOD_ALT) 'Q'  # Ctrl+Shift+Alt+Q -> exit

$form.add_HotkeyPressed({
  param($id)
  switch ($id) {
    1  { Start-Process powershell "-ExecutionPolicy Bypass -File `"$tv`"" }
    2  { Start-Process powershell "-ExecutionPolicy Bypass -File `"$uw`"" }
    99 {
         [HotkeyNative]::UnregisterHotKey($form.Handle,1)|Out-Null
         [HotkeyNative]::UnregisterHotKey($form.Handle,2)|Out-Null
         [HotkeyNative]::UnregisterHotKey($form.Handle,99)|Out-Null
         $form.Close()
       }
  }
})

[Windows.Forms.Application]::Run($form)
