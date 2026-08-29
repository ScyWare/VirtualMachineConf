# Adaptar el toolkit del agente a virsh

Para usar KVM en vez de VirtualBox, el único cambio real en `malware-agent` está en
`src/agent/WindowsVMSandboxToolKit.py` → método `reset_sandbox()`. El resto (SSH a
la VM, ejecución de PowerShell) es idéntico: sigue hablando con `192.168.56.10:22`.

## Antes (VirtualBox)

```python
def reset_sandbox(self):
    subprocess.run(["VBoxManage", "controlvm", self.vm_name, "poweroff"], ...)
    time.sleep(2)
    subprocess.run(["VBoxManage", "snapshot", self.vm_name, "restore", self.snapshot_name], check=True)
    subprocess.run(["VBoxManage", "startvm", self.vm_name, "--type", "headless"], check=True)
```

## Después (KVM / virsh)

```python
def reset_sandbox(self):
    """Revierte la VM al snapshot limpio usando libvirt (virsh)."""
    C = "qemu:///system"
    try:
        # 1) Apagar a la fuerza si está corriendo (ignora error si ya está apagada)
        subprocess.run(["virsh", "-c", C, "destroy", self.vm_name],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(2)
        # 2) Revertir al snapshot y arrancar (--running deja la VM encendida)
        subprocess.run(["virsh", "-c", C, "snapshot-revert",
                        self.vm_name, self.snapshot_name, "--running", "--force"],
                       check=True)
        print(f"🔄 Sandbox '{self.vm_name}' revertida a '{self.snapshot_name}' (KVM)")
    except Exception as e:
        raise RuntimeError(f"Error al interactuar con libvirt/virsh: {e}")
```

## Equivalencias rápidas

| Acción | VirtualBox | virsh |
|---|---|---|
| Listar VMs | `VBoxManage list vms` | `virsh list --all` |
| Apagar (forzado) | `controlvm <vm> poweroff` | `destroy <vm>` |
| Apagar (limpio) | `controlvm <vm> acpipowerbutton` | `shutdown <vm>` |
| Arrancar headless | `startvm <vm> --type headless` | `start <vm>` |
| Crear snapshot | `snapshot <vm> take <n>` | `snapshot-create-as <vm> <n>` |
| Revertir snapshot | `snapshot <vm> restore <n>` | `snapshot-revert <vm> <n> --running --force` |
| Listar snapshots | `snapshot <vm> list` | `snapshot-list <vm>` |
| IP del guest | (por SSH fija) | `domifaddr <vm>` |

## Notas

- **Permisos:** el usuario que corre el agente debe estar en el grupo `libvirt`
  (lo hace `01-install-kvm.sh`), o usar `sudo`. Con `qemu:///system` no hace falta root
  si el grupo está configurado.
- **snapshot-revert con qcow2:** los snapshots internos qcow2 funcionan bien para este
  caso. Para reversión más rápida podrías usar discos con backing file, pero para una
  sola sandbox el snapshot interno es suficiente.
- **Tiempo de reversión:** similar o mejor que VirtualBox; añade un pequeño sleep +
  retry de SSH (ya presente en `_connect_ssh`) para esperar el boot.
- **Detección de VM por malware:** `--cpu host-passthrough` y quitar pistas obvias
  (nombre de disco, etc.) ayuda a que el malware no detecte el entorno virtual.
