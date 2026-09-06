param(
    [string]$MusicExtractionDir = "",
    [string]$Ffmpeg = "",
    [Alias("FsBankEx")]
    [string]$FsBank = "",
    [ValidateSet("mp3", "vorbis")]
    [string]$Codec = "mp3",
    [ValidateRange(0, 100)]
    [int]$Mp3Quality = 75,
    [ValidateRange(0, 100)]
    [int]$VorbisQuality = 50
)

$ErrorActionPreference = "Stop"

function Resolve-Tool([string]$explicitPath, [string]$commandName, [string]$fallbackPath) {
    if (-not [string]::IsNullOrWhiteSpace($explicitPath)) {
        if (-not (Test-Path -LiteralPath $explicitPath -PathType Leaf)) {
            throw "Tool not found: $explicitPath"
        }
        return (Resolve-Path -LiteralPath $explicitPath).Path
    }
    $command = Get-Command $commandName -ErrorAction SilentlyContinue
    if ($command -ne $null) {
        return $command.Source
    }
    if ($fallbackPath -ne "" -and (Test-Path -LiteralPath $fallbackPath -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $fallbackPath).Path
    }
    throw "Tool not found: $commandName"
}

$ffmpegPath = Resolve-Tool $Ffmpeg "ffmpeg" "C:\Users\caiha\AppData\Roaming\TRAE SOLO\ModularData\ai-agent\vm\tools\app\ffmpeg\ffmpeg.exe"
$fsbankCommand = if ($Codec -eq "vorbis") { "fsbankcl" } else { "fsbankexcl" }
$fsbankFallback = if ($Codec -eq "vorbis") {
    "C:\Users\caiha\AppData\Local\Temp\fsbankcl-runtime\fsbankcl.exe"
} else {
    "C:\Users\caiha\AppData\Local\Temp\fsbank-old\fsbankexcl.exe"
}
$fsbankPath = Resolve-Tool $FsBank $fsbankCommand $fsbankFallback
$expectedToolName = if ($Codec -eq "vorbis") { "fsbankcl.exe" } else { "fsbankexcl.exe" }
if ([IO.Path]::GetFileName($fsbankPath) -ine $expectedToolName) {
    throw "Codec '$Codec' requires $expectedToolName; got $fsbankPath"
}
$audioFormat = if ($Codec -eq "vorbis") { "FSB5 Vorbis quality $VorbisQuality" } else { "FSB5 MP3 quality $Mp3Quality" }
$musicPath = if (-not [string]::IsNullOrWhiteSpace($MusicExtractionDir)) { $MusicExtractionDir } else { Join-Path $PSScriptRoot "..\..\kei_carol_music_extract" }
$musicRoot = Convert-Path -LiteralPath $musicPath
$repoRoot = Convert-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$soundRoot = Join-Path $repoRoot "sound"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "tendou-kei-carol-build"
$cacheRoot = Join-Path $tempRoot "fsbank-cache"
$manifestPath = Join-Path $musicRoot "manifest.json"
$templatePath = Join-Path $repoRoot "..\Reference\Takanashi Hoshino\sound\hoshino_sound.fev"

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "manifest.json was not found in $musicRoot"
}
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
    throw "Reference FEV was not found: $templatePath"
}

$manifest = [IO.File]::ReadAllText($manifestPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$items = if ($manifest -is [array]) { @($manifest) } else { @($manifest.items) }
if ($items.Count -ne 53) {
    throw "Expected 53 Carol tracks, found $($items.Count)"
}
foreach ($item in $items) {
    if ([string]::IsNullOrWhiteSpace($item.filename)) {
        throw "Carol manifest contains an item without a filename"
    }
}

# This order matches the reference FEV/FSB sample order. Each bank can expose
# twenty events while the Lua hook combines three banks into one 53-track pool.
$slotNames = @(
    "attacked_1", "attacked_2", "attacked_3", "christmas_carol", "death",
    "do_emote", "drown_in_water", "feel_sleepy", "ghost_1", "ghost_2",
    "ghost_3", "ghost_4", "ghost_5", "pose", "talk_1", "talk_2",
    "talk_3", "talk_4", "talk_5", "yawn"
)
$bankNames = @("kei_carol_a01", "kei_carol_a02", "kei_carol_a03")
$bankTrackCounts = @(20, 20, 13)

if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
New-Item -ItemType Directory -Path $soundRoot -Force | Out-Null

$oldNamespace = [Text.Encoding]::ASCII.GetBytes("hoshino_sound")
$builtBanks = @()
$globalIndex = 0
for ($bankIndex = 0; $bankIndex -lt $bankNames.Count; $bankIndex++) {
    $bankName = $bankNames[$bankIndex]
    $trackCount = $bankTrackCounts[$bankIndex]
    $bankTempRoot = Join-Path $tempRoot $bankName
    New-Item -ItemType Directory -Path $bankTempRoot -Force | Out-Null
    $listEntries = @()
    $trackMapping = @()

    for ($slotIndex = 0; $slotIndex -lt $slotNames.Count; $slotIndex++) {
        # The final bank has 13 real tracks; duplicate the first track only in
        # unused FSB slots so its FEV retains the complete reference layout.
        $sourceIndex = $globalIndex
        if ($slotIndex -ge $trackCount) {
            $sourceIndex = $globalIndex - $trackCount
        }
        $source = $items[$sourceIndex]
        $sourcePath = Join-Path $musicRoot $source.filename
        $wavPath = Join-Path $bankTempRoot ($slotNames[$slotIndex] + ".wav")
        & $ffmpegPath -hide_banner -loglevel error -y -i $sourcePath -ac 2 -ar 44100 -c:a pcm_s16le $wavPath
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $wavPath -PathType Leaf)) {
            throw "FFmpeg failed for $($source.filename)"
        }
        $listEntries += ($slotNames[$slotIndex] + ".wav")
        if ($slotIndex -lt $trackCount) {
            $trackMapping += [pscustomobject]@{
                slot = $slotNames[$slotIndex]
                ordinal = $source.ordinal
                id = $source.id
                title = $source.title
                source_url = $source.source_url
                filename = $source.filename
            }
        }
        $globalIndex++
    }

    $listPath = Join-Path $bankTempRoot ($bankName + ".lst")
    $listEntries | Set-Content -LiteralPath $listPath -Encoding ascii
    $fsbPath = Join-Path $soundRoot ($bankName + ".fsb")
    if (Test-Path -LiteralPath $fsbPath -PathType Leaf) {
        Remove-Item -LiteralPath $fsbPath -Force
    }
    Push-Location $bankTempRoot
    try {
        if ($Codec -eq "vorbis") {
            # fsbankcl 2.01.09 parses cache_dir correctly only after the source list.
            & $fsbankPath -format vorbis -quality $VorbisQuality -build_mode s -rebuild -o $fsbPath (Split-Path $listPath -Leaf) -cache_dir $cacheRoot
        } else {
            # Keep the legacy fallback available for machines without the bundled
            # FMOD SoundBank Generator runtime.
            & $fsbankPath -format mp3 -quality $Mp3Quality -build_mode s -rebuild -o $fsbPath (Split-Path $listPath -Leaf)
        }
        $fsbankExitCode = $LASTEXITCODE
        $fsbHeader = $null
        if (Test-Path -LiteralPath $fsbPath -PathType Leaf) {
            $fsbHeader = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($fsbPath)[0..3])
        }
        if ($fsbankExitCode -ne 0 -or -not (Test-Path -LiteralPath $fsbPath -PathType Leaf) -or $fsbHeader -ne "FSB5") {
            throw "FSBank failed to build a valid FSB5 bank: $fsbPath"
        }
    }
    finally {
        Pop-Location
    }

    $fevBytes = [IO.File]::ReadAllBytes($templatePath)
    $newNamespace = [Text.Encoding]::ASCII.GetBytes($bankName)
    if ($newNamespace.Length -ne $oldNamespace.Length) {
        throw "Bank namespace must be $($oldNamespace.Length) bytes: $bankName"
    }
    for ($i = 0; $i -le $fevBytes.Length - $oldNamespace.Length; $i++) {
        $match = $true
        for ($j = 0; $j -lt $oldNamespace.Length; $j++) {
            if ($fevBytes[$i + $j] -ne $oldNamespace[$j]) {
                $match = $false
                break
            }
        }
        if ($match) {
            [Array]::Copy($newNamespace, 0, $fevBytes, $i, $newNamespace.Length)
            $i += $oldNamespace.Length - 1
        }
    }
    $fevPath = Join-Path $soundRoot ($bankName + ".fev")
    [IO.File]::WriteAllBytes($fevPath, $fevBytes)
    $builtBanks += [pscustomobject]@{
        name = $bankName
        count = $trackCount
        namespace = "$bankName/$bankName"
        bank = "sound/$bankName.fsb"
        fev = "sound/$bankName.fev"
        mapping = $trackMapping
    }
}

$outputManifest = [pscustomobject]@{
    source = "https://kivo.wiki/music/"
    language = "日文/日配曲目"
    format = "$audioFormat, source normalized to stereo 44100 Hz"
    tracks = $items
    banks = $builtBanks
}
$outputManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $soundRoot "kei_carol_manifest.json") -Encoding utf8

Write-Host "Built $($builtBanks.Count) Carol music banks with $($items.Count) tracks"
$builtBanks | ForEach-Object {
    Write-Host "Built $($_.bank)"
    Write-Host "Built $($_.fev)"
}
