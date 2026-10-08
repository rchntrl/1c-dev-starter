@chcp 65001 >nul
@echo off
rem ============================================================
rem  Build .cfe from the XML dump in extensions\
rem
rem  Usage:
rem      build-cf.bat [extension] [platform-version]
rem
rem  Examples:
rem      build-cf.bat
rem      build-cf.bat GS
rem      build-cf.bat GS 8.3.24.1691
rem ============================================================
setlocal

for %%I in ("%~dp0..") do set "ROOT=%%~fI"

set "EXTENSION=%~1"
if "%EXTENSION%"=="" set "EXTENSION=GS"

set "PLATFORM=%~2"
if "%PLATFORM%"=="" set "PLATFORM=8.3.24.1691"

set "V=C:\Program Files (x86)\1cv8\%PLATFORM%\bin\1cv8.exe"
set "IB=%ROOT%\.build\ib"
set "SRC=%ROOT%\extensions\%EXTENSION%"
set "LOGS=%ROOT%\.build\logs"
set "DUMPINFO=%SRC%\ConfigDumpInfo.xml"
set "DUMPINFO_BAK=%ROOT%\.build\ConfigDumpInfo.xml.bak"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "BUILD_DATE=%%I"
if "%BUILD_DATE%"=="" (
    echo [ERROR] Could not determine the current date.
    exit /b 1
)

set "OUT=%ROOT%\%EXTENSION%_%BUILD_DATE%.cfe"

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

rem ---- 2. load the configuration extension from XML ------------
rem ConfigDumpInfo.xml is stale, move it aside to force a full load
if exist "%DUMPINFO%" move /y "%DUMPINFO%" "%DUMPINFO_BAK%" >nul

echo [2/3] Loading configuration from %SRC% ... (may take ~10 min)
"%V%" DESIGNER /F "%IB%" /DisableStartupDialogs /DisableStartupMessages /LoadConfigFromFiles  "%SRC%"  -Extension "%EXTENSION%" /UpdateDBCfg /Out "%LOGS%\load-extension.log"
set RC=%ERRORLEVEL%

if exist "%DUMPINFO_BAK%" move /y "%DUMPINFO_BAK%" "%DUMPINFO%" >nul

if not "%RC%"=="0" (
    echo [ERROR] LoadConfigFromFiles failed ^(rc=%RC%^), see %LOGS%\load-extension.log
    type "%LOGS%\load-extension.log" 2>nul
    exit /b %RC%
)

rem ---- 3. dump .cfe --------------------------------------------
echo [3/3] Dumping %OUT%
"%V%" DESIGNER /F "%IB%" /DisableStartupDialogs /DisableStartupMessages /DumpCfg "%OUT%" -Extension "%EXTENSION%" /Out "%LOGS%\dump-extension.log"
if errorlevel 1 (
    echo [ERROR] DumpCfg failed, see %LOGS%\dump-extension.log
    type "%LOGS%\dump-extension.log" 2>nul
    exit /b 1
)
if not exist "%OUT%" (
    echo [ERROR] Extension package was not created: %OUT%
    type "%LOGS%\dump-extension.log" 2>nul
    exit /b 1
)

echo.
echo [OK] %OUT%
for %%F in ("%OUT%") do echo      %%~zF bytes, %%~tF
endlocal
