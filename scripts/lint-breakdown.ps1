# Lints production/chNN/breakdown.md against engine/chapter-engine.md rules.
# Exit 0 + "LINT PASS (densest page: NN)" or exit 1 + violation list.
param(
    [Parameter(Mandatory)][int]$Chapter
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$ch = 'ch{0:d2}' -f $Chapter
$file = Join-Path $repo "production\$ch\breakdown.md"
if (-not (Test-Path $file)) { Write-Output "FAIL: $file not found"; exit 1 }

# Normalize curly quotes so counting is stable
$text = (Get-Content $file -Raw -Encoding UTF8) -replace '[“”]', '"'
$lines = $text -split "`r?`n"

$violations = @()
$pages = @{}      # num -> @{splash; panels; bubbles; words[]; chibi; }
$cur = 0
foreach ($line in $lines) {
    if ($line -match '^##\s+PAGE\s+(\d+)\s*(?:[-—–]+\s*SPLASH)?\s*$') {
        $cur = [int]$Matches[1]
        $pages[$cur] = @{ splash = ($line -match 'SPLASH'); panels = 0; bubbles = 0; longBubbles = 0; chibi = 0 }
        continue
    }
    if ($line -match '^##\s') { $cur = 0; continue }   # COVER NOTES / CONTINUITY NOTES etc.
    if ($cur -eq 0) { continue }
    $p = $pages[$cur]
    if ($line -match '^PANEL\s+\d+') {
        $p.panels++
        if ($line -match '\[CHIBI\]') { $p.chibi++ }
    }
    elseif ($line -match '^-\s*\([^)]+?(?:,\s*thought)?\)\s*:\s*"(.+)"\s*$' -and $line -notmatch ',\s*aside\)') {
        $p.bubbles++
        $w = ($Matches[1] -split '\s+') | Where-Object { $_ }
        if ($w.Count -gt 8) { $p.longBubbles++ }
    }
}

$nums = $pages.Keys | Sort-Object
if ($nums.Count -lt 25) { $violations += "Only $($nums.Count) pages — floor is 25 (default 26-28; add scenes, never compress)" }
$expected = 1..($nums.Count)
if (Compare-Object $nums $expected) { $violations += "Page numbering not contiguous from 01" }

$splashes = @($nums | Where-Object { $pages[$_].splash })
if ($splashes.Count -ne 1) { $violations += "Splash count $($splashes.Count) — must be exactly 1" }
$chibiTotal = ($nums | ForEach-Object { $pages[$_].chibi } | Measure-Object -Sum).Sum
if ($chibiTotal -lt 3) { $violations += "Only $chibiTotal [CHIBI] panels — need >=3 per chapter" }
if ($text -notmatch '##\s+CONTINUITY NOTES') { $violations += "Missing ## CONTINUITY NOTES section" }

foreach ($n in $nums) {
    $p = $pages[$n]; $id = 'p{0:d2}' -f $n
    if ($p.splash) {
        if ($p.panels -ne 1) { $violations += "$id (splash): $($p.panels) panels — splash is a single panel" }
        if ($p.bubbles -lt 3 -or $p.bubbles -gt 6) { $violations += "$id (splash): $($p.bubbles) bubbles — splash carries 3-6" }
    } else {
        if ($p.panels -lt 5 -or $p.panels -gt 7) { $violations += "$id`: $($p.panels) panels — must be 5-7 (default 6)" }
        if ($p.bubbles -lt 7 -or $p.bubbles -gt 13) { $violations += "$id`: $($p.bubbles) bubbles — must be 7-13 (default 9-11)" }
    }
    if ($p.bubbles -eq 0) { $violations += "$id`: ZERO bubbles — there are no silent pages" }
    if ($p.longBubbles -gt 0) { $violations += "$id`: $($p.longBubbles) bubble(s) over 8 words — split into a bubble chain" }
}

if ($violations) {
    $violations | ForEach-Object { Write-Output "VIOLATION: $_" }
    exit 1
}
$densest = ($nums | Where-Object { $_ -gt 1 -and -not $pages[$_].splash } | Sort-Object { $pages[$_].bubbles } -Descending | Select-Object -First 1)
Write-Output ("LINT PASS ({0} pages; densest page: {1:d2} with {2} bubbles)" -f $nums.Count, $densest, $pages[$densest].bubbles)
