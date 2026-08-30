# Guía completa — Sandbox de Windows 10 headless para el agente

Recorrido de punta a punta de cómo montamos el laboratorio de análisis de malware:
desde cargar el ISO de Windows en el server hasta dejar el `malware-agent`
controlando la VM. Refleja el **Camino 1 (VRDE/RDP)** con los valores y los baches
reales de la instalación.

> Referencia rápida de cada script en [`README.md`](README.md). Aquí va la narrativa
> secuencial; los detalles finos de cada carpeta están en sus READMEs.

---

## 0. Contexto

**Server:** `somath-server` (Acer Nitro AN515-53) · i5-8300H (VT-x) · 31 GiB RAM ·
Debian 13 (trixie) · kernel 6.12 · **headless** (sin monitor) · Secure Boot desactivado.

**Arquitectura:**

```
Portátil (Ubuntu)                     Server (Debian, headless)
  Remmina/RDP  ───VRDE 3389──▶  VirtualBox ── VM Windows 10 (SandboxWindows10)
                                     │            IP host-only 192.168.56.10
  malware-agent (corre EN el server) ┘  ── SSH 22 ──▶ PowerShell dentro de Windows
                                     └─ VBoxManage: restaura snapshot CleanState
```

**Valores usados (constantes en toda la guía):**

| Qué | Valor |
|---|---|
| Nombre VM | `SandboxWindows10` |
| Usuario Windows | `vboxuser` |
| IP de la VM (host-only) | `192.168.56.10` |
| IP del host en host-only | `192.168.56.1` |
| Interfaz host-only | `vboxnet0` |
| Snapshot limpio | `CleanState` |
| Puerto VRDE (setup) | `3389` |
| Ruta repo en el server | `~/ScyWare/VirtualMachineConf` |
| IP LAN del server (ejemplo) | `192.168.78.104` |

---

## 1. Traer el repo y el ISO al server

```bash
# En el server: clonar el repo
git clone <url-del-repo> ~/ScyWare/VirtualMachineConf
```

El ISO de Windows **no** está en git (los ISOs se ignoran). Se trae por SSH. `rsync`
debe estar instalado en **ambos** extremos:

```bash
# Instalar rsync en el server (Debian recién instalado no lo trae)
ssh somath@somath-server 'sudo apt update && sudo apt install -y rsync'

# Copiar el ISO desde el portátil a isos/ (ruta del server: ~/ScyWare/...)
rsync -avhP --partial \
  ~/Documents/projects/malware-agent/_docs/Win10_22H2_Spanish_Mexico_x64v1.iso \
  somath@somath-server:~/ScyWare/VirtualMachineConf/isos/Win10_x64.iso
```

Los scripts de creación buscan el ISO por defecto en `<repo>/isos/Win10_x64.iso`.
Detalle en [`isos/README.md`](isos/README.md).

---

## 2. Instalar VirtualBox (carpeta `virtualbox/common/`)

```bash
cd ~/ScyWare/VirtualMachineConf/virtualbox/common
./00-check-host.sh                 # verifica VT-x, Secure Boot, headers (no cambia nada)
sudo ./01-install-virtualbox.sh    # repo Oracle + DKMS + Extension Pack + grupo vboxusers
newgrp vboxusers                   # aplicar el grupo sin cerrar sesión
```

`01` instala VirtualBox 7.1.x desde el repo oficial de Oracle, compila `vboxdrv` vía
DKMS (por eso hacen falta los `linux-headers` y Secure Boot desactivado) e instala el
Extension Pack (necesario para VRDE).

> **Bache real — Extension Pack:** si falla con `Extension pack name mismatch`, es por
> el nombre del archivo. Instálalo manualmente con el nombre oficial:
> ```bash
> VBOX_VER=$(VBoxManage --version | sed 's/r.*//')
> cd /tmp
> curl -fSL -O "https://download.virtualbox.org/virtualbox/${VBOX_VER}/Oracle_VirtualBox_Extension_Pack-${VBOX_VER}.vbox-extpack"
> sudo VBoxManage extpack install --replace "Oracle_VirtualBox_Extension_Pack-${VBOX_VER}.vbox-extpack"
> ```
> (Ya corregido en `01-install-virtualbox.sh`.)

---

## 3. Red host-only aislada + persistencia

```bash
sudo ./02-setup-hostonly-network.sh   # crea vboxnet0 = 192.168.56.1/24
sudo ./03-persist-hostonly.sh         # servicio systemd que la recrea en cada boot
```

La red host-only aísla la VM: sin salida a Internet ni a la LAN. El agente habla con
la VM por aquí.

> **Bache real — `vboxnet0` no persiste:** las interfaces host-only se **borran al
> reiniciar** el server; tras un reboot `startvm` falla con
> `Nonexistent host networking interface, name 'vboxnet0'`. Por eso `03` instala un
> servicio systemd que la recrea al arranque. Sin ese script, hay que volver a correr
> `02` tras cada reboot.

---

## 4. Conflicto KVM ↔ VirtualBox (VT-x)

VirtualBox y KVM **no pueden usar VT-x a la vez**. Si `kvm_intel` está cargado,
`startvm` falla con `VERR_VMX_IN_VMX_ROOT_MODE`.

```bash
lsmod | grep kvm && sudo modprobe -r kvm_intel kvm     # descargar KVM
# Para que no se recargue tras reboot (nos quedamos con VirtualBox):
echo -e "blacklist kvm_intel\nblacklist kvm" | sudo tee /etc/modprobe.d/blacklist-kvm.conf
sudo update-initramfs -u
```

> Revertir (si algún día pruebas `kvm-qemu/`):
> `sudo rm /etc/modprobe.d/blacklist-kvm.conf && sudo update-initramfs -u && sudo reboot`.

---

## 5. Crear la VM con VRDE (carpeta `virtualbox/01-vrde-rdp/`)

```bash
cd ~/ScyWare/VirtualMachineConf/virtualbox/01-vrde-rdp
./create-vm.sh          # SIN sudo: la VM debe ser del usuario, no de root
./start-vm-vrde.sh      # arranca headless e imprime la IP:3389 para RDP
```

`create-vm.sh` crea `SandboxWindows10` (4 GB RAM, 2 CPU, disco 50 GB), deja el
**adaptador 1 en NAT** (Internet temporal para instalar OpenSSH), activa **VRDE** en
el 3389 y fuerza **`Security/Method=RDP`** (ver bache abajo).

> ⚠️ Corre estos scripts **sin `sudo`**. Con `sudo` la VM queda registrada bajo `root`
> y el agente (que corre como `somath`) no la vería.

---

## 6. Conectar por RDP e instalar Windows

Cliente RDP en el **portátil** (no en el server). Con Remmina:

```bash
sudo apt install -y remmina remmina-plugin-rdp     # Ubuntu/Debian
```

Nueva conexión → protocolo **RDP**, servidor `192.168.78.104:3389`, pestaña
**Advanced → Security protocol negotiation → RDP**. Usuario/contraseña **vacíos**
(VRDE no autentica; te conectas a la *pantalla* de la VM).

> **Bache real — TLS:** por defecto VRDE usa `Security/Method=TLS` con un cert
> autofirmado que Remmina/FreeRDP rechazan (error TLS o se cuelga en "Connecting…").
> Se resuelve con `Security/Method=RDP` (ya lo hace `create-vm.sh`). Si tu VM se creó
> antes de ese fix:
> ```bash
> VBoxManage controlvm SandboxWindows10 poweroff
> VBoxManage modifyvm SandboxWindows10 --vrdeproperty "Security/Method=RDP"
> VBoxManage startvm SandboxWindows10 --type headless
> ```
> Alternativa por consola: `xfreerdp3 /v:192.168.78.104:3389 /sec:rdp /size:1024x768`.

**Instalación de Windows** (dentro de la sesión RDP):

1. Idioma (Español México) → **Instalar ahora**.
2. Clave de producto → **"No tengo clave de producto"**.
3. Edición → **Windows 10 Pro** (trae OpenSSH Server nativo; Home no).
4. Tipo → **Personalizada: instalar solo Windows (avanzado)**.
5. Disco → selecciona el de **50 GB** → Siguiente. Copia archivos y **reinicia solo**
   un par de veces (normal). Si aparece *"Press any key to boot from CD"*, **no** pulses
   nada tras la primera instalación para no re-lanzar el instalador.
6. Cuenta local: busca **"Cuenta sin conexión" → "Experiencia limitada"**, o usa el
   truco del correo falso `no@thankyou.com` + contraseña cualquiera.
7. **Usuario `vboxuser`** + contraseña (la misma que irá en el `.env` del agente —
   anótala).

---

## 7. OpenSSH + IP estática dentro de Windows

La VM tiene Internet por NAT en esta fase (necesario para instalar OpenSSH). El
portapapeles de VRDE suele no funcionar, así que **servimos el script y lo bajamos**:

```bash
# En el server: servir provision.ps1 por HTTP
cd ~/ScyWare/VirtualMachineConf/virtualbox/02-cli-unattended
python3 -m http.server 8000
```

```powershell
# En la VM (PowerShell como Administrador), una sola línea:
irm http://192.168.78.104:8000/provision.ps1 | iex
```

`provision.ps1` hace todo: instala **OpenSSH Server**, arranca el servicio (automático),
abre el **firewall** (puerto 22), pone **PowerShell como shell por defecto de SSH** y
fija la **IP estática `192.168.56.10`**. Verifica dentro de la VM:

```powershell
Get-Service sshd | Select-Object Name, Status, StartType   # Running / Automatic
Get-NetIPAddress -IPAddress 192.168.56.10                   # asignada a "Ethernet"
```

Cierra el `python3 -m http.server` con `Ctrl+C` en el server.

> Al fijar la IP, la VM pierde el Internet del NAT — es esperado. `AddressState:
> Invalid` mientras siga en NAT también es esperado; se valida al pasar a host-only.
> Manual equivalente en [`01-vrde-rdp/README.md`](virtualbox/01-vrde-rdp/README.md)
> (pasos B y C).

---

## 8. Aislar la red y congelar el snapshot `CleanState`

Hacemos el cambio a host-only y **verificamos SSH antes de snapshotear** (el snapshot
es el estado "oro" que el agente restaura siempre).

```bash
# 1) Apagar (limpio). Si Windows ignora el ACPI, apágalo desde Remmina (Inicio → Apagar)
VBoxManage controlvm SandboxWindows10 acpipowerbutton
# esperar a que 'list runningvms' quede vacío

# 2) Cambiar a host-only y quitar el ISO
VBoxManage modifyvm SandboxWindows10 --nic1 hostonly --hostonlyadapter1 vboxnet0
VBoxManage storageattach SandboxWindows10 --storagectl SATA --port 1 --device 0 --type dvddrive --medium none
VBoxManage startvm SandboxWindows10 --type headless

# 3) CHECKPOINT: probar SSH de extremo a extremo (espera ~40 s a que Windows levante)
ssh vboxuser@192.168.56.10        # debe entrar a  PS C:\Users\vboxuser>

# 4) Solo si el SSH funcionó: apagar limpio y crear el snapshot
#    (desde la sesión SSH: Stop-Computer -Force)
VBoxManage snapshot SandboxWindows10 take CleanState --description "Estado esteril: OpenSSH + host-only aislada"
VBoxManage snapshot SandboxWindows10 list      # CleanState con *
```

> Esto es lo mismo que hace [`finalize-snapshot.sh`](virtualbox/01-vrde-rdp/finalize-snapshot.sh),
> pero con el checkpoint del SSH intercalado para no congelar un estado roto.

En este punto el **laboratorio está completo**: VM aislada, SSH funcionando, snapshot
limpio listo para revertir en cada ejecución.

---

## 9. Configurar y correr el `malware-agent`

El agente llama a `VBoxManage` local + SSH a la VM, así que **corre en el server**.

**Llevarlo al server** (rsync desde el portátil, sin el venv ni el ISO):

```bash
rsync -avhP --exclude='.venv' --exclude='_docs' \
  ~/Documents/projects/malware-agent/ \
  somath@somath-server:~/malware-agent/
```

**Entorno + dependencias (en el server):**

```bash
cd ~/malware-agent
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt      # python-dotenv, langgraph, paramiko, langchain-groq
```

**`.env`** (lee `src/settings.py` — ojo: `VM_USERNAME`, no `USERNAME`):

```bash
GROQ_API_KEY=<tu API key de Groq>
VM_NAME=SandboxWindows10
IP_ADDRESS=192.168.56.10
VM_USERNAME=vboxuser
PASSWORD=<contraseña de vboxuser>
SNAPSHOT_NAME=CleanState
```

**Ejecutar:**

```bash
python3 -m src.agent.graph
```

Al iniciar, `reset_sandbox()` restaura `CleanState`, arranca la VM headless y conecta
por SSH. Verás `🔄 Sandbox 'SandboxWindows10' revertida...` y un prompt interactivo
(escribe una tarea; `exit` para salir). El agente ejecuta PowerShell dentro de la VM.

---

## 10. Operación diaria y troubleshooting

**Encender / apagar la VM a mano:**

```bash
VBoxManage startvm SandboxWindows10 --type headless    # encender
VBoxManage controlvm SandboxWindows10 savestate        # "hibernar" (resume idéntico)
VBoxManage controlvm SandboxWindows10 acpipowerbutton  # apagado limpio
```

**Reset manual al estado limpio** (lo que hace el agente):

```bash
VBoxManage controlvm SandboxWindows10 poweroff
VBoxManage snapshot SandboxWindows10 restore CleanState
VBoxManage startvm SandboxWindows10 --type headless
```

**Tabla de baches y soluciones:**

| Síntoma | Causa | Solución |
|---|---|---|
| `VERR_VMX_IN_VMX_ROOT_MODE` al `startvm` | KVM tiene VT-x | `sudo modprobe -r kvm_intel kvm` (+ blacklist) — §4 |
| `Nonexistent host networking interface 'vboxnet0'` | host-only no persiste tras reboot | `sudo ./common/03-persist-hostonly.sh` o re-correr `02` — §3 |
| RDP: error TLS / se cuelga en "Connecting…" | VRDE en `Security/Method=TLS` | `--vrdeproperty "Security/Method=RDP"` — §6 |
| No puedo pegar en la VM por Remmina | portapapeles VRDE | servir script por HTTP + `irm ... | iex` — §7 |
| `Extension pack name mismatch` | nombre del archivo del extpack | instalar con nombre oficial — §2 |
| `rsync: command not found` (al copiar el ISO) | rsync no está en el server | `sudo apt install -y rsync` — §1 |
| `linux-headers-<ver>` faltantes | headers del kernel actual | los instala `01`; o `sudo apt install linux-headers-amd64` |

**Tras reiniciar el server**, para dejar todo operativo:
1. `vboxnet0` se recrea sola (servicio systemd de §3).
2. KVM no se recarga si aplicaste el blacklist (§4); si no, `sudo modprobe -r kvm_intel kvm`.
3. `VBoxManage startvm SandboxWindows10 --type headless` (o deja que el agente lo haga).
