@echo off
set "GIT_BASH_PATH=C:\Program Files\Git\git-bash.exe"


if not exist "%GIT_BASH_PATH%" (
    echo Git Bash no esta instalado en la ubicacion especificada.
    echo Es necesario para ejecutar el juego.
    echo.
    choice /C SN /M "¿Deseas abrir la web de descarga de Git Bash?"
    if errorlevel 2 (
        echo Operacion cancelada.
        timeout /t 5 >nul
        exit /b
    ) else (
        start "" "https://git-scm.com/downloads"
        timeout /t 5 >nul
        exit /b
    )
)

echo Tienes Git Bash esta instalado!.
echo Abriendo "D&D..."  



set "SCRIPT_PATH=%~dp0Game\DandD.sh"

cd /d "%~dp0Game"


start "" "%GIT_BASH_PATH%" --cd="%cd%" -c "bash '%SCRIPT_PATH%'"


timeout /t 5 /nobreak >nul
