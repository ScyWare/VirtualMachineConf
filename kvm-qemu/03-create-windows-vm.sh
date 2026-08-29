#!/usr/bin/env bash
#
# 03-create-windows-vm.sh — Crea la VM de Windows 10 en KVM con virt-install.
# Deja una consola VNC para instalar Windows a mano (o adjunta un autounattend.xml).
#
# NOTA: para la INSTALACIÓN necesitas salida a Internet (OpenSSH). Aquí usamos la red
# NAT 'default' de libvirt; tras instalar y aislar, se cambia a 'sandbox-isolated'.
#
set -euo pipefail

VM_NAME="${VM_NAME:-SandboxWindows10}"
VM_RAM_MB="${VM_RAM_MB:-4096}"
VM_CPUS="${VM_CPUS:-2}"
VM_DISK_GB="${VM_DISK_GB:-50}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "${SCRIPT_DIR}/..")"
ISO_PATH="${ISO_PATH:-$REPO_ROOT/isos/Win10_x64.iso}"
DISK_DIR="${DISK_DIR:-/var/lib/libvirt/images}"
DISK_PATH="${DISK_DIR}/${VM_NAME}.qcow2"

[ -f "$ISO_PATH" ] || { echo "ISO no encontrado: $ISO_PATH" >&2; exit 1; }

# Asegurar la red NAT default para la fase de instalación
virsh net-start default 2>/dev/null || true

echo "== Creando VM ${VM_NAME} (disco qcow2 ${VM_DISK_GB}G) =="
# virtio para disco/red da mejor rendimiento; requiere drivers virtio en Windows.
# Si no quieres lidiar con drivers virtio durante el setup, cambia:
#   --disk bus=virtio -> bus=sata   y   --network model=virtio -> model=e1000e
virt-install \
  --name "$VM_NAME" \
  --memory "$VM_RAM_MB" \
  --vcpus "$VM_CPUS" \
  --cpu host-passthrough \
  --os-variant win10 \
  --disk path="${DISK_PATH}",size="${VM_DISK_GB}",format=qcow2,bus=sata \
  --cdrom "$ISO_PATH" \
  --network network=default,model=e1000e \
  --graphics vnc,listen=127.0.0.1 \
  --video qxl \
  --boot uefi \
  --noautoconsole

echo
echo "✔ VM creada e instalando. Consola VNC (solo localhost):"
virsh vncdisplay "$VM_NAME" | sed 's/^/   /'
cat <<EOF

  Desde tu portátil, tuneliza el VNC y conéctate con un cliente VNC:

      ssh -L 5900:localhost:5900 ${USER}@somath-server
      # cliente VNC -> localhost:5900   (ajusta el número de display de arriba)

  Instala Windows (usuario vboxuser), OpenSSH e IP estática 192.168.56.10.
  Luego AÍSLA la red y toma el snapshot:

      virsh destroy ${VM_NAME}
      virsh detach-interface ${VM_NAME} network --config      # quita la NAT
      virsh attach-interface ${VM_NAME} network sandbox-isolated --model e1000e --config
      virsh start ${VM_NAME}
      virsh snapshot-create-as ${VM_NAME} CleanState "Estado esteril" --atomic
EOF
