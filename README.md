# VMware Toolbox

Colección de herramientas y scripts automatizados en PowerShell para la gestión eficiente de máquinas virtuales en VMware Workstation.

## 🚀 Funcionalidades

### Invoke-VMSnapshotCleanup.ps1
Este script es la herramienta principal del toolbox. Permite automatizar el ciclo de vida de entornos de prueba mediante snapshots:

- **Reset a "Golden State"**: Clona una máquina virtual desde un snapshot específico (por defecto etiquetado como `(OK)`), permitiendo volver a un estado limpio en minutos.
- **Gestión de Backups**: Antes de reemplazar la VM, realiza una copia de seguridad de la versión actual en una carpeta `_Trash_`.
- **Limpieza Automatizada**: Incluye un menú interactivo para listar y eliminar carpetas de backups antiguos (`_Trash_`) y liberar espacio en disco.

## 📋 Requisitos

- **Sistema Operativo**: Windows 10/11.
- **Software**: VMware Workstation Pro o Player (debe incluir `vmrun.exe`).
- **PowerShell**: Versión 5.1 o superior.

## 🛠️ Instalación

1. Clona el repositorio:
   ```bash
   git clone https://github.com/AlexMnrs/VMware-toolbox.git
   ```
2. Accede al directorio:
   ```bash
   cd VMware-toolbox
   ```

## 📖 Uso

### Modo Interactivo
Ejecuta el script sin parámetros para abrir el menú principal:
```powershell
.\Invoke-VMSnapshotCleanup.ps1
```
El menú te permitirá:
1. Seleccionar una VM detectada automáticamente.
2. Elegir un snapshot (el script recomendará el que contenga `(OK)`).
3. Gestionar la limpieza de versiones antiguas.

### Modo Automático
Para integrarlo en otros scripts o pipelines, especifica la ruta del archivo `.vmx`:

```powershell
.\Invoke-VMSnapshotCleanup.ps1 -Path "D:\VMs\MiMaquinaVirtual\MiMaquinaVirtual.vmx"
```

### Personalización del Tag de Snapshot
Si tus snapshots "golden" usan otro nombre (ej. "CleanInstall"), usa el parámetro `-SnapshotTag`:

```powershell
.\Invoke-VMSnapshotCleanup.ps1 -SnapshotTag "CleanInstall"
```

## 📝 Changelog
Ver [CHANGELOG.md](CHANGELOG.md) para el historial de cambios.

## 👤 Autor
**Alex Monrás**

## 📄 Licencia
Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.
