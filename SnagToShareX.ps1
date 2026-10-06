param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$OutputFolder = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'ShareX\Screenshots')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$signature = [byte[]](137, 80, 78, 71, 13, 10, 26, 10)

function Get-PngLength {
    param([byte[]]$Bytes, [int]$Offset)

    $position = $Offset + 8
    if ($position + 12 -gt $Bytes.Length) { return 0 }
    if ([Text.Encoding]::ASCII.GetString($Bytes, $position + 4, 4) -ne 'IHDR') { return 0 }

    while ($position + 12 -le $Bytes.Length) {
        $length = ([long]$Bytes[$position] -shl 24) -bor
                  ([long]$Bytes[$position + 1] -shl 16) -bor
                  ([long]$Bytes[$position + 2] -shl 8) -bor
                  [long]$Bytes[$position + 3]
        if ($length -gt $Bytes.Length - $position - 12) { return 0 }

        $chunkType = [Text.Encoding]::ASCII.GetString($Bytes, $position + 4, 4)
        $position += [int]$length + 12
        if ($chunkType -eq 'IEND') {
            if ($length -ne 0) { return 0 }
            return $position - $Offset
        }
    }

    return 0
}

function Get-LargestPng {
    param([byte[]]$Bytes)

    $best = $null
    for ($offset = 0; $offset -le $Bytes.Length - $signature.Length; $offset++) {
        if ($Bytes[$offset] -ne $signature[0]) { continue }
        $matches = $true
        for ($index = 1; $index -lt $signature.Length; $index++) {
            if ($Bytes[$offset + $index] -ne $signature[$index]) {
                $matches = $false
                break
            }
        }
        if (-not $matches) { continue }

        $length = Get-PngLength -Bytes $Bytes -Offset $offset
        if ($length -eq 0) { continue }
        $stream = New-Object IO.MemoryStream
        try {
            $stream.Write($Bytes, $offset, $length)
            $stream.Position = 0
            $image = [Drawing.Image]::FromStream($stream, $false, $true)
            try { $area = [long]$image.Width * $image.Height }
            finally { $image.Dispose() }
            if ($null -eq $best -or $area -gt $best.Area) {
                $best = @{ Offset = $offset; Length = $length; Area = $area }
            }
        }
        catch [ArgumentException] { }
        finally { $stream.Dispose() }
        $offset += $length - 1
    }
    return $best
}

$inputItem = Get-Item -LiteralPath $InputPath
if ($inputItem.PSIsContainer) {
    $files = Get-ChildItem -LiteralPath $inputItem.FullName -File -Filter '*.SNAG'
} else {
    $files = @($inputItem)
}
foreach ($file in $files) {
    if ($file.Extension -ine '.SNAG') {
        Write-Warning "Skipping non-SNAG file: $($file.FullName)"
        continue
    }
    $monthFolder = Join-Path $OutputFolder $file.CreationTime.ToString('yyyy-MM')
    $destination = Join-Path $monthFolder ($file.BaseName + '.png')
    if (Test-Path -LiteralPath $destination) {
        Write-Warning "Already exists: $destination"
        continue
    }
    try {
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        $png = Get-LargestPng -Bytes $bytes
        if ($null -eq $png) {
            Write-Warning "No decodable embedded PNG: $($file.Name)"
            continue
        }
        $output = New-Object byte[] $png.Length
        [Array]::Copy($bytes, $png.Offset, $output, 0, $png.Length)
        New-Item -ItemType Directory -Path $monthFolder -Force | Out-Null
        [IO.File]::WriteAllBytes($destination, $output)
        Write-Output $destination
    }
    catch {
        Write-Warning "Failed $($file.Name): $_"
    }
}