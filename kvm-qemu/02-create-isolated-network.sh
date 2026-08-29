#!/usr/bin/env bash
#
# 02-create-isolated-network.sh — Red libvirt 'sandbox-isolated' SIN salida a
# Internet/LAN (equivalente al host-only de VirtualBox). El host queda en 192.168.56.1.
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Necesita root. Ejecuta: sudo $0" >&2
  exit 1
fi

NET_NAME="${NET_NAME:-sandbox-isolated}"
HOST_IP="${HOST_IP:-192.168.56.1}"
XML="/tmp/${NET_NAME}.xml"

# Sin <forward>: red aislada. dnsmasq da DHCP interno pero no hay ruta al exterior.
cat > "$XML" <<EOF
<network>
  <name>${NET_NAME}</name>
  <bridge name='virbr-sbx' stp='on' delay='0'/>
  <ip address='${HOST_IP}' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.56.100' end='192.168.56.200'/>
      <!-- IP fija para la sandbox por MAC (ajusta la MAC a la de tu VM) -->
      <!-- <host mac='52:54:00:AA:BB:CC' name='SandboxWindows10' ip='192.168.56.10'/> -->
    </dhcp>
  </ip>
</network>
EOF

echo "== Definiendo red ${NET_NAME} =="
if virsh net-info "$NET_NAME" >/dev/null 2>&1; then
  echo "  La red ${NET_NAME} ya existe."
else
  virsh net-define "$XML"
fi
virsh net-autostart "$NET_NAME"
virsh net-start "$NET_NAME" 2>/dev/null || true

echo
echo "✔ Red '${NET_NAME}' activa (host: ${HOST_IP}, sin salida externa)."
virsh net-info "$NET_NAME" | sed 's/^/   /'
echo
echo "  Recomendado: dentro de Windows fija IP estática 192.168.56.10, o descomenta"
echo "  la línea <host mac=.../> con la MAC de la VM para reserva DHCP."
rm -f "$XML"
