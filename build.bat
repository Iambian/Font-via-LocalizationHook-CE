@echo off
:start
tools\spasm-ng -E src\main.z80 bin\FONTHOOK.8xp
pause
goto start
