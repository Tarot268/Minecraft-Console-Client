[CmdletBinding()]
param(
    [string]$DestinationPath = '',
    [string]$PackagePath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$expectedHash = '83c8a966c599b86060fb3130bb5aa68ce8c2edad2dd77aeded061f607ca2b994'
$expectedSize = 227888945L
$packageName = 'mcc2-console-0.2.0-windows-server-2019-x64-complete-lock-service.zip'
$stageRoot = $null
$createdStage = $false

try {
    if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
        if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
            $deploymentUserRoot = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
            if ([string]::IsNullOrWhiteSpace($deploymentUserRoot)) {
                throw 'Cannot find the user profile. Specify -DestinationPath C:\MCC2.'
            }
            $DestinationPath = Join-Path $deploymentUserRoot 'MCC2'
        }
        else {
            $DestinationPath = Join-Path $PSScriptRoot 'mcc2-console-complete'
        }
    }
    $destination = [System.IO.Path]::GetFullPath($DestinationPath)
    if (Test-Path -LiteralPath $destination) {
        throw ('Destination already exists; no files were changed. Use a new short directory with -DestinationPath, for example C:\MCC2-New. Destination: ' + $destination)
    }
    $destinationParent = [System.IO.Path]::GetDirectoryName($destination)
    if ([string]::IsNullOrWhiteSpace($destinationParent)) {
        throw 'Destination must be a new directory, not a drive root.'
    }
    $stageRoot = Join-Path $destinationParent ('.mcc2-extract-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $contentsPath = Join-Path $stageRoot 'contents'
    # The longest relative file path in this pinned package has 117 characters.
    # Check before creating output; leave room under the legacy 260-char limit.
    if (($contentsPath.Length + 1 + 118) -gt 240) {
        throw 'Destination path is too long for Windows PowerShell 5.1. Specify a short path such as -DestinationPath C:\MCC2.'
    }

    $explicitPackage = ![string]::IsNullOrWhiteSpace($PackagePath)
    if (!$explicitPackage) {
        $PackagePath = Join-Path $PSScriptRoot $packageName
    }
    $packagePathResolved = [System.IO.Path]::GetFullPath($PackagePath)
    $reusePackage = Test-Path -LiteralPath $packagePathResolved -PathType Leaf
    if ($explicitPackage -and !$reusePackage) {
        throw ('Package not found: ' + $packagePathResolved)
    }

    if ($reusePackage) {
        Write-Host ('Reusing the existing ZIP: ' + $packagePathResolved)
        if ((Get-Item -LiteralPath $packagePathResolved -Force).Length -ne $expectedSize) {
            throw 'Existing ZIP has the wrong size. The original file has been left untouched.'
        }
        if ((Get-FileHash -LiteralPath $packagePathResolved -Algorithm SHA256).Hash -ine $expectedHash) {
            throw 'Existing ZIP checksum mismatch. The original file has been left untouched.'
        }
    }
    else {
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
            $actualSize = (Get-Item -LiteralPath $path -Force).Length
            if ($actualSize -ne [long]$part.size) {
                throw ('Package part has the wrong size: ' + $expectedName)
            }
            Write-Host ('Verifying ' + $expectedName + ' ...')
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $part.sha256) {
                throw ('Package part checksum mismatch: ' + $expectedName)
            }
            $partPaths += $path
            $totalSize += $actualSize
        }
        if ($totalSize -ne $expectedSize) {
            throw 'The combined package size is incorrect.'
        }

        $null = [System.IO.Directory]::CreateDirectory($stageRoot)
        $createdStage = $true
        $packagePathResolved = Join-Path $stageRoot 'complete.zip'
        Write-Host 'Reconstructing the complete package in a short temporary directory ...'
        $output = [System.IO.File]::Open($packagePathResolved, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
        try {
            foreach ($path in $partPaths) {
                $inputStream = [System.IO.File]::OpenRead($path)
                try { $inputStream.CopyTo($output) }
                finally { $inputStream.Dispose() }
            }
        }
        finally { $output.Dispose() }
        if ((Get-FileHash -LiteralPath $packagePathResolved -Algorithm SHA256).Hash -ine $expectedHash) {
            throw 'The reconstructed ZIP checksum does not match the original package.'
        }
    }

    # Avoid the Windows PowerShell 5.1 Archive module. The .NET extractor also
    # handles ZIPs without explicit directory entries, as produced by our builder.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($packagePathResolved)
    $entries = @()
    try {
        $pathComparison = [System.StringComparison]::Ordinal
        if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
            $pathComparison = [System.StringComparison]::OrdinalIgnoreCase
        }
        $contentsPrefix = $contentsPath + [System.IO.Path]::DirectorySeparatorChar
        foreach ($entry in $archive.Entries) {
            $relativePath = $entry.FullName.Replace([char]'/', [System.IO.Path]::DirectorySeparatorChar)
            $entryPath = [System.IO.Path]::GetFullPath((Join-Path $contentsPath $relativePath))
            if (!$entryPath.StartsWith($contentsPrefix, $pathComparison)) {
                throw ('ZIP entry is outside the extraction directory: ' + $entry.FullName)
            }
            if ($entryPath.Length -gt 240) {
                throw ('ZIP output path is too long. Choose -DestinationPath C:\MCC2. Entry: ' + $entry.FullName)
            }
            if (![string]::IsNullOrEmpty($entry.Name)) {
                $entries += [PSCustomObject]@{ RelativePath = $relativePath; Size = $entry.Length }
            }
        }
    }
    finally { $archive.Dispose() }

    if (!$createdStage) {
        $null = [System.IO.Directory]::CreateDirectory($stageRoot)
        $createdStage = $true
    }
    Write-Host ('Original ZIP SHA256 verified. Extracting to: ' + $destination)
    [System.IO.Compression.ZipFile]::ExtractToDirectory($packagePathResolved, $contentsPath)
    foreach ($entry in $entries) {
        $file = Join-Path $contentsPath $entry.RelativePath
        if (!(Test-Path -LiteralPath $file -PathType Leaf)) {
            throw ('Extraction is incomplete. Missing file: ' + $entry.RelativePath)
        }
        if ((Get-Item -LiteralPath $file -Force).Length -ne $entry.Size) {
            throw ('Extraction is incomplete. Wrong file size: ' + $entry.RelativePath)
        }
    }
    [System.IO.Directory]::Move($contentsPath, $destination)
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
    $createdStage = $false
    Write-Host ''
    Write-Host ('Ready: ' + $destination)
    Write-Host ('Verified extracted files: ' + $entries.Count)
    Write-Host 'Read AGENT-DEPLOYMENT-WINDOWS-SERVER-2019.zh-CN.md before starting the console.'
    Write-Host 'Then run start-console.cmd inside the destination shown above.'
}
catch {
    $failure = $_
    if ($createdStage -and (Test-Path -LiteralPath $stageRoot)) {
        try { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
        catch { [Console]::Error.WriteLine('Could not remove the temporary extraction directory: ' + $stageRoot) }
    }
    [Console]::Error.WriteLine($failure.Exception.ToString())
    exit 1
}
