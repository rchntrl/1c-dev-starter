param(
    [string]$Configuration,
    [string]$Platform
)

$ErrorActionPreference = 'Stop'
$parametersFile = Join-Path $PSScriptRoot 'parameters.yml'
. (Join-Path $PSScriptRoot 'build-auth.ps1')
$buildParameters = Read-BuildParameters -Path $parametersFile
if ([string]::IsNullOrWhiteSpace($Configuration)) {
    $Configuration = if ($buildParameters['configuration']) { $buildParameters['configuration'] } else { '1Cv8' }
}
if ([string]::IsNullOrWhiteSpace($Platform)) {
    $Platform = if ($buildParameters['platform']) { $buildParameters['platform'] } else { '8.3.24.1691' }
}
$designerAuthenticationArguments = Get-DesignerAuthenticationArguments -Parameters $buildParameters
$root = Split-Path -Parent $PSScriptRoot
$designer = "C:\Program Files (x86)\1cv8\$Platform\bin\1cv8.exe"
$infobase = Join-Path $PSScriptRoot 'ib'
$infobaseArguments = Get-DesignerInfobaseArguments -Parameters $buildParameters -DefaultPath $infobase
$source = Join-Path $root 'conf'
$logs = Join-Path $PSScriptRoot 'logs'
$dumpInfo = Join-Path $source 'ConfigDumpInfo.xml'
$dumpInfoBackup = Join-Path $PSScriptRoot 'ConfigDumpInfo.xml.bak'
$buildDate = Get-Date -Format 'yyyy-MM-dd'
$output = Join-Path $root "${Configuration}_${buildDate}.cf"
$loadConsoleLog = Join-Path $logs 'load-console.log'
$dumpConsoleLog = Join-Path $logs 'dump-console.log'
if (-not (Test-Path -LiteralPath $designer -PathType Leaf)) {
    Write-Host "[ERROR] Platform not found: `"$designer`""
    $platformRoot = 'C:\Program Files (x86)\1cv8'
    if (Test-Path -LiteralPath $platformRoot -PathType Container) {
        Write-Host 'Installed versions:'
        Get-ChildItem -LiteralPath $platformRoot -Directory |
            Where-Object Name -Match '^8\.' |
            ForEach-Object { Write-Host $_.Name }
    }
    exit 1
}
if (-not (Test-Path -LiteralPath (Join-Path $source 'Configuration.xml') -PathType Leaf)) {
    Write-Host "[ERROR] Source dump not found: $(Join-Path $source 'Configuration.xml')"
    exit 1
}

New-Item -ItemType Directory -Path $logs -Force | Out-Null

if ($buildParameters['infobase']) {
    Write-Host "[1/3] Using infobase: $($buildParameters['infobase'])"
}
elseif (-not (Test-Path -LiteralPath (Join-Path $infobase '1Cv8.1CD') -PathType Leaf)) {
    Write-Host "[1/3] Creating empty infobase: $infobase"
    New-Item -ItemType Directory -Path $infobase -Force | Out-Null
    & $designer CREATEINFOBASE "File=$infobase" /DisableStartupDialogs /DisableStartupMessages /Out (Join-Path $logs 'create.log') | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] CREATEINFOBASE failed, see $(Join-Path $logs 'create.log')"
        if (Test-Path -LiteralPath (Join-Path $logs 'create.log')) {
            Get-Content -LiteralPath (Join-Path $logs 'create.log')
        }
        exit 1
    }
}
else {
    Write-Host "[1/3] Reusing existing infobase: $infobase"
}

if (Test-Path -LiteralPath $dumpInfo -PathType Leaf) {
    Move-Item -LiteralPath $dumpInfo -Destination $dumpInfoBackup -Force
}

Write-Host "[2/3] Loading configuration from $source ... (may take ~10 min)"
$previousErrorActionPreference = $ErrorActionPreference
Set-Content -LiteralPath $loadConsoleLog -Value '' -NoNewline
try {
    $ErrorActionPreference = 'Continue'
    & $designer DESIGNER @infobaseArguments @designerAuthenticationArguments /DisableStartupDialogs /DisableStartupMessages /LoadConfigFromFiles $source /Out (Join-Path $logs 'load.log') 2>&1 |
        Tee-Object -FilePath $loadConsoleLog
    $loadExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
    if (Test-Path -LiteralPath $dumpInfoBackup -PathType Leaf) {
        Move-Item -LiteralPath $dumpInfoBackup -Destination $dumpInfo -Force
    }
}

if ($loadExitCode -ne 0) {
    Write-Host "[ERROR] LoadConfigFromFiles failed (rc=$loadExitCode), see $(Join-Path $logs 'load.log')"
    if ((Test-Path -LiteralPath (Join-Path $logs 'load.log')) -and
        (Get-Item -LiteralPath (Join-Path $logs 'load.log')).Length -gt 3) {
        Get-Content -LiteralPath (Join-Path $logs 'load.log')
    }
    Write-Host "Designer console output: $loadConsoleLog"
    if (Test-Path -LiteralPath $loadConsoleLog -PathType Leaf) {
        Get-Content -LiteralPath $loadConsoleLog
    }
    exit $loadExitCode
}

Write-Host "[3/3] Dumping $output"
if (Test-Path -LiteralPath $output -PathType Leaf) {
    Remove-Item -LiteralPath $output -Force
}
$previousErrorActionPreference = $ErrorActionPreference
Set-Content -LiteralPath $dumpConsoleLog -Value '' -NoNewline
try {
    $ErrorActionPreference = 'Continue'
    & $designer DESIGNER @infobaseArguments @designerAuthenticationArguments /DisableStartupDialogs /DisableStartupMessages /DumpCfg $output /Out (Join-Path $logs 'dump.log') 2>&1 |
        Tee-Object -FilePath $dumpConsoleLog
    $dumpExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

if ($dumpExitCode -ne 0) {
    Write-Host "[ERROR] DumpCfg failed, see $(Join-Path $logs 'dump.log')"
    if ((Test-Path -LiteralPath (Join-Path $logs 'dump.log')) -and
        (Get-Item -LiteralPath (Join-Path $logs 'dump.log')).Length -gt 3) {
        Get-Content -LiteralPath (Join-Path $logs 'dump.log')
    }
    Write-Host "Designer console output: $dumpConsoleLog"
    if (Test-Path -LiteralPath $dumpConsoleLog -PathType Leaf) {
        Get-Content -LiteralPath $dumpConsoleLog
    }
    exit $dumpExitCode
}
if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
    Write-Host "[ERROR] Configuration package was not created: $output"
    if (Test-Path -LiteralPath (Join-Path $logs 'dump.log')) {
        Get-Content -LiteralPath (Join-Path $logs 'dump.log')
    }
    exit 1
}

$artifact = Get-Item -LiteralPath $output
Write-Host "`n[OK] $output"
Write-Host "     $($artifact.Length) bytes, $($artifact.LastWriteTime)"
