function Read-BuildParameters {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @{}
    }

    $parameters = @{}
    $supportedKeys = @('username', 'password', 'platform', 'configuration', 'extension')
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*#') {
            continue
        }

        if ($line -notmatch '^\s*([A-Za-z][A-Za-z0-9_-]*)\s*:\s*(.*?)\s*$') {
            throw "Invalid build parameters YAML format in '$Path'. Expected key: value entries."
        }

        $key = $Matches[1]
        $value = $Matches[2]
        if ($key -notin $supportedKeys) {
            throw "Unsupported '$key' entry in build parameters file '$Path'. Supported keys: $($supportedKeys -join ', ')."
        }
        if ($parameters.ContainsKey($key)) {
            throw "Duplicate '$key' entry in build parameters file '$Path'."
        }

        if ($value.StartsWith('"')) {
            if (-not $value.EndsWith('"')) {
                throw "Invalid double-quoted '$key' value in build parameters file '$Path'."
            }
            try {
                $value = ConvertFrom-Json -InputObject $value -ErrorAction Stop
            }
            catch {
                throw "Invalid double-quoted '$key' value in build parameters file '$Path'."
            }
        }
        elseif ($value.StartsWith("'")) {
            if (-not $value.EndsWith("'")) {
                throw "Invalid single-quoted '$key' value in build parameters file '$Path'."
            }
            $value = $value.Substring(1, $value.Length - 2) -replace "''", "'"
        }
        else {
            $value = ($value -replace '\s+#.*$', '').Trim()
        }

        $parameters[$key] = [string]$value
    }

    return $parameters
}

function Get-DesignerAuthenticationArguments {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters
    )

    $hasUsername = -not [string]::IsNullOrWhiteSpace($Parameters['username'])
    $hasPassword = -not [string]::IsNullOrWhiteSpace($Parameters['password'])
    if (-not $hasUsername -and -not $hasPassword) {
        return @()
    }
    if (-not $hasUsername -or -not $hasPassword) {
        throw 'Both username and password must be set in the build parameters file, or both left empty.'
    }

    return @('/N', [string]$Parameters['username'], '/P', [string]$Parameters['password'])
}
