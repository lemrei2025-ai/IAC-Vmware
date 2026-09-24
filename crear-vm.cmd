@echo off
rem ==========================================================================
rem  crear-vm.cmd
rem  Taller de Infraestructura como Codigo (IaC) con VMware Workstation.
rem  Crea una maquina virtual completa (carpeta, disco, VMX) y, opcionalmente,
rem  la enciende. Todo se controla por parametros: mismo script, otra VM.
rem
rem  Uso rapido:   crear-vm.cmd --help
rem  Simulacion:   crear-vm.cmd --name demo --iso C:\ISOs\ubuntu.iso --dry-run
rem
rem  Codigos de salida: 0 = correcto, 1 = error de ejecucion, 2 = error de argumentos
rem  Nota: el archivo esta en ASCII a proposito (sin tildes) para evitar
rem        problemas de codificacion en cmd.exe.
rem ==========================================================================
setlocal EnableExtensions
title Taller IaC - VMware Workstation

rem ---------- Valores por defecto (todos se pueden cambiar por parametro) ----------
set "VM_NAME=VM_Taller"
set "DIR=%USERPROFILE%\Documents\Virtual Machines"
set "ISO="
set "OS=ubuntu-64"
set "CPUS=2"
set "MEM_MB=2048"
set "DISK_GB=20"
set "NET=nat"
set "NIC=e1000e"
set "FIRMWARE=bios"
set "HWVER=16"
set "PREALLOC=0"
set "START=0"
set "MODE=gui"
set "FORCE=0"
set "DRYRUN=0"
set "VMWARE_DIR=C:\Program Files (x86)\VMware\VMware Workstation"

rem ---------- Lectura de parametros ----------
:parse
if "%~1"=="" goto :validate
set "OPT=%~1"
if /i "%OPT%"=="-h"         goto :help
if /i "%OPT%"=="--help"     goto :help
if /i "%OPT%"=="/?"         goto :help
if /i "%OPT%"=="--start"    set "START=1"    & goto :take1
if /i "%OPT%"=="--nogui"    set "MODE=nogui" & goto :take1
if /i "%OPT%"=="--force"    set "FORCE=1"    & goto :take1
if /i "%OPT%"=="--dry-run"  set "DRYRUN=1"   & goto :take1
if /i "%OPT%"=="--prealloc" set "PREALLOC=1" & goto :take1
if /i "%OPT%"=="--vars"     goto :opt_vars
if /i "%OPT%"=="--name"       set "VM_NAME=%~2"    & goto :take2
if /i "%OPT%"=="--dir"        set "DIR=%~2"        & goto :take2
if /i "%OPT%"=="--iso"        set "ISO=%~2"        & goto :take2
if /i "%OPT%"=="--os"         set "OS=%~2"         & goto :take2
if /i "%OPT%"=="--cpus"       set "CPUS=%~2"       & goto :take2
if /i "%OPT%"=="--mem"        set "MEM_MB=%~2"     & goto :take2
if /i "%OPT%"=="--disk"       set "DISK_GB=%~2"    & goto :take2
if /i "%OPT%"=="--net"        set "NET=%~2"        & goto :take2
if /i "%OPT%"=="--nic"        set "NIC=%~2"        & goto :take2
if /i "%OPT%"=="--firmware"   set "FIRMWARE=%~2"   & goto :take2
if /i "%OPT%"=="--hw"         set "HWVER=%~2"      & goto :take2
if /i "%OPT%"=="--vmware-dir" set "VMWARE_DIR=%~2" & goto :take2
set "MSG=Parametro desconocido: %OPT%  (use --help)"
goto :fail_args

:take1
shift
goto :parse

:take2
if "%~2"=="" goto :missing
shift
shift
goto :parse

:missing
set "MSG=Falta el valor del parametro %OPT%"
goto :fail_args

:opt_vars
if "%~2"=="" goto :missing
if not exist "%~2" goto :novars
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%~2") do set "%%A=%%B"
goto :take2

:novars
set "MSG=No existe el archivo de variables: %~2"
goto :fail_args

rem ---------- PASO 1: verificar requisitos y parametros ----------
:validate
echo.
echo ============================================================
echo   Taller IaC - Creacion de VM en VMware Workstation
echo ============================================================
if "%DRYRUN%"=="1" echo   MODO SIMULACION ^(--dry-run^): no se modifica nada.
echo.
echo [1/7] Verificando herramientas y parametros...

if not exist "%VMWARE_DIR%\vmrun.exe" if exist "%ProgramFiles%\VMware\VMware Workstation\vmrun.exe" set "VMWARE_DIR=%ProgramFiles%\VMware\VMware Workstation"
set "VMRUN=%VMWARE_DIR%\vmrun.exe"
set "VDISK=%VMWARE_DIR%\vmware-vdiskmanager.exe"
if not exist "%VMRUN%" goto :e_novmware
if not exist "%VDISK%" goto :e_novmware

echo %VM_NAME%| findstr /r /c:"^[A-Za-z0-9_.-][A-Za-z0-9_.-]*$" >nul || goto :e_name
echo %OS%| findstr /r /c:"^[A-Za-z0-9_.-][A-Za-z0-9_.-]*$" >nul || goto :e_os
echo %HWVER%| findstr /r /c:"^[1-9][0-9]*$" >nul || goto :e_hw

call :chk_num CPUS 1 32 || goto :e_cpus
call :chk_num MEM_MB 512 262144 || goto :e_mem
call :chk_num DISK_GB 1 8192 || goto :e_disk
set /a MEMMOD=%MEM_MB% %% 4
if not "%MEMMOD%"=="0" goto :e_mem4

set "OK="
for %%N in (nat bridged hostonly) do if /i "%NET%"=="%%N" set "NET=%%N" & set "OK=1"
if not defined OK goto :e_net
set "OK="
for %%N in (e1000 e1000e vmxnet3) do if /i "%NIC%"=="%%N" set "NIC=%%N" & set "OK=1"
if not defined OK goto :e_nic
set "OK="
for %%N in (bios efi) do if /i "%FIRMWARE%"=="%%N" set "FIRMWARE=%%N" & set "OK=1"
if not defined OK goto :e_fw

if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
for %%D in ("%DIR%") do set "DIR=%%~fD"
if not "%ISO%"=="" if not exist "%ISO%" goto :e_iso
if not "%ISO%"=="" for %%I in ("%ISO%") do set "ISO=%%~fI"

set "VM_DIR=%DIR%\%VM_NAME%"
set "VMX=%VM_DIR%\%VM_NAME%.vmx"
set "VMDK=%VM_DIR%\%VM_NAME%.vmdk"
set "DISKTYPE=0"
if "%PREALLOC%"=="1" set "DISKTYPE=2"

if not exist "%VMX%" goto :params_ok
if "%FORCE%"=="0" goto :e_exists
"%VMRUN%" -T ws list | findstr /i /c:"%VMX%" >nul && goto :e_running

:params_ok
echo       Herramientas : %VMWARE_DIR%
echo       Nombre       : %VM_NAME%
echo       Carpeta      : %VM_DIR%
echo       CPU / RAM    : %CPUS% vCPU / %MEM_MB% MB
echo       Disco        : %DISK_GB% GB  ^(tipo vmdk %DISKTYPE%: 0=creciente, 2=preasignado^)
echo       Red          : %NET% ^(%NIC%^)   Firmware: %FIRMWARE%   HW: %HWVER%
echo       SO invitado  : %OS%
if "%ISO%"=="" echo       ISO          : ^(ninguna: se usara la unidad fisica^)
if not "%ISO%"=="" echo       ISO          : %ISO%

rem ---------- PASO 2: carpeta de la VM ----------
echo.
echo [2/7] Creando carpeta de la VM...
if "%FORCE%"=="1" for %%E in (vmx vmdk nvram vmsd vmxf) do if exist "%VM_DIR%\%VM_NAME%*.%%E" call :exec del /q "%VM_DIR%\%VM_NAME%*.%%E"
if not exist "%VM_DIR%" call :exec mkdir "%VM_DIR%" || goto :fail_run

rem ---------- PASO 3: disco virtual ----------
echo.
echo [3/7] Creando disco virtual ^(vmware-vdiskmanager^)...
call :exec "%VDISK%" -c -s %DISK_GB%GB -a lsilogic -t %DISKTYPE% "%VMDK%" || goto :fail_run

rem ---------- PASO 4: archivo VMX ----------
echo.
echo [4/7] Generando archivo de configuracion .vmx...
set "VMXOUT=%VMX%"
if "%DRYRUN%"=="1" set "VMXOUT=%TEMP%\%VM_NAME%.vmx.preview"
call :write_vmx
echo       Escrito: %VMXOUT%
if "%DRYRUN%"=="1" type "%VMXOUT%"

rem ---------- PASO 5: validar archivos ----------
echo.
echo [5/7] Validando archivos generados...
if "%DRYRUN%"=="1" goto :step6
if not exist "%VMX%" goto :e_novmx
if not exist "%VMDK%" goto :e_novmdk
findstr /b /c:"displayName" "%VMX%" >nul || goto :e_novmx
for %%F in ("%VMDK%") do echo       Disco: %%~nxF - %%~zF bytes ^(crece bajo demanda si el tipo es 0^)
echo       OK: .vmx y .vmdk presentes. ^(Workstation no requiere "registrar": se usa la ruta del .vmx^)

rem ---------- PASO 6: encender ----------
:step6
echo.
echo [6/7] Encendido de la VM...
if "%START%"=="0" echo       Omitido ^(use --start para encenderla^) & goto :step7
call :exec "%VMRUN%" -T ws start "%VMX%" %MODE% || goto :fail_run

rem ---------- PASO 7: validacion final ----------
:step7
echo.
echo [7/7] Validacion final...
if "%DRYRUN%"=="1" echo       Simulacion terminada. Nada fue creado. & goto :done
if "%START%"=="0" echo       VM creada. Abrala con: Archivo ^> Abrir ^> %VMX% & goto :done
timeout /t 5 /nobreak >nul
"%VMRUN%" -T ws list | findstr /i /c:"%VM_NAME%.vmx" >nul
if errorlevel 1 goto :e_notrunning
echo       OK: la VM aparece en la lista de maquinas en ejecucion.

:done
echo.
echo ============================================================
echo   Listo.  VM: %VM_NAME%
echo   Archivo: %VMX%
echo ============================================================
endlocal
exit /b 0

rem ==========================================================================
rem  SUBRUTINAS
rem ==========================================================================

:exec
rem Muestra el comando; lo ejecuta salvo en --dry-run.
echo     ^> %*
if "%DRYRUN%"=="1" exit /b 0
%*
exit /b %errorlevel%

:chk_num
rem %1 = nombre de variable, %2 = minimo, %3 = maximo. Solo enteros positivos sin ceros a la izquierda.
call set "VAL=%%%~1%%"
echo %VAL%| findstr /r /c:"^[1-9][0-9]*$" >nul || exit /b 1
if not "%VAL:~6,1%"=="" exit /b 1
if %VAL% LSS %2 exit /b 1
if %VAL% GTR %3 exit /b 1
exit /b 0

:write_vmx
> "%VMXOUT%" echo .encoding = "windows-1252"
>> "%VMXOUT%" echo config.version = "8"
>> "%VMXOUT%" echo virtualHW.version = "%HWVER%"
>> "%VMXOUT%" echo displayName = "%VM_NAME%"
>> "%VMXOUT%" echo guestOS = "%OS%"
>> "%VMXOUT%" echo firmware = "%FIRMWARE%"
>> "%VMXOUT%" echo memsize = "%MEM_MB%"
>> "%VMXOUT%" echo numvcpus = "%CPUS%"
>> "%VMXOUT%" echo scsi0.present = "TRUE"
>> "%VMXOUT%" echo scsi0.virtualDev = "lsilogic"
>> "%VMXOUT%" echo scsi0:0.present = "TRUE"
>> "%VMXOUT%" echo scsi0:0.fileName = "%VM_NAME%.vmdk"
>> "%VMXOUT%" echo sata0.present = "TRUE"
>> "%VMXOUT%" echo sata0:0.present = "TRUE"
if "%ISO%"=="" goto :vmx_cdrom_raw
>> "%VMXOUT%" echo sata0:0.deviceType = "cdrom-image"
>> "%VMXOUT%" echo sata0:0.fileName = "%ISO%"
goto :vmx_net
:vmx_cdrom_raw
>> "%VMXOUT%" echo sata0:0.deviceType = "cdrom-raw"
>> "%VMXOUT%" echo sata0:0.autodetect = "TRUE"
:vmx_net
>> "%VMXOUT%" echo sata0:0.startConnected = "TRUE"
>> "%VMXOUT%" echo ethernet0.present = "TRUE"
>> "%VMXOUT%" echo ethernet0.connectionType = "%NET%"
>> "%VMXOUT%" echo ethernet0.virtualDev = "%NIC%"
>> "%VMXOUT%" echo ethernet0.addressType = "generated"
>> "%VMXOUT%" echo ethernet0.startConnected = "TRUE"
>> "%VMXOUT%" echo floppy0.present = "FALSE"
>> "%VMXOUT%" echo usb.present = "TRUE"
>> "%VMXOUT%" echo sound.present = "FALSE"
>> "%VMXOUT%" echo tools.syncTime = "FALSE"
>> "%VMXOUT%" echo uuid.action = "create"
exit /b 0

rem ==========================================================================
rem  MENSAJES DE ERROR
rem ==========================================================================
:e_novmware
set "MSG=No se encontro vmrun.exe / vmware-vdiskmanager.exe en: %VMWARE_DIR%  (use --vmware-dir)"
goto :fail_args
:e_name
set "MSG=Nombre invalido: use solo letras, numeros, punto, guion y guion bajo (--name)"
goto :fail_args
:e_os
set "MSG=Valor invalido para --os (ej.: ubuntu-64, debian12-64, windows11-64)"
goto :fail_args
:e_hw
set "MSG=Valor invalido para --hw (numero entero, ej.: 16)"
goto :fail_args
:e_cpus
set "MSG=--cpus debe ser un entero entre 1 y 32"
goto :fail_args
:e_mem
set "MSG=--mem debe ser un entero entre 512 y 262144 (MB)"
goto :fail_args
:e_mem4
set "MSG=--mem debe ser multiplo de 4 (MB)"
goto :fail_args
:e_disk
set "MSG=--disk debe ser un entero entre 1 y 8192 (GB)"
goto :fail_args
:e_net
set "MSG=--net debe ser: nat, bridged o hostonly"
goto :fail_args
:e_nic
set "MSG=--nic debe ser: e1000, e1000e o vmxnet3"
goto :fail_args
:e_fw
set "MSG=--firmware debe ser: bios o efi"
goto :fail_args
:e_iso
set "MSG=No se encontro el archivo ISO indicado en --iso: %ISO%"
goto :fail_args
:e_exists
set "MSG=La VM ya existe: %VMX%  (use --force para recrearla o cambie --name)"
goto :fail_run
:e_running
set "MSG=La VM esta en ejecucion. Apaguela antes de usar --force."
goto :fail_run
:e_novmx
set "MSG=Validacion fallida: el archivo .vmx no se genero correctamente"
goto :fail_run
:e_novmdk
set "MSG=Validacion fallida: el disco .vmdk no existe"
goto :fail_run
:e_notrunning
set "MSG=La VM no aparece como encendida. Revise la ventana de VMware Workstation."
goto :fail_run

:fail_args
echo.
echo [ERROR] %MSG%
endlocal
exit /b 2

:fail_run
echo.
if not defined MSG set "MSG=Fallo un comando. Revise el mensaje anterior."
echo [ERROR] %MSG%
endlocal
exit /b 1

:help
echo.
echo  crear-vm.cmd - Crea una VM en VMware Workstation ^(Infraestructura como Codigo^)
echo.
echo  USO:   crear-vm.cmd [opciones]
echo.
echo  PARAMETROS                      DEFECTO
echo    --name NOMBRE                 VM_Taller        Nombre de la VM (y de la carpeta)
echo    --dir RUTA                    Documents\Virtual Machines   Carpeta base de las VMs
echo    --iso RUTA.iso                (ninguno)        ISO de instalacion
echo    --os GUEST                    ubuntu-64        guestOS del VMX
echo    --cpus N                      2                vCPU (1-32)
echo    --mem MB                      2048             RAM en MB (multiplo de 4)
echo    --disk GB                     20               Tamano del disco en GB
echo    --net nat/bridged/hostonly    nat              Modo de red
echo    --nic e1000/e1000e/vmxnet3    e1000e           Adaptador de red
echo    --firmware bios/efi           bios             Firmware de arranque
echo    --hw N                        16               virtualHW.version
echo    --prealloc                    (no)             Disco preasignado en vez de creciente
echo    --start                       (no)             Enciende la VM al terminar
echo    --nogui                       (no)             Enciende sin ventana
echo    --force                       (no)             Recrea la VM si ya existe
echo    --dry-run                     (no)             Simula: muestra comandos y VMX, no crea nada
echo    --vars ARCHIVO                (ninguno)        Carga parametros desde un archivo CLAVE=VALOR
echo    --vmware-dir RUTA             Program Files (x86)\VMware\VMware Workstation
echo    -h, --help                                     Muestra esta ayuda
echo.
echo  EJEMPLOS:
echo    crear-vm.cmd --name srv01 --iso C:\ISOs\ubuntu-server.iso --start
echo    crear-vm.cmd --name lab --cpus 4 --mem 8192 --disk 60 --net bridged --dry-run
echo    crear-vm.cmd --vars ejemplos\ubuntu-server.vars --start
echo.
endlocal
exit /b 0
