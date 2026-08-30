# common/ — Instalación de VirtualBox y red host-only

Scripts compartidos por los 3 caminos. Ejecútalos en orden **en el server**.

| Script | Root | Qué hace |
|---|---|---|
| `00-check-host.sh` | no | Verifica VT-x, Secure Boot, kernel headers y espacio en disco. No cambia nada. |
| `01-install-virtualbox.sh` | sí | Añade el repo oficial de Oracle, instala VirtualBox 7.x + DKMS + Extension Pack, carga `vboxdrv` y añade tu usuario a `vboxusers`. |
| `02-setup-hostonly-network.sh` | sí | Permite el rango en `/etc/vbox/networks.conf` y crea `vboxnet0` con IP `192.168.56.1/24`. |
| `03-persist-hostonly.sh` | sí | Instala un servicio systemd que **recrea `vboxnet0` en cada boot** (las host-only NO son persistentes). |

```bash
./00-check-host.sh
sudo ./01-install-virtualbox.sh
sudo ./02-setup-hostonly-network.sh
sudo ./03-persist-hostonly.sh          # recomendado: sobrevive reinicios del server
```

> Tras `01`, cierra y reabre sesión (o `newgrp vboxusers`) para que el grupo tome efecto.

## ⚠️ `vboxnet0` no es persistente

Las interfaces host-only de VirtualBox se **pierden al reiniciar** el server. Sin
persistencia, tras un reboot `startvm` falla con
`Nonexistent host networking interface, name 'vboxnet0'` y el agente no puede arrancar
la VM. `03-persist-hostonly.sh` lo resuelve con un servicio systemd. Si prefieres no
usar systemd, vuelve a correr `sudo ./02-setup-hostonly-network.sh` tras cada reboot.
