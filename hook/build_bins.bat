@echo off
rem Not for general use.
rem This builds the .h files needed by the font editor project

rem Build resource (appvar-only) stub
type src\sahead.asm > obj\resostub.asm
type src\hook.asm >> obj\resostub.asm
..\tools\\spasm-ng -E obj\resostub.asm obj\resostub.bin
py ..\tools\bin2c.py obj\resostub.bin bin\resostub.h


rem Build standalone (protprog) stub
echo #define USING_LOADER > obj\stalstub.asm
type src\sahead.asm >> obj\stalstub.asm
type src\loader.asm >> obj\stalstub.asm
type src\hook.asm >> obj\stalstub.asm
..\tools\\spasm-ng -E obj\stalstub.asm obj\stalstub.bin
python ..\tools\bin2c.py obj\stalstub.bin bin\stalstub.h












