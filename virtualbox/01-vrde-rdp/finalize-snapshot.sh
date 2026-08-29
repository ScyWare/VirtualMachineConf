#!/usr/bin/env bash
#
# finalize-snapshot.sh — Aísla la VM (host-only) y crea el snapshot 'CleanState'.
# Ejecutar SOLO cuando Windows ya tiene OpenSSH funcionando e IP estática 192.168.56.10.
#
set -euo pipefail

VM_NAME="${VM_NAME:-SandboxWindows10}"
SNAPSHOT_NAME="${SNAPSHOT_NAME:-CleanState}"
VM_IP="${VM_IP:-192.168.56.10}"

echo "== [1/4] Apagando la VM =="
if VBoxManage list runningvms | grep -q "\"${VM_NAME}\""; then
  VBoxManage controlvm "$VM_NAME" acpipowerbutton || true
  # Esperar apagado limpio hasta 60 s
  for _ in $(seq 1 30); do
    VBoxManage list runningvms | grep -q "\"${VM_NAME}\"" || break
    sleep 2
  done
  VBoxManage controlvm "$VM_NAME" poweroff 2>/dev/null || true
fi

echo "== [2/4] Cambiando adaptador 1 a host-only vboxnet0 (corta Internet) =="
VBoxManage modifyvm "$VM_NAME" --nic1 hostonly --hostonlyadapter1 vboxnet0
# Desmontar el ISO para que no vuelva a bootear al instalador
VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium none || true
VBoxManage modifyvm "$VM_NAME" --boot1 disk --boot2 none

echo "== [3/4] Arrancando aislada y probando SSH desde el server =="
VBoxManage startvm "$VM_NAME" --type headless
echo "  Esperando a que Windows levante SSH en ${VM_IP} ..."
for _ in $(seq 1 30); do
  if nc -z -w2 "$VM_IP" 22 2>/dev/null; then echo "  SSH abierto en ${VM_IP}:22"; break; fi
  sleep 3
done

echo "== [4/4] Tomando snapshot '${SNAPSHOT_NAME}' =="
VBoxManage controlvm "$VM_NAME" poweroff 2>/dev/null || true
sleep 3
VBoxManage snapshot "$VM_NAME" take "$SNAPSHOT_NAME" --description "Estado estéril con OpenSSH, red host-only"

echo
echo "✔ Listo. Snapshot '${SNAPSHOT_NAME}' creado. Configura el .env del malware-agent:"
echo "   VM_NAME=${VM_NAME}  IP=${VM_IP}  SNAPSHOT=${SNAPSHOT_NAME}"
