#!/usr/bin/env bash
#
# create-vm.sh — Crea la VM de Windows 10 con VRDE activado para instalar por RDP.
# Adaptador 1 en NAT (temporal, para que el instalador tenga Internet y puedas
# instalar OpenSSH). Se cambia a host-only en finalize-snapshot.sh.
#
set -euo pipefail

VM_NAME="${VM_NAME:-SandboxWindows10}"
VM_RAM_MB="${VM_RAM_MB:-4096}"
VM_CPUS="${VM_CPUS:-2}"
VM_DISK_GB="${VM_DISK_GB:-50}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "${SCRIPT_DIR}/../..")"
ISO_PATH="${ISO_PATH:-$REPO_ROOT/isos/Win10_x64.iso}"
VRDE_PORT="${VRDE_PORT:-3389}"

VM_DIR="$(VBoxManage list systemproperties | awk -F': *' '/Default machine folder/{print $2}')"
DISK_PATH="${VM_DIR}/${VM_NAME}/${VM_NAME}.vdi"

[ -f "$ISO_PATH" ] || { echo "ISO no encontrado: $ISO_PATH (define ISO_PATH)" >&2; exit 1; }
if VBoxManage list vms | grep -q "\"${VM_NAME}\""; then
  echo "La VM '${VM_NAME}' ya existe. Bórrala con: VBoxManage unregistervm ${VM_NAME} --delete" >&2
  exit 1
fi

echo "== Creando VM ${VM_NAME} =="
VBoxManage createvm --name "$VM_NAME" --ostype Windows10_64 --register

VBoxManage modifyvm "$VM_NAME" \
  --memory "$VM_RAM_MB" --cpus "$VM_CPUS" \
  --ioapic on --pae off --rtcuseutc on \
  --nested-hw-virt on \
  --graphicscontroller vboxsvga --vram 128 \
  --nic1 nat                                   # NAT temporal para el instalador

echo "== Disco de ${VM_DISK_GB} GB =="
VBoxManage createmedium disk --filename "$DISK_PATH" --size "$((VM_DISK_GB * 1024))" --format VDI

echo "== Controladores + adjuntar disco e ISO =="
VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci --portcount 2
VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$DISK_PATH"
VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "$ISO_PATH"
VBoxManage modifyvm "$VM_NAME" --boot1 dvd --boot2 disk --boot3 none --boot4 none

echo "== Activando VRDE (escritorio remoto) en puerto ${VRDE_PORT} =="
VBoxManage modifyvm "$VM_NAME" --vrde on --vrdeport "$VRDE_PORT" --vrdeaddress ""
# Seguridad RDP estandar (sin TLS). El default "TLS" usa un cert autofirmado que
# Remmina/FreeRDP rechazan o cuelgan; en una red host-only aislada el cifrado TLS
# no aporta. Con "RDP" cualquier cliente conecta sin lidiar con certificados.
VBoxManage modifyvm "$VM_NAME" --vrdeproperty "Security/Method=RDP"

echo
echo "✔ VM '${VM_NAME}' creada. Siguiente: ./start-vm-vrde.sh"
