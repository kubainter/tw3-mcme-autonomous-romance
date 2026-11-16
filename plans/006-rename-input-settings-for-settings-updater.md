# Plan 006: Rename `MCME_AR.input.settings.txt` to `input.settings.txt` for Settings Updater compatibility

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat b20a368..HEAD -- Mods/modMCME_AutonomousRomance repo/README.md repo/ARCHITECTURE.md repo/CODEBASE.md`
> (run from `repo/`). If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: migration
- **Planned at**: commit `b20a368`, 2026-11-16
- **Related**: ticket `../Tickets/active/W3-TIK-021-sheathe-sword-mod-9257-settings-updater-swordsheathe-breakage.md` (this plan is its "Krok 3" packaging fix)

## Why this matters

The mod ships its input-bindings fragment as `MCME_AR.input.settings.txt` at the
mod root. Two mod managers scan mod roots for input fragments, and they disagree
on names:

- **Settings Updater** (Nexus 11421, native `.asi` plugin, required by popular
  mods like "Sheathe Sword" 9257) accepts ONLY the exact filenames
  `input.settings.txt` and `input.settings.part.txt` at the mod root — verified
  in its source (`_work/settings_updater_src/src/lib.rs`, `make_mod` ~lines
  268–271, outside this repo). Our prefixed name is silently ignored, so
  **Vortex + Settings Updater users never get `MCM_AR_Consent` bindings** and
  consent works only through the `SwordSheathe` fallback.
- **The Witcher 3 Mod Manager (W3MM, Systemcluster fork)** detects input
  fragments with the regex
  `.*input[.]?s(ettings)?([-_.].+)?(\.part)?(\.txt)?$` (IGNORECASE) at
  `w3modmanager/domain/mod/fetcher.py:448` — it matches BOTH the current name
  and plain `input.settings.txt` (source mirrored at
  `_work/w3mm_src/` for reference). Renaming loses nothing for W3MM users.

Rename is strictly safer than shipping both files (W3MM would detect both and
run identical `ConfigParser.set()` merges — harmless but pointless) and loses
no functionality for any installer path. Verified independently by a delegated
review (BoteX `mem_task_d1acfbb5_report`: all five claims CONFIRMED).

## Current state

Files and their roles:

- `Mods/modMCME_AutonomousRomance/MCME_AR.input.settings.txt` — the fragment
  itself: ~49 lines, sections `[Exploration]`, `[Combat]`, `[Horse]`, `[Boat]`,
  `[Swimming]`, `[BoatPassenger]`, `[Scene]`, `[ScriptedAction]`,
  `[SCENE_IS_STARTING_HACK]`, `[JumpClimb]`, `[Diving]`, `[ThrowHold]`,
  `[ThrowHoldChain]`, `[LootPopup]`, Ciri replacer contexts, etc.; each section
  holds `IK_C=(Action=MCM_AR_Consent)` + `IK_Pad_DigitLeft/Right=(Action=MCM_AR_Consent)`.
  **Content does NOT change in this plan — only the filename.**
- `Mods/modMCME_AutonomousRomance/` is an NTFS junction into this repo — edits
  here are live in the deployed game folder `Mods\modMCME_AutonomousRomance`.
- `scripts/package_release.ps1` (line ~37) copies the whole `Mods\` tree
  recursively into the release staging dir — **no filename whitelist**, the
  renamed file ships automatically. Line ~84 excludes only `*.bak`, `*.devbak`,
  `*.tmp`, `*~`, `*.csv`, `__folder_managed_by_vortex` — `.txt` is fine.

References to the old filename that MUST be updated (exact current text):

- `README.md:233` — `The mod also ships `Mods/modMCME_AutonomousRomance/MCME_AR.input.settings.txt` registering a dedicated `MCM_AR_Consent` action:`
- `Mods/modMCME_AutonomousRomance/README.txt:172` — `(MCME_AR.input.settings.txt) that registers a separate MCM_AR_Consent`
- `ARCHITECTURE.md:299` — `...zdefiniowaną w `MCME_AR.input.settings` pod klawisz [C]...` (internal doc; keep prose, fix filename)
- `CODEBASE.md:54` — `mapowanie w `MCME_AR.input.settings`)` (internal doc; fix filename)
- `../nexus/description.bbcode:228` — `([i]MCME_AR.input.settings.txt[/i])` and `:231` — `[i]Mods/modMCME_AutonomousRomance/MCME_AR.input.settings.txt[/i]` (public Nexus description, BBCode outside repo root — same release surface)

References that must NOT be touched:

- `CHANGELOG.md:146,157,308` — historical release notes describing past
  filenames; rewriting history is wrong. The rename gets its own entry at the
  next release (maintainer adds it per AGENTS.md changelog rules).

Conventions: docs are Markdown/BBCode, English in `README.md`/`description.bbcode`,
 Polish in `ARCHITECTURE.md`/`CODEBASE.md`/`README.txt` — match each file's
 existing language and tone. No code comments involved.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Repo root | `cd "G:\GOG Galaxy\Games\The Witcher 3 Wild Hunt GOTY\_ModDev\MCME_AutonomousRomance\repo"` | — |
| Rename | `git mv "Mods/modMCME_AutonomousRomance/MCME_AR.input.settings.txt" "Mods/modMCME_AutonomousRomance/input.settings.txt"` | exit 0, `git status` shows `R` rename |
| Old-name sweep | `grep -rn "MCME_AR\.input" .` (from repo root) | only `CHANGELOG.md` hits remain |
| New-name check | `ls "Mods/modMCME_AutonomousRomance/input.settings.txt"` | file exists |

## Scope

**In scope** (the only files you should modify):

- `Mods/modMCME_AutonomousRomance/MCME_AR.input.settings.txt` → rename to `input.settings.txt` (content byte-identical)
- `README.md` (one filename on line 233)
- `Mods/modMCME_AutonomousRomance/README.txt` (one filename on line 172)
- `ARCHITECTURE.md` (one filename on line 299)
- `CODEBASE.md` (one filename on line 54)
- `../nexus/description.bbcode` (two filename mentions, lines 228 and 231)

**Out of scope** (do NOT touch, even though they look related):

- `CHANGELOG.md` — historical entries stay verbatim; release notes are the maintainer's job at packaging time.
- The fragment's CONTENT (bindings, sections, keys) — a separate open question
  about `IK_C` overwriting vanilla `SwordSheathe` under W3MM's ConfigParser
  merge is tracked in `../Tickets/active/W3-TIK-021-*.md` and must NOT be
  "fixed" here.
- Any `.ws` file, `input.xml.txt` creation, `user.settings` files.
- `plans/README.md` index row update IS in scope (step 6).

## Git workflow

- Work directly on the current branch in `repo/` (no new branch — this is a
  small docs+rename change; repo convention is direct commits on the working
  branch, see `git log`).
- One commit for the whole change is fine. Message style from `git log`:
  short imperative subject, e.g. `Rename input fragment for Settings Updater compatibility`.
- Do NOT push. Do NOT commit `../nexus/description.bbcode` inside the repo —
  it lives outside the repo tree; edit it but leave it uncommitted (the nexus
  folder has its own lifecycle).

## Steps

### Step 1: Rename the fragment

```powershell
cd "G:\GOG Galaxy\Games\The Witcher 3 Wild Hunt GOTY\_ModDev\MCME_AutonomousRomance\repo"
git mv "Mods/modMCME_AutonomousRomance/MCME_AR.input.settings.txt" "Mods/modMCME_AutonomousRomance/input.settings.txt"
```

**Verify**: `git status --short` shows `R  Mods/modMCME_AutonomousRomance/MCME_AR.input.settings.txt -> Mods/modMCME_AutonomousRomance/input.settings.txt` and `ls "Mods/modMCME_AutonomousRomance/input.settings.txt"` prints the file.

### Step 2: Update `README.md`

On line 233 replace `MCME_AR.input.settings.txt` with `input.settings.txt`
(keep the rest of the sentence identical).

**Verify**: `grep -n "input.settings.txt" README.md` shows line ~233 with the new name; `grep -n "MCME_AR.input" README.md` returns nothing.

### Step 3: Update `Mods/modMCME_AutonomousRomance/README.txt`

On line 172 replace `(MCME_AR.input.settings.txt)` with `(input.settings.txt)`.

**Verify**: `grep -n "MCME_AR.input" "Mods/modMCME_AutonomousRomance/README.txt"` returns nothing.

### Step 4: Update internal docs `ARCHITECTURE.md` and `CODEBASE.md`

- `ARCHITECTURE.md:299`: change `` `MCME_AR.input.settings` `` to `` `input.settings.txt` `` (keep the Polish sentence otherwise intact).
- `CODEBASE.md:54`: change `` `MCME_AR.input.settings` `` to `` `input.settings.txt` ``.

**Verify**: `grep -rn "MCME_AR\.input" ARCHITECTURE.md CODEBASE.md` returns nothing.

### Step 5: Update `../nexus/description.bbcode`

- Line 228: `([i]MCME_AR.input.settings.txt[/i])` → `([i]input.settings.txt[/i])`
- Line 231: `[i]Mods/modMCME_AutonomousRomance/MCME_AR.input.settings.txt[/i]` → `[i]Mods/modMCME_AutonomousRomance/input.settings.txt[/i]`

**Verify**: `grep -n "MCME_AR.input" "../nexus/description.bbcode"` returns nothing.

### Step 6: Final sweep + index

Run from repo root: `grep -rn "MCME_AR\.input" .` — expected: ONLY hits inside `CHANGELOG.md` (historical, intentionally kept). Any other hit = STOP and report.

Then add a row to `plans/README.md` execution table:

`| 006  | Rename input fragment for Settings Updater | P2 | S | — | TODO |`

and a one-line note under Dependency notes: `006 is a packaging fix unrelated to the Unicorn series (tracked in Tickets/W3-TIK-021).`

**Verify**: the grep above; `git status --short` shows only the rename + the four doc edits inside `repo/` (description.bbcode is outside the repo and stays uncommitted).

## Test plan

No code changes — no unit tests apply. Verification is the grep sweep in step 6
plus a packaging sanity check:

- `powershell -NoProfile -ExecutionPolicy Bypass -File "G:\GOG Galaxy\Games\The Witcher 3 Wild Hunt GOTY\_ModDev\MCME_AutonomousRomance\scripts\package_release.ps1" -Version "vX.Y.Z"` is NOT required for this plan (run only at actual release time by the maintainer).
- Manual sanity: open `Mods/modMCME_AutonomousRomance/input.settings.txt` and confirm the first lines are still `IK_C=(Action=MCM_AR_Consent)` etc. (content unchanged).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `ls "Mods/modMCME_AutonomousRomance/input.settings.txt"` succeeds; `MCME_AR.input.settings.txt` no longer exists in the mod folder.
- [ ] `grep -rn "MCME_AR\.input" .` from repo root returns matches ONLY in `CHANGELOG.md`.
- [ ] `grep -n "MCME_AR.input" "../nexus/description.bbcode"` returns nothing.
- [ ] `git status --short` inside `repo/` shows the rename (`R`) and modifications only to `README.md`, `ARCHITECTURE.md`, `CODEBASE.md`, `Mods/modMCME_AutonomousRomance/README.txt`, `plans/README.md`.
- [ ] Fragment content unchanged: `git diff` on the renamed file shows rename only (no content edits) — `git show HEAD:"Mods/modMCME_AutonomousRomance/MCME_AR.input.settings.txt"` vs working file are identical.
- [ ] `plans/README.md` has the 006 row.

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows in-scope files changed since `b20a368` in ways that
  contradict the "Current state" excerpts.
- `git mv` fails because the target name already exists (someone renamed it
  already — verify state and report).
- The grep sweep finds `MCME_AR.input` references in files NOT listed in
  "Current state" (e.g. a script, `.github` workflow, or `nexus/` file we
  missed) — that means the reference map is incomplete; report the full list.
- You discover a tool that REQUIRES the `MCME_AR.` prefix (e.g. evidence that
  W3MM or another manager treats `input.settings.txt` differently from
  `*.input.settings.txt` in a harmful way) — the whole premise would be wrong.

## Maintenance notes

- After this lands and the mod is re-released, **Settings Updater users will
  start receiving `MCM_AR_Consent` bindings automatically** — consent prompts
  will show the dedicated action's glyph instead of relying on the
  `SwordSheathe` fallback. That is the intended improvement; if users report
  the consent key "changed", this is why.
- W3MM users updating the mod get a clean remove+add cycle (W3MM stores the
  detected `InputSettings` per mod and re-detects on update; content is
  identical so `input.settings` ends up unchanged).
- Vortex/manual users are unaffected — they merge file *contents*, not names.
- Deferred follow-up (do NOT do here): whether the fragment should keep
  binding `IK_C` at all, because W3MM's `ConfigParser.set()` merge overwrites
  vanilla `IK_C=(Action=SwordSheathe)` (consent works, C-sheathe dies for W3MM
  users — likely mechanism behind ticket W3-TIK-010). Tracked in
  `../Tickets/active/W3-TIK-021-*.md`.
- If a future `input.xml.txt` is ever added to expose `MCM_AR_Consent` in the
  keybindings menu, it is a separate change — Settings Updater accepts
  `input.xml.txt` at mod root too.
