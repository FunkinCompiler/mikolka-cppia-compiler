# Usage: ./build_cppia.ps1 [--sdk <sdk-dir>] <script-dir> <output.cppia> [Class ...]

# SDK here contains `export_classes.info`, `cppia.hxml` as well as libraries used by CPPIA to compile your mod
# https://github.com/FunkinCompiler/fcpkg-cdn/releases
# Make sure to download the `full` version, not the `shallow` one 

# A full example of it might be:
# ./build_cppia.ps1 --sdk ./cppia-sdk ./my-mod/scripts/cppia-src/ MyMod.cppia

# You are also able (as seen by 'Class ...') to write specific classes you want to compile.
# IE: [MyModule YourModule OurModule]

[CmdletBinding()]
# Parse the original Bash-style leading options.
$argv = @($args)
$Sdk = ''
$KeepResources = $false
$argIndex = 0

while ($argIndex -lt $argv.Count) {
    # arg "--keep-resources" will keed the debug files in case you need to look at them
    if ($argv[$argIndex] -eq '--keep-resources') {
        $KeepResources = $true
        $argIndex++
    }
    elseif ($argv[$argIndex] -eq '--sdk') {
        if (($argIndex + 1) -ge $argv.Count) {
            throw 'Missing value for --sdk'
        }
        $Sdk = $argv[$argIndex + 1]
        $argIndex += 2
    }
    else {
        break
    }
}

if (($argv.Count - $argIndex) -lt 2) {
    Write-Error "Usage: $($MyInvocation.MyCommand.Name) [--sdk <sdk-dir>] <script-dir> <output.cppia> [Class ...]"
    exit 1
}

$ScriptDir = $argv[$argIndex]
$Output = $argv[$argIndex + 1]
$Classes = @($argv | Select-Object -Skip ($argIndex + 2))

if ([string]::IsNullOrWhiteSpace($Sdk)) {
    throw 'No SDK specified! Point --sdk at a valid FCPKG directory.'
}


Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-HaxePath {
    param([Parameter(Mandatory = $true)][string] $Path)

    # Forward slashes work in HXML on Windows and avoid backslash escaping issues.
    return [System.IO.Path]::GetFullPath($Path).Replace('\', '/')
}

function Get-HaxeStdPath {
    $candidates = @()

    if ($env:HAXE_STD_PATH) {
        $candidates += $env:HAXE_STD_PATH
    }

    $candidates += @(
        'C:\HaxeToolkit\haxe\std',
        'C:\Program Files\HaxeToolkit\haxe\std',
        'C:\Haxe\haxe\std',
        (Join-Path $HOME 'haxe\std'),
        (Join-Path $HOME 'HaxeToolkit\haxe\std')
    )

    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath (Join-Path $path 'Std.hx') -PathType Leaf)) {
            return ConvertTo-HaxePath $path
        }
    }

    throw 'Haxe std folder not found. Set HAXE_STD_PATH to the folder containing Std.hx.'
}

$scriptPath = (Resolve-Path -LiteralPath $ScriptDir).Path
if (-not (Test-Path -LiteralPath $scriptPath -PathType Container)) {
    throw "No such script directory: $ScriptDir"
}
if (-not (Test-Path -LiteralPath $Sdk -PathType Container)) {
    throw "No such SDK directory: $Sdk"
}

$sdkPath = (Resolve-Path -LiteralPath $Sdk).Path
$outputPath = [System.IO.Path]::GetFullPath($Output)

$hxmlPath = Join-Path $sdkPath 'cppia.hxml'
$hostClassesPath = Join-Path $sdkPath 'export_classes.info'

if (-not (Test-Path -LiteralPath $hxmlPath -PathType Leaf)) {
    throw "SDK at $sdkPath has no cppia.hxml. Is this an FCPKG package?"
}

$haxeCommand = Get-Command 'haxe' -ErrorAction SilentlyContinue
if (-not $haxeCommand) {
    throw 'Could not find haxe on PATH.'
}

# If no classes were specified, compile every .hx file under the script directory.
if (-not $Classes -or $Classes.Count -eq 0) {
    $root = $scriptPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar

    $Classes = @(
        Get-ChildItem -LiteralPath $scriptPath -Recurse -File -Filter '*.hx' |
            Sort-Object FullName |
            ForEach-Object {
                $relativePath = $_.FullName.Substring($root.Length)
                [System.IO.Path]::ChangeExtension($relativePath, $null).Replace('\', '.').Replace('/', '.') -replace '\.$', ''
            }
    )
}

if (-not $Classes -or $Classes.Count -eq 0) {
    throw "No .hx files found under $scriptPath"
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("build_cppia_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir | Out-Null
$generatedHxml = Join-Path $tempDir 'cppia.hxml'
$generatedHostClasses = Join-Path $tempDir 'export_classes.info'

$removeTemporarySdkInfo = $false
$previousHaxelibPath = $env:HAXELIB_PATH

try {
    if (-not (Test-Path -LiteralPath $hostClassesPath -PathType Leaf)) {
        Write-Host "SDK at $sdkPath is not compiled! I'll temporary compile it for you."
        Write-Host "Please re-compile it using Funkin Compiler!"
        Push-Location $sdkPath
        try {
            $env:HAXELIB_PATH = $sdkPath
            & $haxeCommand.Source 'funkin.hxml' '-D' 'scriptable'
            if ($LASTEXITCODE -ne 0) {
                throw "SDK compilation failed with exit code $LASTEXITCODE."
            }
        }
        finally {
            Pop-Location
        }

        if (-not (Test-Path -LiteralPath $hostClassesPath -PathType Leaf)) {
            throw "SDK compilation completed but did not create $hostClassesPath"
        }

        $removeTemporarySdkInfo = $true
    }

    $classNames = $Classes -join "`n"
    $classNamesArray = ($Classes | ForEach-Object {
        "'" + $_.Replace("'", "\'") + "'"
    }) -join ','

    $replacements = [ordered]@{
        '$CPPIA_SOURCE'     = ConvertTo-HaxePath $scriptPath
        '$CLASS_NAMES_ARRAY' = $classNamesArray
        '$CLASS_NAMES'      = $classNames
        '$CPPIA_DLL'        = ConvertTo-HaxePath $generatedHostClasses
        '$DEBUG_FLAG'       = '--debug'
        '$CPPIA_OUT'        = ConvertTo-HaxePath $outputPath
    }

    $hxmlText = [System.IO.File]::ReadAllText($hxmlPath)
    foreach ($token in $replacements.Keys) {
        $hxmlText = $hxmlText.Replace($token, [string]$replacements[$token])
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($generatedHxml, $hxmlText, $utf8NoBom)

    $hostClassesText = [System.IO.File]::ReadAllText($hostClassesPath)
    $hostClassesText = $hostClassesText.Replace('$HAXE_STD', (Get-HaxeStdPath))
    $hostClassesText = $hostClassesText.Replace('$CPPIA_SDK', (ConvertTo-HaxePath $sdkPath))
    [System.IO.File]::WriteAllText($generatedHostClasses, $hostClassesText, $utf8NoBom)

    Write-Host "Building $outputPath from $scriptPath"
    Write-Host "  $($Classes.Count) class(es): $($Classes -join ' ')"

    Push-Location $sdkPath
    try {
        $env:HAXELIB_PATH = $sdkPath
        & $haxeCommand.Source $generatedHxml
        if ($LASTEXITCODE -ne 0) {
            throw "Haxe compilation failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }

    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "Haxe reported success but produced no $outputPath"
    }

    $size = (Get-Item -LiteralPath $outputPath).Length
    Write-Host "Wrote $outputPath ($size bytes)"
}
finally {
    $env:HAXELIB_PATH = $previousHaxelibPath

    if ($removeTemporarySdkInfo -and (Test-Path -LiteralPath $hostClassesPath -PathType Leaf)) {
        Remove-Item -LiteralPath $hostClassesPath -Force
        Write-Host 'Removed temporary export_classes.info from the SDK.'
    }

    if ($KeepResources) {
        Write-Host "Temporary build files kept at: $tempDir"
    }
    else {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
