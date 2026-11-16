# Plan 004: Polish — voice packs, in-scene lines, hint suppression, cinematic lead-in experiment

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Prerequisite**: `plans/003-preference-map-context.md` DONE — dispatch,
> preference map and context layer all live-verified.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED (Lua handler override + a latent hybrid transition)
- **Depends on**: plans/003-preference-map-context.md
- **Category**: direction
- **Planned at**: commit `b20a368`, 2026-11-15

## Why this matters

Plan 003 makes scenes correct; this plan makes them feel like MCME:
character-true voices instead of generic body-fallbacks, our localized
w3strings lines during scenes, no Num-pad HUD noise, and an experiment to
recover the cinematic camera lead-in that vanilla `.w2scene` gave us. Each
step is independently shippable — do them in order, stop where value thins.

## Current state

- Bridge: `Mods\modMCME_AR_Unicorn\content\scripts\local\MCM_AR_Unicorn.ws`;
  listener `CMCMEARUnicornListener` registered under hook `'MCME_AR'` with
  `OnSceneEnd` doing bookkeeping.
- Verified API (`unicorn_api.ws`):
  `PlayLine(actor, stringId : int)` (L572) — any game line w/ lip sync;
  `AddSceneLines`/`AddMonologueLines`/`AddReactionLines` exist on `CUnicorn`;
  `SetActorExpression(actor, profile)`; `SetValue(actor,key,val)`/`GetValue`
  (L602/608, save-persistent); `OnMeditate` event (arousal≥70 → dream hook);
  `t.SetSpeed`, `t.SetAuto`.
- Voice pack pipeline: `tools\voice_pack.py` in the Unicorn download →
  produces `pack.lua` from WAV/OGG folders; resolution order
  actor > template > voicetag > body-fallback; slots breath/moan×3/climax/
  kiss/lines.
- Mouth/deform coverage (~70 NPCs in `bin\x64_dx12\tw3se\unicorn\mouth\`):
  triss, yen, keira, cerys, ciri, filippa, ves, priscilla, edna, fringilla,
  margaritta, iris, corine, anna_henrietta, vivienne, oriana… — MISSING:
  Salma, Rosa var Attre, Tomira, Jutta, Lady of the Lake, Lussi, Yoana
  (silent in scenes → note in docs).
- Num hints: `uc\controls.lua` shows StageStart hint text over player during
  scenes with player; `SetAuto(true)` mostly covers it; complete suppression
  needs `tw3se\init.lua` override of
  `UNICORN_LUA.handlers.StageStart["unicorn:controls"]` (bridge-side Lua,
  not base mod).
- Our localized lineIds live in `repo\...\w3strings.csv` set
  (`pl,en,de,es,esmx` only — Zero RU protocol).
- Cinematic lead-in assets: `trissFollowWithKiss.w2scene` (cleaned, in our
  blob0.bundle, tag `mcme_companion`) + kiss dispatch path `PlayKissScene`.

## Commands you will need

| Purpose     | Command / tool                                                     | Expected |
|-------------|--------------------------------------------------------------------|----------|
| Syntax      | `precheck_syntax.ps1`                                               | PASS     |
| Compile     | `test_compile.ps1 -TimeoutSeconds 60`                               | ExitCode 0 |
| Events      | `tw3se_pipe.ps1 -Cmd "exec uc_listen()"` + in-scene watch           | stage/orgasm events |
| Voice build | `python tools\voice_pack.py <folder>` (from `!Downloads\unicorn`)   | `pack.lua` out |

## Scope

**In scope**:
- `Mods\modMCME_AR_Unicorn\` — `.ws` additions, `tw3se\init.lua` (new),
  voice pack `pack.lua` files, MCM xml var `CinematicIntro`.
- `repo\CHANGELOG.md` — entries per shipped step.
- Optional new w3strings CSV rows for in-scene lines (canonical languages
  only).

**Out of scope**:
- Base-mod `.ws` edits — `PlayKissScene` is invoked, not modified.
- Generating/recording voice audio — executor wires the pipeline; audio
  assets are the operator's licensing responsibility (see STOP conditions).
- Motion/Conjunction toolchain work — that's plan 005 territory.
- Modifying `unicorn.dll`, `modUnicornCore` files, or Billyy packs — never.

## Git workflow

- Branch: `advisor/004-unicorn-polish`; conventional commits per step
  (`feat(unicorn): voice pack wiring`, `feat(unicorn): cinematic lead-in
  experiment`). No push/PR without instruction.

## Steps

### Step 1: Num-hint suppression via bridge `init.lua`

Create `Mods\modMCME_AR_Unicorn\tw3se\init.lua`: after core loads
(`w3.use("modUnicornCore")` in a deferred frame), replace
`UNICORN_LUA.handlers.StageStart["unicorn:controls"]` with a wrapper that
skips the hint when a thread has context `mcme_ar` (or unconditionally for
our hook). Keep `SetAuto(true)` as the primary behavior — Lua override is
belt-and-braces for the first stage before auto kicks in.

**Verify**: live scene — zero Num1-9 hint text above Geralt; `uc_listen`
still prints stage events (handlers intact).

### Step 2: In-scene localized lines

On `OnStageStart`/`OnOrgasmStart` (listener, hook-filtered): occasionally
`u.PlayLine(npc, <stringId>)` using EXISTING w3strings lineIds from our
CSV set (grep the CSVs for suitable intimate/bark ids — do not invent ids).
Rate-limit: max 1 line per stage, 30% probability — silence is fine.
Optional: `AddSceneLines` mapping for orgasm events.

**Verify**: live — an NPC line plays mid-scene with lip sync; ids resolve
in all 5 supported languages (check CSV presence, not playback ×5).

### Step 3: Voice pack wiring (assets-provided)

If the operator supplies licensed audio per companion: run
`tools\voice_pack.py` → drop `pack.lua` under
`Mods\modMCME_AR_Unicorn\tw3se\uc\voice\<key>.pack.lua` (check exact pack
path convention in `modUnicornCore` docs/GUIDE.md voice section before
writing). Register nothing else — Unicorn resolves packs itself by
actor/template/voicetag.

**Verify**: Triss scene uses Triss pack files (log/`uc_listen` shows pack
pick); NPCs without mouth-map stay silent (documented, acceptable).

### Step 4: Cinematic lead-in experiment (MCM `CinematicIntro`)

Hypothesis (unverified, that's why it's an experiment): play a short
`.w2scene` lead-in (our cleaned kiss scene or a dedicated intro) and call
`StartScene` while actors are positioned by the story-scene outro. Implement
behind `CinematicIntro` (0=off default):
1. In the bridge dispatch, when flag on AND `IsWomanBaseCompanion(npc)`:
   `PlayScene(npc, <leadin path>)` first, then `StartScene` immediately.
2. Measure: does Geralt's camera leave cinematic mode cleanly; do actors
   snap/drift between outro pose and Unicorn's first stage; does the story
   scene end handler fight `Relocate`?
3. If transition is jarring >acceptable, keep flag OFF in defaults and
   record findings — the experiment's value is the verdict either way.

**Verify**: record findings (smooth/acceptable/jarring + evidence notes)
into `_work\research\unicorn_f3_leadin.md`. If smooth → default the flag
on for `woman_base` only.

### Step 5: Downtime dream hook (optional, small)

`OnMeditate(arousal)` from Unicorn during our `ar_dt_meditation` channel:
when arousal≥70, log + optionally play a bark line via `PlayLine` on the
nearest companion (no scene start — just flavor). Wire `SetValue(npc,
'mcme_dreams', count)` for persistence testing.

**Verify**: meditate near companion at high arousal → event fires, bark
plays, `GetValue` round-trips across save/load.

## Test plan

- `precheck`/`test_compile` green after each step (bridge is `.ws` + Lua).
- Live per-step verifies listed above; `test_e2e.ps1` at the end for base
  regression.
- The lead-in experiment produces a written verdict file — it is the test.

## Done criteria

- [ ] `init.lua` suppresses Num hints (or documented why not needed).
- [ ] `PlayLine` fires on stage/orgasm events with real CSV ids.
- [ ] Voice pack convention documented; wiring verified with ≥1 provided pack
      (or step marked BLOCKED-awaiting-assets, not failed).
- [ ] `CinematicIntro` var exists; lead-in verdict doc written; default set
      by verdict.
- [ ] `test_e2e.ps1` green.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Lua handler replacement breaks `uc_listen`/stage flow — revert override;
  keep `SetAuto` only, report.
- Audio assets unlicensed — do NOT pull random game WAVs into the pack;
  mark the step BLOCKED for the operator.
- Lead-in experiment crashes or leaves actors in a broken state twice —
  abandon the hybrid (style C stays), record the failure modes.
- `PlayLine` ids missing from CSVs — create the rows in the canonical
  languages only; if translation bandwidth is zero, skip lines (feature
  is optional).

## Maintenance notes

- Voice packs are user-installed content — document folder layout in the
  bridge README; never bundle Unicorn/Billyy audio.
- The `StageStart` Lua override is version-fragile against Unicorn core
  updates — wrap in pcall, degrade silently.
- `CinematicIntro` verdict decides whether plan 005's Motion/Conjunction
  recon becomes urgent (full cinematic) or stays a nice-to-have.
