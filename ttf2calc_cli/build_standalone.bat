@echo off
rem Usage:   build_standalone.bat <basename> [fhook]
rem Example: build_standalone.bat courier
rem Example: build_standalone.bat courier fhook

rem BUILDS STANDALONE FONT INSTALLER (loader+hook+data).
if not exist "obj" mkdir obj
python packer.py

set HOOK_LIB=lhook
if /I "%2"=="fhook" set HOOK_LIB=fhook

echo #define USING_LOADER > obj\main.asm
type ..\lib\%HOOK_LIB%\sahead.asm >> obj\main.asm
type ..\lib\%HOOK_LIB%\loader.asm >> obj\main.asm
type ..\lib\%HOOK_LIB%\hook.asm >> obj\main.asm
type obj\encodings.z80 >> obj\main.asm
type obj\lfont.z80 >> obj\main.asm
if /I not "%HOOK_LIB%"=="fhook" type obj\sfont.z80 >> obj\main.asm
..\tools\spasm-ng -E -I ..\include obj\main.asm obj\main.bin
if "%1%"=="" (
 set VAR=FONTHOOK.8xp
) else (
 set VAR=%1%.8xp
)
python ..\tools\binconv.py obj\main.bin ..\build\%VAR%

