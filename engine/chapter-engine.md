# CHAPTER ENGINE

The rules that let ANY chapter be written and drawn with no further creative input.
A writer agent needs exactly four inputs: `bible/*`, `continuity/log.md`, `chapters.json`, and this file.
Its output is one file: `production/chNN/breakdown.md`.

## Chapter shape

- **25-32 pages, default 26-28.** Never compress to hit a number. If the outline runs short, add scenes — another domestic beat, a B-plot touch, a supporting-cast aside — never stretch single moments thin.
- Page 1 carries a caption box with `CHAPTER N — TITLE` **and** dialogue. The chapter opens mid-life, not on an establishing pin-up.
- **Exactly one SPLASH page** per chapter, placed at an emotional or comedic peak. It is a single full-bleed panel and it still carries 3-6 bubbles. There are no other full-page panels.
- **Panels: default 7 per page. 8 often. 6 for quiet pages; 5 sparingly; 9 allowed for reaction insets** — five is a floor, not a target. (Splash: 1.) Vary the count and arrangement across a chapter; repeated six-box grids feel synthetic.
- **Bubbles: default 12-14 per page.** Hard floor 11, hard ceiling 15. (Splash: 4-7.) Count every speech bubble and thought bubble; captions/asides/SFX don't count toward it.
- **Bubble length: usually 2-8 words, hard cap 8.** One-word and two-word reactions are allowed when they carry timing; no more than three sub-four-word bubbles per page. Density comes from the NUMBER and rhythm of bubbles, never from speeches. Split a thought into a staggered chain; let interruptions, corrections, and backchannels occupy their own balloons.
- **Muttered asides: 3-5 per page.** Small unbubbled text beside a head. Use them often — they are the series' comedy engine and the visual glue between larger balloons.
- Thought bubbles carry the private-face interiority; both leads think more than they say.
- **SFX: 2-5 per page**, romaji + English translation in parens, from the lexicon in `bible/style.md`. With bubbles, asides, captions and SFX combined, a normal page should carry **at least 16 readable text beats**, usually 17-22.
- **At least 3 [CHIBI] panels per chapter**, dropped mid-conversation as comedy beats — never grouped, never announced.
- **Every chapter contains a domestic beat**: food, laundry, a bandage, a bus ride, dishes, a bento, an umbrella. It gets real page time, not a cutaway.
- Plot events are seasoning: at most one external development (a school event, a customer, a parent, a deadline, an exam) per chapter, and it must pay a character beat. The two of them in a quiet room is the meal.
- **Comedy is texture, not the engine.** Gentle humour runs through every chapter — small jokes, a chibi beat, a dry aside — but no chapter is built on a gag. Warmth first; the ache underneath.
- **THERE ARE NO SILENT PAGES.** Every page carries dialogue, page 1 included. A quiet moment gets three bubbles, never zero. Do not designate any page as "the silent page."

## Breakdown grammar (strict — scripts parse this)

```markdown
# CHAPTER 4 — TITLE HERE

LOGLINE: one sentence.
CONTINUITY IN: 2-4 bullets of what this chapter inherits from the log.

## PAGE 01
PANEL 1 [big]: Camera + action description, present tense, concrete.
- CAPTION: CHAPTER 4 — TITLE HERE
- (Renka): "SHORT LINE HERE."
- (Renka, thought): "PRIVATE REACTION."
- (Renka, aside): so heavy...
- SFX: GACHA (kachak)
PANEL 2 [small]: ...
- (Sou): "REPLY, 4-8 WORDS."
...

## PAGE 13 — SPLASH
PANEL 1 [splash]: ...
- (Renka): "..."

## CONTINUITY NOTES
- New facts established / promises made / props introduced / relationship deltas.
```

Rules:
- Page headers exactly `## PAGE NN` (two digits), splash `## PAGE NN — SPLASH`.
- Panel lines start `PANEL k [size]` with size ∈ `big | wide | tall | small | splash`; append `[CHIBI]` for chibi panels.
- Dialogue lines: `- (Name): "UPPERCASE TEXT."` · thought: `- (Name, thought):` · aside: `- (Name, aside): lowercase mutter` · `- SFX: ROMAJI (translation)` · `- CAPTION: TEXT`.
- Speaker names must match `bible/cast.md`. Voices must match each character's sample lines.
- End with `## CONTINUITY NOTES` — publish appends these to the log.

## Lint (mechanical, before any drawing)

`pwsh scripts/lint-breakdown.ps1 -Chapter N` checks: page count ≥25; per-page bubble count 11-15 (splash 4-7); at least 16 total text beats on normal pages; no page with 0 bubbles; bubble word count ≤8; panel count 5-9 per page (splash 1); exactly one splash; ≥3 chibi panels; CONTINUITY NOTES present. Violations go back to the writer; drawing never starts on a failing breakdown.

## Calibration gate (every chapter, before the full draw)

Do NOT generate 25 pages and then judge. Generate TWO:
1. **Page 1**, and **the densest mid-chapter conversation page** (most bubbles). The conversation page is the real gate — page 1 alone cannot show whether dialogue density renders right.
2. OPEN the two files and **COUNT**: panels (must match the script ±1), speech/thought balloons (**≥11 and every scripted balloon present**), total readable text beats (**≥16**), and panels containing a human face (all panels, or all-but-one). Confirm portrait ratio, B&W, visible dot screentone, irregular manga composition, and at least three distinct lettering treatments.
3. **Zero bubbles or zero faces is a failure to fix, not a variation to report.** Adjust the page prompt emphasis and redraw until both pages pass, then draw the rest.

## Cover (after the chapter's pages exist)

One per chapter. Use the page-prompt template with the COVER OVERRIDE block from `engine/art-spec.md`: both leads split down the middle between public and private selves, one continuous split line passing through both figures, ~40% white, series title + chapter number lettered on. Output `cover.png` → published as `cover.jpg`.

The writer MAY include a `## COVER NOTES` section (2-3 lines of chapter-specific imagery — props, outfits, season) right before CONTINUITY NOTES; the prompt builder folds it into the cover call.

## Continuity

- The writer reads `continuity/log.md` IN FULL before writing; nothing may contradict it.
- CONTINUITY IS A FILE, NEVER A CONTEXT WINDOW. Every cycle starts cold from bible + log + manifest.
- Publish appends the breakdown's CONTINUITY NOTES to the log with date + chapter number.
- The series is STRICTLY 55 chapters, one complete story. At each arc boundary (ch 12, 23, 34, 45) the writer FIRST expands the next arc's chapters into full rows in `bible/arc.md` (same format as arc 1, consistent with the locked milestones), then writes the chapter. After chapter 55 publishes, production stops: the story is over.
