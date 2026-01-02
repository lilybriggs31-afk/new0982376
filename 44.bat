@echo off
setlocal enabledelayedexpansion

:: ====================================================
:: IF ALREADY HIDDEN — CONTINUE
:: ====================================================
if "%1"=="-hidden" goto hidden

:: ====================================================
:: START HIDDEN (NO VBS, NO RECURSION)
:: ====================================================
powershell -WindowStyle Hidden -Command "Start-Process '%~f0' -ArgumentList '-hidden' -WindowStyle Hidden"
exit /b


:hidden
:: ====================================================
:: NOW RUNNING HIDDEN
:: ====================================================

:: Force log creation
set LOG_FILE=%~dp0superops_deploy.log
echo ==== SuperOps Deployment Log (Start) ==== > "%LOG_FILE%"
echo Timestamp: %date% %time% >> "%LOG_FILE%"
echo ------------------------------------------ >> "%LOG_FILE%"

echo Running hidden mode... >> "%LOG_FILE%"

:: ====================================================
:: ADMIN CHECK + AUTO ELEVATION
:: ====================================================
>nul 2>&1 net session
if %errorlevel% neq 0 (
    echo Elevating to admin... >> "%LOG_FILE%"
    powershell -WindowStyle Hidden -Command "Start-Process '%~f0' -ArgumentList '-hidden' -Verb RunAs -WindowStyle Hidden"
    exit /b
)

echo Admin rights confirmed. >> "%LOG_FILE%"


:: ====================================================
:: CONFIG
:: ====================================================
set DOWNLOAD_URL=https://superops-wininstaller-prod.s3.us-east-2.amazonaws.com/agent/4498192794087583744/Y6B09M1ZHS74_19SI0B7FBSUF4_windows_x64.msi

:: Extract file name
for %%A in ("%DOWNLOAD_URL%") do (
    for /f "tokens=*" %%B in ("%%~nxA") do set MSI_NAME=%%B
)

echo MSI Name: %MSI_NAME% >> "%LOG_FILE%"
echo URL: %DOWNLOAD_URL% >> "%LOG_FILE%"


:: ====================================================
:: DOWNLOAD MSI
:: ====================================================
echo Downloading MSI... >> "%LOG_FILE%"

powershell -WindowStyle Hidden -Command ^
 "(New-Object Net.WebClient).DownloadFile('%DOWNLOAD_URL%', '%MSI_NAME%')" ^
 >> "%LOG_FILE%" 2>&1

if not exist "%MSI_NAME%" (
    echo ERROR: Download failed. >> "%LOG_FILE%"
    echo ==== FAIL ==== >> "%LOG_FILE%"
    exit /b 10
)

echo Download OK. >> "%LOG_FILE%"


:: ====================================================
:: UNINSTALL OLD VERSION
:: ====================================================
echo Removing old SuperOps version... >> "%LOG_FILE%"

wmic product where "Name like 'SuperOps%%'" call uninstall /nointeractive ^
 >> "%LOG_FILE%" 2>&1

timeout /t 3 >nul


:: ====================================================
:: INSTALL MSI SILENTLY
:: ====================================================
echo Running silent installation... >> "%LOG_FILE%"

msiexec /i "%MSI_NAME%" /qn LicenseAccepted=YES /norestart /l*v "%LOG_FILE%"

set EXITCODE=%errorlevel%
echo Installer ExitCode: %EXITCODE% >> "%LOG_FILE%"

if %EXITCODE% neq 0 (
    echo INSTALL FAILED >> "%LOG_FILE%"
    exit /b %EXITCODE%
)

echo Installation OK >> "%LOG_FILE%"
echo ==== DONE ==== >> "%LOG_FILE%"

exit /b
