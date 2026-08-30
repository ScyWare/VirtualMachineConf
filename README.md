# ScyWare — VirtualMachineConf

Documentación y scripts para montar el **hipervisor headless** del laboratorio de
análisis de malware de ScyWare, sobre un servidor Debian dedicado.

El objetivo es correr una VM de **Windows 10** aislada (sandbox de ransomware) que
el agente [`malware-agent`](../../malware-agent) controla por CLI (`VBoxManage` /
`virsh`) + SSH, revirtiendo a un snapshot limpio (`CleanState`) tras cada ejecución.

> 📖 **¿Montándolo de cero?** Sigue [`GUIA-COMPLETA.md`](GUIA-COMPLETA.md): el recorrido
> secuencial de punta a punta (del ISO al agente) con los baches reales y sus arreglos.
> Este README es el índice/referencia de cada carpeta.
>
> 🧰 **¿Aprendiendo VirtualBox?** [`COMANDOS-VIRTUALBOX.md`](COMANDOS-VIRTUALBOX.md):
> cheatsheet de `VBoxManage` (listar, encender/apagar, snapshots, crear otra VM desde
> otro ISO, redes, discos, clonar…).

## Servidor objetivo

| | |
|---|---|
| Host | `somath-server` (Acer Nitro AN515-53) |
| CPU | Intel Core i5-8300H (4c/8t) — **VT-x confirmado** (`vmx`) |
| RAM | 31 GiB |
| Disco | 1.76 TiB libres |
| SO | Debian GNU/Linux 13 (trixie) x86_64 |
| Kernel | 6.12.x |
| Secure Boot | **Desactivado** (necesario para DKMS sin firmar módulos) |
| Modo | **Headless** (sin entorno gráfico) |

## El reto

El agente ya corre 100% headless: solo usa `VBoxManage` por `subprocess` y SSH a la
VM por la red host-only. **Lo que NO es headless es el setup inicial**: instalar
Windows desde el ISO y crear la VM/red normalmente se hace con la GUI de VirtualBox.

Este repo explora **3 caminos** para resolver ese setup inicial sin monitor en el
server, más **1 alternativa** al propio VirtualBox.

## Estructura

```
VirtualMachineConf/
├── virtualbox/              # Camino principal: VirtualBox (cero cambios en el agente)
│   ├── common/              #   Instalación + red host-only (compartido por los 3 caminos)
│   ├── 01-vrde-rdp/         #   Camino 1: instalar Windows por escritorio remoto (VRDE/RDP)
│   ├── 02-cli-unattended/   #   Camino 2: instalación desatendida 100% por CLI
│   └── 03-gui-remote/       #   Camino 3: GUI de VirtualBox reenviada por SSH X11 / VNC
├── kvm-qemu/                # Alternativa: KVM/QEMU + libvirt (requiere adaptar el toolkit)
└── isos/                    # ISOs de Windows — NO versionados (se traen por SSH). Ver isos/README.md
```

## Orden recomendado

1. `virtualbox/common/` — instalar VirtualBox y crear la red host-only (para los 3 caminos).
2. Elegir **uno** de los 3 caminos para instalar Windows y dejar el snapshot `CleanState`.
3. (Opcional / futuro) evaluar `kvm-qemu/` como reemplazo más nativo del hipervisor.

> ⚠️ **VirtualBox y KVM/QEMU son mutuamente excluyentes:** ambos necesitan VT-x y solo
> uno puede tenerlo a la vez. Si `kvm_intel` está cargado, VirtualBox falla con
> `VERR_VMX_IN_VMX_ROOT_MODE`; hay que descargar KVM (`sudo modprobe -r kvm_intel kvm`)
> o blacklistearlo. Detalles en [`virtualbox/README.md`](virtualbox/README.md#-conflicto-con-kvm-vt-x).

## Convenciones comunes

Todos los scripts comparten estas variables (definidas al inicio de cada uno, y
sobreescribibles por entorno):

| Variable | Valor por defecto | Uso |
|---|---|---|
| `VM_NAME` | `SandboxWindows10` | Nombre de la VM |
| `VM_RAM_MB` | `4096` | RAM (4 GB) |
| `VM_CPUS` | `2` | vCPUs |
| `VM_DISK_GB` | `50` | Disco virtual |
| `VM_USER` | `vboxuser` | Usuario dentro de Windows |
| `HOSTONLY_IF` | `vboxnet0` | Interfaz host-only |
| `HOSTONLY_HOST_IP` | `192.168.56.1` | IP del host en la red host-only |
| `SNAPSHOT_NAME` | `CleanState` | Snapshot estéril que restaura el agente |
| `ISO_PATH` | `<repo>/isos/Win10_x64.iso` | Ruta al ISO de Windows (ver `isos/README.md`) |

> ⚠️ **Seguridad:** dentro de esta VM se ejecuta malware real. La red host-only la
> deja sin salida a Internet ni a la LAN; el snapshot garantiza que nada persiste.
> No cambies el adaptador a NAT/Bridge una vez terminado el setup.
