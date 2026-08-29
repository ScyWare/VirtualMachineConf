#!/usr/bin/env bash
#
# 01-install-kvm.sh — Instala KVM/QEMU + libvirt + herramientas en Debian 13.
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Necesita root. Ejecuta: sudo $0" >&2
  exit 1
fi

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"

echo "== [1/4] Verificando soporte KVM =="
if [ ! -e /dev/kvm ]; then
  echo "!! No existe /dev/kvm. Habilita VT-x en BIOS y revisa 'kvm-ok'." >&2
  exit 1
fi

echo "== [2/4] Instalando paquetes =="
apt-get update -y
apt-get install -y --no-install-recommends \
  qemu-system-x86 qemu-utils \
  libvirt-daemon-system libvirt-clients \
  virtinst virt-viewer \
  bridge-utils dnsmasq-base

echo "== [3/4] Habilitando libvirtd =="
systemctl enable --now libvirtd

echo "== [4/4] Grupos para el usuario ${REAL_USER} =="
usermod -aG libvirt,kvm "$REAL_USER"

echo
echo "✔ KVM/QEMU listo. Verifica con:  virsh -c qemu:///system version"
echo "  Cierra sesión y reingresa (o 'newgrp libvirt') para aplicar los grupos."
