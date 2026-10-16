$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$expectedHash = '83c8a966c599b86060fb3130bb5aa68ce8c2edad2dd77aeded061f607ca2b994'
$expectedSize = 227888945L
$packageName = 'mcc2-console-0.2.0-windows-server-2019-x64-complete-lock-service.zip'
$packagePath = Join-Path $PSScriptRoot $packageName
$temporaryPath = $packagePath + '.assembling'
$destination = Join-Path $PSScriptRoot 'mcc2-console-complete'
$createdTemporary = $false

try {
    if ((Test-Path -LiteralPath $destination) -or
        (Test-Path -LiteralPath $packagePath) -or
        (Test-Path -LiteralPath $temporaryPath)) {
        throw 'Output already exists. Use a fresh folder to avoid overwriting files.'
    }

    $manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'package-parts.json') -Raw | ConvertFrom-Json
    if (@($manifest.parts).Count -ne 5) {
        throw 'The download must contain exactly five package parts.'
    }

    $partPaths = @()
    $totalSize = 0L
    for ($index = 0; $index -lt 5; $index++) {
        $part = $manifest.parts[$index]
        $expectedName = 'complete-package.part{0:d2}' -f ($index + 1)
        if ($part.name -cne $expectedName) {
            throw ('Unexpected part name: ' + $expectedName)
        }
        $path = Join-Path (Join-Path $PSScriptRoot 'parts') $expectedName
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
            throw ('Missing package part: ' + $expectedName)
        }
        $actualSize = (Get-Item -LiteralPath $path).Length
        if ($actualSize -ne [long]$part.size) {
            throw ('Package part has the wrong size: ' + $expectedName)
        }
        Write-Host ('Verifying ' + $expectedName + ' ...')
        $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($actualHash -ine $part.sha256) {
            throw ('Package part checksum mismatch: ' + $expectedName)
        }
        $partPaths += $path
        $totalSize += $actualSize
    }
    if ($totalSize -ne $expectedSize) {
        throw 'The combined package size is incorrect.'
    }

    Write-Host 'Reconstructing the complete package ...'
    $output = [System.IO.File]::Open($temporaryPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
    $createdTemporary = $true
    try {
        foreach ($path in $partPaths) {
            $inputStream = [System.IO.File]::OpenRead($path)
            try {
                $inputStream.CopyTo($output)
            }
            finally {
                $inputStream.Dispose()
            }
        }
    }
    finally {
        $output.Dispose()
    }

    if ((Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256).Hash -ine $expectedHash) {
        throw 'The reconstructed ZIP checksum does not match the original package.'
    }
    Move-Item -LiteralPath $temporaryPath -Destination $packagePath
    Write-Host 'Original ZIP SHA256 verified. Extracting ...'
    Expand-Archive -LiteralPath $packagePath -DestinationPath $destination
    Write-Host ''
    Write-Host ('Ready: ' + $destination)
    Write-Host 'Read AGENT-DEPLOYMENT-WINDOWS-SERVER-2019.zh-CN.md before starting the console.'
    Write-Host 'Then run start-console.cmd inside mcc2-console-complete.'
}
catch {
    if ($createdTemporary -and (Test-Path -LiteralPath $temporaryPath)) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
    Write-Error $_
    exit 1
}
