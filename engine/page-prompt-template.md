# PAGE PROMPT TEMPLATE

How one artist call is assembled. `scripts/build-prompts.ps1` does this mechanically for every page;
nothing here requires judgment. The FULL ART SPEC goes into EVERY call, verbatim, never abbreviated.

## Assembly order (one prompt file per page → `production/chNN/prompts/pNN.txt`)

```
<PREAMBLE with this page's absolute save path>

<ART SPEC — the full block between BEGIN/END markers in engine/art-spec.md, verbatim>

CHARACTER LOCKS — draw these characters EXACTLY as specified, every panel:
<the full ARTIST LOCK block of every character appearing in this chapter, from bible/cast.md>

PAGE SCRIPT — render exactly this, panel by panel, every bubble:
<this page's block from production/chNN/breakdown.md, verbatim>
```

## Preamble (fill the two placeholders)

```
You are the ARTIST agent for an ongoing manga series. Your entire job on this call:
render ONE finished manga page as a single image with your built-in image_gen tool,
then deliver the file. You never invent story: do not add, remove, reorder, or reword
panels, dialogue, or SFX — the PAGE SCRIPT below is final. Your craft is executing it
with the ART SPEC's rules.

DELIVERY:
- Generate at size 1024x1536 (portrait).
- Copy the final PNG to exactly: {ABS_RAW_PATH}   (create directories if needed)
- Verify the file exists and is larger than 100 KB.
- Reply with only: SAVED <bytes>. If generation fails, retry once; if it fails again
  reply FAILED <one-line reason>.
```

`{ABS_RAW_PATH}` = `<repo>\production\chNN\raw\pNN.png` (cover: `...\raw\cover.png`).

## Artist invocation (exact command — draw-pages.ps1 runs this per page)

```
codex exec -m gpt-5.6-sol --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check `
  -c model_reasoning_effort="low" -C <repo> - < production\chNN\prompts\pNN.txt
```

- Prompt is piped via stdin (`-`) to avoid shell quoting damage. The file IS the call.
- Up to 3 pages run in parallel; each call is stateless — no artist ever sees another page's chat.
- Verification is on disk, not in chat: a page "exists" when its PNG is at the expected path, >100 KB.
- Covers: same command, prompt file `prompts/cover.txt` (built with `-Cover`), which uses the
  COVER OVERRIDE block appended after the ART SPEC and includes both leads' locks.

## Why each part exists (failure modes this template kills)

| Failure seen in the wild | Countermeasure baked in |
|---|---|
| One illustration, no panels | ART SPEC's PAGE CONSTRUCTION section is first and imperative ("divide the sheet") |
| Sparse and cinematic | White space is defined as EMPTY BACKGROUNDS, never fewer panels/bubbles |
| No people, just objects | FACES section: max ONE personless panel per page |
| Zero dialogue | Script bubbles are mandatory renders; zero-bubble page = failed page; no silent-page allowance exists |
| Minimum becomes target | Spec and engine state DEFAULTS (7 panels, 10-12 bubbles); floors are labeled floors |
| Character drift | Full ARTIST LOCK block pasted into every call |
| Artist rewrites the story | Preamble: "you never invent story"; script is final |
