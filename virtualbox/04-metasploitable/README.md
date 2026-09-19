# 04 — VM víctima Metasploitable 2 (headless, SSH)

VM-4 del laboratorio: **`VictimMetasploitable` = `192.168.56.14`**. Máquina
**deliberadamente vulnerable** (Ubuntu 8.04) para practicar desde Kali (`.10`).

Se usa la **imagen pre-construida (VMDK)** de Metasploitable 2, igual que hicimos con la
imagen prebuilt de Kali: **no hay instalador**. Viene con SSH corriendo y usuario
`msfadmin`/`msfadmin`. Todo se maneja por terminal (SSH), sin GUI ni Remmina.

> **Credenciales por defecto:** `msfadmin` / `msfadmin` (también `root`/`msfadmin` en algunos servicios).
> Metasploitable2 **NO tiene Guest Additions** → no hay `guestcontrol`: la IP se fija por SSH.

---

## 1. Descargar la imagen (en el server, con Internet)

Metasploitable 2 se distribuye en SourceForge como un zip con el `.vmdk`:

```bash
cd ~/Downloads
# Página del proyecto: https://sourceforge.net/projects/metasploitable/files/Metasploitable2/
wget -O metasploitable-linux-2.0.0.zip \
  "https://sourceforge.net/projects/metasploitable/files/Metasploitable2/metasploitable-linux-2.0.0.zip/download"

sudo apt install -y unzip
# Extraer el .vmdk directo a la carpeta de VMs (para no meter el disco en el repo git)
mkdir -p "$HOME/VirtualBox VMs/VictimMetasploitable"
unzip metasploitable-linux-2.0.0.zip -d /tmp/msf2
mv /tmp/msf2/Metasploitable2-Linux/Metasploitable.vmdk \
   "$HOME/VirtualBox VMs/VictimMetasploitable/Metasploitable.vmdk"
```

> El nombre exacto de la carpeta interna del zip puede variar
> (`Metasploitable2-Linux/`). Ajusta la ruta del `mv` según lo que veas con
> `unzip -l metasploitable-linux-2.0.0.zip`.

---

## 2. Crear/registrar la VM en NAT

```bash
cd ~/ScyWare/VirtualMachineConf/virtualbox/04-metasploitable
./create-metasploitable.sh          # usa el VMDK de ~/VirtualBox VMs/VictimMetasploitable/

# Arrancar headless y entrar por SSH (NAT port-forward 2222 -> 22)
VBoxManage startvm VictimMetasploitable --type headless
sleep 45
ssh -p 2222 msfadmin@127.0.0.1      # password: msfadmin
```

> Si ya usaste `127.0.0.1:2222` para otra VM antes:
> `ssh-keygen -f ~/.ssh/known_hosts -R "[127.0.0.1]:2222"` y reconecta.

```bash
ssh -p 2222 \
    -o HostKeyAlgorithms=+ssh-rsa \
    -o PubkeyAcceptedAlgorithms=+ssh-rsa \
    -o KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group-exchange-sha1 \
    -o Ciphers=+aes128-cbc,3des-cbc \
    -o MACs=+hmac-sha1 \
    msfadmin@127.0.0.1
```

contraseña: `msfadmin`.

> **Por qué:** Metasploitable2 corre OpenSSH 4.7 (2007) y solo ofrece `ssh-rsa`/`ssh-dss`;
> los clientes modernos los rechazan por inseguros (`no matching host key type`). Hay que
> permitirlos explícitamente en el cliente. Aplica igual cuando esté en `.14` (host-only).

Para no repetir las opciones, déjalas fijas en `~/.ssh/config` (en el host):

```
Host msf-nat
    HostName 127.0.0.1
    Port 2222
    User msfadmin
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
    KexAlgorithms +diffie-hellman-group1-sha1,diffie-hellman-group-exchange-sha1
    Ciphers +aes128-cbc,3des-cbc
    MACs +hmac-sha1

Host msf
    HostName 192.168.56.14
    User msfadmin
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
    KexAlgorithms +diffie-hellman-group1-sha1,diffie-hellman-group-exchange-sha1
    Ciphers +aes128-cbc,3des-cbc
    MACs +hmac-sha1
```

Así te conectas con `ssh msf-nat` (por NAT) o `ssh msf` (en host-only `.14`).

---

## 3. Fijar IP estática `.14` (por SSH, editando /etc/network/interfaces)

`vboxnet0` **no tiene DHCP** (el lab usa IPs estáticas), y Metasploitable2 trae `eth0`
en `dhcp`. Cámbialo a estático **antes** del flip a host-only. Dentro de la VM (por SSH):

```bash
sudo tee /etc/network/interfaces >/dev/null <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.56.14
    netmask 255.255.255.0
EOF
```

> Sin `gateway` a propósito: la víctima **no debe tener salida a Internet** (§8 de la guía
> del lab). No lo apliques todavía por SSH (te cortarías): se activa al reiniciar en el §4.

---

## 4. Flip a host-only + verificar + congelar

```bash
# Apagar, quitar el port-forward y pasar el adaptador a host-only
VBoxManage controlvm VictimMetasploitable poweroff
VBoxManage modifyvm VictimMetasploitable --natpf1 delete ssh
VBoxManage modifyvm VictimMetasploitable --nic1 hostonly --hostonlyadapter1 vboxnet0
VBoxManage startvm VictimMetasploitable --type headless

# Verificar desde el host (o desde Kali .10) — usa las opciones legacy o `ssh msf`
sleep 45
ssh msf                             # (alias de ~/.ssh/config) password: msfadmin
#   dentro: ip -4 a  ->  debe mostrar 192.168.56.14

# si no funciona

ssh \
  -o HostKeyAlgorithms=+ssh-rsa \
  -o PubkeyAcceptedAlgorithms=+ssh-rsa \
  -o KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group-exchange-sha1 \
  -o Ciphers=+aes128-cbc,3des-cbc \
  -o MACs=+hmac-sha1 \
  msfadmin@192.168.56.14

# Congelar en estado limpio (nombre CleanState, como el resto del lab)
VBoxManage controlvm VictimMetasploitable poweroff
VBoxManage snapshot VictimMetasploitable take CleanState \
  --description "Metasploitable 2 victima, IP .14, SSH"
```

---

## 5. Superficie de ataque (para practicar desde Kali)

Metasploitable2 expone, entre otros: FTP `vsftpd 2.3.4` (backdoor, :21), SSH viejo (:22),
Telnet (:23), SMTP (:25), web con DVWA/Mutillidae (:80), Samba (:139/:445), `distccd`
(:3632), PostgreSQL/MySQL, `UnrealIRCd` (:6667, backdoor). Escanéalo desde Kali:

```bash
nmap -sV 192.168.56.14
```

> **Estado:** ⬜ pendiente. Ver la topología completa en `../../GUIA-LABORATORIO.md`.

---

## Notas / baches probables

| Síntoma | Causa | Solución |
|---|---|---|
| VM arranca pero no bootea el disco | VMDK adjunto en SATA en vez de IDE | Metasploitable2 espera **IDE**; el script ya usa `--add ide` |
| `ssh -p 2222` rechaza / cuelga | La VM aún bootea (Ubuntu 8.04 tarda) | Espera 45-60s; reintenta |
| Tras flip no responde en `.14` | `eth0` seguía en DHCP | Aplicaste bien el §3 antes del flip; si no, entra por consola VBox y edita `/etc/network/interfaces` |
| `VERR_VMX_IN_VMX_ROOT_MODE` al arrancar | KVM cargado usando VT-x | `sudo modprobe -r kvm_intel kvm` (ver guía del lab §2.1) |
