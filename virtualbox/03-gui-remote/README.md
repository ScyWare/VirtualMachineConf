# Camino 3 — GUI de VirtualBox remota (X11 forwarding / VNC)

**Idea:** el server sigue sin monitor, pero traes la **GUI de VirtualBox** a tu
portátil. Así sigues el README clásico del malware-agent tal cual (crear VM,
instalar Windows, red host-only, snapshot) con clics, sin aprender `VBoxManage`.

Es el camino más **familiar** si vienes de usar VirtualBox en escritorio, a costa de
latencia gráfica y de instalar dependencias Qt/X11 en el server.

## Dos variantes

### A) SSH X11 forwarding (recomendada, ligera)

La GUI se ejecuta en el server pero se **dibuja en tu portátil** por el túnel SSH.

**En el server** (una vez):
```bash
sudo ./install-gui-deps.sh     # asegura virtualbox-qt + libs X11
```

**Desde tu portátil Linux/Mac** (con un servidor X local; en Mac usa XQuartz):
```bash
ssh -X somath@somath-server
# ya dentro del server:
virtualbox &                   # la ventana aparece en TU portátil
```

Desde ahí sigues el README del malware-agent (Fases 3–7). Al terminar y tener el
snapshot `CleanState`, cierras la GUI y el agente corre headless como siempre.

> `./launch-remote-gui.sh` (córrelo en tu **portátil**) automatiza el `ssh -X` + `virtualbox`.

### B) VNC (si X11 forwarding va lento o no tienes servidor X)

Levantas un framebuffer virtual + servidor VNC en el server y te conectas con un
cliente VNC. Más pesado, pero independiente del X11 del cliente.

```bash
sudo ./install-gui-deps.sh --vnc   # añade xvfb + x11vnc + fluxbox
./start-vnc-session.sh             # arranca Xvfb:99 + x11vnc en :5900
# luego, en el server dentro de esa sesión, lanzas virtualbox
```

Conéctate con un cliente VNC (Remmina, RealVNC, TigerVNC) a `somath-server:5900`.

> ⚠️ VNC sin cifrar viaja en claro por la LAN. Túnelízalo por SSH:
> `ssh -L 5900:localhost:5900 somath@somath-server` y conéctate a `localhost:5900`.

## Cuándo NO usar este camino

Si solo quieres montar la VM una vez, el **Camino 1 (VRDE/RDP)** es más simple y no
mete dependencias gráficas en el server. Este camino tiene sentido si prefieres la
GUI completa de VirtualBox o vas a administrar varias VMs visualmente.
