@echo off
rem Executa o jogo (usa a versao console para mostrar erros e prints neste terminal).
rem Ajuste GODOT se mover a instalacao.
set "GODOT=D:\Program Files\Godot_v4.6-beta2_mono_win64\Godot_v4.6-stable_win64_console.exe"

if not exist "%GODOT%" (
    echo Godot nao encontrado em: %GODOT%
    pause
    exit /b 1
)

pushd "%~dp0"
"%GODOT%" --path . %*
set "CODE=%errorlevel%"
popd
if not "%CODE%"=="0" pause
