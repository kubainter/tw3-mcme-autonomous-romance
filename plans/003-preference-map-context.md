# Plan 003: Full per-NPC tag map, scene context and anti-repeat for the Unicorn bridge

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat b20a368..HEAD -- Mods/modMCME_AR_Unicorn/ Mods/modMCME_AutonomousRomance/content/scripts/local/romance/`
>
> **Prerequisite**: `plans/002-bridge-mod-skeleton.md` DONE — bridge
> compiles, dispatches with fallback, busy-gate works.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW (bridge-internal changes only)
- **Depends on**: plans/002-bridge-mod-skeleton.md
- **Category**: direction
- **Planned at**: commit `b20a368`, 2026-11-15

## Why this matters

Plan 002 ships a generic `Vaginal,-Forced` dispatch. This plan makes it
feel designed: Cerys gets rough-leaning scenes, Yennefer dominant, Triss
loving — the user-facing promise of the integration. It also adds the
context layer (NaughtyPoint→Bed, campfire→no-furniture), anti-repeat via
`ScenesFor`/`StartSceneEx`, undress fixes via `SetNudeAppearance`, and the
world-effect switches (`npc_reactions` off) that keep scenes private.

## Current state

- Bridge file from plan 002: `Mods\modMCME_AR_Unicorn\content\scripts\local\MCM_AR_Unicorn.ws`
  — dispatch wraps `PlayIntimateScene`, tag string currently hardcoded
  `"Vaginal,-Forced"`.
- Roster to map: every `woman_base` companion (rig check + noble blacklist
  in `IsWomanBaseCompanion`, `MCM_RomanceInteraction.ws` L219–233). Noble
  trio handled per F0 findings (undress result).
- Billyy pack tag inventory (from `dlcunicornbillyy_unicorn.ws`,
  ~55 scenes/260 stages): `Vaginal` ~8, `Anal` ~21, `Oral`/`Blowjob` ~6,
  `Cunnilingus`, `LeadIn`/`Foreplay` ~12, `FootJob`, `BoobJob`, `ThighJob`;
  mood `Loving`, `Dominant`, `Aggressive`, `Bound`, `Teasing`, `Missionary`;
  furniture `Bed`, `Chair`, `Table`, `Bench`, `Wall`, `Furniture`, `XCross`,
  `Yoke`. ALL scenes are MF, roles `[1,0]` — no solo/FF/group.
- Scene-context marker: `t.AddContext('mcme_ar')` already set; scenes can
  be filtered with `!ctx` in queries if needed.
- Verified API additions (`unicorn_api.ws`):
  `ScenesFor(list, tags) : array<name>` (L178),
  `StartSceneEx(list, sceneIds : array<name>, ...)` (L192),
  `SetPreference(actor, tag : string, weight : float)` (L464 — enjoyment
  multiplier ~0.1–3×, NOT selection),
  `SetNudeAppearance(template : string, appearance : name, nude : name)` (L710),
  `SetEffectEnabled(effect : name, on : bool)` (L494),
  `ForbidActor(actor, forbid)` (L626).
- Tag grammar: `A` required · `-A` excluded · `~A,~B` at-least-one · `!ctx`
  exclude by context word.
- Anti-repeat stamp pattern already exists in base mod (scene stamps per
  `nam`+tier — reuse the same fact naming, e.g. `mcme_ar_uc_lastscene_<nam>`).

## Commands you will need

Same as plan 002: `precheck_syntax.ps1`, `test_compile.ps1`,
`tw3se_pipe.ps1 -Cmd "exec ar_uc_eval()"`, `ar_eval()`, live `ar_intimate`.

## Scope

**In scope**:
- `Mods\modMCME_AR_Unicorn\content\scripts\local\MCM_AR_Unicorn.ws` — all changes.
- `Mods\modMCME_AR_Unicorn\bin\config\r4game\user_config_matrix\pc\modMCME_AR_Unicorn.xml` — new MCM vars.
- `repo\CHANGELOG.md` — one line.

**Out of scope**:
- Base-mod `.ws` files (the bridge reads `IsWomanBaseCompanion`, `IsOnNaughtyPoint`,
  `IsCiriAdultMode` as public API — do not modify them).
- Voice packs, `PlayLine`, hint suppression, cinematic lead-in — plan 004.
- `RegisterPacks`/custom scenes — plan 005.

## Git workflow

- Branch: `advisor/003-unicorn-preferences`. Conventional commits,
  e.g. `feat(unicorn): per-NPC tag preferences and scene context`.
- Do NOT push or PR unless instructed.

## Steps

### Step 1: `MCM_AR_UcTagsForNpc(nm : name) : string`

A data-driven map (array of pairs or a `switch` keyed on `StrLower(NameToString(nm))`)
producing the per-NPC tag query. Seed values from research §2.3 (tune in
live tests):

| nam | tag string |
|---|---|
| default (any `woman_base`) | `Vaginal,~Loving,-Forced,-Humiliation` |
| `cerys` / `becca` | `Vaginal,~Aggressive,~Dominant,-Forced` |
| `yennefer` / `yen` | `~Dominant,-Humiliation,-Forced` |
| `triss` | `~Loving,-Aggressive,-Bound,-Forced` |
| `keira` | `~Teasing,~Loving,-Forced` |
| `philippa` | `~Dominant,-Forced` |
| `shani` | `~Loving,~Missionary,-Forced` |
| `priscilla`/`pryscilla` | `~Loving,-Forced` |

Gate `Aggressive`/`Bound`/`Yoke` tags behind MCM var `AllowRough` — when
off, append `,-Aggressive,-Bound,-Yoke` to every query. ALWAYS include
`-Forced,-Humiliation` for romance scenes.

**Verify**: `ar_uc_eval()` prints each live companion's query string and
`ScenesFor` count > 0 for every mapped NPC.

### Step 2: Furniture/context resolution

`MCM_AR_UcContextFor() : int/string pair` —
- `IsOnNaughtyPoint()` → `furniture=2`, append `,~Bed` to query; pass the
  point's pos/rot to `t.Relocate` (verify `mod_scm_NaughtyPoint` field names
  during implementation — if inaccessible, `where=NULL` and rely on
  `UnicornFreeSpot`).
- Outdoor/campfire (not on point) → `furniture=1`, exclude furniture tags
  (`,-Bed,-Chair,-Table,-Yoke,-XCross`).
- Noble per F0: if noble undress worked → same rules; if not → route to
  `wrappedMethod` (`naughty\*` scenes) — encode in the map, not hardcoded.

**Verify**: live — `ar_intimate` at NaughtyPoint starts a `Bed`-tagged scene
(check `uc_listen` stage names); at campfire starts a non-furniture scene.

### Step 3: Anti-repeat + `StartSceneEx`

Before `StartScene`: call `ScenesFor(actors, tags)` → filter out scene
names recorded in `mcme_ar_uc_lastscene_<nam>` facts (keep last 2–3) →
if empty, clear the fact and reuse full pool → pick deterministically
(`StartSceneEx` with the filtered list so OUR randomness, not Unicorn's,
decides — log the pick).

**Verify**: run `ar_intimate` 4× for one NPC → log shows different scene
names until pool exhausted, then reset without repeat of the immediate last.

### Step 4: NPC enjoyment preferences + nude mapping + forbidden actors

- `u.SetPreference(npc, '<dominant tag from map>', 0.8)` once per session per
  NPC (enjoyment multiplier; safe to repeat — idempotent set).
- `u.SetNudeAppearance(templateStr, currentApp, nudeApp)` for companions whose
  upstream `nakedAppearance` is broken (our T17 issue) and for noble NPCs if
  F0 showed undress failure but anims fit — register at bridge init for the
  known roster; data-driven table `nam → nude appearance name` (fill values
  from our bodypack manifest `BODYPACK_MANIFEST.md` / companion templates).
- Ciri: bridge calls `ForbidActor` unless `IsCiriAdultMode()` — double-gate
  behind our own `nm=='ciri'` check anyway.

**Verify**: live — Cerys scene shows higher enjoyment curve (`uc_listen`
arousal/enjoyment events); noble companion (if mapped) actually undresses.

### Step 5: Effect switches at init

In bridge init (first `StartScene` gate or `OnGameStart`): 
`u.SetEffectEnabled('npc_reactions', false)` — no guard attacks during
private scenes; `u.SetEffectEnabled('stats', false)` — arousal must not
combat-slow companions; log each switch. `dreams`/`monologue` leave ON
(downtime synergy is plan 004+ but harmless now).

**Verify**: `uc_status()`/log shows switches applied once; NPC near scene
does not aggro.

## Test plan

- `precheck_syntax.ps1` → PASS; `test_compile.ps1 -TimeoutSeconds 60` → 0.
- `ar_uc_eval()` table: every live companion shows its tag string + scenes
  count; noble rows show intended routing (Unicorn vs native).
- Live matrix (≥4 NPCs incl. Cerys): scene started matches map mood
  (`uc_listen` stage/scene name check), `AllowRough=0` forces the safe pool.
- Anti-repeat: 4 scenes on one NPC → distinct names in log.
- `test_e2e.ps1` → base 103 assertions still pass.

## Done criteria

- [ ] `MCM_AR_UcTagsForNpc` covers every `woman_base` roster `nam` + default.
- [ ] `AllowRough` MCM var exists and gates rough tags.
- [ ] NaughtyPoint→`furniture=2`/`Bed`/`Relocate` wired; campfire→`furniture=1`.
- [ ] Anti-repeat via `ScenesFor`+`StartSceneEx` demonstrably cycles scenes.
- [ ] `SetNudeAppearance` table exists (even if only noble needs entries).
- [ ] `npc_reactions` + `stats` disabled at init; logged.
- [ ] `precheck`/`test_compile`/`test_e2e` all green.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- `ScenesFor` returns empty for ALL mapped NPCs (pack not registering or
  tag grammar wrong) — verify against `uc_scenes()` output; if the pack
  itself is broken, report rather than loosening tags to "match anything".
- Noble undress fix via `SetNudeAppearance` cannot be expressed (no nude
  appearance exists for the template) — report; noble stays on native path.
- `mod_scm_NaughtyPoint` exposes no position data at all — report; keep
  `UnicornFreeSpot` placement and note it in findings.
- Any requirement needs base-mod `.ws` edits beyond reading existing public
  functions — report; do not edit.

## Maintenance notes

- Tag map is DATA — new companions join by adding a row; keep alphabetical
  order for diffs.
- `SetPreference` weights are session-volatile; if Unicorn persists them,
  revisit to avoid compounding (check on save/load).
- When plan 004 adds cinematic lead-in, `CinematicIntro` MCM var already
  reserved in bridge xml — wire it there.
