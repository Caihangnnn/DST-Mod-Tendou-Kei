param(
    [string]$ExtractionDir = (Join-Path $PSScriptRoot "..\..\kei_voice_extract"),
    [string]$Ffmpeg = "",
    [string]$FsBankEx = "",
    [switch]$PruneExtraction
)

$ErrorActionPreference = "Stop"

function Resolve-Tool([string]$explicitPath, [string]$commandName, [string]$fallbackPath) {
    if ($explicitPath -ne "") {
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
    throw "Tool not found: $commandName. Pass -$commandName or add it to PATH."
}

$ffmpegPath = Resolve-Tool $Ffmpeg "ffmpeg" "C:\Users\caiha\AppData\Roaming\TRAE SOLO\ModularData\ai-agent\vm\tools\app\ffmpeg\ffmpeg.exe"
$fsbankexPath = Resolve-Tool $FsBankEx "fsbankexcl" "C:\Users\caiha\AppData\Local\Temp\fsbank-old\fsbankexcl.exe"
$extractionRoot = (Resolve-Path -LiteralPath $ExtractionDir).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$soundRoot = Join-Path $repoRoot "sound"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "tendou-kei-voice-build"
$individualRoot = Join-Path $soundRoot "kei_voice_individual"

# Remove outputs from the old kei_voice package name so the game cannot pick
# up a stale FEV/FSB pair after the bank is renamed to its actual namespace.
foreach ($legacyName in @("kei_voice.fev", "kei_voice.fsb")) {
    $legacyPath = Join-Path $soundRoot $legacyName
    if (Test-Path -LiteralPath $legacyPath -PathType Leaf) {
        Remove-Item -LiteralPath $legacyPath -Force
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $extractionRoot "manifest.json") -PathType Leaf)) {
    throw "manifest.json was not found in $extractionRoot"
}

$manifest = Get-Content -Raw -LiteralPath (Join-Path $extractionRoot "manifest.json") | ConvertFrom-Json
$itemsByIndex = @{}
foreach ($item in $manifest.items) {
    $itemsByIndex[[int]$item.index] = $item
}

# Keep the FEV-compatible names from the reference bank, while mapping them
# to Kei's Japanese combat, interaction, and upgrade lines selected from the
# extraction. Reference event names are reused as stable FEV slots.
$mapping = @(
    # The three requested short battle lines.
    @{ Name = "attacked_1"; Index = 49 },
    @{ Name = "attacked_2"; Index = 50 },
    @{ Name = "attacked_3"; Index = 51 },
    # Both death slots use the two complete Japanese battle-failure lines.
    @{ Name = "christmas_carol"; Index = 57 },
    @{ Name = "death"; Index = 58 },
    @{ Name = "do_emote"; Index = 85 },
    # Upgrade success lines, played when the protocol slot count increases.
    @{ Name = "drown_in_water"; Index = 53 },
    @{ Name = "feel_sleepy"; Index = 54 },
    # The FEV template uses this exact sample order for its event indices.
    @{ Name = "ghost_1"; Index = 18 },
    @{ Name = "ghost_2"; Index = 19 },
    @{ Name = "ghost_3"; Index = 24 },
    @{ Name = "ghost_4"; Index = 71 },
    @{ Name = "ghost_5"; Index = 25 },
    @{ Name = "pose"; Index = 55 },
    # The remaining requested regular speech lines.
    @{ Name = "talk_1"; Index = 4 },
    @{ Name = "talk_2"; Index = 10 },
    @{ Name = "talk_3"; Index = 13 },
    @{ Name = "talk_4"; Index = 16 },
    @{ Name = "talk_5"; Index = 17 },
    @{ Name = "yawn"; Index = 86 }
)

if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
New-Item -ItemType Directory -Path $soundRoot -Force | Out-Null
New-Item -ItemType Directory -Path $individualRoot -Force | Out-Null

$expectedIndividualFiles = @()

$listEntries = @()
foreach ($entry in $mapping) {
    $source = $itemsByIndex[$entry.Index]
    if ($source -eq $null) {
        throw "Voice index $($entry.Index) is missing from manifest.json"
    }
    $sourcePath = Join-Path $extractionRoot $source.filename
    $wavPath = Join-Path $tempRoot ($entry.Name + ".wav")
    & $ffmpegPath -hide_banner -loglevel error -y -i $sourcePath -ac 1 -ar 44100 -c:a pcm_s16le $wavPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $wavPath -PathType Leaf)) {
        throw "FFmpeg failed for $($source.filename)"
    }
    $individualPath = Join-Path $individualRoot ($entry.Name + ".ogg")
    & $ffmpegPath -hide_banner -loglevel error -y -i $wavPath -c:a libvorbis -q:a 6 $individualPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $individualPath -PathType Leaf)) {
        throw "FFmpeg failed to export individual voice $($entry.Name)"
    }
    $expectedIndividualFiles += [IO.Path]::GetFileName($individualPath)
    $listEntries += ($entry.Name + ".wav")
}

Get-ChildItem -LiteralPath $individualRoot -File -Filter "*.ogg" | ForEach-Object {
    if ($expectedIndividualFiles -notcontains $_.Name) {
        Remove-Item -LiteralPath $_.FullName -Force
    }
}

$listPath = Join-Path $tempRoot "kei_voice.lst"
$listEntries | Set-Content -LiteralPath $listPath -Encoding ascii
$fsbPath = Join-Path $soundRoot "tendou_kei_vc.fsb"
Push-Location $tempRoot
try {
    # The reference FEV is paired with a PCM16 FSB. DST rejects a bank built
    # with a different codec even when all event and sample names match.
    & $fsbankexPath -format pcm -build_mode s -rebuild -o $fsbPath (Split-Path $listPath -Leaf)
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $fsbPath -PathType Leaf)) {
        throw "FSBank failed to build $fsbPath"
    }
}
finally {
    Pop-Location
}

$templatePath = Join-Path $repoRoot "..\Reference\Takanashi Hoshino\sound\hoshino_sound.fev"
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
    throw "Reference FEV was not found: $templatePath"
}
$fevBytes = [IO.File]::ReadAllBytes($templatePath)
$oldNamespace = [Text.Encoding]::ASCII.GetBytes("hoshino_sound")
$newNamespace = [Text.Encoding]::ASCII.GetBytes("tendou_kei_vc")
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
[IO.File]::WriteAllBytes((Join-Path $soundRoot "tendou_kei_vc.fev"), $fevBytes)

$sourceManifest = @{
    source = $manifest.source_page
    language = $manifest.language
    format = "FSB5 PCM16, source normalized to mono 44100 Hz"
    bank = "sound/tendou_kei_vc.fsb"
    fev = "sound/tendou_kei_vc.fev"
    individual_directory = "sound/kei_voice_individual"
    namespace = "tendou_kei_vc/tendou_kei_vc"
    mapping = $mapping
}
$sourceManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $soundRoot "kei_voice_manifest.json") -Encoding utf8

if ($PruneExtraction) {
    # Keep only the source files that are part of the successfully built bank.
    $requiredSourceNames = @("manifest.json")
    foreach ($entry in $mapping) {
        $requiredSourceNames += $itemsByIndex[$entry.Index].filename
    }
    Get-ChildItem -LiteralPath $extractionRoot -File | Where-Object {
        $requiredSourceNames -notcontains $_.Name
    } | Remove-Item -Force
    Write-Host "Pruned unused source voice files from $extractionRoot"
}

Write-Host "Built $fsbPath"
Write-Host "Built $(Join-Path $soundRoot 'tendou_kei_vc.fev')"
