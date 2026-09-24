# Taller de IaC: crear una VM en VMware Workstation con un script parametrizado

![Plataforma](https://img.shields.io/badge/host-Windows-0078D6)
![VMware](https://img.shields.io/badge/VMware-Workstation%20Pro-607078)
![Script](https://img.shields.io/badge/script-.cmd-4EAA25)
![Licencia](https://img.shields.io/badge/licencia-MIT-blue)

Versión mejorada del taller *“Creación de VM en ESXi por consola”*. En lugar de teclear comandos uno por uno, la infraestructura (una máquina virtual) se **describe con parámetros** y se **construye con un solo script repetible**. Esa es la idea central de la **Infraestructura como Código (IaC)**: la misma definición produce siempre el mismo resultado.

> **Estado de las pruebas:** los scripts fueron revisados línea por línea, pero su ejecución real sobre Windows con VMware Workstation debe validarla quien los use. Empiece siempre con `--dry-run`.

## Contenido del repositorio

```text
taller-iac-vmware-workstation/
├── crear-vm.cmd              # Crea la VM (carpeta + disco + VMX + encendido opcional)
├── eliminar-vm.cmd           # Destruye la VM (operación inversa)
├── ejemplos/
│   ├── ubuntu-server.vars    # Definición declarativa de una VM (CLAVE=VALOR)
│   └── laboratorio-ligero.vars
├── .gitignore                # Evita subir discos, ISOs y logs
├── .gitattributes            # Fuerza finales de línea CRLF en los .cmd
├── LICENSE
└── README.md
```

## Requisitos

| Requisito | Detalle |
|---|---|
| Sistema anfitrión | Windows 10/11 con `cmd.exe` |
| Hipervisor | VMware Workstation Pro (Pro o Player con `vmrun`/`vmware-vdiskmanager` instalados) |
| ISO | Un archivo `.iso` de instalación accesible desde el equipo (opcional, pero recomendado) |
| Ruta de herramientas | `C:\Program Files (x86)\VMware\VMware Workstation` (se puede cambiar con `--vmware-dir`) |

## Inicio rápido

```bat
:: 1. Ver la ayuda
crear-vm.cmd --help

:: 2. Simular (NO crea nada; muestra comandos y el .vmx que se generaría)
crear-vm.cmd --name srv01 --iso C:\ISOs\ubuntu-24.04-live-server-amd64.iso --dry-run

:: 3. Crear de verdad y encender
crear-vm.cmd --name srv01 --iso C:\ISOs\ubuntu-24.04-live-server-amd64.iso --start

:: 4. Destruir cuando termine el laboratorio
eliminar-vm.cmd --name srv01
```

## Parámetros de `crear-vm.cmd`

| Parámetro | Defecto | Descripción |
|---|---|---|
| `--name NOMBRE` | `VM_Taller` | Nombre de la VM; también nombra la carpeta, el `.vmx` y el `.vmdk`. Solo letras, números, `.`, `-`, `_`. |
| `--dir RUTA` | `Documents\Virtual Machines` | Carpeta base donde se crea `RUTA\NOMBRE\`. |
| `--iso RUTA.iso` | *(ninguno)* | ISO de instalación. Sin ella se usa la unidad óptica física. |
| `--os GUEST` | `ubuntu-64` | Valor `guestOS` del VMX (p. ej. `debian12-64`, `windows11-64`). |
| `--cpus N` | `2` | vCPU, de 1 a 32. |
| `--mem MB` | `2048` | RAM en MB (512–262144, múltiplo de 4). |
| `--disk GB` | `20` | Tamaño del disco virtual en GB. |
| `--net nat\|bridged\|hostonly` | `nat` | Modo de red. |
| `--nic e1000\|e1000e\|vmxnet3` | `e1000e` | Adaptador de red virtual. |
| `--firmware bios\|efi` | `bios` | Firmware de arranque. |
| `--hw N` | `16` | `virtualHW.version` (compatibilidad de hardware virtual). |
| `--prealloc` | *(no)* | Disco preasignado (tipo 2) en lugar de creciente (tipo 0). |
| `--start` | *(no)* | Enciende la VM al terminar. |
| `--nogui` | *(no)* | Al encender no abre la ventana de VMware. |
| `--force` | *(no)* | Recrea la VM si ya existe (no funciona si está encendida). |
| `--dry-run` | *(no)* | Simula: imprime comandos y el VMX en pantalla, sin tocar el disco. |
| `--vars ARCHIVO` | *(ninguno)* | Carga parámetros desde un archivo `CLAVE=VALOR`. |
| `--vmware-dir RUTA` | ruta estándar | Carpeta de instalación de VMware Workstation. |
| `-h`, `--help` | | Muestra la ayuda. |

**Códigos de salida:** `0` correcto · `1` fallo en la ejecución · `2` error en los argumentos (útil para automatizar con otros scripts).

### Definir la VM en un archivo (`--vars`)

Es la forma más cercana a IaC: la VM queda descrita en un archivo que se versiona en Git.

```ini
# ejemplos/ubuntu-server.vars
VM_NAME=ubuntu-server
ISO=C:\ISOs\ubuntu-24.04-live-server-amd64.iso
CPUS=2
MEM_MB=4096
DISK_GB=40
NET=nat
```

```bat
crear-vm.cmd --vars ejemplos\ubuntu-server.vars --start
:: Un parámetro posterior sobrescribe el archivo:
crear-vm.cmd --vars ejemplos\ubuntu-server.vars --name srv02 --mem 8192
```

Claves válidas: `VM_NAME`, `DIR`, `ISO`, `OS`, `CPUS`, `MEM_MB`, `DISK_GB`, `NET`, `NIC`, `FIRMWARE`, `HWVER`. Sin espacios alrededor del `=`.

## Qué hace cada paso (y equivalencia con el taller ESXi)

El script imprime los pasos `[1/7]`…`[7/7]`. Esta tabla compara con el taller original:

| Paso | Taller original (ESXi) | Este taller (Workstation) | Qué ocurre |
|---|---|---|---|
| 1 | `esxcli storage filesystem list` (verificar datastore) | Verificación de herramientas y parámetros | Comprueba que existan `vmrun.exe` y `vmware-vdiskmanager.exe`, valida cada parámetro y detecta si la VM ya existe. |
| 2 | `mkdir` en `/vmfs/volumes/...` | `mkdir` en `--dir\NOMBRE` | Crea la carpeta que contendrá todos los archivos de la VM. |
| 3 | `vmkfstools -c 20G -d thin` | `vmware-vdiskmanager -c -s 20GB -a lsilogic -t 0` | Crea el disco virtual. Tipo `0` = archivo creciente (equivale a *thin*); `--prealloc` usa el tipo `2` (equivale a *thick*). |
| 4 | Escribir el VMX a mano | El script **genera** el `.vmx` con tus parámetros | Sin errores de tipeo ni nombres inconsistentes. |
| 5 | `vim-cmd solo/registervm` | Validación de archivos | En Workstation no se “registra”: la VM se identifica por la ruta de su `.vmx`. Para verla en la biblioteca use *Archivo → Abrir*. |
| 6 | `vim-cmd vmsvc/power.on ID` | `vmrun -T ws start "ruta.vmx" gui` | Enciende la VM (solo con `--start`). |
| 7 | `vim-cmd vmsvc/power.getstate ID` | `vmrun -T ws list` | Confirma que la VM aparece entre las máquinas en ejecución. |

### Mejoras respecto al taller original

- **Parametrizado:** nombre, CPU, RAM, disco, red e ISO cambian sin editar el script.
- **Consistente:** el original mezclaba `sunombre.vmx`, `VM_Taller` y `Nombre_datastore`/`datastore_nombre`; aquí un solo nombre gobierna todos los archivos.
- **Validación de entradas:** rechaza nombres, rangos y valores de red inválidos antes de tocar el disco.
- **Modo simulación (`--dry-run`):** permite ver qué haría el script, ideal para explicar cada paso.
- **Idempotencia razonable:** si la VM ya existe, se detiene con un mensaje; con `--force` la recrea.
- **Operación inversa:** `eliminar-vm.cmd` cierra el ciclo crear → usar → destruir.
- **Definición declarativa:** `--vars` permite versionar la VM en Git.
- **Códigos de salida** claros para integrarlo con otros scripts.

## Archivo VMX generado

Con los valores por defecto, el script produce algo equivalente a:

```ini
.encoding = "windows-1252"
config.version = "8"
virtualHW.version = "16"
displayName = "VM_Taller"
guestOS = "ubuntu-64"
firmware = "bios"
memsize = "2048"
numvcpus = "2"
scsi0.present = "TRUE"
scsi0.virtualDev = "lsilogic"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "VM_Taller.vmdk"
sata0.present = "TRUE"
sata0:0.present = "TRUE"
sata0:0.deviceType = "cdrom-image"
sata0:0.fileName = "C:\ISOs\ubuntu.iso"
sata0:0.startConnected = "TRUE"
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "e1000e"
ethernet0.addressType = "generated"
ethernet0.startConnected = "TRUE"
floppy0.present = "FALSE"
usb.present = "TRUE"
sound.present = "FALSE"
tools.syncTime = "FALSE"
uuid.action = "create"
```

## Actividades para el estudiante

Conserve la exigencia del taller original: **explique cada paso con investigación propia y use normas APA 7** en todo el documento (citas, figuras y tablas).

1. Ejecute `crear-vm.cmd ... --dry-run` y capture la salida (Figura 1). Explique qué hace cada comando y cada línea del VMX.
2. Investigue la diferencia entre disco creciente (`-t 0`) y preasignado (`-t 2`) y elabore una tabla comparativa (Tabla 1) con espacio en disco y rendimiento.
3. Cree la VM real con `--start`, instale el sistema y muestre la VM en ejecución (Figura 2).
4. Repita la creación con otros parámetros (`--cpus 4 --mem 4096 --net bridged`) y compare los `.vmx`. ¿Qué cambió?
5. Cree un archivo `.vars` propio y explique por qué versionar la definición es una práctica de IaC.
6. Ejecute de nuevo el mismo comando **sin** `--force`: ¿qué ocurre y por qué es deseable? Luego use `--force`.
7. Destruya la VM con `eliminar-vm.cmd` y verifique que la carpeta desapareció.
8. Reflexión: ¿qué ventajas y qué limitaciones tiene este script frente a herramientas como Terraform o Vagrant?

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `No se encontro vmrun.exe...` | VMware instalado en otra ruta | Use `--vmware-dir "D:\Ruta\VMware Workstation"` |
| `Nombre invalido` | Espacios o símbolos en `--name` | Use solo letras, números, `.`, `-`, `_` |
| `La VM ya existe` | Existe la carpeta/VMX | Cambie `--name` o use `--force` |
| La VM no arranca desde la ISO | Ruta de ISO incorrecta o firmware inadecuado | Verifique `--iso`; pruebe `--firmware efi` si la ISO lo requiere |
| Windows 11 no instala | Windows 11 exige requisitos adicionales (p. ej. TPM y arranque seguro) que este script no configura | Cree esa VM desde la interfaz gráfica de Workstation o use un SO invitado distinto |
| Caracteres extraños | Ruta con tildes/ñ | Use rutas sin caracteres especiales |

## Publicar este taller en GitHub

Desde la carpeta del proyecto:

```bash
git init
git add .
git commit -m "Taller IaC con VMware Workstation"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/taller-iac-vmware-workstation.git
git push -u origin main
```

El archivo `.gitattributes` garantiza que los `.cmd` mantengan finales de línea CRLF, y `.gitignore` evita subir discos, ISOs y logs.

## Referencias (APA 7)

Broadcom. (s. f.). *Syntax of vmrun commands*. VMware Workstation Pro 17.0 Documentation. https://techdocs.broadcom.com/us/en/vmware-cis/desktop-hypervisors/workstation-pro/17-0/using-vmware-workstation-pro/using-the-vmrun-command-to-control-virtual-machines/running-vmrun-commands/syntax-of-vmrun-commands.html

Broadcom. (s. f.). *Using Virtual Disk Manager*. VMware Workstation Pro 17.0 Documentation. https://techdocs.broadcom.com/us/en/vmware-cis/desktop-hypervisors/workstation-pro/17-0/using-vmware-workstation-pro/configuring-and-managing-devices/configuring-and-maintaining-virtual-hard-disks-1/using-virtual-disk-manager.html

## Licencia

[MIT](LICENSE)
