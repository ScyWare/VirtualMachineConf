# common/ — Instalación de VirtualBox y red host-only

Scripts compartidos por los 3 caminos. Ejecútalos en orden **en el server**.

| Script | Root | Qué hace |
|---|---|---|
| `00-check-host.sh` | no | Verifica VT-x, Secure Boot, kernel headers y espacio en disco. No cambia nada. |
| `01-install-virtualbox.sh` | sí | Añade el repo oficial de Oracle, instala VirtualBox 7.x + DKMS + Extension Pack, carga `vboxdrv` y añade tu usuario a `vboxusers`. |
| `02-setup-hostonly-network.sh` | sí | Permite el rango en `/etc/vbox/networks.conf` y crea `vboxnet0` con IP `192.168.56.1/24`. |

```bash
./00-check-host.sh
sudo ./01-install-virtualbox.sh
sudo ./02-setup-hostonly-network.sh
```

> Tras `01`, cierra y reabre sesión (o `newgrp vboxusers`) para que el grupo tome efecto.
