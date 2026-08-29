# VirtualBox (camino principal)

VirtualBox es el camino de **menor esfuerzo**: el agente
(`WindowsVMSandboxToolKit.py`) ya está escrito contra `VBoxManage`, así que **no hay
que tocar código**. Lo único a resolver es el setup inicial sin GUI en el server.

## Prerrequisito compartido: `common/`

Antes de cualquiera de los 3 caminos, corre en orden:

```bash
cd common/
./00-check-host.sh              # verifica VT-x, Secure Boot, headers
sudo ./01-install-virtualbox.sh # repo oficial de Oracle + DKMS + Ext Pack
sudo ./02-setup-hostonly-network.sh  # crea vboxnet0 (192.168.56.1/24)
```

Luego eliges **un** camino para instalar Windows.

## Los 3 caminos comparados

| | `01-vrde-rdp` | `02-cli-unattended` | `03-gui-remote` |
|---|---|---|---|
| **Idea** | VM headless con escritorio remoto; instalas Windows por RDP desde tu portátil | Instalación desatendida con `autounattend.xml` vía `VBoxManage unattended` | Reenvías la GUI de VirtualBox por SSH X11 / VNC y sigues el README clásico |
| **Interacción manual** | Media (instalas Windows a mano por RDP) | Mínima (casi todo automatizado) | Alta (como en un desktop) |
| **Reproducibilidad** | Media | **Alta** (todo en script) | Baja |
| **Complejidad de montaje** | Baja | Media-alta (armar el answer file) | Baja |
| **Dependencias extra en server** | Ninguna (RDP corre en el cliente) | Ninguna | `virtualbox-qt` + X11 / servidor VNC |
| **Mejor para** | Hacerlo una vez, rápido | Rehacer la sandbox muchas veces / CI | Quien prefiere la GUI y no le importa la latencia |

**Recomendación:** empieza por **`01-vrde-rdp`** (rápido y sin dependencias en el
server). Si más adelante quieres reconstruir la VM de forma repetible, invierte en
**`02-cli-unattended`**.

## Notas sobre VirtualBox 7.x en Debian 13

- El paquete de Debian suele ir por detrás; usamos el **repo oficial de Oracle** para
  tener soporte del kernel 6.12 vía DKMS.
- Las redes host-only en 7.x están restringidas por `/etc/vbox/networks.conf`. El
  rango `192.168.56.0/21` viene permitido por defecto; `02-setup-hostonly-network.sh`
  lo verifica.
- Con Secure Boot desactivado (ya es el caso), DKMS compila `vboxdrv` sin firmar el módulo.
