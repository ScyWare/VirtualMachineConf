# Comandos útiles de VirtualBox (VBoxManage)

Guía práctica de `VBoxManage`, la CLI de VirtualBox — ideal para un server **headless**
(sin GUI). Todo lo que la interfaz gráfica hace, se puede hacer por aquí.

> Ayuda integrada: `VBoxManage` (lista todos los subcomandos) y
> `VBoxManage <subcomando> --help` (detalle de uno). Ejemplo: `VBoxManage modifyvm --help`.
> En estos ejemplos la VM se llama `SandboxWindows10`; cámbialo por el tuyo.

---

## 1. Ver / listar máquinas virtuales

```bash
VBoxManage list vms                 # todas las VMs registradas (nombre + UUID)
VBoxManage list runningvms          # solo las que están encendidas
VBoxManage list ostypes            # tipos de SO válidos para --ostype (Windows10_64, Ubuntu_64, ...)
VBoxManage list hostonlyifs         # interfaces host-only (vboxnet0, IPs)
VBoxManage list bridgedifs          # interfaces físicas para modo bridged
VBoxManage list extpacks            # Extension Packs instalados
VBoxManage list systemproperties    # rutas por defecto, límites, etc.
```

**Detalle de una VM** (hardware, red, snapshots, estado):

```bash
VBoxManage showvminfo SandboxWindows10
VBoxManage showvminfo SandboxWindows10 --machinereadable    # formato clave=valor (para scripts)
VBoxManage showvminfo SandboxWindows10 | grep -iE 'State|Memory|NIC|VRDE'   # filtrar
```

---

## 2. Encender y apagar

```bash
# Encender
VBoxManage startvm SandboxWindows10 --type headless   # sin ventana (server): lo normal
VBoxManage startvm SandboxWindows10 --type gui        # con ventana (solo si hay escritorio)
VBoxManage startvm SandboxWindows10 --type separate   # ventana separada, controlable aparte

# Apagar / controlar (VM encendida)
VBoxManage controlvm SandboxWindows10 acpipowerbutton # apagado LIMPIO (como botón de power)
VBoxManage controlvm SandboxWindows10 poweroff        # apagado FORZADO (como cortar la luz)
VBoxManage controlvm SandboxWindows10 savestate       # "hibernar": congela y guarda el estado
VBoxManage controlvm SandboxWindows10 pause           # pausar
VBoxManage controlvm SandboxWindows10 resume          # reanudar tras pause
VBoxManage controlvm SandboxWindows10 reset           # reinicio en caliente (como reset físico)
```

> **Regla práctica:** para apagar usa `acpipowerbutton` (limpio); deja `poweroff` para
> cuando la VM no responde. Para "seguir mañana igual", `savestate`.

---

## 3. Snapshots (instantáneas)

Un snapshot congela el estado de la VM para volver a él después. Es el corazón del
sandbox (revertir el malware).

```bash
VBoxManage snapshot SandboxWindows10 list                          # listar snapshots
VBoxManage snapshot SandboxWindows10 take LimpioBase --description "estado inicial"
VBoxManage snapshot SandboxWindows10 restore LimpioBase            # volver a ese snapshot
VBoxManage snapshot SandboxWindows10 restorecurrent                # volver al último tomado
VBoxManage snapshot SandboxWindows10 delete LimpioBase             # borrar un snapshot
VBoxManage snapshot SandboxWindows10 edit LimpioBase --name NuevoNombre
```

> Para restaurar, la VM debe estar apagada:
> `VBoxManage controlvm <vm> poweroff` → `snapshot restore <n>` → `startvm ...`.
> Si tomas el snapshot con la VM **encendida**, guarda también la memoria (revierte a
> ese instante exacto); con la VM **apagada**, guarda solo el disco (arranque en frío).

---

## 4. Crear una VM nueva desde otro ISO (p. ej. otro SO)

Ejemplo: crear una VM de **Ubuntu** desde un ISO. Primero mira el `--ostype` correcto:

```bash
VBoxManage list ostypes | grep -i ubuntu     # -> Ubuntu_64 (o Ubuntu22_LTS_64, etc.)
```

Secuencia completa (adáptala; es lo mismo que hace `virtualbox/01-vrde-rdp/create-vm.sh`
pero genérico):

```bash
VM=MiUbuntu
ISO=~/ScyWare/VirtualMachineConf/isos/ubuntu.iso
VM_DIR="$(VBoxManage list systemproperties | awk -F': *' '/Default machine folder/{print $2}')"
DISK="${VM_DIR}/${VM}/${VM}.vdi"

# 1) Crear y registrar la VM
VBoxManage createvm --name "$VM" --ostype Ubuntu_64 --register

# 2) Hardware: RAM, CPUs, video, red NAT (Internet para instalar)
VBoxManage modifyvm "$VM" --memory 4096 --cpus 2 --vram 128 \
  --graphicscontroller vmsvga --nic1 nat --firmware efi     # Linux moderno: EFI

# 3) Disco virtual de 40 GB
VBoxManage createmedium disk --filename "$DISK" --size $((40*1024)) --format VDI

# 4) Controlador SATA + adjuntar disco e ISO
VBoxManage storagectl "$VM" --name SATA --add sata --controller IntelAhci --portcount 2
VBoxManage storageattach "$VM" --storagectl SATA --port 0 --device 0 --type hdd --medium "$DISK"
VBoxManage storageattach "$VM" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "$ISO"
VBoxManage modifyvm "$VM" --boot1 dvd --boot2 disk         # bootear del ISO primero

# 5) (Server headless) activar VRDE para instalar por RDP desde otro equipo
VBoxManage modifyvm "$VM" --vrde on --vrdeport 3390 --vrdeproperty "Security/Method=RDP"

# 6) Arrancar e instalar (conéctate por RDP a IP-del-server:3390)
VBoxManage startvm "$VM" --type headless
```

Tras instalar el SO, quita el ISO y cambia el arranque a disco:

```bash
VBoxManage storageattach "$VM" --storagectl SATA --port 1 --device 0 --type dvddrive --medium none
VBoxManage modifyvm "$VM" --boot1 disk
```

> **Nota Windows vs Linux:** el `--ostype` cambia (`Windows10_64`, `Ubuntu_64`, …), y
> para Linux moderno conviene `--firmware efi`. El resto del flujo (VRDE para instalar
> sin monitor) es igual. Usa un **puerto VRDE distinto** por VM si corres varias a la vez.

---

## 5. Modificar hardware de una VM (apagada)

```bash
VBoxManage modifyvm SandboxWindows10 --memory 8192          # 8 GB de RAM
VBoxManage modifyvm SandboxWindows10 --cpus 4               # 4 vCPUs
VBoxManage modifyvm SandboxWindows10 --vram 256            # memoria de video
VBoxManage modifyvm SandboxWindows10 --nested-hw-virt on    # virtualización anidada
VBoxManage modifyvm SandboxWindows10 --description "sandbox ransomware"
```

`modifyvm` solo funciona con la VM **apagada** (salvo unas pocas propiedades en caliente
vía `controlvm`).

---

## 6. Red — los modos y cómo se configuran

| Modo | Internet | VM↔host | VM↔VM | VM↔LAN | Uso típico |
|---|:---:|:---:|:---:|:---:|---|
| **NAT** | ✅ | ⛔ (salvo port-forward) | ⛔ | ⛔ | Internet de salida, aislada (default) |
| **Host-only** | ⛔ | ✅ | ✅ | ⛔ | **Nuestro sandbox** (aislado, host lo controla) |
| **Bridged** | ✅ | ✅ | ✅ | ✅ | La VM es "una más" en tu red física |
| **Internal** | ⛔ | ⛔ | ✅ | ⛔ | Solo VM↔VM, ni el host las ve |
| **NAT Network** | ✅ | ⛔ | ✅ | ⛔ | Varias VMs con Internet que se ven entre sí |

```bash
VBoxManage modifyvm <vm> --nic1 nat                                  # NAT
VBoxManage modifyvm <vm> --nic1 hostonly --hostonlyadapter1 vboxnet0 # host-only
VBoxManage modifyvm <vm> --nic1 bridged --bridgeadapter1 wlp0s20f3   # bridged (ver 'list bridgedifs')
VBoxManage modifyvm <vm> --nic1 intnet  --intnet1 lab               # interna llamada "lab"
```

**Interfaces host-only** (las que usa el sandbox):

```bash
VBoxManage hostonlyif create                                        # crea vboxnet0
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1 --netmask 255.255.255.0
VBoxManage hostonlyif remove vboxnet0                               # borrar
```

**Port forwarding en NAT** (p. ej. exponer el SSH de la VM en el host):

```bash
VBoxManage modifyvm <vm> --natpf1 "ssh,tcp,,2222,,22"   # host:2222 -> guest:22
VBoxManage modifyvm <vm> --natpf1 delete ssh            # quitarlo
```

---

## 7. Discos y almacenamiento

```bash
VBoxManage list hdds                                        # discos virtuales registrados
VBoxManage createmedium disk --filename disco.vdi --size 51200 --format VDI   # 50 GB
VBoxManage modifymedium disk disco.vdi --resize 102400     # agrandar a 100 GB
VBoxManage storagectl <vm> --name SATA --add sata          # añadir controlador
VBoxManage storageattach <vm> --storagectl SATA --port 0 --device 0 --type hdd --medium disco.vdi
VBoxManage storageattach <vm> --storagectl SATA --port 1 --device 0 --type dvddrive --medium none  # "sacar" el CD
VBoxManage closemedium disk disco.vdi --delete             # desregistrar y borrar el archivo
```

---

## 8. Clonar, exportar, importar

```bash
# Clonar una VM (full = copia independiente)
VBoxManage clonevm SandboxWindows10 --name SandboxCopia --mode all --register

# Exportar a un appliance OVA (portable, para llevar a otra máquina)
VBoxManage export SandboxWindows10 -o sandbox.ova

# Importar un OVA
VBoxManage import sandbox.ova
```

---

## 9. Borrar una VM

```bash
VBoxManage controlvm SandboxWindows10 poweroff 2>/dev/null   # apagar si corre
VBoxManage unregistervm SandboxWindows10 --delete            # ⚠️ borra la VM Y su disco
```

`--delete` es **irreversible**: elimina el `.vdi` y todos los snapshots.

---

## 10. Ejecutar comandos dentro de la VM (guestcontrol)

Requiere **Guest Additions** instaladas en el guest. Alternativa a SSH:

```bash
VBoxManage guestcontrol <vm> run --username user --password pass \
  --exe "C:\\Windows\\System32\\cmd.exe" -- cmd.exe /c "ipconfig"
VBoxManage guestcontrol <vm> copyto  archivo.txt "C:\\archivo.txt" --username user --password pass
```

> En nuestro sandbox no usamos esto: el agente controla la VM por **SSH** (más limpio y
> sin Guest Additions).

---

## 11. Dónde vive todo / misceláneos

```bash
VBoxManage --version                         # versión de VirtualBox
ls ~/"VirtualBox VMs"/                        # carpeta por defecto de las VMs y discos
VBoxManage list runningvms | wc -l           # cuántas VMs corriendo
VBoxManage setproperty machinefolder /ruta   # cambiar la carpeta por defecto de VMs
VBoxManage controlvm <vm> screenshotpng /tmp/vm.png   # captura de pantalla de la VM
```

---

### Chuleta mínima para el día a día

```bash
VBoxManage list vms                                   # ¿qué VMs tengo?
VBoxManage list runningvms                            # ¿cuáles están encendidas?
VBoxManage startvm SandboxWindows10 --type headless   # encender
VBoxManage controlvm SandboxWindows10 acpipowerbutton # apagar (limpio)
VBoxManage snapshot SandboxWindows10 restore CleanState  # volver al estado limpio
```
