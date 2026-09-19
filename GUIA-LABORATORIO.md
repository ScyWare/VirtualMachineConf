# Guía del Laboratorio de Red Aislada (ScyWare)

Despliegue en el servidor Debian `somath-server` de un laboratorio de red aislada:
un **agente atacante** (VM-0) que se propaga hacia varias **VMs víctima**, con toda la
red **sin salida a Internet** salvo un **proxy LLM** que corre en el host.

> Esta guía documenta el procedimiento **real y probado**, con los baches que
> encontramos resueltos (ver §9 Troubleshooting). Complementa a `GUIA-COMPLETA.md`
> (que cubre la primera VM Windows) y al `README.md` del proxy en `../llm-proxy/`.

---

## 1. Topología

| VM / Rol | Nombre VM | SO | IP (host-only `vboxnet0`) | Vulnera plantada |
|---|---|---|---|---|
| **VM-0 Atacante** | `WormKaliAttacker` | Kali Linux (headless) | `192.168.56.10` | Punto de partida (Gen-0): agente + `nmap`, `python3`, etc. |
| **VM-1 Víctima** | `VictimLinux1` | Debian 12 | `192.168.56.11` | Credenciales SSH débiles (`test:test123`). |
| **VM-2 Víctima** | `VictimLinux2` | Debian 12 | `192.168.56.12` | App web con Command Injection + `.env` expuesto. |
| **VM-3 Víctima** | `VictimLinux3` | Debian 12 | `192.168.56.13` | Servicio vulnerable (`vsftpd 2.3.4` / SambaCry). |
| **VM-4 Víctima** | `VictimMetasploitable` | Metasploitable 2 (Ubuntu 8.04) | `192.168.56.14` | Imagen deliberadamente vulnerable (FTP/SMB/IRC backdoors, DVWA...). |
| **VM-5 Víctima** | `VictimWindows` | Windows 10 | `192.168.56.15` | OpenSSH + debilidad de config / privesc. |

- **Host `somath-server`** → `192.168.56.1` en `vboxnet0`. Aquí corre el **proxy LLM**.
- Ninguna VM tiene salida a Internet ni a la LAN. El único puente controlado es el proxy.

---

## 2. Prerequisitos del host

### 2.1 Conflicto KVM vs VirtualBox (¡importante!)

Si el kernel tiene cargado el módulo **KVM**, VirtualBox no puede usar VT-x y falla al
arrancar VMs con:

```
VBoxManage: error: VT-x is being used by another hypervisor (VERR_VMX_IN_VMX_ROOT_MODE)
```

**Solución** — descargar KVM antes de usar VirtualBox:

```bash
lsmod | grep kvm                              # ver si está cargado y su refcount
ps aux | grep -i qemu | grep -v grep          # que no haya VMs QEMU corriendo
sudo modprobe -r kvm_intel kvm                # Intel  (AMD: kvm_amd kvm)
```

> Es un cambio de toda la máquina y **no permanente**: KVM se recarga solo al reiniciar
> (o con `sudo modprobe kvm_intel`). Como el lab es 100% VirtualBox, no estorba. Si no
> vas a usar QEMU nunca en este server, se puede poner en blacklist para que no cargue
> al bootear.

### 2.2 Extension Pack (para VRDE/RDP)

VRDE (consola gráfica por RDP) necesita el Oracle Extension Pack. Verifica:

```bash
VBoxManage list extpacks     # debe listar "Oracle VirtualBox Extension Pack" y Usable: true
```

### 2.3 Red host-only

```bash
VBoxManage list hostonlyifs | grep -A1 vboxnet0   # debe existir con IP 192.168.56.1, Status: Up
```

Si no existe o no persiste tras reboot, ver `GUIA-COMPLETA.md` §3 (script systemd que
la recrea en cada boot).

---

## 3. Proxy LLM (en el host)

El proxy **corre en el host, NO dentro de una VM**: solo el host tiene la IP
`192.168.56.1` (lado host de `vboxnet0`) y salida a Internet. Ver detalles completos en
`../llm-proxy/README.md`.

Arranque manual (se levanta cada vez que se usa el lab):

```bash
cd ~/ScyWare/llm-proxy
python3 -m venv .venv          # solo la primera vez
source .venv/bin/activate
pip install -r requirements.txt
# .env con GROQ_API_KEY
uvicorn main:app --host 192.168.56.1 --port 8080
```

La VM-0 lo consume con una key dummy (la real vive solo en el host):

```python
llm = ChatGroq(
    model="openai/gpt-oss-20b",
    api_key="proxy_dummy_key",
    base_url="http://192.168.56.1:8080/v1",
)
```

---

## 4. Contención con iptables

```bash
# Bloquear forwarding desde vboxnet0 hacia cualquier otra interfaz (LAN/WAN)
sudo iptables -A FORWARD -i vboxnet0 -j DROP

# Permitir solo el puerto del proxy dentro de la red host-only
sudo iptables -A INPUT -i vboxnet0 -p tcp --dport 8080 -j ACCEPT

# Persistir
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save
```

---

## 5. VM-5: Windows (`VictimWindows` = `192.168.56.15`) — ✅ HECHO

Se **reutilizó** la VM `SandboxWindows10` (de `GUIA-COMPLETA.md`) sin dañarla, clonando
desde su snapshot a una VM nueva independiente para el lab.

```bash
# 1. Apagar la VM original y clonar DESDE su snapshot a una VM nueva
VBoxManage controlvm SandboxWindows10 poweroff
VBoxManage clonevm SandboxWindows10 --snapshot CleanState \
  --name VictimWindows --register --mode machine

# 2. (La original queda intacta para otros proyectos; recuperable con:)
#    VBoxManage snapshot SandboxWindows10 restore CleanState

# 3. Arrancar el clon (nace con la IP del snapshot = .10)
VBoxManage startvm VictimWindows --type headless
```

Cambiar la IP del clon de `.10` a `.15` **dentro de Windows** (ver baches en §9 —
hazlo por RDP y con PowerShell **como Administrador**):

```powershell
Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false
New-NetIPAddress -InterfaceAlias Ethernet -IPAddress 192.168.56.15 -PrefixLength 24
```

Verificar y congelar:

```bash
ssh vboxuser@192.168.56.15
VBoxManage controlvm VictimWindows poweroff
VBoxManage snapshot VictimWindows take CleanState --description "Windows lab, IP .15, OpenSSH"
```

---

## 6. VM-0: Kali (`WormKaliAttacker` = `192.168.56.10`) — ✅ HECHO

Se usó la **imagen pre-construida de Kali para VirtualBox** (viene instalada, con usuario
`kali`/`kali` y **Guest Additions**), en vez del ISO installer. Esto evita por completo el
instalador **y** Remmina: todo se hace por terminal (SSH + `guestcontrol`).

> **Credenciales por defecto de la imagen prebuilt:** usuario `kali`, password `kali`.
> **SSH viene apagado** por defecto; se habilita por `guestcontrol` (ver abajo).

### 6.1 Descargar y registrar la imagen prebuilt

El índice navegable está en `cdimage.kali.org` (ojo: `kali.download/virtual-images/` da
404). Descubre el nombre exacto y descarga:

```bash
# Ver el archivo VirtualBox de la versión (ajusta kali-2026.2 a la actual)

# Extraer el .vbox + .vdi directo a la carpeta de VMs (para no meter el disco en el repo)
sudo apt install -y p7zip-full
7z x kali-linux-2026.2-virtualbox-amd64.7z -o"$HOME/VirtualBox VMs/"

# Registrar y renombrar
VBoxManage registervm "$HOME/VirtualBox VMs/kali-linux-2026.2-virtualbox-amd64/"*.vbox
VBoxManage list vms                                                  # ver el nombre original
VBoxManage modifyvm "kali-linux-2026.2-virtualbox-amd64" --name WormKaliAttacker
VBoxManage modifyvm WormKaliAttacker --memory 4096 --cpus 2
```

### 6.2 Arrancar en NAT y habilitar SSH sin GUI

```bash
# NAT con port-forward (2222 host -> 22 guest) para entrar por SSH
VBoxManage modifyvm WormKaliAttacker --nic1 nat
VBoxManage modifyvm WormKaliAttacker --natpf1 "ssh,tcp,,2222,,22"
VBoxManage startvm WormKaliAttacker --type headless

# Esperar ~40-60s al boot y habilitar SSH por guestcontrol.
# OJO sintaxis VBox 7: tras `--` van SOLO los args (argv[1..]); NO repetir "bash".
VBoxManage guestcontrol WormKaliAttacker run --username kali --password kali --wait-stdout --wait-stderr \
  --exe /bin/bash -- -c "echo kali | sudo -S systemctl enable --now ssh"

ssh -p 2222 kali@127.0.0.1        # password: kali
```

Instalar herramientas (con NAT/Internet, dentro de Kali):

```bash
sudo apt update && sudo apt install -y nmap curl python3-pip python3-venv git
ip -brief a                       # anotar el nombre de la NIC (fue eth0)
```

### 6.3 Flip a host-only + IP estática `.10`

```bash
VBoxManage controlvm WormKaliAttacker poweroff
VBoxManage modifyvm WormKaliAttacker --natpf1 delete ssh
VBoxManage modifyvm WormKaliAttacker --nic1 hostonly --hostonlyadapter1 vboxnet0
VBoxManage startvm WormKaliAttacker --type headless

# Fijar la IP por guestcontrol (Kali usa NetworkManager). Esperar el boot; si da
# "Guest Additions not ready", reintentar a los pocos segundos.
VBoxManage guestcontrol WormKaliAttacker run --username kali --password kali --wait-stdout --wait-stderr \
  --exe /bin/bash -- -c "echo kali | sudo -S nmcli con add type ethernet ifname eth0 con-name hostonly ipv4.method manual ipv4.addresses 192.168.56.10/24 autoconnect yes; echo kali | sudo -S nmcli con up hostonly"
```

### 6.4 Verificar y congelar

```bash
# .10 antes era la VM Windows -> host key cambió -> borrar la clave vieja:
ssh-keygen -f ~/.ssh/known_hosts -R 192.168.56.10
ssh kali@192.168.56.10            # aceptar fingerprint (yes), password: kali

VBoxManage controlvm WormKaliAttacker poweroff
VBoxManage snapshot WormKaliAttacker take CleanState --description "Kali atacante, IP .10, SSH + herramientas"
```

> **Estado:** ✅ hecho.

### 6.5 Internet para Kali durante desarrollo (opcional, NO en el snapshot)

Para `git pull` / instalar dependencias / debuggear el agente, Kali puede tener internet
**sin perder** la IP `.10` del lab: se le agrega un **segundo adaptador NAT** (`eth1`),
dejando `eth0` en host-only. NO lo hagas cambiando `nic1` a NAT (eso le quita el `.10` y
el atacante deja de ver a las víctimas — `nmap` sale "all filtered").

```bash
VBoxManage controlvm WormKaliAttacker poweroff
VBoxManage modifyvm WormKaliAttacker --nic1 hostonly --hostonlyadapter1 vboxnet0  # eth0 = .10
VBoxManage modifyvm WormKaliAttacker --nic2 nat                                    # eth1 = internet
VBoxManage startvm WormKaliAttacker --type headless
# dentro: ip -brief a  ->  eth0=192.168.56.10 , eth1=10.0.2.15 ; ping 8.8.8.8 OK
```

> Es un **toggle de desarrollo**: `nic2` NO está en `CleanState` (aislado a propósito).
> Para la prueba real de aislamiento, restaura el snapshot o quita el NIC:
> `VBoxManage modifyvm WormKaliAttacker --nic2 none`.

---

## 7. VM-1 / VM-2 / VM-3: víctimas Linux

Base común (ejemplo VM-1; repetir cambiando nombre/IP/disco):

```bash
VBoxManage createvm --name VictimLinux1 --ostype "Debian_64" --register
VBoxManage modifyvm VictimLinux1 --memory 2048 --cpus 1 --nic1 nat
VBoxManage createhd --filename "$HOME/VirtualBox VMs/VictimLinux1/disk.vdi" --size 15000
VBoxManage storagectl VictimLinux1 --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach VictimLinux1 --storagectl "SATA" --port 0 --device 0 --type hdd \
  --medium "$HOME/VirtualBox VMs/VictimLinux1/disk.vdi"
VBoxManage storageattach VictimLinux1 --storagectl "SATA" --port 1 --device 0 --type dvddrive \
  --medium "$HOME/ScyWare/VirtualMachineConf/isos/debian.iso"
```

Aprovisionamiento de vulnerabilidades:

- **VM-1 (`.11`) — SSH débil:**
  ```bash
  sudo useradd -m -s /bin/bash test && echo "test:test123" | sudo chpasswd
  sudo systemctl enable --now ssh
  ```
- **VM-2 (`.12`) — Command Injection + `.env` expuesto:** app Flask `/ping?ip=` que hace
  `os.popen(f"ping -c 1 {ip}")`, y `/var/www/html/.env` con credenciales de la VM-3.
- **VM-3 (`.13`) — servicio vulnerable:** `vsftpd 2.3.4` o Samba desactualizado.

Cada VM: pasar a host-only, fijar su IP, verificar y `snapshot take CleanState`.

> **Estado:** ⬜ pendiente.

---

## 7bis. VM-4: Metasploitable 2 (`VictimMetasploitable` = `192.168.56.14`)

Víctima "de fábrica": imagen **pre-construida** deliberadamente vulnerable (Ubuntu 8.04,
`msfadmin`/`msfadmin`, SSH ya corriendo). No hay instalador ni Guest Additions; la IP se
fija por SSH editando `/etc/network/interfaces`. Procedimiento detallado y superficie de
ataque en `virtualbox/04-metasploitable/README.md`. Resumen:

```bash
cd ~/ScyWare/VirtualMachineConf/virtualbox/04-metasploitable
# (Descarga/descomprime el .vmdk antes — README §1)
./create-metasploitable.sh                      # NAT + port-forward 2222->22
VBoxManage startvm VictimMetasploitable --type headless
ssh -p 2222 msfadmin@127.0.0.1                  # pass: msfadmin -> fija IP .14 (README §3)
# flip a host-only + snapshot CleanState (README §4)
```

> **OJO — SSH legacy:** Metasploitable2 corre OpenSSH 4.7 y solo ofrece `ssh-rsa`/`ssh-dss`.
> Los clientes modernos lo rechazan (`no matching host key type`). Conéctate SIEMPRE con:
> ```bash
> ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa \
>     -o KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group-exchange-sha1 \
>     -o Ciphers=+aes128-cbc,3des-cbc -o MACs=+hmac-sha1 msfadmin@192.168.56.14
> ```
> (o deja esas opciones fijas en `~/.ssh/config` — ver README §2).

> **Estado:** ✅ hecho. IP `.14` verificada, snapshot `CleanState` tomado.

---

## 8. Verificación y reversión

**Aislamiento** (desde `WormKaliAttacker`):

```bash
ping -c1 8.8.8.8                 # DEBE FALLAR (sin Internet)
ping -c1 192.168.56.11          # DEBE responder (inter-VM OK)
curl http://192.168.56.1:8080/health   # DEBE responder (proxy OK)
```

**Reversión de todo el lab a estado limpio:**

```bash
for vm in WormKaliAttacker VictimLinux1 VictimLinux2 VictimLinux3 VictimMetasploitable VictimWindows; do
    VBoxManage controlvm $vm poweroff 2>/dev/null
    VBoxManage snapshot $vm restore CleanState
    VBoxManage startvm $vm --type headless
done
```

> El nombre de snapshot debe ser **`CleanState`** en las 5 VMs para que el loop funcione.

---

## 9. Troubleshooting (baches encontrados y resueltos)

| Síntoma | Causa | Solución |
|---|---|---|
| `VERR_VMX_IN_VMX_ROOT_MODE` al arrancar una VM | KVM cargado usando VT-x | `sudo modprobe -r kvm_intel kvm` (§2.1) |
| SSH se congela al cambiar la IP desde dentro | Borraste la IP por la que estabas conectado | Cambia IP por **RDP** (consola gráfica), no por SSH; o por `guestcontrol` si hay Guest Additions |
| `Remove-NetIPAddress: Acceso denegado` / Error 5 | PowerShell no elevado | Abrir PowerShell **como Administrador** |
| VM queda sin IP (ni vieja ni nueva) | `Remove` corrió pero `New` no (sesión SSH murió antes) | Entrar por RDP y reasignar la IP |
| Remmina: `Failed to connect to RDP server 127.0.0.1` | Remmina corre en el **portátil**; `127.0.0.1` = portátil, no el server | Usar la **IP LAN del server** + puerto VRDE: `192.168.78.104:3390` |
| VRDE `on` pero no conecta | Falta Extension Pack, o puerto equivocado | `VBoxManage list extpacks`; confirmar puerto con `ss -tlnp \| grep 339x` |
| `Guest Additions are not installed or not ready` en `guestcontrol` | No hay GA, **o** la VM acaba de bootear y `VBoxService` aún no levanta | Si hay GA (imagen prebuilt): esperar unos segundos y **reintentar**. Si no hay GA: ir por RDP |
| `ssh: No route to host` justo tras arrancar | VM aún booteando / sin IP asignada | Esperar 1-2 min; no confíes en `ping` (Windows bloquea ICMP), usa `nc -vz IP 22` |
| `guestcontrol`: `/usr/bin/bash: ...: cannot execute binary file` | En VBox 7, tras `--` van SOLO los args (`argv[1..]`); repetir el nombre del programa lo mete como script | No repitas `bash`: `--exe /bin/bash -- -c "comando"` |
| SSH: `REMOTE HOST IDENTIFICATION HAS CHANGED` | Reutilizaste una IP para otra máquina (p.ej. `.10` pasó de Windows a Kali) | `ssh-keygen -f ~/.ssh/known_hosts -R <IP>` y reconectar |
| `VERR_VMX_IN_VMX_ROOT_MODE` **de nuevo tras un reboot** | KVM se recarga solo en cada arranque del server | Repetir `sudo modprobe -r kvm_intel kvm`; o poner KVM en blacklist para que no cargue |
| SSH a Metasploitable: `no matching host key type found. Their offer: ssh-rsa,ssh-dss` | OpenSSH 4.7 (2007) solo ofrece algoritmos legacy que el cliente moderno rechaza | Conectar con `-o HostKeyAlgorithms=+ssh-rsa -o KexAlgorithms=+diffie-hellman-group1-sha1,... -o Ciphers=+aes128-cbc,3des-cbc -o MACs=+hmac-sha1` (ver `04-metasploitable/README.md` §2) |
| `nmap` desde Kali sale "All ports filtered" aunque la víctima esté viva | Kali quedó **solo en NAT** (cambiaste `nic1` a nat); no tiene interfaz en `vboxnet0` | Volver `nic1` a host-only y agregar internet como `nic2 nat` (§6.5), no reemplazar el host-only |

### Recuperar una VM Windows con SSH roto (sin perder el snapshot)

```bash
VBoxManage controlvm <vm> poweroff
VBoxManage snapshot <vm> restore CleanState   # descarta el estado roto, vuelve al snapshot
VBoxManage startvm <vm> --type headless
```

### Cambiar IP de Windows sin cortarte (por RDP, PowerShell Admin)

```powershell
Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false
New-NetIPAddress -InterfaceAlias Ethernet -IPAddress <IP> -PrefixLength 24
```
