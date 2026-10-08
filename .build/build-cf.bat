@chcp 65001 >nul
@echo off
rem ============================================================
rem  Build .cf from the XML dump in conf\
rem
rem  Usage:
rem      build-cf.bat [configuration-name] [platform-version]
rem
rem  Examples:
rem      build-cf.bat
rem      build-cf.bat
rem      build-cf.bat 1Cv8
rem      build-cf.bat 1Cv8 8.3.24.1691
rem ============================================================
setlocal

for %%I in ("%~dp0..") do set "ROOT=%%~fI"

set "CONFIGURATION=%~1"
if "%CONFIGURATION%"=="" set "CONFIGURATION=1Cv8"

set "PLATFORM=%~2"
if "%PLATFORM%"=="" set "PLATFORM=8.3.24.1691"

set "V=C:\Program Files (x86)\1cv8\%PLATFORM%\bin\1cv8.exe"
set "IB=%ROOT%\.build\ib"
set "SRC=%ROOT%\conf"
set "LOGS=%ROOT%\.build\logs"
set "DUMPINFO=%SRC%\ConfigDumpInfo.xml"
set "DUMPINFO_BAK=%ROOT%\.build\ConfigDumpInfo.xml.bak"
set "OUT=%ROOT%\%CONFIGURATION%.cf"

if not exist "%V%" (
    echo [ERROR] Platform not found: "%V%"
    echo         Installed versions:
    dir /b "C:\Program Files (x86)\1cv8" 2>nul | findstr /r "^8\."
    exit /b 1
)
if not exist "%SRC%\Configuration.xml" (
    echo [ERROR] Source dump not found: %SRC%\Configuration.xml
    exit /b 1
)

if not exist "%LOGS%" mkdir "%LOGS%"

rem ---- 1. create the infobase if it is missing -----------------
if not exist "%IB%\1Cv8.1CD" (
    echo [1/3] Creating empty infobase: %IB%
    if not exist "%IB%" mkdir "%IB%"
    "%V%" CREATEINFOBASE File="%IB%" /DisableStartupDialogs /DisableStartupMessages /Out "%LOGS%\create.log"
    if errorlevel 1 (
        echo [ERROR] CREATEINFOBASE failed, see %LOGS%\create.log
        type "%LOGS%\create.log" 2>nul
        exit /b 1
    )
) else (
    echo [1/3] Reusing existing infobase: %IB%
)

rem ---- 2. load configuration from XML --------------------------
rem ConfigDumpInfo.xml is stale, move it aside to force a full load
if exist "%DUMPINFO%" move /y "%DUMPINFO%" "%DUMPINFO_BAK%" >nul

echo [2/3] Loading configuration from %SRC% ... (may take ~10 min)
"%V%" DESIGNER /F "%IB%" /DisableStartupDialogs /DisableStartupMessages /LoadConfigFromFiles "%SRC%" /Out "%LOGS%\load.log"
set RC=%ERRORLEVEL%

if exist "%DUMPINFO_BAK%" move /y "%DUMPINFO_BAK%" "%DUMPINFO%" >nul

if not "%RC%"=="0" (
    echo [ERROR] LoadConfigFromFiles failed ^(rc=%RC%^), see %LOGS%\load.log
    type "%LOGS%\load.log" 2>nul
    exit /b %RC%
)

rem ---- 3. dump .cf ---------------------------------------------
echo [3/3] Dumping %OUT%
"%V%" DESIGNER /F "%IB%" /DisableStartupDialogs /DisableStartupMessages /DumpCfg "%OUT%" /Out "%LOGS%\dump.log"
if errorlevel 1 (
    echo [ERROR] DumpCfg failed, see %LOGS%\dump.log
    type "%LOGS%\dump.log" 2>nul
    exit /b 1
)
if not exist "%OUT%" (
    echo [ERROR] Configuration package was not created: %OUT%
    type "%LOGS%\dump.log" 2>nul
    exit /b 1
)

echo.
echo [OK] %OUT%
for %%F in ("%OUT%") do echo      %%~zF bytes, %%~tF
endlocal
