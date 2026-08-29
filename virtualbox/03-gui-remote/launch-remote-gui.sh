#!/usr/bin/env bash
#
# launch-remote-gui.sh — Córrelo en TU PORTÁTIL (no en el server).
# Abre la GUI de VirtualBox del server dibujada localmente vía SSH X11 forwarding.
#
set -euo pipefail

SERVER="${SERVER:-somath@somath-server}"

echo "Conectando a ${SERVER} con X11 forwarding y lanzando VirtualBox..."
echo "(Requiere un servidor X local: nativo en Linux, XQuartz en Mac.)"
exec ssh -X "$SERVER" 'virtualbox'
