param(
    [Parameter(Mandatory=$true)][string]$AddonDirectory,
    [string]$BackupDirectory,
    [Parameter(Mandatory=$true)][string]$ExpectedBaseline
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$manifest = Get-Content -LiteralPath (Join-Path $repo 'outputs\build-manifest.json') -Raw | ConvertFrom-Json
$package = $manifest.packages | Where-Object { $_.file -notlike '*-source.zip' } | Select-Object -First 1
$zipPath = Join-Path $repo ('outputs\' + $package.file)
if ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash -ne $package.sha256) { throw 'Package hash mismatch' }
$target = [IO.Path]::GetFullPath($AddonDirectory).TrimEnd('\')
if ([IO.Path]::GetFileName($target) -ne 'EncounterLab' -or [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($target)) -ne 'AddOns') {
    throw 'Target must be the EncounterLab directory directly inside AddOns'
}
if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw 'Existing installation is required for this upgrade' }
$reparse = Get-ChildItem -LiteralPath $target -Force -Recurse | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }
if ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint -or $reparse) { throw 'Refusing to move a linked installation' }
$baseline = Get-Content -LiteralPath $ExpectedBaseline -Raw | ConvertFrom-Json
foreach ($entry in $baseline.addon_files) {
    if ($entry.path -eq 'README.md') { continue }
    $installed = [IO.Path]::GetFullPath((Join-Path $target $entry.path))
    if (-not $installed.StartsWith($target+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid baseline path' }
    if (-not (Test-Path -LiteralPath $installed) -or (Get-FileHash -LiteralPath $installed).Hash -ne $entry.sha256) { throw "Installed runtime changed: $($entry.path)" }
}
$backupRoot = if ($BackupDirectory) { [IO.Path]::GetFullPath($BackupDirectory) } else { Join-Path ([IO.Path]::GetPathRoot($target)) 'EncounterLab-backups' }
if ($backupRoot.StartsWith([IO.Path]::GetDirectoryName($target)+'\',[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetPathRoot($backupRoot) -ne [IO.Path]::GetPathRoot($target)) { throw 'Backup must be outside AddOns and on the same volume' }
$backup = [IO.Path]::GetFullPath((Join-Path $backupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+$manifest.version)))
if (-not $backup.StartsWith([IO.Path]::GetFullPath($backupRoot)+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $backup)) { throw 'Invalid or existing backup directory' }
$stage = Join-Path $backup 'staged'
New-Item -ItemType Directory -Path $stage | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $seen=@{};[long]$bytes=0
    foreach ($entry in $archive.Entries) {
        $name=$entry.FullName
        if ($name -notmatch '^EncounterLab/(?:[A-Za-z0-9_-]+\.lua|EncounterLab\.toc|README\.md|LICENSE|Locales/[A-Za-z0-9_-]+\.(?:lua|md)|Media/[A-Za-z0-9_-]+\.tga)$' -or $seen[$name]) { throw "Unexpected package entry: $name" }
        $seen[$name]=$true;$bytes+=$entry.Length
        if ($bytes -gt 2MB) { throw 'Package exceeds the 2 MiB runtime size gate' }
        $dest=[IO.Path]::GetFullPath((Join-Path $stage $name))
        if (-not $dest.StartsWith($stage+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Package path escaped staging' }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest)) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$dest,$false)
    }
    if ($seen.Count -ne $manifest.addonFiles -or -not $seen['EncounterLab/EncounterLab.toc']) { throw 'Incomplete package' }
} finally { $archive.Dispose() }
$stagedAddon = Join-Path $stage 'EncounterLab'
$stagedFiles = @(Get-ChildItem -LiteralPath $stagedAddon -File -Recurse)
foreach ($file in $stagedFiles) {
    $relative = $file.FullName.Substring($stagedAddon.Length+1)
    $source = Join-Path $PSScriptRoot ('EncounterLab\'+$relative)
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $source).Hash) { throw "Source/package mismatch: $relative" }
}
$oldFiles=@(Get-ChildItem -LiteralPath $target -Force -File -Recurse)
$beforeBytes=($oldFiles | Measure-Object Length -Sum).Sum
$previous=Join-Path $backup 'previous-EncounterLab'
# Both resolved paths are explicit, checked and on the same volume. Preserve the
# entire old installation, including its accidentally bundled repository and tools.
if (-not $previous.StartsWith($backup+'\',[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetPathRoot($previous) -ne [IO.Path]::GetPathRoot($target)) { throw 'Unsafe backup destination' }
Move-Item -LiteralPath $target -Destination $previous
try { Move-Item -LiteralPath $stagedAddon -Destination $target }
catch { Move-Item -LiteralPath $previous -Destination $target; throw }
$newFiles=@(Get-ChildItem -LiteralPath $target -Force -File -Recurse)
if ($newFiles.Count -ne $manifest.addonFiles) { throw 'Installed file count mismatch' }
foreach ($file in $newFiles) {
    $relative=$file.FullName.Substring($target.Length+1)
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot ('EncounterLab\'+$relative))).Hash) { throw "Installed hash mismatch: $relative" }
}
$preservedFiles=@(Get-ChildItem -LiteralPath $previous -Force -File -Recurse)
if ($preservedFiles.Count -ne $oldFiles.Count -or ($preservedFiles | Measure-Object Length -Sum).Sum -ne $beforeBytes) { throw 'Backup inventory mismatch' }
$report=[ordered]@{version=$manifest.version;path=$target;backup=$previous;oldFiles=$oldFiles.Count;oldBytes=$beforeBytes;newFiles=$newFiles.Count;newBytes=($newFiles | Measure-Object Length -Sum).Sum;allSourceHashesMatch=$true;oldInstallationPreserved=$true;reloadRequired=$true}
$json=$report | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText((Join-Path $repo 'outputs\install-verification.json'),$json,[Text.UTF8Encoding]::new($false))
$json
