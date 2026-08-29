#!/usr/bin/env bash
#
# 00-check-host.sh — Verifica que el server cumple los requisitos para VirtualBox.
# NO modifica nada. Solo lee y reporta.
#
set -uo pipefail

ok()   { printf '  \033[32m✔\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; }

echo "== Chequeo de host para VirtualBox =="

# 1) Virtualización por hardware (VT-x)
if grep -qoE 'vmx|svm' /proc/cpuinfo; then
  ok "Virtualización por hardware disponible (vmx/svm)"
else
  fail "No se detecta VT-x/AMD-V. Habilítalo en la BIOS (Intel Virtualization Technology)."
fi

# 2) Módulo KVM cargado (compite con VirtualBox por VT-x en kernels viejos;
#    en 7.x/6.12 conviven, pero lo reportamos)
if lsmod | grep -q '^kvm'; then
  warn "Módulo KVM cargado: BLOQUEARÁ a VirtualBox (VERR_VMX_IN_VMX_ROOT_MODE). Descárgalo: sudo modprobe -r kvm_intel kvm  (ver virtualbox/README.md → Conflicto con KVM)"
else
  ok "KVM no acapara VT-x ahora (ojo: podría cargarse después; si startvm falla por VT-x, descárgalo)"
fi

# 3) Secure Boot (debe estar desactivado para DKMS sin firmar)
if command -v mokutil >/dev/null 2>&1; then
  if mokutil --sb-state 2>/dev/null | grep -qi disabled; then
    ok "Secure Boot desactivado"
  else
    warn "Secure Boot podría estar activo: DKMS necesitará firmar vboxdrv o desactívalo en BIOS"
  fi
else
  warn "mokutil no instalado; no se pudo comprobar Secure Boot (instálalo con: sudo apt install mokutil)"
fi

# 4) Kernel headers (necesarios para compilar el módulo vboxdrv vía DKMS)
KVER="$(uname -r)"
if dpkg -l "linux-headers-${KVER}" >/dev/null 2>&1; then
  ok "Headers para el kernel actual (${KVER}) instalados"
else
  warn "Faltan linux-headers-${KVER}. El script de instalación intentará instalar linux-headers-amd64."
fi

# 5) Espacio en disco (>= 60 GB libres recomendados para VM de 50 GB + ISO)
FREE_GB="$(df --output=avail -BG "$HOME" | tail -1 | tr -dc '0-9')"
if [ "${FREE_GB:-0}" -ge 60 ]; then
  ok "Espacio libre en \$HOME: ${FREE_GB} GB"
else
  warn "Solo ${FREE_GB} GB libres en \$HOME; recomendado >= 60 GB (VM 50 GB + ISO)"
fi

# 6) RAM total
RAM_GB="$(free -g | awk '/^Mem:/{print $2}')"
if [ "${RAM_GB:-0}" -ge 6 ]; then
  ok "RAM total: ${RAM_GB} GB (suficiente para VM de 4 GB)"
else
  warn "RAM total baja (${RAM_GB} GB); la VM pide 4 GB"
fi

echo "== Fin del chequeo =="
