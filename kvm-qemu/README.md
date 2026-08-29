# Alternativa — KVM / QEMU + libvirt

VirtualBox funciona, pero KVM es el hipervisor **nativo de Linux**: más ligero,
headless de fábrica, mejor rendimiento y sin módulos DKMS que recompilar en cada
kernel. La contra: el agente (`WindowsVMSandboxToolKit.py`) está escrito contra
`VBoxManage`, así que **hay que adaptar `reset_sandbox()`** a `virsh` (ver
`toolkit-virsh-notes.md`). Por eso es la vía "a explorar", no la de arranque.

## Panorama

| | VirtualBox | KVM/QEMU + libvirt |
|---|---|---|
| Headless | Sí (con truco de setup) | **Nativo** |
| Rendimiento | Bueno | **Mejor** (virtualización de tipo 1 sobre KVM) |
| Módulos kernel | `vboxdrv` vía DKMS | `kvm_intel` en el kernel mainline (ya cargado) |
| Snapshots | `VBoxManage snapshot` | `virsh snapshot-*` (interno qcow2 o externo) |
| Red aislada | host-only `vboxnet0` | red libvirt `isolated` |
| Control CLI | `VBoxManage` | `virsh` / `virt-install` |
| Cambio en el agente | **Ninguno** | Adaptar `reset_sandbox()` a `virsh` |

## Requisitos

- VT-x (confirmado) y `/dev/kvm` presente (`ls -l /dev/kvm`).
- Debian 13; todo viene de los repos oficiales (sin repos externos).

## ⚠️ Incompatible con VirtualBox (VT-x)

KVM y VirtualBox **no pueden usar VT-x a la vez**. Si vienes del camino
[`../virtualbox/`](../virtualbox/) y blacklisteaste los módulos de KVM, KVM no
funcionará hasta revertirlo:

```bash
sudo rm -f /etc/modprobe.d/blacklist-kvm.conf
sudo update-initramfs -u
sudo reboot
```

Tras el reboot, verifica que `kvm_intel` está cargado (`lsmod | grep kvm`) y que
**ninguna VM de VirtualBox está corriendo** (`VBoxManage list runningvms`).

## Pasos

```bash
sudo ./01-install-kvm.sh              # qemu-kvm, libvirt, virtinst, virt-viewer
sudo ./02-create-isolated-network.sh  # red 'sandbox-isolated' (192.168.56.0/24, sin salida)
# ISO por defecto: <repo>/isos/Win10_x64.iso  (exporta ISO_PATH solo si usas otra ruta)
sudo ./03-create-windows-vm.sh        # crea e instala Windows (consola VNC para el setup)
```

Instala Windows conectándote por VNC/SPICE (el script imprime el puerto), configura
OpenSSH e IP estática `192.168.56.10` igual que en los caminos de VirtualBox, y
crea el snapshot:

```bash
virsh snapshot-create-as SandboxWindows10 CleanState \
  "Estado esteril con OpenSSH y red aislada" --atomic
```

## Reset como hace el agente

Equivalencias `VBoxManage` → `virsh` (detalle en `toolkit-virsh-notes.md`):

| VirtualBox | virsh |
|---|---|
| `VBoxManage controlvm <vm> poweroff` | `virsh destroy <vm>` |
| `VBoxManage snapshot <vm> restore CleanState` | `virsh snapshot-revert <vm> CleanState --force` |
| `VBoxManage startvm <vm> --type headless` | `virsh start <vm>` (o `snapshot-revert --running`) |

## Aislamiento

La red `sandbox-isolated` se define **sin `<forward>`**: los guests hablan entre sí y
con el host, pero **no tienen ruta a Internet ni a la LAN** — equivalente al
host-only de VirtualBox. Verifícalo desde Windows: no debe haber ping a `8.8.8.8`.
