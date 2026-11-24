# MCME Autonomous Romance - Unicorn Bridge - Changelog

Single source of truth for the bridge release history. The shipped
`CHANGELOG.txt` is generated from the `[Nexus Mods Changelog Snippet]`
block below (same convention as the base mod's package flow).

## [1.0.0] - 2026-11-24 - Initial release

Requires: MCME Autonomous Romance v2.4.0+, Unicorn core, a scene pack
(tested with the Billyy pack, 55 scenes).

* Tier-4 routing: hands intimate scenes to the Unicorn engine when
  installed; the native .w2scene path stays as full fallback. Scene
  backend mode 0=off / 1=prefer+fallback / 2=unicorn-only / 3=mix.
* Per-companion scene picks: each companion has a tag row (Cerys leans
  Aggressive/Dominant, Yennefer and Philippa Dominant, Triss/Shani/
  Priscilla Loving, Keira/Ves/Fringilla Teasing/Loving); companions
  without a row use a conservative default. 'Sex' is always required;
  rough-mood tags are stripped when Allow Rough is off, on top of the
  always-on -Forced,-Humiliation exclusions.
* Context-aware picks: Bed scenes near NaughtyPoints with relocation
  onto the point; furniture-bound scenes excluded outdoors; SweetSpot
  furniture excludes standing/kneeling/squatting (the engine's own
  furniture preference does not apply on the StartSceneEx path).
* Anti-repeat: last 3 scenes per NPC excluded, deterministic pick via
  StartSceneEx, pool resets when exhausted.
* Furniture anchoring: bed scenes anchor to the same invisible action
  point the native intimate path uses (mod_scm_sexap), lifted so actors
  rest on furniture; fine-tunable via gameplay fact mcm_ar_uc_bedlift_cm
  (centimeters).
* Foreplay chaining: optional "Open with a foreplay scene" plays a
  LeadIn-tagged scene first, then chains into a regular explicit scene
  on the same anchor (arousal carries over via scene_chain).
* Hint suppression: ships tw3se\init.lua that hides Unicorn's Num-pad
  exit hints for MCME_AR-hooked scenes only - manual Unicorn and quest
  scenes keep their hints and keys.
* Per-session preferences and per-NPC nude appearances registered on
  first scene (SetPreference / SetNudeAppearance, mapped from the
  appearance pack manifest). Unicorn's ambient npc_reactions and stats
  effects are switched off.
* Own MCM page: Options -> Mods -> Autonomous Romance - Unicorn
  (backend mode, Allow Rough, foreplay), localized en/pl/de/es/esmx.
* Cross-mod busy gate: gameplay facts mcme_ar_uc_active and
  mcme_ar_uc_on_<name> keep base-mod actions from colliding with a
  running scene; self-expiring, so a crash cannot lock anything.
* Ciri follows the same Adult Mode gate as the native path
  (ForbidActor enforced inside Unicorn too); her invite also gains a
  campfire context when the bridge is installed and enabled
  (base-side support in v2.4.0).
* Console diagnostics: ar_uc_status, ar_uc_mode N, ar_uc_eval.

Verified live in-game: 3 complete scenes on Mode 1 with correct
per-NPC tags/context, a full anti-repeat cycle (pool 2/2->1/2->reset),
working undress via appearance mapping, post-scene cleanup with
watchdog recovery, Mode 0 native-only routing, second-NPC busy
blocking, AllowRough=0 pool shrink (Cerys 13->2), and clean busy-fact
handoff (threads=1/busy=1 during scenes, 0/0 after).

---

## [Nexus Mods Changelog Snippet]

```text
v1.0.0 - Initial release
* New optional add-on for MCME Autonomous Romance: hands Tier-4 intimate scenes to the Unicorn engine when installed - the native scenes stay as a full fallback. Backend modes: off / prefer+fallback / unicorn-only / mix.
* Per-companion scene picks: every companion gets her own tag profile (Cerys leans Dominant, Triss/Shani/Priscilla Loving, Keira/Ves Teasing...) with conservative defaults for the rest; rough-mood tags are stripped when Allow Rough is off.
* Context-aware: bed scenes anchor onto real furniture (the same point the native path uses), outdoor picks skip furniture-bound scenes, and an optional foreplay scene can open before flowing into the main one.
* Anti-repeat: the last 3 scenes per companion are excluded, so invites stop feeling recycled.
* Polished edges: Unicorn's Num-pad exit hints are hidden in our scenes (manual Unicorn scenes keep theirs), ambient reaction/stat effects off, per-companion undress via appearance mapping.
* Ciri follows the same Adult Mode gate as the native path - and her invite gains a campfire context when the bridge is enabled.
* Requires: MCME Autonomous Romance v2.4.0+, the Unicorn core mod, and a scene pack (tested with the Billyy pack).
* Console diagnostics: ar_uc_status, ar_uc_mode, ar_uc_eval.
```
