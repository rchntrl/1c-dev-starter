@chcp 65001 >nul
@echo off
rem ============================================================
rem  Build .epf or .erf from the XML dump in external\
rem
rem  Usage:
rem      build-ep.bat <external-processing-or-report-name> [platform-version]
rem
rem  Examples:
rem      build-ep.bat MyProcessor
rem      build-ep.bat MyProcessor 8.3.24.1691
rem ============================================================
setlocal

for %%I in ("%~dp0..") do set "ROOT=%%~fI"

set "PROCESSING=%~1"
if "%PROCESSING%"=="" (
    echo [ERROR] External processing or report name is required.
    echo         Usage: build-ep.bat ^<external-processing-or-report-name^> [platform-version]
    exit /b 1
)

set "PLATFORM=%~2"
if "%PLATFORM%"=="" set "PLATFORM=8.3.24.1691"

set "V=C:\Program Files (x86)\1cv8\%PLATFORM%\bin\1cv8.exe"
set "IB=%ROOT%\.build\ib"
set "SRC=%ROOT%\external\%PROCESSING%.xml"
set "LOGS=%ROOT%\.build\logs"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "BUILD_DATE=%%I"
if "%BUILD_DATE%"=="" (
    echo [ERROR] Could not determine the current date.
    exit /b 1
)

if not exist "%V%" (
    echo [ERROR] Platform not found: "%V%"
    echo         Installed versions:
    dir /b "C:\Program Files (x86)\1cv8" 2>nul | findstr /r "^8\."
    exit /b 1
)
if not exist "%SRC%" (
    echo [ERROR] Source XML not found: %SRC%
    exit /b 1
)

rem ---- the root element of the dump tells a report from a processing
set "EXT=epf"
for /f %%I in ('powershell -NoProfile -Command "if (Select-String -LiteralPath $env:SRC -Pattern '<ExternalReport[\s>]' -Quiet) { 'erf' }"') do set "EXT=%%I"
set "OUT=%ROOT%\%PROCESSING%_%BUILD_DATE%.%EXT%"

if not exist "%LOGS%" mkdir "%LOGS%"

rem ---- 1. create the infobase if it is missing -----------------
if not exist "%IB%\1Cv8.1CD" (
    echo [1/2] Creating empty infobase: %IB%
    if not exist "%IB%" mkdir "%IB%"
    "%V%" CREATEINFOBASE File="%IB%" /DisableStartupDialogs /DisableStartupMessages /Out "%LOGS%\create.log"
    if errorlevel 1 (
        echo [ERROR] CREATEINFOBASE failed, see %LOGS%\create.log
        type "%LOGS%\create.log" 2>nul
        exit /b 1
    )
) else (
    echo [1/2] Reusing existing infobase: %IB%
)

rem ---- 2. build .epf/.erf from XML ---------------------------
echo [2/2] Building %OUT% from %SRC%
"%V%" DESIGNER /F "%IB%" /DisableStartupDialogs /DisableStartupMessages /LoadExternalDataProcessorOrReportFromFiles "%SRC%" "%OUT%" /Out "%LOGS%\build-external.log"
if errorlevel 1 (
    echo [ERROR] LoadExternalDataProcessorOrReportFromFiles failed, see %LOGS%\build-external.log
    type "%LOGS%\build-external.log" 2>nul
    exit /b 1
)
if not exist "%OUT%" (
    echo [ERROR] External processing or report file was not created: %OUT%
    type "%LOGS%\build-external.log" 2>nul
    exit /b 1
)

echo.
echo [OK] %OUT%
for %%F in ("%OUT%") do echo      %%~zF bytes, %%~tF
endlocal