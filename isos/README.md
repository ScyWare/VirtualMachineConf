# isos/ — Imágenes de instalación (NO versionadas)

Los ISOs de Windows viven aquí pero **no se suben a GitHub** (el `.gitignore` de esta
carpeta ignora todo menos sí mismo y este README). En el server los traes por SSH
después de clonar/pull del repo.

Los scripts de creación de VM buscan el ISO **por defecto en esta carpeta**:

```
VirtualMachineConf/isos/Win10_x64.iso
```

Puedes sobreescribir la ruta con la variable `ISO_PATH` en cualquier script.

## Traer el ISO al server por SSH

El ISO está en el proyecto `malware-agent`:
`malware-agent/_docs/Win10_22H2_Spanish_Mexico_x64v1.iso`

> ⚠️ **Ojo con las rutas:** en el portátil el repo está en
> `~/Documents/projects/ScyWare/VirtualMachineConf`, pero en el server se clonó en
> `~/ScyWare/VirtualMachineConf`. Los ejemplos usan la ruta **del server** como
> destino; ajústala si clonaste en otro sitio.

### Opción A — rsync (recomendado para archivos grandes: reanudable + progreso)

**Requisito:** `rsync` debe estar instalado en **ambos** extremos. El server recién
instalado no lo trae; instálalo una vez:

```bash
ssh somath@somath-server 'sudo apt update && sudo apt install -y rsync'
```

Luego, desde tu portátil (donde vive el ISO):

```bash
rsync -avhP --partial \
  ~/Documents/projects/malware-agent/_docs/Win10_22H2_Spanish_Mexico_x64v1.iso \
  somath@somath-server:~/ScyWare/VirtualMachineConf/isos/Win10_x64.iso
```

`--partial` deja reanudar si se corta la transferencia; `-P` muestra progreso.

### Opción B — scp (más simple, sin instalar nada)

```bash
scp ~/Documents/projects/malware-agent/_docs/Win10_22H2_Spanish_Mexico_x64v1.iso \
  somath@somath-server:~/ScyWare/VirtualMachineConf/isos/Win10_x64.iso
```

La contra: si se corta a mitad, `scp` empieza de cero (no reanuda).

## Verificar la integridad (opcional pero recomendado)

Tras la copia, compara el hash en ambas máquinas (deben coincidir):

```bash
# en el portátil:
sha256sum ~/Documents/projects/malware-agent/_docs/Win10_22H2_Spanish_Mexico_x64v1.iso
# en el server:
ssh somath@somath-server 'sha256sum ~/ScyWare/VirtualMachineConf/isos/Win10_x64.iso'
```
