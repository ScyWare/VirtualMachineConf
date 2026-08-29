# provision.ps1 — Post-instalación dentro de Windows (ejecutado por VBoxManage unattended).
# Enciende OpenSSH, abre el firewall, pone PowerShell como shell de SSH y fija IP estática.
# Se inyecta como 'powershell -EncodedCommand <base64>' desde create-and-install-vm.sh.

$ErrorActionPreference = 'Stop'
Start-Transcript -Path 'C:\provision.log' -Append

# 1) OpenSSH Server (requiere Internet vía NAT en esta fase)
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# 2) Servicio SSH automático
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# 3) Firewall: permitir entrada al puerto 22
if (-not (Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name 'sshd' -DisplayName 'OpenSSH Server (SSH-In)' `
    -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}

# 4) PowerShell como shell por defecto de SSH (CRÍTICO para el toolkit)
New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name 'DefaultShell' `
  -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
  -PropertyType String -Force | Out-Null

# 5) IP estática en la red host-only (192.168.56.10/24). El adaptador se llamará
#    'Ethernet'; si hay varios, ajusta por InterfaceIndex.
$if = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
try {
  New-NetIPAddress -InterfaceIndex $if.ifIndex -IPAddress '192.168.56.10' -PrefixLength 24 -ErrorAction Stop
} catch {
  Write-Host "IP ya asignada o pendiente hasta cambiar a host-only: $_"
}

Stop-Transcript
