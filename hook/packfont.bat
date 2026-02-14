@echo off
rem RUNS THE PACKER AND OVERWRITES FONT DATA CURRENTLY IN OBJ FOLDER
rem THIS IS SEPARATE TO ALLOW MANUAL TWEAKING AFTER INITIAL GENERATE
cd ..\builder
python packer.py
if not exist "..\hook\obj" mkdir ..\hook\obj
move /Y encodings.z80 ..\hook\obj\encodings.asm
move /y lfont.z80 ..\hook\obj\lfont.asm
move /y sfont.z80 ..\hook\obj\sfont.asm
cd ..\hook