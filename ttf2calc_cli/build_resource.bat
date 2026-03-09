@echo off
echo [DEPRECATED] build_resource.bat is deprecated.
echo [DEPRECATED] Use: python builder.py --resource ^<NAME^>

if "%1"=="" (
	echo ERROR: NAME is required.
	exit /b 1
)

python builder.py --resource "%1"
exit /b %ERRORLEVEL%

