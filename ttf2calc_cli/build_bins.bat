@echo off
echo [DEPRECATED] build_bins.bat is deprecated.
echo [DEPRECATED] Use: python builder.py --bins ^<NAME^>

if "%1"=="" (
	echo ERROR: NAME is required.
	exit /b 1
)

python builder.py --bins "%1"
exit /b %ERRORLEVEL%












