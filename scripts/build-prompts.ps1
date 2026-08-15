# Builds artist prompt files: preamble + FULL ART SPEC (verbatim) + character locks + page script.
# One file per page -> production/chNN/prompts/pNN.txt ; -Cover builds prompts/cover.txt instead.
param(
    [Parameter(Mandatory)][int]$Chapter,
    [switch]$Cover
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$ch = 'ch{0:d2}' -f $Chapter
$prodDir = Join-Path $repo "production\$ch"
$breakdown = Get-Content (Join-Path $prodDir 'breakdown.md') -Raw -Encoding UTF8
$specFile = Get-Content (Join-Path $repo 'engine\art-spec.md') -Raw -Encoding UTF8
$locks = (Get-Content (Join-Path $repo 'engine\locks.md') -Raw -Encoding UTF8).Trim()
New-Item -ItemType Directory -Force (Join-Path $prodDir 'prompts') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $prodDir 'raw') | Out-Null

if ($specFile -notmatch '(?s)<!-- BEGIN ART SPEC -->(.*?)<!-- END ART SPEC -->') { throw 'ART SPEC markers not found' }
$spec = $Matches[1].Trim()

$preamble = @'
You are the ARTIST agent for an ongoing manga series. Your entire job on this call:
render ONE finished manga page as a single image with your built-in image_gen tool,
then deliver the file. You never invent story: do not add, remove, reorder, or reword
panels, dialogue, or SFX - the PAGE SCRIPT below is final. Your craft is executing it
with the ART SPEC's rules.

DELIVERY:
- Generate at size 1024x1536 (portrait).
- Copy the final PNG to exactly: {ABS_RAW_PATH}   (create directories if needed)
- Verify the file exists and is larger than 100 KB.
- Reply with only: SAVED <bytes>. If generation fails, retry once; if it fails again
  reply FAILED <one-line reason>.
'@

if ($Cover) {
    $title = if ($breakdown -match '(?m)^#\s+CHAPTER\s+\d+\s*[-—–]+\s*(.+?)\s*$') { $Matches[1].Trim() } else { '' }
    $series = (Get-Content (Join-Path $repo 'chapters.json') -Raw | ConvertFrom-Json).series.title
    if ($specFile -notmatch '(?s)(COVER OVERRIDE:.*?)(\r?\n\r?\n|\s*$)') { throw 'COVER OVERRIDE block not found' }
    $override = $Matches[1].Trim()
    $notes = if ($breakdown -match '(?s)##\s+COVER NOTES\s*\r?\n(.*?)(?=\r?\n##\s|$)') { $Matches[1].Trim() } else { '' }
    $target = Join-Path $prodDir 'raw\cover.png'
    $body = @(
        ($preamble -replace '\{ABS_RAW_PATH\}', $target).Replace('ONE finished manga page', 'ONE chapter cover')
        $spec
        $override
        "SERIES TITLE (letter exactly): $series"
        "CHAPTER $Chapter — $title"
        $(if ($notes) { "COVER NOTES:`n$notes" })
        "CHARACTER LOCKS — draw these characters EXACTLY as specified:`n$locks"
    ) | Where-Object { $_ }
    $out = Join-Path $prodDir 'prompts\cover.txt'
    [IO.File]::WriteAllText($out, ($body -join "`n`n"), [Text.UTF8Encoding]::new($false))
    Write-Output "BUILT $out"
    exit 0
}

# Split page blocks: '## PAGE NN ...' up to the next '## ' heading
$pageMatches = [regex]::Matches($breakdown, '(?ms)^##\s+PAGE\s+(\d+)[^\r\n]*\r?\n(.*?)(?=^##\s|\z)')
if ($pageMatches.Count -eq 0) { throw 'No page blocks found in breakdown' }
foreach ($m in $pageMatches) {
    $n = [int]$m.Groups[1].Value
    $id = 'p{0:d2}' -f $n
    $target = Join-Path $prodDir "raw\$id.png"
    $header = ($m.Value -split "`r?`n")[0]   # keeps the SPLASH marker visible to the artist
    $body = @(
        ($preamble -replace '\{ABS_RAW_PATH\}', $target)
        $spec
        "CHARACTER LOCKS — draw these characters EXACTLY as specified, every panel:`n$locks"
        "PAGE SCRIPT — render exactly this, panel by panel, every bubble:`n$header`n$($m.Groups[2].Value.Trim())"
    )
    $out = Join-Path $prodDir "prompts\$id.txt"
    [IO.File]::WriteAllText($out, ($body -join "`n`n"), [Text.UTF8Encoding]::new($false))
}
Write-Output "BUILT $($pageMatches.Count) prompt files in production\$ch\prompts"
