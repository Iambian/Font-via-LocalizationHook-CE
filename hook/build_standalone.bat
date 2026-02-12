@echo off
rem Usage:   build_standalone.bat <basename>
rem Example: build_standalone.bat courier

rem BUILDS STANDALONE FONT INSTALLER (loader+hook+data).
rem ASSUMES CURRENT DIRECTORY IS hook
rem IF FIRST TIME RUNNING OR WANT TO USE A NEW FONT, RUN packfont.bat

echo #define USING_LOADER > obj\main.asm
type src\sahead.asm >> obj\main.asm
type src\loader.asm >> obj\main.asm
type src\hook.asm >> obj\main.asm
type obj\encodings.asm >> obj\main.asm
type obj\lfont.asm >> obj\main.asm
type obj\sfont.asm >> obj\main.asm
..\tools\spasm-ng -E obj\main.asm obj\main.bin
if "%1%"=="" (
 set VAR=FONTHOOK.8xp
) else (
 set VAR=%1%.8xp
)
python ..\tools\binconv.py obj\main.bin bin\%VAR%

