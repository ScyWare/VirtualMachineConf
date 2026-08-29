#!/usr/bin/env bash
#
# start-vnc-session.sh — Variante B: framebuffer virtual + VNC en el server.
# Levanta Xvfb en :99, un gestor de ventanas mínimo (fluxbox) y x11vnc en :5900.
# Luego, en esa misma sesión, puedes lanzar 'virtualbox'.
#
# Requiere: sudo ./install-gui-deps.sh --vnc
#
set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-99}"
VNC_PORT="${VNC_PORT:-5900}"
GEOMETRY="${GEOMETRY:-1440x900x24}"

command -v Xvfb  >/dev/null || { echo "Falta Xvfb. Corre: sudo ./install-gui-deps.sh --vnc" >&2; exit 1; }
command -v x11vnc >/dev/null || { echo "Falta x11vnc. Corre: sudo ./install-gui-deps.sh --vnc" >&2; exit 1; }

export DISPLAY=":${DISPLAY_NUM}"

echo "== Arrancando Xvfb en ${DISPLAY} (${GEOMETRY}) =="
Xvfb "$DISPLAY" -screen 0 "$GEOMETRY" &
XVFB_PID=$!
sleep 2

echo "== Gestor de ventanas (fluxbox) =="
fluxbox >/dev/null 2>&1 &

echo "== x11vnc en puerto ${VNC_PORT} (solo localhost; tunelízalo por SSH) =="
x11vnc -display "$DISPLAY" -rfbport "$VNC_PORT" -localhost -forever -nopw &
X11VNC_PID=$!

cat <<EOF

✔ Sesión gráfica virtual lista.
  Desde tu portátil, tuneliza y conéctate:

      ssh -L ${VNC_PORT}:localhost:${VNC_PORT} ${USER}@somath-server
      # luego apunta tu cliente VNC a  localhost:${VNC_PORT}

  Dentro de esta sesión (misma terminal/DISPLAY) lanza:

      DISPLAY=${DISPLAY} virtualbox &

  Para cerrar todo:  kill ${XVFB_PID} ${X11VNC_PID}
EOF

wait
