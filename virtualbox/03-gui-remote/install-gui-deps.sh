#!/usr/bin/env bash
#
# install-gui-deps.sh — Dependencias para usar la GUI de VirtualBox en un server headless.
#   sin args : variante A (X11 forwarding) -> asegura virtualbox-qt + libs X11 mínimas
#   --vnc    : variante B (VNC)            -> añade Xvfb + x11vnc + fluxbox
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Necesita root. Ejecuta: sudo $0 [--vnc]" >&2
  exit 1
fi

echo "== Dependencias para X11 forwarding =="
apt-get update -y
# virtualbox-qt trae la GUI; xauth es necesario para 'ssh -X'
apt-get install -y --no-install-recommends virtualbox-qt xauth x11-apps

# Asegurar que sshd permite X11 forwarding
SSHD_CONF="/etc/ssh/sshd_config"
if ! grep -qE '^\s*X11Forwarding\s+yes' "$SSHD_CONF"; then
  echo "  Activando X11Forwarding en ${SSHD_CONF}"
  sed -i 's/^#\?\s*X11Forwarding.*/X11Forwarding yes/' "$SSHD_CONF" || echo "X11Forwarding yes" >> "$SSHD_CONF"
  systemctl reload ssh || systemctl reload sshd || true
fi

if [ "${1:-}" = "--vnc" ]; then
  echo "== Dependencias para VNC =="
  apt-get install -y --no-install-recommends xvfb x11vnc fluxbox
  echo "  Instalados Xvfb + x11vnc + fluxbox (ver start-vnc-session.sh)"
fi

echo "✔ Dependencias GUI instaladas."
