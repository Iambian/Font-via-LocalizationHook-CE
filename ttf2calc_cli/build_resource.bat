@echo off
rem Usage:   build_resource.bat <basename>
rem Example: build_resource.bat courier

rem BUILDS RESOURCE FILE FOR USE WITH FONT PREVIEWER (hook+data).
rem ASSUMES CURRENT DIRECTORY IS hook
if not exist "obj" mkdir obj

python packer.py

type ..\lib\lhook\sahead.asm > obj\main.asm
type ..\lib\lhook\hook.asm >> obj\main.asm
type obj\encodings.z80 >> obj\main.asm
type obj\lfont.z80 >> obj\main.asm
type obj\sfont.z80 >> obj\main.asm
..\tools\spasm-ng -E -I ..\include obj\main.asm obj\main.bin
if "%1%"=="" (
 echo ============================================
 echo ERROR You must name your font resource file!
 echo ============================================
 exit /b 1
) else (
 set VAR=%1%.8xv
)
python ..\tools\binconv.py obj\main.bin ..\build\%VAR%

