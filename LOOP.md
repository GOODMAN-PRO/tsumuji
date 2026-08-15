# PRODUCTION LOOP

One cycle produces and publishes one chapter, unattended. Any orchestrator agent (fresh context,
zero chat history) runs a cycle from this file alone. **CONTINUITY IS A FILE, NEVER A CONTEXT
WINDOW** — cold-start truth is exactly: `bible/` + `continuity/log.md` + `chapters.json` + `engine/`.

Roles, fixed: **Opus 5 writes** (bible, breakdowns, dialogue, continuity, site). **GPT-5.6 Sol +
ImageGen draws** (pages, covers). The writer never draws. The artist never invents story — it
renders a finished page block.

## The cycle

0. **Sync + orient.** `git pull`. Read `chapters.json` → next chapter N. Read `continuity/log.md`.
   The series is STRICTLY 55 chapters — one complete story, finale at 55. If N > 55: STOP, the
   series is finished; do not produce chapter 56. If N is an arc boundary (12, 23, 34, 45):
   FIRST spawn the writer to expand that arc's chapters into full rows in `bible/arc.md`
   (consistent with the locked milestones in `bible/pillars.md`), commit, then continue.
1. **Write.** Spawn Opus 5 WRITER agent #1 with: `bible/pillars.md`, `bible/series.md`,
   `bible/cast.md`, `bible/style.md`, the chapter's row in `bible/arc.md`, the FULL
   `continuity/log.md`, and `engine/chapter-engine.md`. It writes `production/chNN/breakdown.md`
   per the engine grammar, cold, seeing no other chat context.
   **It MUST write the file in THREE installments** (pages 1-9, then 10-18, then 19-end +
   COVER NOTES + CONTINUITY NOTES). One giant write stalls the agent and gets it killed.
2. **Edit + lint.** Spawn Opus 5 EDITOR agent #2 (fresh context, never the writer) to audit the
   draft against bible + canon numbers + gag/ration ledgers + address ladder, fix in place, and
   run `pwsh scripts/lint-breakdown.ps1 -Chapter N` until it prints LINT PASS. Showrunner
   re-runs the lint independently. Drawing never starts on a failing breakdown.
   *Both Opus agents work every cycle: #1 writes, #2 edits. That is the labor split.*
3. **Build prompts.** `pwsh scripts/build-prompts.ps1 -Chapter N` → `production/chNN/prompts/pNN.txt`
   (preamble + full ART SPEC + character locks + page script; see engine/page-prompt-template.md).
4. **Calibration gate.** `pwsh scripts/draw-pages.ps1 -Chapter N -Pages "01,<densest>" -Parallel 2`
   where <densest> = the mid-chapter page with the most bubbles (lint prints it). OPEN both PNGs
   with the Read tool and COUNT panels, bubbles, faces per engine/chapter-engine.md. Zero bubbles
   or zero faces is a failure to fix, not a variation to report. Only a passing gate unlocks step 5.
   **If the gate reveals a WARDROBE or RENDER drift** (wrong garment, gradient shading, detailed
   crowd faces, an object drawn that the locks forbid): fix `engine/locks.md` with an explicit
   mechanical instruction, DELETE the gate PNGs, re-run `build-prompts.ps1`, and re-gate. Locks
   are cumulative armor — every drift caught once is prevented for all 54 remaining chapters.
5. **Draw.** `pwsh scripts/draw-pages.ps1 -Chapter N` — draws every missing page, 5 in parallel,
   full ART SPEC on every single call, retry once per page, verifies every PNG on disk. Rerun the
   same command to fill any stragglers; it is idempotent.
6. **Cover.** `pwsh scripts/build-prompts.ps1 -Chapter N -Cover` then
   `pwsh scripts/draw-pages.ps1 -Chapter N -Cover` (needs the pages done first — the cover is
   generated after its chapter exists).
7. **Publish.** `pwsh scripts/publish.ps1 -Chapter N -Title "<chapter title>"` →
   downscales raw PNGs to `chapters/chNN/pNN.jpg` (~900px wide, JPEG q75, ~200 KB) + `cover.jpg`,
   appends the chapter entry to `chapters.json`, appends CONTINUITY NOTES to `continuity/log.md`
   (date-stamped), commits **web-sized images + text only** (raw PNGs are gitignored), pushes.
8. **Check placement (independent).** Spawn a fresh-context CHECKER agent — never the agent that
   wrote or drew the chapter. It: (a) runs `pwsh scripts/check-placement.ps1` (file completeness,
   contiguous page numbering, image widths/sizes, manifest consistency, continuity log entry,
   git clean + pushed, raws untracked, live URLs serving 200 with propagation retries);
   (b) OPENS the published first page, splash page, and last page JPEGs and confirms each is the
   right content for this chapter (correct chapter caption on p01, dialogue legible at web size,
   pages in story order); (c) loads the live site and confirms the new chapter appears first on
   the index and its reader deep-link works. Any violation goes back to the orchestrator to fix
   and re-publish — the cycle does not end on a failing check.
9. **Repeat.** Start the next cycle at step 0.

## Invariants (do not renegotiate these mid-loop)

- Full ART SPEC on every image call. Never abbreviated, never "as before".
- No chapter under 25 pages; no page under 6 panels (splash excepted); no page under 8 bubbles
  (splash 3-6); no silent pages anywhere.
- Exactly one splash per chapter. At least 3 chibi panels. A domestic beat every chapter.
- The gate runs for EVERY chapter, not just the first.
- Full-res raws never enter git history. Web-sized JPEGs only.
- The log is append-only. Never rewrite history in it.

## Unattended operation

The orchestrator session runs cycles back-to-back via scheduled wakeups, one chapter per cycle,
to a hard stop at chapter 55. If the session dies, restart is one message in Claude Code at the
repo: **"Run one production cycle per LOOP.md."** Nothing else is needed — the repo is the memory.

## Operational facts (scars — do not relearn these)

- **Artist invocation** (draw-pages.ps1 already does this): prompt piped via stdin —
  `codex exec -m gpt-5.6-sol --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check
  -c model_reasoning_effort="low" -C <repo> - < prompts\pNN.txt`. The bypass flag is REQUIRED on
  this machine; the sandbox helper is broken and file writes fail without it.
- **Draw at `-Parallel 5`.** The script is idempotent (skips PNGs >100KB): rerun the identical
  command until it reports N/N present. Background shell commands cap at 10 minutes.
- **Writer agents write breakdowns in 3 installments.** Non-negotiable; see step 1.
- **Ration ledgers live in `continuity/log.md`** — bit-bleed uses (5 in the series, one per arc),
  the acknowledged aside (ch44 only), DOKI (0 scheduled). Every cycle appends its usage.
- **Arc boundaries (ch12, 23, 34, 45):** expand that arc's one-liners into full rows in
  `bible/arc.md` BEFORE writing the chapter.
- **After ch55 publishes, production STOPS.** The story is finished. Do not write chapter 56.
