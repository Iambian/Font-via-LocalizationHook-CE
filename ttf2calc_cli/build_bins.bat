@echo off
rem Not for general use.
rem This builds the .h files needed by the font editor project

rem Build resource (appvar-only) stub
if not exist "obj" mkdir obj
python packer.py

type ..\lib\lhook\sahead.asm > obj\resostub.asm
type ..\lib\lhook\hook.asm >> obj\resostub.asm
..\tools\\spasm-ng -E -I ..\include obj\resostub.asm obj\resostub.bin
python ..\tools\bin2c.py obj\resostub.bin ..\build\resostub.h


rem Build standalone (protprog) stub
echo #define USING_LOADER > obj\stalstub.asm
type ..\lib\lhook\sahead.asm >> obj\stalstub.asm
type ..\lib\lhook\loader.asm >> obj\stalstub.asm
type ..\lib\lhook\hook.asm >> obj\stalstub.asm
..\tools\\spasm-ng -E -I ..\include obj\stalstub.asm obj\stalstub.bin
python ..\tools\bin2c.py obj\stalstub.bin ..\build\stalstub.h












