#!/usr/bin/env bash
#
# create-and-install-vm.sh — Crea la VM e instala Windows 10 de forma DESATENDIDA
# con 'VBoxManage unattended'. El post-install ejecuta provision.ps1 (OpenSSH, etc.).
#
set -euo pipefail

VM_NAME="${VM_NAME:-SandboxWindows10}"
VM_RAM_MB="${VM_RAM_MB:-4096}"
VM_CPUS="${VM_CPUS:-2}"
VM_DISK_GB="${VM_DISK_GB:-50}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "${SCRIPT_DIR}/../..")"
ISO_PATH="${ISO_PATH:-$REPO_ROOT/isos/Win10_x64.iso}"
VM_USER="${VM_USER:-vboxuser}"
VM_PASSWORD="${VM_PASSWORD:-changeme}"
LOCALE="${LOCALE:-en_US}"
COUNTRY="${COUNTRY:-US}"
TZ_VBOX="${TZ_VBOX:-America/Bogota}"

PROVISION="${SCRIPT_DIR}/provision.ps1"

[ -f "$ISO_PATH" ]  || { echo "ISO no encontrado: $ISO_PATH" >&2; exit 1; }
[ -f "$PROVISION" ] || { echo "Falta provision.ps1 junto a este script" >&2; exit 1; }
if VBoxManage list vms | grep -q "\"${VM_NAME}\""; then
  echo "La VM '${VM_NAME}' ya existe. Bórrala: VBoxManage unregistervm ${VM_NAME} --delete" >&2
  exit 1
fi

VM_DIR="$(VBoxManage list systemproperties | awk -F': *' '/Default machine folder/{print $2}')"
DISK_PATH="${VM_DIR}/${VM_NAME}/${VM_NAME}.vdi"

echo "== [1/3] Creando VM y disco =="
VBoxManage createvm --name "$VM_NAME" --ostype Windows10_64 --register
VBoxManage modifyvm "$VM_NAME" \
  --memory "$VM_RAM_MB" --cpus "$VM_CPUS" --ioapic on --rtcuseutc on \
  --nested-hw-virt on --graphicscontroller vboxsvga --vram 128 \
  --nic1 nat                                     # NAT: el post-install necesita Internet
VBoxManage createmedium disk --filename "$DISK_PATH" --size "$((VM_DISK_GB * 1024))" --format VDI
VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci --portcount 2
VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$DISK_PATH"

echo "== [2/3] Codificando provision.ps1 para el post-install =="
# PowerShell -EncodedCommand espera UTF-16LE en base64.
ENCODED="$(iconv -f UTF-8 -t UTF-16LE "$PROVISION" | base64 -w0)"
POST_CMD="powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${ENCODED}"

echo "== [3/3] Instalación desatendida (headless) =="
VBoxManage unattended install "$VM_NAME" \
  --iso="$ISO_PATH" \
  --user="$VM_USER" --password="$VM_PASSWORD" \
  --full-user-name="$VM_USER" \
  --locale="$LOCALE" --country="$COUNTRY" --time-zone="$TZ_VBOX" \
  --install-additions \
  --post-install-command="$POST_CMD" \
  --start-vm=headless

cat <<EOF

✔ Instalación desatendida lanzada en headless. Tarda ~10–25 min.
  Sigue el progreso esperando el puerto SSH:

      until nc -z -w2 192.168.56.10 22; do sleep 5; done && echo "SSH arriba"

  Cuando responda, aísla y congela el snapshot:

      ../01-vrde-rdp/finalize-snapshot.sh

  (Para ver la pantalla durante el debug: VBoxManage modifyvm ${VM_NAME} --vrde on)
EOF
