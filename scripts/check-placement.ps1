# Independent placement audit — run AFTER publish, by a checker that did not build the chapter.
# Verifies files <-> manifest <-> git <-> live site all agree. Exit 0 PASS / 1 violations.
param(
    [switch]$SkipRemote,          # local-only mode (tests, offline)
    [int]$Retries = 4,            # GH Pages propagation retries
    [int]$RetrySeconds = 30
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$v = @()
Add-Type -AssemblyName System.Drawing

$manifest = Get-Content (Join-Path $repo 'chapters.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$log = Get-Content (Join-Path $repo 'continuity\log.md') -Raw -Encoding UTF8

foreach ($c in $manifest.chapters) {
    $dir = Join-Path $repo "chapters\$($c.slug)"
    if (-not (Test-Path $dir)) { $v += "$($c.slug): chapters dir missing"; continue }

    $cover = Join-Path $dir 'cover.jpg'
    if (-not (Test-Path $cover)) { $v += "$($c.slug): cover.jpg missing" }
    elseif ((Get-Item $cover).Length -lt 10KB) { $v += "$($c.slug): cover.jpg suspiciously small" }

    for ($i = 1; $i -le $c.pages; $i++) {
        $p = Join-Path $dir ('p{0:d2}.jpg' -f $i)
        if (-not (Test-Path $p)) { $v += "$($c.slug): missing p$('{0:d2}' -f $i).jpg (manifest says $($c.pages) pages)"; continue }
        $f = Get-Item $p
        if ($f.Length -lt 30KB) { $v += "$($c.slug)/$($f.Name): only $([math]::Round($f.Length/1KB))KB — likely broken" }
        if ($f.Length -gt 450KB) { $v += "$($c.slug)/$($f.Name): $([math]::Round($f.Length/1KB))KB — over web budget" }
        $img = [Drawing.Image]::FromFile($f.FullName)
        try { if ($img.Width -ne 900) { $v += "$($c.slug)/$($f.Name): width $($img.Width)px, expected 900" } }
        finally { $img.Dispose() }
    }
    $stray = @(Get-ChildItem (Join-Path $dir 'p*.jpg') | Where-Object { [int]($_.BaseName -replace 'p') -gt $c.pages })
    if ($stray) { $v += "$($c.slug): $($stray.Count) stray page file(s) beyond manifest count" }

    if (-not (Test-Path (Join-Path $repo "production\$($c.slug)\breakdown.md"))) { $v += "$($c.slug): breakdown.md not in repo" }
    if ($log -notmatch "Chapter\s+$($c.n)\b") { $v += "$($c.slug): no continuity log entry" }
}

# Git placement: nothing uncommitted, nothing unpushed, no raws tracked
Push-Location $repo
try {
    if (git status --porcelain) { $v += 'git: uncommitted changes present' }
    git fetch origin main --quiet 2>$null
    if ((git rev-parse HEAD) -ne (git rev-parse origin/main 2>$null)) { $v += 'git: HEAD not pushed to origin/main' }
    if (git ls-files 'production/*/raw/*') { $v += 'git: full-res raws are tracked — must never enter the repo' }
} finally { Pop-Location }

# Live site (retry for Pages propagation)
if (-not $SkipRemote) {
    $base = 'https://goodman-pro.github.io/tsumuji/'
    $urls = @($base, "${base}chapters.json")
    $newest = $manifest.chapters | Sort-Object n | Select-Object -Last 1
    if ($newest) {
        $urls += "$base$($newest.cover)"
        $urls += "${base}chapters/$($newest.slug)/p01.jpg"
        $urls += "${base}chapters/$($newest.slug)/p$('{0:d2}' -f $newest.pages).jpg"
    }
    foreach ($u in $urls) {
        $ok = $false
        for ($t = 1; $t -le $Retries; $t++) {
            try { if ((Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 20).StatusCode -eq 200) { $ok = $true; break } } catch {}
            if ($t -lt $Retries) { Start-Sleep -Seconds $RetrySeconds }
        }
        if (-not $ok) { $v += "live: $u not serving 200 after $Retries tries" }
    }
    if ($newest) {
        try {
            $remote = (Invoke-WebRequest -Uri "${base}chapters.json" -UseBasicParsing -TimeoutSec 20).Content | ConvertFrom-Json
            if (@($remote.chapters).Count -ne @($manifest.chapters).Count) { $v += "live: remote manifest has $(@($remote.chapters).Count) chapters, local has $(@($manifest.chapters).Count)" }
        } catch { $v += 'live: could not fetch remote chapters.json for comparison' }
    }
}

if ($v) { $v | ForEach-Object { Write-Output "VIOLATION: $_" }; exit 1 }
Write-Output "PLACEMENT PASS ($(@($manifest.chapters).Count) chapter(s) verified$(if ($SkipRemote) { ', remote skipped' }))"
