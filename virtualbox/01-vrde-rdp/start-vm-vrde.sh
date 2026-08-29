#!/usr/bin/env bash
#
# start-vm-vrde.sh — Arranca la VM headless con VRDE e imprime cómo conectar por RDP.
#
set -euo pipefail

VM_NAME="${VM_NAME:-SandboxWindows10}"
VRDE_PORT="${VRDE_PORT:-3389}"

if VBoxManage list runningvms | grep -q "\"${VM_NAME}\""; then
  echo "La VM '${VM_NAME}' ya está corriendo."
else
  echo "== Arrancando ${VM_NAME} en modo headless =="
  VBoxManage startvm "$VM_NAME" --type headless
fi

# IP LAN del server (la que ve tu portátil)
LAN_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
LAN_IP="${LAN_IP:-<IP-DEL-SERVER>}"

cat <<EOF

──────────────────────────────────────────────────────────────
  Conéctate por RDP desde tu portátil a:

      ${LAN_IP}:${VRDE_PORT}

  Clientes RDP:
    - Linux : Remmina  (o: xfreerdp /v:${LAN_IP}:${VRDE_PORT})
    - Windows: mstsc  →  ${LAN_IP}:${VRDE_PORT}
    - Mac   : Microsoft Remote Desktop

  Instala Windows (usuario 'vboxuser'), luego OpenSSH dentro de la VM
  y por último corre ./finalize-snapshot.sh.
──────────────────────────────────────────────────────────────
EOF
