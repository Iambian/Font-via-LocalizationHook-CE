@echo off
rem Usage:   build_resource.bat <basename>
rem Example: build_resource.bat courier

rem BUILDS RESOURCE FILE FOR USE WITH FONT PREVIEWER (hook+data).
rem ASSUMES CURRENT DIRECTORY IS hook
rem IF FIRST TIME RUNNING OR WANT TO USE A NEW FONT, RUN packfont.bat

type src\sahead.asm > obj\main.asm
type src\hook.asm >> obj\main.asm
type obj\encodings.asm >> obj\main.asm
type obj\lfont.asm >> obj\main.asm
type obj\sfont.asm >> obj\main.asm
..\tools\spasm-ng -E obj\main.asm obj\main.bin
if "%1%"=="" (
 echo ============================================
 echo ERROR You must name your font resource file!
 echo ============================================
 exit /b 1
) else (
 set VAR=%1%.8xv
)
py ..\tools\binconv.py obj\main.bin bin\%VAR%

