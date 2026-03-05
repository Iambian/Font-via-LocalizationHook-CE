@echo off
rem Usage:   build_standalone.bat <basename>
rem Example: build_standalone.bat courier

rem BUILDS STANDALONE FONT INSTALLER (loader+hook+data).
rem ASSUMES CURRENT DIRECTORY IS hook
if not exist "obj" mkdir obj
python packer.py

echo #define USING_LOADER > obj\main.asm
type ..\lib\lhook\sahead.asm >> obj\main.asm
type ..\lib\lhook\loader.asm >> obj\main.asm
type ..\lib\lhook\hook.asm >> obj\main.asm
type obj\encodings.z80 >> obj\main.asm
type obj\lfont.z80 >> obj\main.asm
type obj\sfont.z80 >> obj\main.asm
..\tools\spasm-ng -E -I ..\include obj\main.asm obj\main.bin
if "%1%"=="" (
 set VAR=FONTHOOK.8xp
) else (
 set VAR=%1%.8xp
)
python ..\tools\binconv.py obj\main.bin ..\build\%VAR%

