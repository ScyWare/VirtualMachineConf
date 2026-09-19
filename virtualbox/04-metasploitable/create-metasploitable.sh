#!/usr/bin/env bash
#
# create-metasploitable.sh — Registra la VM víctima Metasploitable 2 a partir de su
# imagen PRE-CONSTRUIDA (VMDK). No hay instalador: Metasploitable2 es un Ubuntu 8.04
# deliberadamente vulnerable que ya viene instalado, con SSH corriendo y usuario
# msfadmin/msfadmin. Igual que la imagen prebuilt de Kali, todo se hace por terminal.
#
# Arranca en NAT con port-forward (2222 host -> 22 guest) para entrar por SSH y
# fijarle la IP estática host-only. El flip a host-only + IP .14 va en el README (§3-4),
# porque Metasploitable2 NO tiene Guest Additions (no hay guestcontrol): la IP se
# configura por SSH editando /etc/network/interfaces.
#
# Uso:
#   1) Descarga y descomprime la imagen (ver README §1). Deja el .vmdk en una ruta.
#   2) VMDK_PATH=/ruta/al/Metasploitable.vmdk ./create-metasploitable.sh
#
set -euo pipefail

VM_NAME="${VM_NAME:-VictimMetasploitable}"
VM_RAM_MB="${VM_RAM_MB:-1024}"
VM_CPUS="${VM_CPUS:-1}"
SSH_PF_PORT="${SSH_PF_PORT:-2222}"   # puerto del host que reenvía al 22 del guest

# Metasploitable2 es i386 (32-bit), kernel 2.6 -> ostype Ubuntu (32-bit).
OS_TYPE="${OS_TYPE:-Ubuntu}"

# La imagen viene como Metasploitable.vmdk dentro del zip. Por defecto la buscamos en la
# carpeta de VMs de VirtualBox; puedes sobreescribir con VMDK_PATH.
VM_DIR="$(VBoxManage list systemproperties | awk -F': *' '/Default machine folder/{print $2}')"
VMDK_PATH="${VMDK_PATH:-${VM_DIR}/${VM_NAME}/Metasploitable.vmdk}"

[ -f "$VMDK_PATH" ] || {
  echo "VMDK no encontrado: $VMDK_PATH" >&2
  echo "Descárgalo/descomprímelo primero (ver README §1) y define VMDK_PATH." >&2
  exit 1
}
if VBoxManage list vms | grep -q "\"${VM_NAME}\""; then
  echo "La VM '${VM_NAME}' ya existe. Bórrala con: VBoxManage unregistervm ${VM_NAME} --delete" >&2
  exit 1
fi

echo "== Creando VM ${VM_NAME} (Metasploitable 2) =="
VBoxManage createvm --name "$VM_NAME" --ostype "$OS_TYPE" --register

VBoxManage modifyvm "$VM_NAME" \
  --memory "$VM_RAM_MB" --cpus "$VM_CPUS" \
  --ioapic on --rtcuseutc on \
  --nic1 nat                                    # NAT temporal para entrar por SSH
VBoxManage modifyvm "$VM_NAME" --natpf1 "ssh,tcp,,${SSH_PF_PORT},,22"

echo "== Adjuntando el disco VMDK (controlador IDE, como la imagen original) =="
# Metasploitable2 espera IDE; con IDE arranca sin tocar fstab del guest.
VBoxManage storagectl "$VM_NAME" --name "IDE" --add ide --controller PIIX4
VBoxManage storageattach "$VM_NAME" --storagectl "IDE" --port 0 --device 0 \
  --type hdd --medium "$VMDK_PATH"
VBoxManage modifyvm "$VM_NAME" --boot1 disk --boot2 none --boot3 none --boot4 none

echo
echo "✔ VM '${VM_NAME}' registrada."
echo "  Arráncala:  VBoxManage startvm ${VM_NAME} --type headless"
echo "  Espera ~30-60s y entra:  ssh -p ${SSH_PF_PORT} msfadmin@127.0.0.1   (pass: msfadmin)"
echo "  Luego sigue el README §3 (IP estática .14) y §4 (flip a host-only + snapshot)."
