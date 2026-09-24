@echo off
rem ==========================================================================
rem  eliminar-vm.cmd
rem  Taller IaC con VMware Workstation: destruye una VM creada con crear-vm.cmd.
rem  (En IaC, crear y destruir deben ser reproducibles y simetricos.)
rem
rem  Uso:  eliminar-vm.cmd --name NOMBRE [--dir RUTA] [--yes] [--dry-run]
rem  Codigos de salida: 0 = correcto, 1 = error de ejecucion, 2 = error de argumentos
rem ==========================================================================
setlocal EnableExtensions
title Taller IaC - Eliminar VM

set "VM_NAME="
set "DIR=%USERPROFILE%\Documents\Virtual Machines"
set "YES=0"
set "DRYRUN=0"
set "VMWARE_DIR=C:\Program Files (x86)\VMware\VMware Workstation"

:parse
if "%~1"=="" goto :validate
set "OPT=%~1"
if /i "%OPT%"=="-h"         goto :help
if /i "%OPT%"=="--help"     goto :help
if /i "%OPT%"=="/?"         goto :help
if /i "%OPT%"=="--yes"      set "YES=1"    & goto :take1
if /i "%OPT%"=="--dry-run"  set "DRYRUN=1" & goto :take1
if /i "%OPT%"=="--name"       set "VM_NAME=%~2"    & goto :take2
if /i "%OPT%"=="--dir"        set "DIR=%~2"        & goto :take2
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

:validate
echo.
echo ============================================================
echo   Taller IaC - Eliminacion de VM en VMware Workstation
echo ============================================================
if "%DRYRUN%"=="1" echo   MODO SIMULACION ^(--dry-run^): no se modifica nada.
echo.

if "%VM_NAME%"=="" set "MSG=Debe indicar --name NOMBRE" & goto :fail_args
echo %VM_NAME%| findstr /r /c:"^[A-Za-z0-9_.-][A-Za-z0-9_.-]*$" >nul || goto :e_name

if not exist "%VMWARE_DIR%\vmrun.exe" if exist "%ProgramFiles%\VMware\VMware Workstation\vmrun.exe" set "VMWARE_DIR=%ProgramFiles%\VMware\VMware Workstation"
set "VMRUN=%VMWARE_DIR%\vmrun.exe"
if not exist "%VMRUN%" goto :e_novmware

if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
for %%D in ("%DIR%") do set "DIR=%%~fD"
set "VM_DIR=%DIR%\%VM_NAME%"
set "VMX=%VM_DIR%\%VM_NAME%.vmx"
if not exist "%VMX%" goto :e_notfound

echo   VM a eliminar : %VM_NAME%
echo   Archivo       : %VMX%
echo.
if "%YES%"=="1" goto :go
if "%DRYRUN%"=="1" goto :go
set "CONF="
set /p "CONF=Se eliminaran la VM y sus discos. Escriba SI para confirmar: "
if /i not "%CONF%"=="SI" goto :cancel

:go
echo [1/3] Comprobando si la VM esta encendida...
"%VMRUN%" -T ws list | findstr /i /c:"%VMX%" >nul
if errorlevel 1 goto :step2
echo       Esta encendida: se apagara ^(hard^).
call :exec "%VMRUN%" -T ws stop "%VMX%" hard || goto :fail_run

:step2
echo.
echo [2/3] Eliminando la VM ^(vmrun deleteVM^)...
call :exec "%VMRUN%" -T ws deleteVM "%VMX%" || goto :fail_run

echo.
echo [3/3] Limpiando carpeta...
if "%DRYRUN%"=="1" goto :done
if exist "%VM_DIR%" rmdir "%VM_DIR%" 2>nul
if exist "%VM_DIR%" echo       La carpeta contiene otros archivos y se conservo: %VM_DIR%

:done
echo.
echo ============================================================
echo   Listo.
echo ============================================================
endlocal
exit /b 0

:cancel
echo.
echo   Operacion cancelada. No se elimino nada.
endlocal
exit /b 1

:exec
echo     ^> %*
if "%DRYRUN%"=="1" exit /b 0
%*
exit /b %errorlevel%

:e_name
set "MSG=Nombre invalido: use solo letras, numeros, punto, guion y guion bajo"
goto :fail_args
:e_novmware
set "MSG=No se encontro vmrun.exe en: %VMWARE_DIR%  (use --vmware-dir)"
goto :fail_args
:e_notfound
set "MSG=No existe la VM: %VMX%"
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
echo  eliminar-vm.cmd - Elimina una VM creada con crear-vm.cmd
echo.
echo  USO:   eliminar-vm.cmd --name NOMBRE [opciones]
echo.
echo    --name NOMBRE        Nombre de la VM ^(obligatorio^)
echo    --dir RUTA           Carpeta base ^(defecto: Documents\Virtual Machines^)
echo    --yes                No pide confirmacion
echo    --dry-run            Simula: muestra los comandos sin ejecutarlos
echo    --vmware-dir RUTA    Carpeta de instalacion de VMware Workstation
echo    -h, --help           Muestra esta ayuda
echo.
endlocal
exit /b 0
