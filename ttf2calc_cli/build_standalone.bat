@echo off
echo [DEPRECATED] build_standalone.bat is deprecated.
echo [DEPRECATED] Use: python builder.py ^<NAME^> [--hook fhook]

if "%1"=="" (
	echo ERROR: NAME is required.
	exit /b 1
)

set EXTRA=
if /I "%2"=="fhook" set EXTRA=--hook fhook

python builder.py %EXTRA% "%1"
exit /b %ERRORLEVEL%

