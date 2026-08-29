#!/usr/bin/env bash
#
# 01-install-virtualbox.sh — Instala VirtualBox 7.x desde el repo oficial de Oracle
# en Debian 13 (trixie), con DKMS para kernel 6.12 y el Extension Pack.
#
# Uso:  sudo ./01-install-virtualbox.sh
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Este script necesita root. Ejecuta: sudo $0" >&2
  exit 1
fi

# Usuario real (el que invocó sudo) para añadirlo a vboxusers
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"

VBOX_SERIES="7.1"                       # serie a instalar (paquete virtualbox-7.1)
DEBIAN_CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
KEYRING="/usr/share/keyrings/oracle-virtualbox-2016.gpg"
LIST="/etc/apt/sources.list.d/virtualbox.list"

echo "== [1/6] Dependencias base =="
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg dkms build-essential \
  "linux-headers-$(uname -r)" linux-headers-amd64

echo "== [2/6] Clave GPG de Oracle =="
curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc \
  | gpg --dearmor --yes -o "$KEYRING"

echo "== [3/6] Repositorio de Oracle (codename: ${DEBIAN_CODENAME}) =="
# Nota: si Oracle aún no publica sección para 'trixie', usa el codename estable
# más cercano (p. ej. 'bookworm'). Cambia FALLBACK_CODENAME si el update falla.
FALLBACK_CODENAME="bookworm"
echo "deb [arch=amd64 signed-by=${KEYRING}] https://download.virtualbox.org/virtualbox/debian ${DEBIAN_CODENAME} contrib" > "$LIST"

if ! apt-get update -y 2>/dev/null; then
  echo "!! Oracle no tiene sección para '${DEBIAN_CODENAME}', usando '${FALLBACK_CODENAME}'"
  echo "deb [arch=amd64 signed-by=${KEYRING}] https://download.virtualbox.org/virtualbox/debian ${FALLBACK_CODENAME} contrib" > "$LIST"
  apt-get update -y
fi

echo "== [4/6] Instalando VirtualBox ${VBOX_SERIES} =="
apt-get install -y "virtualbox-${VBOX_SERIES}"

echo "== [5/6] Compilando/cargando módulos del kernel (vboxdrv) =="
/sbin/vboxconfig || {
  echo "!! /sbin/vboxconfig falló. Revisa DKMS: dkms status ; journalctl -k | grep -i vbox" >&2
  exit 1
}
modprobe vboxdrv
lsmod | grep -q vboxdrv && echo "  vboxdrv cargado OK"

echo "== [6/6] Extension Pack + grupo vboxusers =="
# El Extension Pack añade VRDE (usado por el camino 01), USB2/3, etc.
VBOX_VERSION="$(VBoxManage --version | sed 's/_.*//; s/r.*//')"
# IMPORTANTE: conservar el nombre OFICIAL del archivo. VBoxManage deriva el nombre
# del pack desde el nombre del archivo y lo compara con el XML interno; si lo renombras
# falla con "Extension pack name mismatch".
EXTPACK_FILE="Oracle_VirtualBox_Extension_Pack-${VBOX_VERSION}.vbox-extpack"
EXTPACK_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/${EXTPACK_FILE}"
TMP_EXT="/tmp/${EXTPACK_FILE}"
if curl -fsSL "$EXTPACK_URL" -o "$TMP_EXT"; then
  yes | VBoxManage extpack install --replace "$TMP_EXT" || echo "!! No se pudo instalar el Extension Pack (opcional)"
  rm -f "$TMP_EXT"
else
  echo "!! No se pudo descargar el Extension Pack para ${VBOX_VERSION} (opcional; VRDE lo necesita)"
fi

usermod -aG vboxusers "$REAL_USER"

echo
echo "✔ VirtualBox instalado. Versión: $(VBoxManage --version)"
echo "  Cierra sesión y vuelve a entrar (o 'newgrp vboxusers') para aplicar el grupo."
