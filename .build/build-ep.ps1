param(
    [Parameter(Position = 0)]
    [string]$Processing = '',

    [Parameter(Position = 1)]
    [string]$Platform
)

$ErrorActionPreference = 'Stop'
$parametersFile = Join-Path $PSScriptRoot 'parameters.yml'
. (Join-Path $PSScriptRoot 'build-auth.ps1')
$buildParameters = Read-BuildParameters -Path $parametersFile
if ([string]::IsNullOrWhiteSpace($Platform)) {
    $Platform = if ($buildParameters['platform']) { $buildParameters['platform'] } else { '8.3.24.1691' }
}
if ([string]::IsNullOrWhiteSpace($Processing)) {
    $Processing = if ($buildParameters['external']) { $buildParameters['external'] }
}
$designerAuthenticationArguments = Get-DesignerAuthenticationArguments -Parameters $buildParameters
$root = Split-Path -Parent $PSScriptRoot
$designer = "C:\Program Files (x86)\1cv8\$Platform\bin\1cv8.exe"
$infobase = Join-Path $PSScriptRoot 'ib'
$infobaseArguments = Get-DesignerInfobaseArguments -Parameters $buildParameters -DefaultPath $infobase
$source = Join-Path (Join-Path $root 'external') "$Processing.xml"
$logs = Join-Path $PSScriptRoot 'logs'
$buildDate = Get-Date -Format 'yyyy-MM-dd'
$output = Join-Path $root "${Processing}_${buildDate}.epf"
$buildLog = Join-Path $logs 'build-external.log'
$createLog = Join-Path $logs 'create.log'
if ([string]::IsNullOrEmpty($Processing)) {
    Write-Host '[ERROR] External processing name is required.'
    Write-Host '        Usage: build-ep.ps1 [external-processing-name] [platform-version]'
    Write-Host "        Pass the name as an argument or set 'external' in parameters.yml."
    exit 1
}

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
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    Write-Host "[ERROR] Source XML not found: $source"
    exit 1
}

New-Item -ItemType Directory -Path $logs -Force | Out-Null

if ($buildParameters['infobase']) {
    Write-Host "[1/2] Using infobase: $($buildParameters['infobase'])"
}
elseif (-not (Test-Path -LiteralPath (Join-Path $infobase '1Cv8.1CD') -PathType Leaf)) {
    Write-Host "[1/2] Creating empty infobase: $infobase"
    New-Item -ItemType Directory -Path $infobase -Force | Out-Null
    & $designer CREATEINFOBASE "File=$infobase" /DisableStartupDialogs /DisableStartupMessages /Out $createLog
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] CREATEINFOBASE failed, see $createLog"
        if (Test-Path -LiteralPath $createLog) {
            Get-Content -LiteralPath $createLog
        }
        exit 1
    }
}
else {
    Write-Host "[1/2] Reusing existing infobase: $infobase"
}

Write-Host "[2/2] Building $output from $source"
$previousErrorActionPreference = $ErrorActionPreference
$previousArtifact = Get-Item -LiteralPath $output -ErrorAction SilentlyContinue
Set-Content -LiteralPath $buildLog -Value '' -NoNewline
try {
    $ErrorActionPreference = 'Continue'
    & $designer DESIGNER @infobaseArguments @designerAuthenticationArguments /DisableStartupDialogs /DisableStartupMessages /LoadExternalDataProcessorOrReportFromFiles $source $output /Out $buildLog
    $buildExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

$completedSuccessfully = $false
$reportedOutput = $false
$artifact = $null
for ($attempt = 0; $attempt -lt 120; $attempt++) {
    $buildLogContent = if (Test-Path -LiteralPath $buildLog -PathType Leaf) {
        Get-Content -LiteralPath $buildLog -Raw
    }
    else {
        ''
    }
    $completedSuccessfully = $buildLogContent -match '(?im)^\s*(\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430 \u0437\u0430\u0432\u0435\u0440\u0448\u0435\u043d\u0430|Loading completed)\.'
    $reportedOutput = $buildLogContent -match [regex]::Escape($output)
    $artifact = Get-Item -LiteralPath $output -ErrorAction SilentlyContinue
    $artifactUpdated = $null -ne $artifact -and (
        $null -eq $previousArtifact -or
        $artifact.LastWriteTimeUtc -gt $previousArtifact.LastWriteTimeUtc -or
        $artifact.Length -ne $previousArtifact.Length
    )
    if ($completedSuccessfully -and $reportedOutput -and $artifactUpdated) {
        break
    }
    Start-Sleep -Milliseconds 500
}
$completionConfirmed = $completedSuccessfully -and $reportedOutput -and $artifactUpdated
$buildFailed = $null -ne $buildExitCode -and $buildExitCode -ne 0

if (-not $completionConfirmed) {
    $exitCodeText = if ($null -eq $buildExitCode) { 'unavailable' } else { $buildExitCode }
    Write-Host "[ERROR] Build completion was not confirmed (Designer rc=$exitCodeText), see $buildLog"
    Write-Host "        Completion: $completedSuccessfully; target: $reportedOutput; EPF updated: $artifactUpdated"
    if (Test-Path -LiteralPath $buildLog) {
        Get-Content -LiteralPath $buildLog
    }
    if ($buildFailed) {
        exit $buildExitCode
    }
    exit 1
}
if ($buildFailed) {
    Write-Host "[WARNING] Designer returned code $buildExitCode, but the current build log confirms completion and the EPF exists."
}

Write-Host "`n[OK] $output"
Write-Host "     $($artifact.Length) bytes, $($artifact.LastWriteTime)"
