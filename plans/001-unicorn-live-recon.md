# Plan 001: Install Unicorn in the dev game and produce GO/NO-GO live findings

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat b20a368..HEAD -- ../archive/research/RESEARCH_UNICORN_INTEGRATION.md`
> If the research doc changed since this plan was written, re-check that the
> open questions in section 7 are still the ones listed below.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW (no repo code changes; game-install file copies only)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `b20a368`, 2026-11-15

## Why this matters

Every downstream plan depends on facts only a running game can answer: does a
noble-rig companion (Anna Henrietta / Vivienne / Orianna) pass
`ValidateActor` AND undress correctly; do Unicorn threads set any of the
scene-playing flags our tick relies on; does `modUnicornBody` fight our
`MCME_AR_FemaleAppearancePack`; does `unicorn.dll` survive our TW3SE build.
Skipping this recon means building the bridge on guesses.

## Current state

- Unicorn package (NOT yet installed) lives at
  `G:\GOG Galaxy\Games\The Witcher 3 Wild Hunt GOTY\!Downloads\unicorn`:
  - `Mods\modUnicornCore`, `Mods\modUnicornBody`, `Mods\modUnicornBillyy`,
    `Mods\modUnicornPlayer`
  - `dlc\dlcunicornbillyy`
  - `bin\x64_dx12\tw3se\plugins\unicorn.dll` and
    `bin\x64_dx12\tw3se\plugins\unicorn\*.bin`
  - `bin\x64_dx12\tw3se\unicorn\mouth\*.twdf` (~70 NPC mouth maps)
- Target install root = the game dir:
  `G:\GOG Galaxy\Games\The Witcher 3 Wild Hunt GOTY` (dev environment, TW3SE
  already installed for this mod's dev layer).
- Requirements: **DX12/NextGen build only**, TW3SE **>= 1.3.3**
  (`modUnicornBody` README). If dev TW3SE is older → STOP.
- Our mod is already installed via NTFS junction
  `Mods\modMCME_AutonomousRomance` → `repo\Mods\modMCME_AutonomousRomance`.
- `MCM_AR_FemaleAppearancePack` (our bodypack) and `modUnicornBody` both
  override bare-body/naked resources — load-order conflict is expected and
  must be observed, not assumed.
- Dev console commands provided by Unicorn (`unicorn_commands.ws`):
  `uc_status()`, `uc_scenes(tags)`, `uc_start(tags)`, `uc_listen()`.
- Stability switches in `bin\config\r4game\user_config_matrix\pc\` /
  `tw3se.config` style keys (`unicorn_part_*`, `unicorn_blendshapes`,
  `unicorn_hook_observe`) — check `Mods\modUnicornCore\tw3se\init.lua`
  around lines 137–148 for exact key names before enabling.

## Commands you will need

| Purpose            | Command / tool                                                                 | Expected on success |
|--------------------|--------------------------------------------------------------------------------|---------------------|
| TW3SE version      | `tw3se_pipe.ps1 -Cmd "exec TW3SE_GetVersion()"` or check `tw3se.log` header      | version >= 1.3.3    |
| Mod presence       | in-game console `~` → `uc_status()`                                            | prints version, scene count >0 |
| Scene list         | `uc_scenes(Vaginal)`                                                           | non-empty scene names |
| Scene start        | `uc_start(Loving,-Aggressive)` near a companion                                | live scene starts   |
| Event log          | `uc_listen()`                                                                  | events print to console |
| Our mod sanity     | `tw3se_pipe.ps1 -Cmd "exec ar_status()"`                                       | normal [AR] status output |

## Scope

**In scope** (the only things you may change):
- Copy Unicorn files from `!Downloads\unicorn` into the game dirs listed above.
- `tw3se.config` / config keys needed to enable Unicorn safely (document each
  key you set in the findings doc).
- Create the findings report:
  `_ModDev\MCME_AutonomousRomance\_work\research\unicorn_f0_findings.md`.

**Out of scope** (do NOT touch):
- Any `.ws` file in `repo\Mods` — zero code changes in this plan.
- `Mods\modMCME_AutonomousRomance` contents (junction → repo).
- `modUnicornBody` load-order experiments must be reversible — do not delete
  our bodypack files; toggle via mod management, not deletion.
- `.env` files anywhere (hard ban).

## Git workflow

- No code changes → no branch needed. The findings doc lands in
  `_work\research\` which is outside `repo\` (not versioned).
- Do NOT commit anything as part of this plan.

## Steps

### Step 1: Preconditions

1. Confirm game build is NextGen/DX12 (`bin\x64_dx12\witcher3.exe` exists —
   it does; verify we launch dx12 variant).
2. Confirm TW3SE >= 1.3.3 (check `tw3se\` dir / `tw3se.log` header on launch).
3. Backup: note which files Unicorn adds vs overwrites. `modUnicornBody`
   overwrites `hud_wolfstatbars.redswf`-related resources and bare-body
   meshes — record a list so uninstall is possible.

**Verify**: `Get-ChildItem "bin\x64_dx12\witcher3.exe", "tw3se"` → both exist.

### Step 2: Install

Copy per-component: `Mods\*` → `Mods\`, `dlc\*` → `dlc\`,
`bin\x64_dx12\tw3se\plugins\*` → same relative target. Do NOT copy the
`Unicorn docs` or `tools` folders into the game dir.

**Verify**: `uc_status()` in console prints framework version and
`GetSceneCount()` > 0 (proves dll + core + Billyy pack all loaded).

### Step 3: Core validation matrix (companions)

With an MCME companion spawned nearby (use existing `ar_status()` to confirm
roster), run for each of: a `woman_base` companion (e.g. Triss or Shani) and
each noble rig (`anarietta`, `vivienne`, `oriana`):

1. `uc_start(Vaginal,-Forced)` near the companion → does a scene start?
2. Watch undress: does the NPC actually undress (BODY mapping) or stay
   clothed? Note per companion.
3. Watch anim fit: limbs aligned, no floating/T-pose, penetration solver
   engaged? Note per companion.
4. `uc_listen()` output for our actor names.

**Verify**: results table filled for >= 1 woman_base + 3 noble NPCs.

### Step 4: Busy-flag probe (mutual exclusion evidence)

During a running Unicorn scene, check via TW3SE bridge/console whether:
- `theGame.IsDialogOrCutscenePlaying()` returns true (expected: NO per research).
- `thePlayer.IsInGameplayScene()` or equivalent flags change.
- Our `ar_status()` during the scene: does our tick consider itself free?

**Verify**: findings doc states explicitly which flags Unicorn sets (if any)
— this decides the exact shape of the busy-gate fact in plan 002.

### Step 5: Bodypack / HUD load-order check

1. With `modUnicornBody` + `MCME_AR_FemaleAppearancePack` both installed:
   load a save, undress via scene, inspect which meshes/body win (ours or
   Unicorn's). Note artifacts (missing vulva/anatomy, texture seams).
2. Check HUD: is the wolf stat-bar / lust meter `mcLustBar` visible and does
   it clash with our HUD mods?

**Verify**: findings doc names the winning mod and visible artifacts (or
"no conflict observed").

### Step 6: Lifecycle checks

1. `uc_start(...)` → let scene end naturally → confirm actors redress and AI
   resumes (follow state intact for our companion).
2. `uc_start(...)` → `End` key / `uc_` stop → same check on interrupted scene.
3. Save during scene → reload → state sane? (`ar_status`, no orphan facts.)
4. `IsReady()` timing: after fresh save-load, `uc_status()` immediately —
   how soon is the Lua core answering?

**Verify**: each item gets PASS/FAIL + one-line evidence in findings doc.

## Test plan

This plan IS the test. Deliverable = findings doc
`_work\research\unicorn_f0_findings.md` containing:

- Answers to research §7 open questions 1–7 (verdict + evidence each).
- Validation matrix table (step 3).
- Busy-flags observation (step 4).
- Load-order verdict (step 5).
- Lifecycle results (step 6).
- Final **GO / CONDITIONAL-GO / NO-GO** recommendation with rationale.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `unicorn_f0_findings.md` exists under `_work\research\` and answers all
      7 open questions from `RESEARCH_UNICORN_INTEGRATION.md` §7.
- [ ] Validation matrix covers ≥1 `woman_base` + all 3 noble companions.
- [ ] Busy-flag section states observed facts (not "should").
- [ ] GO/CONDITIONAL-GO/NO-GO verdict stated at top of doc.
- [ ] `git status` inside `repo` shows zero modified files.
- [ ] `plans/README.md` status row updated.

## STOP conditions

Stop and report back (do not improvise) if:

- TW3SE < 1.3.3 or game runs DX11 — Unicorn cannot function; report NO-GO.
- `unicorn.dll` crashes the game on boot twice in a row — report with the
  crash context; do not start disabling random `unicorn_*` flags.
- `uc_start()` on a `woman_base` companion fails to produce any scene after
  three attempts in different locations — likely integration dead-end;
  report before continuing.
- Any step would require editing a `.ws` file — that is plan 002+, not here.

## Maintenance notes

- Keep the installed Unicorn files after the plan — plans 002–005 need them.
- If `modUnicornBody` conflicts with our bodypack, the resolution belongs to
  a compat note + documentation, not to this recon.
- Findings doc feeds plan 002's "escape hatches" — quote it, don't paraphrase.
