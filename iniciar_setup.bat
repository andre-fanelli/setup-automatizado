@echo off
title Piloto Automatico de Configuracao de PC

:: Verifica e solicita privilégios de Administrador
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Solicitando privilegios de Administrador...
    powershell.exe -Command "Start-Process cmd.exe -ArgumentList '/c %~s0' -Verb RunAs"
    exit /B
)

:: Executa o script PowerShell principal
pushd "%~dp0"
powershell.exe -ExecutionPolicy Bypass -File "%~dp0setup_automatizado.ps1"

echo.
echo Processo finalizado. Pressione qualquer tecla para fechar.
pause > nul