# Draws chapter pages via GPT-5.6 Sol (codex + built-in ImageGen). Idempotent: skips pages whose
# PNG already exists >100KB. Full ART SPEC rides in every prompt file. 3 pages in parallel.
# ponytail: no per-call watchdog; a hung codex call blocks its slot — rerun the script to resume.
param(
    [Parameter(Mandatory)][int]$Chapter,
    [string]$Pages = '',        # e.g. "01,14" — empty = all
    [switch]$Cover,
    [int]$Parallel = 5
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$ch = 'ch{0:d2}' -f $Chapter
$prodDir = Join-Path $repo "production\$ch"

$targets = @()
if ($Cover) {
    $targets += [pscustomobject]@{ id = 'cover'; prompt = Join-Path $prodDir 'prompts\cover.txt'; png = Join-Path $prodDir 'raw\cover.png' }
} else {
    $filter = if ($Pages) { $Pages -split ',' | ForEach-Object { 'p{0:d2}' -f [int]$_ } } else { @() }
    foreach ($f in (Get-ChildItem (Join-Path $prodDir 'prompts\p*.txt') | Sort-Object Name)) {
        $id = $f.BaseName
        if ($filter -and $id -notin $filter) { continue }
        $targets += [pscustomobject]@{ id = $id; prompt = $f.FullName; png = Join-Path $prodDir "raw\$id.png" }
    }
}
$todo = @($targets | Where-Object { -not (Test-Path $_.png) -or (Get-Item $_.png).Length -lt 100KB })
Write-Output "$($targets.Count) target(s), $($todo.Count) to draw"

$results = $todo | ForEach-Object -ThrottleLimit $Parallel -Parallel {
    $t = $_
    $repo = $using:repo
    foreach ($attempt in 1, 2) {
        Get-Content -Raw $t.prompt |
            codex exec -m gpt-5.6-sol --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check `
                -c model_reasoning_effort="low" -C $repo - 2>$null | Out-Null
        if ((Test-Path $t.png) -and (Get-Item $t.png).Length -gt 100KB) {
            return "OK   $($t.id) ($([math]::Round((Get-Item $t.png).Length/1KB))KB)"
        }
    }
    return "FAIL $($t.id)"
}
$results | ForEach-Object { Write-Output $_ }
$fails = @($results | Where-Object { $_ -like 'FAIL*' })
$missing = @($targets | Where-Object { -not (Test-Path $_.png) -or (Get-Item $_.png).Length -lt 100KB })
Write-Output "DONE: $($targets.Count - $missing.Count)/$($targets.Count) present"
if ($fails -or $missing) { exit 1 }
