# Taller de IaC: construya un script `.cmd` que cree una VM en VMware Workstation

![Plataforma](https://img.shields.io/badge/host-Windows-0078D6)
![VMware](https://img.shields.io/badge/VMware-Workstation-607078)
![Entrega](https://img.shields.io/badge/entrega-GitHub-181717)

Este taller es la evolución del taller *“Creación de VM en ESXi por consola”*. Allí se ejecutaban comandos uno por uno; aquí usted **construirá un script parametrizado que crea la máquina virtual por usted**, siempre de la misma manera. Esa es la idea de la **Infraestructura como Código (IaC)**: la infraestructura se describe y se crea con código repetible, versionable y auditable.

> **Este enunciado no incluye comandos ni ejemplos de solución.** Encontrar las herramientas, los formatos de archivo y la sintaxis correcta hace parte del aprendizaje. Investigue, pruebe y **explique con sus propias palabras** lo que descubra.

## 1. Objetivo

Construir un script para `cmd.exe` (`crear-vm.cmd`) que, a partir de parámetros, cree y opcionalmente encienda una máquina virtual en **VMware Workstation** instalado en Windows, y documentar la investigación y las pruebas realizadas.

**Resultados de aprendizaje**

- Explicar qué archivos componen una máquina virtual de VMware y qué función cumple cada uno.
- Automatizar la creación de una VM usando únicamente las utilidades de línea de comandos que incluye VMware Workstation.
- Aplicar buenas prácticas de IaC: parametrización, validación de entradas, idempotencia, simulación y control de versiones.
- Documentar y sustentar el trabajo con fuentes confiables en formato APA 7.

## 2. Restricciones

1. El script debe ser un archivo `.cmd` o `.bat` (sin PowerShell, Python ni otros lenguajes).
2. Solo puede usar comandos propios de Windows y las utilidades de línea de comandos **incluidas con VMware Workstation**.
3. No se permite editar a mano el archivo de configuración de la VM: **debe generarlo el script**.
4. El script no debe contener rutas personales fijas (por ejemplo, su nombre de usuario). Use variables de entorno o parámetros.
5. El script no debe hacer preguntas interactivas durante la creación (todo entra por parámetros).
6. Todo el trabajo se entrega en un repositorio de **GitHub** (ver sección 8).

## 3. Requisitos funcionales

El script debe reproducir, adaptados a Workstation, los pasos del taller ESXi. Para cada uno, **usted decide qué comando lo resuelve**:

| # | Paso del taller original | Requisito para su script |
|---|---|---|
| 1 | Verificar el datastore | Verificar que las herramientas de VMware existan, que los parámetros sean válidos y que el archivo ISO (si se indica) exista. |
| 2 | Crear la carpeta de la VM | Crear la carpeta destino de la VM (con el nombre de la VM). |
| 3 | Crear el disco virtual | Crear un disco virtual del tamaño indicado; por defecto **de crecimiento dinámico**. |
| 4 | Crear el archivo de configuración | Generar el archivo de configuración de la VM a partir de los parámetros (ver 3.2). |
| 5 | Registrar la VM | Investigue si Workstation requiere “registrar” una VM y qué equivale a ese paso. Explíquelo en su informe. |
| 6 | Encender la VM | Encender la VM únicamente cuando se pida. |
| 7 | Validar | Comprobar y mostrar si la VM quedó creada y, si se encendió, si está en ejecución. |

### 3.1 Parámetros de línea de comandos

El script debe aceptar **exactamente estos nombres de parámetro** (así se podrá probar su trabajo de forma automática):

| Parámetro | Valor por defecto | Requisito |
|---|---|---|
| `--name NOMBRE` | `VM_Taller` | Nombre de la VM. Solo letras, números, punto, guion y guion bajo. Nombra la carpeta y los archivos. |
| `--dir RUTA` | Carpeta *Documents\Virtual Machines* del usuario actual | Carpeta base donde se crea la carpeta de la VM. |
| `--iso RUTA` | *(ninguno)* | Imagen ISO de instalación. Si se indica y no existe, el script debe fallar. |
| `--cpus N` | `2` | Número de procesadores virtuales (entero positivo). |
| `--mem MB` | `2048` | Memoria RAM en MB (entero positivo). |
| `--disk GB` | `20` | Tamaño del disco en GB (entero positivo). |
| `--net MODO` | `nat` | Modo de red: `nat`, `bridged` o `hostonly`. |
| `--start` | *(desactivado)* | Enciende la VM al terminar. |
| `--dry-run` | *(desactivado)* | Simula: muestra lo que haría, **sin crear ni modificar nada en disco**. |
| `--force` | *(desactivado)* | Permite recrear una VM que ya existe. |
| `-h`, `--help` | | Muestra la ayuda de uso y termina. |

El sistema operativo invitado por defecto debe ser un **Ubuntu de 64 bits**.

### 3.2 Contenido mínimo de la VM generada

Investigue el formato del archivo de configuración de VMware y asegúrese de que la VM incluya, como mínimo: nombre visible, sistema operativo invitado, memoria, procesadores, el disco virtual creado, una unidad de CD/DVD apuntando a la ISO (si se indicó) y un adaptador de red en el modo pedido.

### 3.3 Comportamiento esperado

- **Validación de entradas:** rechazar valores no válidos *antes* de crear nada, con un mensaje claro.
- **Idempotencia segura:** si la VM ya existe, el script se detiene sin modificarla, salvo que se use `--force`. Con `--force`, no debe actuar sobre una VM que esté encendida.
- **Simulación:** con `--dry-run` no debe quedar ningún archivo nuevo en la carpeta de la VM.
- **Ayuda:** `--help` documenta todos los parámetros.
- **Mensajes:** el script informa el progreso paso a paso.
- **Códigos de salida:** `0` = todo correcto · `1` = falló la ejecución · `2` = parámetros inválidos.

## 4. Pruebas de aceptación

Su script será evaluado con estas pruebas. Ejecútelas usted mismo y adjunte la evidencia.

| # | Prueba | Resultado esperado |
|---|---|---|
| T1 | `--help` | Muestra la ayuda; código de salida `0`. |
| T2 | `--name prueba --dry-run` | Muestra los pasos; no crea archivos; código `0`. |
| T3 | `--name "mi vm"` | Rechaza el nombre; código `2`. |
| T4 | `--cpus 0` y `--mem abc` | Rechaza los valores; código `2`. |
| T5 | `--net wifi` | Rechaza el modo de red; código `2`. |
| T6 | `--iso` con una ruta inexistente | Falla antes de crear nada; código `2`. |
| T7 | Creación real con ISO | Existe la carpeta con el archivo de configuración y el disco; **la VM abre correctamente en Workstation**. |
| T8 | Repetir T7 tal cual | Se detiene sin modificar la VM; código `1`. |
| T9 | Repetir T7 con `--force` | Recrea la VM. |
| T10 | Creación real con `--start` | La VM queda encendida y el script lo comprueba. |
| T11 | Parámetros no por defecto (`--cpus 4 --mem 4096 --disk 30 --net bridged`) | La VM generada refleja esos valores. |

## 5. Guía de investigación (preguntas, no respuestas)

Responda estas preguntas en su informe con sus propias palabras y con fuentes citadas:

1. ¿Qué archivos forman una VM de VMware Workstation y para qué sirve cada extensión?
2. ¿Qué utilidades de línea de comandos incluye VMware Workstation? ¿Para qué sirve cada una y dónde se instalan?
3. ¿Qué tipos de disco virtual existen? ¿En qué se diferencia un disco de crecimiento dinámico de uno preasignado? ¿A qué equivale cada uno en ESXi?
4. ¿Cómo se estructura el archivo de configuración de una VM? ¿Qué significan los pares `clave = "valor"`?
5. ¿Qué diferencia hay entre los modos de red NAT, puente (*bridged*) y solo-anfitrión (*host-only*)?
6. ¿Qué es la idempotencia y por qué es deseable en IaC?
7. ¿Cómo se leen parámetros, se validan valores y se devuelven códigos de salida en un archivo por lotes de Windows?
8. ¿Por qué los archivos por lotes son sensibles al formato de fin de línea y a la codificación de caracteres?
9. ¿Qué diferencias hay entre lo que hizo en ESXi y lo que hace ahora en Workstation? ¿Qué pasos desaparecen o cambian y por qué?
10. ¿Qué ventajas y limitaciones tiene su script frente a herramientas como Terraform o Vagrant?

## 6. Informe (formato APA 7)

Igual que en el taller original, **explique cada paso realizado e incluya investigación propia**. Use APA 7 en todo el documento: citas en el texto, referencias, y figuras y tablas numeradas con título. Estructura sugerida:

1. Portada e introducción
2. Marco teórico (respuestas a la guía de investigación)
3. Diseño del script (diagrama de flujo o tabla de pasos)
4. Implementación: explicación de cada bloque del script
5. Pruebas: tabla con T1–T11 y capturas de pantalla como figuras
6. Conclusiones y reflexión
7. Referencias

## 7. Rúbrica (100 puntos)

| Criterio | Puntos |
|---|---|
| **Funcionalidad**: pruebas T1–T11 superadas | 40 |
| **Investigación y explicación**: respuestas a la guía y explicación de cada paso | 25 |
| **Calidad del script**: comentarios, estructura, mensajes claros, sin rutas fijas, uso correcto de validaciones | 15 |
| **Informe APA 7**: citas, referencias, figuras y tablas | 10 |
| **GitHub**: repositorio ordenado, README de uso, commits significativos, `.gitignore` | 10 |
| **Bonus (hasta +10)**: opción para cargar parámetros desde un archivo; script inverso que elimine la VM; opción de disco preasignado; mensajes de error con sugerencias | +10 |

## 8. Entrega en GitHub

Cree un repositorio propio (`taller-iac-vmware-workstation-SU_APELLIDO`) con esta estructura:

```text
.
├── crear-vm.cmd        # su script
├── README.md           # cómo usar su script (parámetros, ejemplos, requisitos)
├── informe/            # informe en PDF con formato APA 7
├── evidencias/         # capturas de las pruebas T1–T11
├── .gitignore          # NO suba discos virtuales, ISOs ni logs
└── .gitattributes      # mantenga finales de línea CRLF en los .cmd
```

Requisitos de entrega:

- Al menos **5 commits** con mensajes descriptivos que muestren su avance.
- **Prohibido** subir archivos `.vmdk`, `.iso`, `.nvram` o cualquier archivo pesado de VM.
- Compartir la URL del repositorio en la plataforma del curso antes de la fecha límite.

## 9. Sugerencia de trabajo

1. Cree **una VM a mano** desde la interfaz gráfica de Workstation y observe qué archivos se generan.
2. Averigüe qué utilidades de línea de comandos existen y pruébelas de forma aislada.
3. Empiece por un script mínimo que cree solo el disco; agregue un paso a la vez.
4. Implemente `--dry-run` y las validaciones desde el principio: le ahorrarán borrar VMs de prueba.
5. Haga un commit cada vez que un paso funcione.

## 10. Referencias de partida

Consulte la documentación oficial de VMware Workstation Pro publicada por Broadcom (sección de uso de utilidades de línea de comandos y gestión de discos virtuales) y la documentación de Microsoft sobre `cmd` y archivos por lotes. **Búsquelas usted mismo y cítelas en APA 7**.
