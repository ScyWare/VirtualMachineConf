# Camino 2 — Instalación desatendida (100% CLI)

**Idea:** cero interacción gráfica. Usamos `VBoxManage unattended`, que genera un
`autounattend.xml` y instala Windows solo. Un script de post-instalación
(`provision.ps1`) enciende OpenSSH, abre el firewall, pone PowerShell como shell de
SSH y fija la IP estática. Al final, tomamos el snapshot `CleanState`.

Es el camino **más reproducible**: reconstruir la sandbox desde cero es un comando.
A cambio, armar y depurar la automatización cuesta más la primera vez.

## Requisitos

- `common/` ya ejecutado.
- ISO de Windows 10 en el server (`ISO_PATH`).
- **Importante:** el ISO debe permitir instalación desatendida. Los ISO oficiales de
  Windows 10 funcionan; algunos "recortados" no traen todas las ediciones y fallan.

## Cómo funciona

`VBoxManage unattended install`:
1. Detecta el tipo de SO y monta un floppy/ISO auxiliar con el `autounattend.xml`.
2. Instala Windows sin intervención (usuario, password, locale, zona horaria).
3. Opcionalmente instala las Guest Additions.
4. Ejecuta el **post-install command** que le pasamos.

Nuestro post-install es `provision.ps1` inyectado como `powershell -EncodedCommand`
(base64), así no hay que transferir archivos al guest.

## Pasos

```bash
# ISO por defecto: <repo>/isos/Win10_x64.iso  (exporta ISO_PATH solo si usas otra ruta)
export VM_USER=vboxuser
export VM_PASSWORD='tu_contraseña'      # la misma del .env del agente
./create-and-install-vm.sh              # crea VM + instalación desatendida + provisioning
```

El script arranca la VM headless y la instalación corre sola (10–25 min según disco).
Puedes seguir el progreso conectándote por VRDE si lo dejaste activo, o esperando a
que el puerto SSH responda:

```bash
# desde el server, esperar a que SSH levante
until nc -z -w2 192.168.56.10 22; do sleep 5; done && echo "SSH arriba"
```

Cuando SSH responda:

```bash
./finalize-snapshot.sh                  # (reutiliza el del camino 01) aísla + snapshot
```

> Reutiliza `../01-vrde-rdp/finalize-snapshot.sh` para el aislamiento y el snapshot,
> o cópialo aquí si prefieres tenerlo autocontenido.

## Depuración

- Si la instalación se cuelga, activa VRDE para ver la pantalla:
  `VBoxManage modifyvm SandboxWindows10 --vrde on` y conéctate por RDP.
- Revisa el `autounattend.xml` generado en la carpeta auxiliar que imprime el script.
- Si `Add-WindowsCapability` (OpenSSH) falla, es por falta de Internet durante el
  post-install: confirma que el adaptador 1 sigue en NAT en esta fase.
