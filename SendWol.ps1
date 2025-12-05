# Send Wake-on-LAN packet
param(
    [string]$MacAddress = "DC:03:98:2C:FE:76",
    [string]$LocalIP = "192.168.12.117"
)

$mac = $MacAddress -replace '[:-]',''
$macBytes = [byte[]]@(
    [Convert]::ToByte($mac.Substring(0,2), 16),
    [Convert]::ToByte($mac.Substring(2,2), 16),
    [Convert]::ToByte($mac.Substring(4,2), 16),
    [Convert]::ToByte($mac.Substring(6,2), 16),
    [Convert]::ToByte($mac.Substring(8,2), 16),
    [Convert]::ToByte($mac.Substring(10,2), 16)
)

# Magic packet: 6x 0xFF followed by MAC address repeated 16 times
$packet = [byte[]](,0xFF * 6) + ($macBytes * 16)

# Bind to specific local interface and broadcast on that subnet
$localEndpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse($LocalIP), 0)
$udp = New-Object System.Net.Sockets.UdpClient($localEndpoint)
$udp.EnableBroadcast = $true
$broadcastEndpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Broadcast, 9)
$udp.Send($packet, $packet.Length, $broadcastEndpoint) | Out-Null
$udp.Close()

Write-Host "WOL packet sent to $MacAddress via $LocalIP"
