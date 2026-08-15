# Publishes a finished chapter: downscale raws to web JPEGs, update chapters.json, append
# continuity log, commit + push. Web-sized images only enter git (production/*/raw is ignored).
param(
    [Parameter(Mandatory)][int]$Chapter,
    [Parameter(Mandatory)][string]$Title,
    [int]$Width = 900,
    [int]$Quality = 75,
    [switch]$NoPush
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$ch = 'ch{0:d2}' -f $Chapter
$rawDir = Join-Path $repo "production\$ch\raw"
$webDir = Join-Path $repo "chapters\$ch"
New-Item -ItemType Directory -Force $webDir | Out-Null

Add-Type -AssemblyName System.Drawing
$jpegCodec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$encParams = [Drawing.Imaging.EncoderParameters]::new(1)
$encParams.Param[0] = [Drawing.Imaging.EncoderParameter]::new([Drawing.Imaging.Encoder]::Quality, [long]$Quality)

$raws = Get-ChildItem (Join-Path $rawDir '*.png') | Sort-Object Name
if (-not $raws) { throw "No raw PNGs in $rawDir" }
foreach ($f in $raws) {
    $src = [Drawing.Image]::FromFile($f.FullName)
    try {
        $h = [int]($src.Height * $Width / $src.Width)
        $bmp = [Drawing.Bitmap]::new($Width, $h)
        $g = [Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($src, 0, 0, $Width, $h)
        $g.Dispose()
        $out = Join-Path $webDir ($f.BaseName + '.jpg')
        $bmp.Save($out, $jpegCodec, $encParams)
        $bmp.Dispose()
    } finally { $src.Dispose() }
}
$pageCount = @(Get-ChildItem (Join-Path $webDir 'p*.jpg')).Count
Write-Output "Downscaled $(@($raws).Count) images -> $webDir ($pageCount pages)"

# Manifest
$manifestPath = Join-Path $repo 'chapters.json'
$manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$manifest.chapters = @($manifest.chapters | Where-Object { $_.n -ne $Chapter })
$manifest.chapters += [pscustomobject]@{
    n = $Chapter; slug = $ch; title = $Title; pages = $pageCount
    cover = "chapters/$ch/cover.jpg"; published = (Get-Date -Format 'yyyy-MM-dd')
}
$manifest.chapters = @($manifest.chapters | Sort-Object n)
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))

# Continuity log (append-only; skip if this chapter already logged — republish case)
$breakdown = Get-Content (Join-Path $repo "production\$ch\breakdown.md") -Raw -Encoding UTF8
$logNow = Get-Content (Join-Path $repo 'continuity\log.md') -Raw -Encoding UTF8
if ($logNow -notmatch "—\s*Chapter\s+$Chapter\b" -and $breakdown -match '(?s)##\s+CONTINUITY NOTES\s*\r?\n(.*?)\z') {
    $entry = "`n## $(Get-Date -Format 'yyyy-MM-dd') — Chapter $Chapter`: $Title`n`n$($Matches[1].Trim())`n"
    Add-Content (Join-Path $repo 'continuity\log.md') $entry -Encoding UTF8
}

# Commit + push
Push-Location $repo
try {
    git add -A
    git commit -m "ch$('{0:d2}' -f $Chapter): $Title ($pageCount pages)" | Out-Null
    if (-not $NoPush) { git push }
    Write-Output "PUBLISHED $ch — $Title"
} finally { Pop-Location }
