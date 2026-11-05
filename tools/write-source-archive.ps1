param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$ArchivePath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
$repositoryPath = (Resolve-Path -LiteralPath $RepositoryRoot).Path.TrimEnd([char[]]'\/')
$inventory = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$expected = @($inventory.files)
if ($expected.Count -eq 0 -or $expected.Count -ne $inventory.fileCount) { throw 'Invalid source inventory.' }
$archiveFullPath = [IO.Path]::GetFullPath($ArchivePath)
$outputRoot = [IO.Path]::Combine($repositoryPath, 'github-upload') + [IO.Path]::DirectorySeparatorChar
if (-not $archiveFullPath.StartsWith($outputRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Archive must remain inside the ignored export directory.' }
$stream = [IO.File]::Open($archiveFullPath, [IO.FileMode]::CreateNew)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
try {
    foreach ($file in $expected) {
        $relativePath = [string]$file.path
        if ([IO.Path]::IsPathRooted($relativePath) -or $relativePath.Contains(':') -or ($relativePath -split '[/\\]') -contains '..') { throw 'Unsafe archive entry.' }
        $sourcePath = [IO.Path]::GetFullPath([IO.Path]::Combine($repositoryPath, $relativePath))
        if (-not $sourcePath.StartsWith($repositoryPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Source is outside the repository.' }
        $entry = $archive.CreateEntry($relativePath.Replace('\', '/'), [IO.Compression.CompressionLevel]::Optimal)
        $entryStream = $entry.Open()
        $inputStream = [IO.File]::OpenRead($sourcePath)
        try { $inputStream.CopyTo($entryStream) } finally { $inputStream.Dispose(); $entryStream.Dispose() }
    }
} finally { $archive.Dispose(); $stream.Dispose() }

# Reopen the finished archive: check exact entry list, sizes and SHA-256 hashes.
$stream = [IO.File]::OpenRead($archiveFullPath)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read, $false)
$hash = [Security.Cryptography.SHA256]::Create()
try {
    if ($archive.Entries.Count -ne $expected.Count) { throw 'Unexpected ZIP entries.' }
    foreach ($file in $expected) {
        $entry = $archive.GetEntry([string]$file.path)
        if ($null -eq $entry -or $entry.Length -ne $file.bytes) { throw 'ZIP entry missing or size mismatch.' }
        $inputStream = $entry.Open()
        try { $digest = [BitConverter]::ToString($hash.ComputeHash($inputStream)).Replace('-', '').ToLowerInvariant() } finally { $inputStream.Dispose() }
        if ($digest -ne $file.sha256) { throw 'ZIP content changed; do not upload.' }
    }
} finally { $hash.Dispose(); $archive.Dispose(); $stream.Dispose() }
Write-Output ('Verified ZIP entries and hashes: ' + $expected.Count)
