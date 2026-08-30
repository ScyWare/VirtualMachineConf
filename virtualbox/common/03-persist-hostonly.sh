#!/usr/bin/env bash
#
# 03-persist-hostonly.sh — Hace que la interfaz host-only 'vboxnet0' se recree
# automáticamente en cada arranque del server (via systemd).
#
# Las interfaces host-only de VirtualBox NO son persistentes: se pierden al reiniciar.
# El agente arranca la VM en cada ejecución y necesita 'vboxnet0', así que sin esto
# el laboratorio se rompe tras cada reboot. Este script instala:
#   - /usr/local/sbin/vbox-hostonly-up.sh   (crea vboxnet0 + IP, idempotente)
#   - /etc/systemd/system/vbox-hostonly.service (lo ejecuta al boot)
#
# Uso:  sudo ./03-persist-hostonly.sh
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Necesita root. Ejecuta: sudo $0" >&2
  exit 1
fi

HOSTONLY_HOST_IP="${HOSTONLY_HOST_IP:-192.168.56.1}"
HOSTONLY_NETMASK="${HOSTONLY_NETMASK:-255.255.255.0}"
HELPER="/usr/local/sbin/vbox-hostonly-up.sh"
UNIT="/etc/systemd/system/vbox-hostonly.service"

echo "== [1/3] Instalando helper ${HELPER} =="
cat > "$HELPER" <<EOF
#!/usr/bin/env bash
# Recrea vboxnet0 con IP fija si no existe. Idempotente.
set -e
if ! VBoxManage list hostonlyifs | grep -q 'vboxnet0'; then
  VBoxManage hostonlyif create
fi
VBoxManage hostonlyif ipconfig vboxnet0 --ip ${HOSTONLY_HOST_IP} --netmask ${HOSTONLY_NETMASK}
EOF
chmod 0755 "$HELPER"

echo "== [2/3] Instalando servicio ${UNIT} =="
cat > "$UNIT" <<EOF
[Unit]
Description=Recrear la interfaz host-only vboxnet0 de VirtualBox al arranque
After=vboxdrv.service systemd-modules-load.service
Wants=vboxdrv.service

[Service]
Type=oneshot
RemainAfterExit=yes
# Asegurar los módulos de red de VirtualBox (idempotente; '-' ignora fallos)
ExecStartPre=-/sbin/modprobe vboxdrv
ExecStartPre=-/sbin/modprobe vboxnetadp
ExecStartPre=-/sbin/modprobe vboxnetflt
ExecStart=${HELPER}

[Install]
WantedBy=multi-user.target
EOF

echo "== [3/3] Habilitando y arrancando el servicio =="
systemctl daemon-reload
systemctl enable --now vbox-hostonly.service

echo
echo "✔ Persistencia lista. vboxnet0 se recreará en cada boot."
systemctl --no-pager --full status vbox-hostonly.service | sed -n '1,6p' || true
echo
echo "  Verifica la interfaz:"
VBoxManage list hostonlyifs | grep -E 'Name:|IPAddress:' | sed 's/^/   /'
