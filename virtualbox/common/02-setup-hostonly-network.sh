#!/usr/bin/env bash
#
# 02-setup-hostonly-network.sh — Crea la red host-only 'vboxnet0' (192.168.56.1/24)
# que aísla la sandbox de Internet y de la LAN. El agente habla con la VM por aquí.
#
# Uso:  sudo ./02-setup-hostonly-network.sh
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script necesita root. Ejecuta: sudo $0" >&2
  exit 1
fi

HOSTONLY_HOST_IP="${HOSTONLY_HOST_IP:-192.168.56.1}"
HOSTONLY_NETMASK="${HOSTONLY_NETMASK:-255.255.255.0}"
NETWORKS_CONF="/etc/vbox/networks.conf"

echo "== [1/3] Permitiendo el rango en ${NETWORKS_CONF} =="
# VirtualBox 7.x solo permite host-only adapters en rangos declarados aquí.
mkdir -p /etc/vbox
if ! grep -qs '192.168.56.0/21' "$NETWORKS_CONF" 2>/dev/null; then
  {
    echo "* 192.168.56.0/21"
    echo "* 10.0.0.0/8 192.168.0.0/16"
  } >> "$NETWORKS_CONF"
  echo "  Rango 192.168.56.0/21 permitido"
else
  echo "  Rango ya permitido"
fi

echo "== [2/3] Creando interfaz host-only =="
# Si ya existe vboxnet0 no la recreamos.
if VBoxManage list hostonlyifs | grep -q 'Name:.*vboxnet0'; then
  echo "  vboxnet0 ya existe"
else
  VBoxManage hostonlyif create   # crea vboxnet0
  echo "  vboxnet0 creada"
fi

echo "== [3/3] Configurando IP del host en la red host-only =="
VBoxManage hostonlyif ipconfig vboxnet0 \
  --ip "$HOSTONLY_HOST_IP" --netmask "$HOSTONLY_NETMASK"

echo
echo "✔ Red host-only lista:"
VBoxManage list hostonlyifs | grep -E 'Name:|IPAddress:|NetworkMask:' | sed 's/^/   /'
echo
echo "  El servidor DHCP de VirtualBox NO se activa a propósito: asignaremos IP"
echo "  estática dentro de Windows (rango 192.168.56.x) para que el agente siempre"
echo "  la encuentre. Ver el README del camino elegido."
