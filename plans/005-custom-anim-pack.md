# Plan 005: Custom `.w2anims` scene pack registration + Motion/Conjunction recon

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Prerequisite**: `plans/002-bridge-mod-skeleton.md` DONE. Independent of
> 003/004 — can run in parallel with them.

## Status

- **Priority**: P3 (optional/stretch)
- **Effort**: L
- **Risk**: MED (binary asset pipeline + licensing gate, not code risk)
- **Depends on**: plans/002-bridge-mod-skeleton.md
- **Category**: direction
- **Planned at**: commit `b20a368`, 2026-11-15

## Why this matters

Unicorn's `RegisterPacks` extension point lets the bridge ship OUR OWN scene
pack — MCME-branded scenes built from converted or self-produced `.w2anims`
— without touching `modUnicornCore`. This is the endgame of the abandoned
"Etap D" custom-anim roadmap, now with a working runtime. Separately, a
Motion/Conjunction toolchain recon decides if full-cinematic Unicorn scenes
(camera tracks + live solver) are achievable — the "ścieżka B" answer.

## Current state

- Registration pattern (verified in `dlcunicornbillyy_unicorn.ws`, ~1537
  lines of registrations):
  - `@wrapMethod(CUnicorn) function RegisterPacks()` → call
    `wrappedMethod()`, then build scenes.
  - `sd = NewScene('mcme_scene_id', "Vaginal,Loving,...") : CUnicornSceneDef`
  - `sd.AddRole(sex)` per actor slot (packs are MF: `[1,0]`).
  - `sd.AddAnimSet("dlc\<dlcname>\data\animations\w3stage\<file>.w2anims")`
    — FIRST set added names the pack.
  - `sd.AddStage(id, seconds, animPerRole...)`; `sd.SetLoop(...)`;
    `sd.SetPenisAim(...)`; `sd.AddExit(from, to)`.
  - DLC mounts anim sets onto game figure lists; Unicorn mounts sets onto
    off-list entities for scene duration.
- `.w2anims` production: the gap. Options ranked by feasibility: (a)
  convert TGL clip sources with author's permission; (b) extract single
  animation tracks from vanilla `.w2anims` into a new pack via wcc/dingdio;
  (c) Blender → dingdio pipeline (research Etap D). None is pure-script
  work — each needs external tooling.
- Licensing gate (research R10): Unicorn code has NO explicit license;
  penis mesh CC BY-SA 4.0; face shapes MIT; Billyy scenes = LoversLab.
  Bridge may NOT bundle Unicorn/Billyy assets; our own pack needs either
  self-produced clips or written permission (Tenour for framework-side
  questions, Billyy only if reusing their clips).
- Motion/Conjunction: Unicorn docs mention quest scenes embedding Unicorn
  stages (`unicorn_quest.ws`, `IsExternal()` threads) — the toolchain to
  AUTHOR such scenes is NOT in the download package. Public availability
  unknown → recon item.
- Bridge home: `Mods\modMCME_AR_Unicorn` — pack registration lives in the
  same `MCM_AR_Unicorn.ws` (or a sibling `.ws` in the same mod).

## Commands you will need

| Purpose  | Command                                        | Expected    |
|----------|------------------------------------------------|-------------|
| Syntax   | `precheck_syntax.ps1`                           | PASS        |
| Compile  | `test_compile.ps1 -TimeoutSeconds 60`           | ExitCode 0  |
| Pack reg | in-game `uc_scenes()` / `ar_uc_eval()`          | our scene id listed |
| Scene    | `uc_start(<our scene tag>)` or `StartSceneEx`   | our scene plays |

## Scope

**In scope**:
- `Mods\modMCME_AR_Unicorn\content\scripts\local\MCM_AR_UnicornPacks.ws`
  (new — pack registration only).
- `Mods\modMCME_AR_Unicorn\tw3se\` — pack metadata if needed.
- `dlc\dlcMCME_AR_Unicorn\` — NEW dlc skeleton holding our `.w2anims`
  (created only when Step 4 produces clips).
- `_work\research\unicorn_motion_recon.md` — Motion/Conjunction findings.
- `repo\CHANGELOG.md`.

**Out of scope**:
- Anything under `!Downloads\unicorn\Mods\` or `dlc\dlcunicornbillyy` —
  never modify, never copy into our package.
- Blender/dingdio authoring itself — this plan wires registration; clip
  production is an operator/toolchain task.
- `.w2scene` authoring for Motion path — recon only.

## Git workflow

- Branch: `advisor/005-unicorn-pack`; commits `feat(unicorn): pack
  registration scaffold`, `docs(research): motion toolchain recon`.
- No push/PR without instruction.

## Steps

### Step 1: Registration scaffold (no assets yet)

`MCM_AR_UnicornPacks.ws`:

```ws
@wrapMethod(CUnicorn) function RegisterPacks()
{
    wrappedMethod();                     // Billyy + others register first
    MCM_AR_UcRegisterOurPack(this);      // global func in our file
}
```

`MCM_AR_UcRegisterOurPack(u : CUnicorn)` — guarded by a manifest table of
`(sceneId, tagString, animsetPath, stages[])`; iterate `u.NewScene(...)` etc.
Ship the table EMPTY first (zero scenes registered) — scaffold proves the
wrap point works without assets.

**Verify**: compile green; `uc_status()`/`uc_listen()` show `RegisterPacks`
ran; log line `[AR] Unicorn packs: 0 custom (scaffold)`.

### Step 2: Single proof scene with a borrowed-but-legal clip

Pick ONE animation already legally usable — best candidate: a vanilla game
`.w2anims` already loaded (e.g. an idle/embrace clip) referenced by path, or
a clip produced from our own existing scene assets. Register a 1-stage scene
`mcme_probe` tagged `~Loving` to prove end-to-end registration→selection→
playback.

**Verify**: `uc_scenes()` lists `mcme_probe`; `StartSceneEx` plays it
visually correct on two woman_base-compat actors.

### Step 3: Motion/Conjunction recon (write-only)

Investigate WITHOUT installing anything: what `unicorn_quest.ws` expects
(scene def APIs, `IsExternal` threads, stage embedding); search Nexus/LL
for the Motion/Conjunction toolchain availability; check whether a
`.w2scene` can reference Unicorn stage ids via public APIs only. Deliver
`_work\research\unicorn_motion_recon.md`: verdict `public|private|ask-author`,
what a Motion scene would need from us, and how it changes the
`CinematicIntro` calculus from plan 004.

**Verify**: doc exists with a one-line verdict + evidence links/quotes.

### Step 4: DLC skeleton for our pack (only if Step 2 succeeded)

`dlc\dlcMCME_AR_Unicorn\` with `data\animations\w3stage\` for future
`.w2anims` + `AddAnimSet` paths pointed there. No binary clips yet — empty
mount or the single probe clip from step 2 if it's ours.

**Verify**: game loads with dlc mounted; `uc_scenes()` unchanged (or shows
probe).

## Test plan

- `precheck`/`test_compile` green after each `.ws` step.
- `uc_scenes()`/`ar_uc_eval()` list `mcme_probe`.
- Live `StartSceneEx({npc, thePlayer}, {'mcme_probe'}, 'MCME_AR')` plays.
- `test_e2e.ps1` green.

## Done criteria

- [ ] `RegisterPacks` wrap registers our manifest table (empty-safe).
- [ ] ≥1 custom scene plays end-to-end from registration.
- [ ] `unicorn_motion_recon.md` written with verdict.
- [ ] No Unicorn/Billyy assets copied into our packages (`git status` clean
      of foreign binaries).
- [ ] `plans/README.md` status row updated.

## STOP conditions

- `RegisterPacks` wrap silently never runs (shadowing by another mod) —
  report; do not stack wraps.
- No legally usable clip exists for the proof scene — stop after scaffold;
  registration code is the deliverable, assets come later via operator.
- Licensing contact required (Tenour for embedding questions, Billyy for
  clip reuse) — escalate to the operator; do not guess.
- Motion toolchain is paywalled/private — verdict doc says so; plan ends,
  `CinematicIntro` stays the answer for camera.

## Maintenance notes

- Pack manifest = data table; adding scenes = rows, not code.
- DLC folder is a second binary payload — release packaging needs a third
  staging rule when this lands (coordinate with `package_release.ps1`).
- If Motion becomes available, this plan's registration code becomes the
  scene-def source for Motion-authored `.w2scene` files too — keep the
  manifest format toolchain-agnostic.
