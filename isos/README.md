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

### Opción A — rsync (recomendado para archivos grandes: reanudable + progreso)

```bash
# Desde tu portátil (donde vive el ISO):
rsync -avhP --partial \
  ~/Documents/projects/malware-agent/_docs/Win10_22H2_Spanish_Mexico_x64v1.iso \
  somath@somath-server:~/Documents/projects/ScyWare/VirtualMachineConf/isos/Win10_x64.iso
```

`--partial` deja reanudar si se corta la transferencia; `-P` muestra progreso.

### Opción B — scp (más simple)

```bash
scp ~/Documents/projects/malware-agent/_docs/Win10_22H2_Spanish_Mexico_x64v1.iso \
  somath@somath-server:~/Documents/projects/ScyWare/VirtualMachineConf/isos/Win10_x64.iso
```

> Ajusta las rutas a donde tengas clonado el repo en cada máquina.

## Verificar la integridad (opcional pero recomendado)

En el server, tras la copia, compara el hash con el del origen:

```bash
sha256sum isos/Win10_x64.iso
```

Debe coincidir con el `sha256sum` del archivo original en tu portátil.
