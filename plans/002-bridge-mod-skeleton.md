# Plan 002: Create optional bridge mod `modMCME_AR_Unicorn` with fallback dispatch

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat b20a368..HEAD -- Mods/modMCME_AutonomousRomance/content/scripts/local/romance/`
> If any romance `.ws` changed since this plan was written, compare the
> "Current state" excerpts against live code; on mismatch, treat as STOP.
>
> **Prerequisite**: `plans/001-unicorn-live-recon.md` DONE with GO or
> CONDITIONAL-GO, and
> `_work\research\unicorn_f0_findings.md` present. Read it first — the
> busy-flag section decides Step 5's shape.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED (new mod package + a 3-line guarded change in the base mod)
- **Depends on**: plans/001-unicorn-live-recon.md
- **Category**: direction
- **Planned at**: commit `b20a368`, 2026-11-15

## Why this matters

WitcherScript resolves symbols at compile time: any reference to `CUnicorn`,
`UnicornGet()`, or `CUnicornListener` inside `modMCME_AutonomousRomance`
makes the base mod unlaunchable for users without Unicorn. The only safe
shape is a **separate optional mod** that owns all Unicorn references and
wraps `PlayIntimateScene` — every failure path must fall through to
`wrappedMethod()`, preserving today's `.w2scene` behavior exactly.

## Current state

### Call chain being wrapped (verified)

`Mods\modMCME_AutonomousRomance\content\scripts\local\romance\MCM_RomanceInteraction.ws`:

```ws
// L2184
public latent function PlayIntimateScene(npc : CNewNPC) : bool
{
    if (!thePlayer || !npc || !npc.scmcc || !npc.scmcc.data) return false;
    nm = npc.scmcc.data.nam;
    dialogueFree = WaitForDialogueFree(25.0);
    if (!dialogueFree) { ... return false; }
    scm = mod_scm_GetSCM(); mcm = MCM_GetMCM();
    if (!scm || !mcm || !scm.NaughtyManager || !scm.NaughtyManager.naughtyPoints)
    { ... return false; }
    path = ResolveIntimateScenePath(npc);          // L1933
    if (path == "") { ... return false; }
    ... // NaughtyPoint <=20m gate, LoadResource, HideActorWeapons,
        // appearance strip, PlayScene + WaitForSceneEnd, cleanup, affinity
}
```

- Consent (`ApproachAndConsent` L1368, `[C]`/`SwordSheathe`) happens BEFORE
  `PlayIntimateScene` — the bridge never re-asks consent; it only dispatches.
- `IsOnNaughtyPoint()` L2013: 16m eligibility gate via
  `scm.NaughtyManager.naughtyPoints.GetClosestPoint(16.0)`;
  `PlayIntimateScene` re-checks at 20m (`GetClosestPoint(20.0)`, L2270).
- `IsWomanBaseCompanion()` L219–233: `woman_base` rig check + hardcoded noble
  blacklist (`anarietta/anna_henrietta/anna/vivienne/sq701_vivienne/oriana/
  orianna/vampire_diva/anabelle`).
- Busy gate to extend: `MCM_RomanceCore.ws` L2027
  `public function IsStagedBusy() : bool` — add a `FactsQuerySum` check.
- Affinity bookkeeping hook: `MCM_AR_GetAffinity().AddAffinityPoints(nm, int)`
  (`MCM_RomanceAffinity.ws` L383; used e.g. `MCM_RomanceCore.ws` L3068).
- Config pattern to copy: `MCM_AR_ConfigWrapper`
  (`MCM_RomanceAffinity.ws` L9–50) reads `user.settings` via
  `theGame.GetInGameConfigWrapper().GetVarValue(group, var_)` with defaults.
- MCM xml exemplar: `repo\bin\config\r4game\user_config_matrix\pc\modMCME_AutonomousRomance.xml` (group `MCM_AR`).
- dev/stub pattern exemplar (for file structure only):
  `MCM_RomanceTw3seDev.ws` + `MCM_RomanceTw3seDev.stub.ws`.

### Unicorn API surface to use (verified signatures, `unicorn_api.ws`)

```ws
u = UnicornGet()                                   // : CUnicorn (lazy singleton)
u.IsReady() : bool                                 // L142
u.GetSceneCount() : int                            // L166
u.ValidateActor(actor : CActor) : EUnicornValidation // L614; UV_Valid==1
t = u.StartScene(list, tags, optional hook : name, // L188 — returns
                 optional where : CNode,           //        CUnicornThread or NULL
                 optional furniture : int)         // 0=allowed 1=never 2=preferred
u.AddListener(listener : CUnicornListener, hook)   // L268 — hook filters events
t.SetConsent(true); t.AddContext('mcme_ar');       // L985 / L967
t.SetAuto(true);                                   // L1009 — suppress Num hints
t.Relocate(pos : Vector, rot : EulerAngles)        // L1039
t.IsLive() : bool                                  // L805
u.SetEffectEnabled('npc_reactions', false)         // L494 — call once
u.ForbidActor(cirillaActor, true)                  // L626 — Lore mode defense
```

Tag query grammar: `Vaginal` required, `-Aggressive` excluded,
`~A,~B` at-least-one, `!ctx` context exclusion. `ScenesFor(list, tags) :
array<name>` = dry-run of the same pool (L178).

### Hard constraints (AGENTS.md §3 + research)

- `@wrapMethod` on `event`-signature methods must NOT declare a return type;
  `PlayIntimateScene` is a `latent function : bool` → the wrapper must also be
  `latent` and keep `: bool`.
- Latent calls are forbidden inside `if (...)` conditions — assign first,
  branch on the variable.
- No `StringToName` — compare via `StrLower(NameToString(nam))`.
- Never wrap Unicorn's own methods in this plan (shadowing risk) — only OUR
  `MCM_RomanceInteraction.PlayIntimateScene`.
- Ciri: `IsCiriAdultMode()` gate must run BEFORE `StartScene`
  (`nm == 'cirilla'`/'ciri' check, see `MCM_AR_Generic_CiriAction` pattern).

## Commands you will need

| Purpose     | Command                                                                                  | Expected         |
|-------------|------------------------------------------------------------------------------------------|------------------|
| Syntax pre-check | `powershell -NoProfile -ExecutionPolicy Bypass -File "_ModDev\MCME_AutonomousRomance\scripts\precheck_syntax.ps1"` | PASS, no errors |
| Engine compile   | `powershell -NoProfile -ExecutionPolicy Bypass -File "_ModDev\MCME_AutonomousRomance\scripts\test_compile.ps1" -TimeoutSeconds 60` | ExitCode 0 |
| Live status      | `tw3se_pipe.ps1 -Cmd "exec ar_uc_status()"`                                              | prints bridge status block |
| Live fallback    | trigger `ar_intimate` with bridge MCM `Mode=0`                                           | vanilla `.w2scene` plays |

## Scope

**In scope** (the only files you may create/modify):
- `repo\Mods\modMCME_AR_Unicorn\` — new package:
  - `content\scripts\local\MCM_AR_Unicorn.ws` (all Unicorn references)
  - `bin\config\r4game\user_config_matrix\pc\modMCME_AR_Unicorn.xml`
- `repo\Mods\modMCME_AutonomousRomance\content\scripts\local\romance\MCM_RomanceCore.ws`
  — ONLY the `IsStagedBusy()` addition described in Step 5 (fact check, no
  Unicorn symbols).
- `repo\CHANGELOG.md` — one line under Unreleased, if the repo keeps one.

**Out of scope**:
- Any other `.ws` in the base mod (dispatch/preference details = plan 003).
- `PlayIntimateScene` internals themselves — we wrap, we don't edit.
- Release packaging (`package_release.ps1` bridge staging) — separate task.
- `tw3se\init.lua` for the bridge — plan 004 (hint suppression) if needed.
- `.w2anims`/scene assets, voice packs, `RegisterPacks` — plan 005.

## Git workflow

- Branch: `advisor/002-bridge-mod` (repo convention: `release/*` for
  releases; feature branches acceptable).
- Commit style: conventional commits seen in log (`feat(romance): ...`,
  `docs: ...`). Example: `feat(unicorn): optional bridge mod skeleton with
  PlayIntimateScene fallback dispatch`.
- Do NOT push or open a PR unless the operator instructs.

## Steps

### Step 1: Package skeleton

Create `Mods\modMCME_AR_Unicorn\` with the structure above (mirror the main
mod's layout). The mod has NO bundle — scripts compile from
`content\scripts\local`. MCM xml defines group `MCM_AR_Unicorn` with vars:
`Mode` (int: 0=off, 1=prefer-unicorn+fallback, 2=unicorn-only, 3=mix-random;
default 1), `AllowRough` (bool, default true).

**Verify**: `precheck_syntax.ps1` → PASS (new file must compile standalone).

### Step 2: `MCM_AR_Unicorn.ws` — config + status + busy flag

Functions:
- `MCM_AR_UcMode() : int` — config read, same wrapper pattern as
  `MCM_AR_ConfigWrapper.GetFloat` but for group `MCM_AR_Unicorn`.
- `MCM_AR_UcSceneActive() : bool` — `FactsQuerySum('mcme_ar_uc_active') > 0`.
- `exec function ar_uc_status()` — prints: bridge loaded, `UnicornGet()`!=NULL,
  `IsReady()`, `GetVersion()`, `GetSceneCount()`, current Mode.
- `exec function ar_uc_eval()` — for each live companion: `ValidateActor`
  result + `ScenesFor` count for its tag string (debug dry-run).

**Verify**: `test_compile.ps1 -TimeoutSeconds 60` → ExitCode 0 (proves
Unicorn symbols resolve — run with Unicorn installed).

### Step 3: Listener class + scene wait

```ws
class CMCMEARUnicornListener extends CUnicornListener
{
    function OnSceneEnd(actors : array<CActor>, hook : name) { /* step 6 */ }
}
```

Register once (lazily, on first successful StartScene, via
`u.AddListener(listener, 'MCME_AR')`; keep a module-level instance).
Wait loop: after `StartScene`, poll `t.IsLive()` in a `Sleep`-based latent
loop with timeout (mirror the existing `WaitForSceneEnd(90)` pattern in
`MCM_RomanceInteraction.ws`) — do NOT use `IsDialogOrCutscenePlaying`.

**Verify**: `test_compile.ps1` → ExitCode 0.

### Step 4: The wrap — dispatch with total fallback

```ws
@wrapMethod(MCM_RomanceInteraction) function PlayIntimateScene(npc : CNewNPC) : bool
{
    // order: mode gate → UnicornGet/IsReady/GetSceneCount →
    // IsWomanBaseCompanion-or-allowed-noble (see findings) → Ciri gate →
    // ValidateActor(npc)==UV_Valid → build tags (minimal: "Vaginal,-Forced"
    // for now; full map = plan 003) → StartScene({npc, thePlayer}, tags,
    // 'MCME_AR', NULL, furniture) → NULL? → wrappedMethod(npc)
    // success → consent/context/auto/Relocate → wait IsLive → true
}
```

Every `return` path that is not a successful Unicorn scene MUST end in
`return wrappedMethod(npc);` — the base `.w2scene` path is the fallback.
`furniture`: `2` when `IsOnNaughtyPoint()`, else `1` (campfire/outdoor);
`Relocate` to the NaughtyPoint when known (read `mod_scm_NaughtyPoint` fields
at implementation — class lives outside our `.ws` set; `GetClosestPoint`
returns it; if fields are inaccessible pass `NULL` where and let Unicorn
pick a `UnicornFreeSpot`).

**Verify**: `test_compile.ps1` → ExitCode 0. Live: `ar_intimate` at a
NaughtyPoint with `Mode=1` → Unicorn scene starts (`uc_listen` shows hook
`MCME_AR`); with `Mode=0` → native `.w2scene` plays.

### Step 5: Mutual busy-gate (base-mod change)

In `MCM_RomanceCore.ws` `IsStagedBusy()` (L2027), add the fact check so our
tick treats a live Unicorn scene as busy — base mod compiles for everyone
because it's a plain `FactsQuerySum`:

```ws
if (FactsQuerySum('mcme_ar_uc_active') > 0) return true;
```

Bridge sets `FactsSet('mcme_ar_uc_active', 1)` on `StartScene` success and
`FactsSet('mcme_ar_uc_active', 0)` (or `FactsRemove`) in `OnSceneEnd` +
timeout path. Also gate the other direction: before `StartScene`, require
`!IsStagedBusy()`.

**Verify**: `precheck_syntax.ps1` + `test_compile.ps1` → 0. Live: during a
Unicorn scene `ar_status()`/`ar_eval()` shows busy; `uc_start` during a
staged MCME action is refused by our gate.

### Step 6: Post-scene bookkeeping

In `OnSceneEnd` (hook `'MCME_AR'`): clear `mcme_ar_uc_active`, apply the
same post-scene bookkeeping the native path applies — affinity points via
`MCM_AR_GetAffinity().AddAffinityPoints(nm, <same amount as native T4>)`,
cooldown/`lastScene` stamps if the native path writes them (inspect
`PlayIntimateScene` tail ~L2450-2541 and mirror), `u.ModAffection(npc,
thePlayer, 5)`. Log `[AR] Unicorn scene end: <nm>`.

**Verify**: live — full cycle consent→scene→end restores follow state,
affinity increases once, cooldown stamps written, no double-undress
artifacts.

## Test plan

- `precheck_syntax.ps1` → PASS.
- `test_compile.ps1 -TimeoutSeconds 60` → ExitCode 0 **with** Unicorn
  installed. (Known limitation: without `modUnicornCore` the BRIDGE package
  fails compile by design — that is the fail-fast contract; base mod alone
  must still compile: run compile with bridge folder temporarily renamed
  and confirm base still builds.)
- Live: `ar_uc_status()` output sane; `ar_uc_eval()` lists companions.
- Live: `Mode=1` + NaughtyPoint → Unicorn scene; `Mode=0` → native scene;
  `Mode=1` + `ValidateActor` failure case (e.g. noble if F0 said fail) →
  native fallback automatically.
- Live: `ar_test_e2e()` (scripts/test_e2e.ps1) → existing 103 assertions
  still pass (base behavior unregressed).

## Done criteria

- [ ] `Mods\modMCME_AR_Unicorn\` exists with `.ws` + MCM xml; compiles.
- [ ] Every non-Unicorn path in the wrap ends in `wrappedMethod(npc)`.
- [ ] `IsStagedBusy` honors `mcme_ar_uc_active`; bridge sets/clears the fact.
- [ ] `test_compile.ps1` ExitCode 0; `precheck_syntax.ps1` PASS.
- [ ] `test_e2e.ps1` suite passes (no base regression).
- [ ] Live fallback demonstrated: `Mode=0` → `.w2scene` plays.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- F0 findings say NO-GO for `woman_base` validation — bridge has no viable
  target; report before writing dispatch.
- `PlayIntimateScene`'s signature or call-site changed (drift) — do not wrap
  a different method shape; report.
- A needed check requires referencing `CUnicorn` in the BASE mod — that
  breaks optionality; redesign the fact/flag instead.
- `@wrapMethod` on `PlayIntimateScene` conflicts with another installed mod
  wrapping it (shadowing) — report; do not try priority hacks.

## Maintenance notes

- When `PlayIntimateScene` grows new behavior (e.g. T16 pos save/restore),
  the Unicorn branch must mirror it — the wrap only dispatches, post-scene
  parity is manual.
- `mcme_ar_uc_active` fact is now a cross-mod contract: the base mod reads
  it, the bridge writes it. Renaming requires touching both packages.
- Noble-rig policy (allow list vs noble blacklist) comes from F0 findings —
  encode as data, not `if`-chains, so plan 003 can extend it.
