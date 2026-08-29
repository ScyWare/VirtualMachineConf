# Camino 1 — VRDE / RDP

**Idea:** la VM corre headless en el server, pero con el **escritorio remoto de
VirtualBox (VRDE)** activado. Desde tu portátil te conectas por **RDP** y haces la
instalación de Windows como si tuvieras monitor. Al terminar, congelas el snapshot y
la VM queda lista para el agente.

Es el camino **más rápido** y sin dependencias gráficas en el server (el cliente RDP
corre en tu máquina).

## Requisitos

- `common/` ya ejecutado (VirtualBox + `vboxnet0`).
- El **Extension Pack** instalado (VRDE lo provee) — lo instala `01-install-virtualbox.sh`.
- Un ISO de Windows 10 en el server, en la carpeta `isos/` del repo (traído por SSH).
  Ver [`../../isos/README.md`](../../isos/README.md). Por defecto los scripts buscan
  `<repo>/isos/Win10_x64.iso`.
- Un cliente RDP en tu portátil: **Remmina** (Linux), **mstsc** (Windows) o
  **Microsoft Remote Desktop** (Mac).

## Pasos

### 1. Crear la VM y arrancarla con VRDE

```bash
# ISO por defecto: <repo>/isos/Win10_x64.iso  (exporta ISO_PATH solo si usas otra ruta/nombre)
./create-vm.sh          # crea disco, adaptadores, VRDE; adaptador 1 en NAT (para el instalador)
./start-vm-vrde.sh      # arranca headless y te dice a qué IP:puerto conectar por RDP
```

`start-vm-vrde.sh` imprime algo como:
```
Conéctate por RDP a:  192.168.78.104:3389   (IP LAN del server)
```

### 2. Instalar Windows por RDP

Desde tu portátil abre el cliente RDP hacia esa IP:puerto y sigue el instalador
clásico de Windows (ver `../../README` raíz del malware-agent, Fase 4):
- Sin clave de producto → Windows 10 Pro → instalación personalizada.
- Forzar cuenta local con el truco `no@thankyou.com`.
- Usuario **`vboxuser`**, con la contraseña que uses en el agente (`.env`).

### 3. Instalar OpenSSH dentro de Windows

Dentro de la VM (todavía con NAT para tener Internet), en PowerShell **como
administrador** (ver Fase 5 del README del malware-agent):

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (SSH-In)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
# PowerShell como shell por defecto de SSH:
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
```

Y fija una **IP estática** en la red host-only para que el agente siempre la
encuentre (ejecuta *después* de cambiar a host-only, o desde ya sabiendo que será
`192.168.56.10`):

```powershell
# Ajusta el índice de interfaz con: Get-NetAdapter
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.56.10 -PrefixLength 24
```

### 4. Aislar la red y congelar el snapshot

```bash
./finalize-snapshot.sh   # apaga la VM, cambia a host-only, arranca y toma 'CleanState'
```

Este script deja el adaptador 1 en **host-only vboxnet0** (sin Internet) y crea el
snapshot `CleanState` que el agente restaura en cada ejecución.

### 5. Probar desde el server

```bash
ssh vboxuser@192.168.56.10
```

Debe entrar directo a `PS C:\Users\vboxuser>`. Listo: actualiza el `.env` del
malware-agent con `VM_NAME=SandboxWindows10`, `IP=192.168.56.10`, credenciales y
`SNAPSHOT=CleanState`.

## Seguridad

Tras el paso 4 la VM **no tiene salida a Internet ni a la LAN**. VRDE solo se usó
para el setup; el agente ya no lo necesita (puedes dejarlo activo para depurar o
apagarlo con `VBoxManage modifyvm SandboxWindows10 --vrde off`).
