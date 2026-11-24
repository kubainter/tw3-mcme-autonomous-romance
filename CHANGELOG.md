# MCME Autonomous Romance - Changelog

All notable changes to this project will be documented in this file.

## [2.4.0] - 2026-11-24 - Optional Unicorn Bridge

- **Optional Unicorn bridge (`modMCME_AR_Unicorn`):** new separate mod package routing Tier-4 intimate scenes through the Unicorn framework when installed, keeping the native `.w2scene` path as full fallback — the base detects the bridge through its MCM group and works unchanged without it.
- **Unicorn bridge internals:** per-companion scene tags, context picks (bed/outdoor/furniture), anti-repeat pool, own MCM page, furniture anchoring, foreplay chaining and hint suppression ship with the bridge package — details live in `Mods/modMCME_AR_Unicorn/CHANGELOG.txt`.
- **Ciri intimate invite now supports campfire context (Unicorn bridge):** her dedicated Tier-4 action previously required a NaughtyPoint (bed) — it now also accepts the outdoor campfire context **when the optional Unicorn bridge is installed and enabled** (MCM `MCM_AR_UcMode > 0`), which routes the scene through the bridge's outdoor dispatch. On a base-only install her native `naughty\ciri` scene requires a real NaughtyPoint, so the campfire exception stays gated off without the bridge (fail-closed instead of a post-consent scene failure). Her Adult Mode gate is unchanged (verified live end-to-end: Adult OFF → blocked on both paths, Adult ON at a campfire → consent → Unicorn dispatch with outdoor furniture exclusions → complete scene + afterglow cleanup).
- **Consent key hardening:** the consent prompt now polls only the active consent action — a dedicated `MCM_AR_Consent` binding fully separates consent from sword sheathing (sheathe presses no longer confirm prompts), while the default path still rides passive `SwordSheathe` polling. The gamepad fast-accept no longer misfires when the last active device is keyboard/mouse with a Steam Input controller attached (`IDT_Steam` stale-state guard).
- **Pad consent without sword side-effects:** the consent prompt on gamepad now advertises D-pad Down (`DrinkPotion2`) as the confirm gesture - D-pad L/R still works but draws/sheathes the swords. While the prompt is up, quickslot potion actions are suppressed (per-source `EIAB_QuickSlots` lock plus `potionModeHold` off, silent on HUD), so the gesture can never drink a potion or flip the slot; the activation edge is recorded before the handler gate, so suppression cannot eat the confirm. A player-bound `MCM_AR_Consent` pad key keeps glyph priority when present.
- **`input.xml.txt` renamed to `input.xml.optional`:** the template stays in the package for manual Keybindings setup, but under a name that The Witcher 3 Mod Manager does not auto-merge — previously every install injected a raw `Consent (MCME AR)` row into Options → Keybindings and engine-side rebinding silently stripped it on next write.
- **`ar_kiss` rewritten with full roster handling:** explicit companion names now match against the complete active roster (canonical names, runtime aliases, niceName and display name, then substring), noble-rig refusals stay by-design, an unmatched explicit name now fails closed with a HUD error instead of silently re-targeting the nearest companion, and the `generic_kiss` path validates the `woman_base` rig up front — no more silent fallbacks or cooldown resets under the wrong target.
- **Alias unification in `MCM_RomanceQoL.ws`:** QoL/diagnostic commands resolve companion names through the same `MCM_AR_CanonCompanionName` mapping as the dispatchers, so every console command accepts the same aliases (e.g. `cerys` → `becca`, `pryscilla` → `priscilla`, `salma` → `mh303_succbus_v2`).
- **`MCM_Other` coverage in the E2E suite:** the dev E2E suite now exercises companions spawned under the `MCM_Other` tag (Cerys, Tomira, Rosa and friends), matching `MCM_AR_GetActiveCompanions` which already merges both companion tag sets.
- **Base package isolation hardened in CI:** `ci_verify_package.ps1` now hard-fails on any `Mods/` entry other than `modMCME_AutonomousRomance` and any `user_config_matrix/pc/` XML other than the base mod's — a future packaging mistake cannot leak the WIP Unicorn bridge into the production ZIP.

## [2.3.3] - 2026-11-20 - Localization Hotfix

- **Fixed broken text rendering for all translated languages.** The 2.3.2 package shipped the `en`, `pl`, `de`, `es` and `esmx` string tables in the wrong binary format, so every mod string — menu labels, consent prompts, companion lines — rendered as garbage characters. All 17 shipped binaries are re-encoded in the correct format — the five translated tables (`en`, `pl`, `de`, `es`, `esmx`) plus the 12 English fallback copies for the remaining game locales. No code changes; identical scripts to 2.3.2.

## [2.3.2] - 2026-11-20 - Consent Key Fix

- **Consent key no longer touches vanilla sword sheathing — and gamepad consent works again.** The prompt used to listen for the vanilla `SwordSheathe` input action; in this engine a script listener registered on the same object+action replaces the game's own sheathe handler, so C stopped sheathing while the mod was installed. Consent is now detected by passive polling (`GetAction`/`IsPressed`) inside the prompt loop and the mod keeps its listener only on its own `MCM_AR_Consent` action — C sheathes exactly like vanilla and still confirms consent (hold ~1s or tap twice). On gamepad, the vanilla D-pad sheathe binding (`State=Duration,IdleTime=0.3`) fires the action only once per hold, so the prompt detects it via `GetLastActivationTime` edge-tracking instead of held-state polling — one deliberate D-pad Left/Right press during a prompt confirms consent (verified in-game). The prompt icon now renders both real mappings — keyboard and pad glyph (`[C] / [D-pad]`) — resolved from your actual `input.settings` bindings, so it follows rebinding. The shipped `input.settings.txt` no longer binds any key: the tuple syntax `(Action=A,Action=B)` was invalid (the engine keeps only the first action) and the game strips unknown actions on its next write. A dedicated consent key stays optional — declare `IK_<key>=(Action=MCM_AR_Consent)` in `bin\config\r4game\legacy\base\input_qwerty.ini` and in `Documents\The Witcher 3\input.settings`, or add the `input.xml.txt` Var for a menu row. If C stopped sheathing for you after the earlier update, restore `IK_C=(Action=SwordSheathe)` in `input.settings` (or let your mod manager re-merge the vanilla line).

## [2.3.1] - 2026-11-16 - Input Bindings Packaging Fix

The shipped consent-bindings file now uses the standard `input.settings.txt` name, so it merges automatically on every install path. File contents and key assignments are unchanged.

## Fixes
- **Input bindings file renamed:** `Mods/modMCME_AutonomousRomance/MCME_AR.input.settings.txt` is now `Mods/modMCME_AutonomousRomance/input.settings.txt`. The prefixed name was invisible to tools that scan mod folders for the conventional filename, so the `MCM_AR_Consent` bindings (keyboard C, gamepad D-pad Left/Right) never got merged there and consent ran purely on the sword-sheathe fallback. Contents unchanged; the fallback still covers installs where the file is not merged.
- **Docs:** README, the in-mod README.txt and the Nexus install section now point at `input.settings.txt`.

## [2.3.0] - 2026-11-08 - Generic T1-T3 Actions for the Extended Woman_Base Roster

Shared flirt, care and kiss actions for every MCME woman_base follower without dedicated AR actions (Tamara, Iris, Corinne, Jutta, Sasha, Eveline Gallo, Lady of the Lake, Lussi, Yoana and more), a universal kiss-scene fallback, and description accuracy fixes for Rosa var Attre / Tomira Tier 4.

## Features & Improvements
- **Generic flirt bark (T1):** MCM_AR_Generic_FlirtBark - RTT_OneLiner wildcard (minAffinity 0, weight 6, cd 300s) rotating a shared pool of four flirt lines; gated to woman_base companions that have NO dedicated AR actions via the new `MCM_AR_IsNamedCompanion` exclusion list (19 named companions incl. runtime aliases). Blocked at night and near campfires, matching the dedicated OneLinerFlirt actions.
- **Generic post-combat care (T2):** MCM_AR_Generic_Care - RTT_Gesture wildcard (minAffinity 30, weight 8, cd 900s) with the same HP below 60% plus recent-combat (300s) gates as the dedicated care actions; comfort bark only, no heal.
- **Generic kiss (T3):** MCM_AR_Generic_Kiss - RTT_Prompt wildcard (minAffinity 50, usesAutonomousKiss, cd 1800s) playing the shared `ar_tomira_kiss` scene through a new `default` fallback in `AutonomousScenePath` for every woman_base companion without a dedicated kiss mapping. Ciri and noble-rig companions keep their own switch cases and gates; Ciri Adult Mode isolation is preserved both by the named-exclusion list and by her case returning empty in Lore Mode.
- **Localization:** 7 new keys `ar_line_generic_flirt_1..4`, `ar_line_generic_care`, `ar_line_generic_kiss`, `ar_prompt_generic_kiss` (IDs 2118800290-2118800296) in en/pl/de/es/esmx; compiled .w3strings binaries rebuilt for all 17 locales (the 12 without a dedicated translation are English copies).

## Docs
- description.bbcode: Rosa var Attre and Tomira no longer listed under bespoke indoor suites (their Tier 4 uses the shared universal outdoor scene); extended MCME roster documented as covered by shared banter, care and kiss actions.
- README: extended roster row updated from "T4 (Universal)" to "T1 - T4 (Generic)"; `ar_intimate` console documentation corrected (Rosa/Tomira do not stop at kisses).
- Binary rig verification (`.w2ent` audit of blob/ep1/bob bundles): Tamara, Iris, Corinne, Jutta, Sasha, Eveline Gallo, Lady of the Lake and barons_wife_celina all confirmed `woman_base` (CMovingPhysicalAgentComponent markers); `mq3031_nidas` is a mislabeled `man_base` entry, `cirilla_young` is `child_base`, both intentionally out of scope.

## [2.2.1] - 2026-11-05 - Night Ambient Lines, Post-Combat Care Gating & Idle-Sit Fix

Night-time companion barks for the full roster, lore‑friendly health‑and‑combat gating for Tier‑2 care/allure gestures, and a fix for ambient dance/drink sequences conflicting with idle sitting poses.

## Features & Improvements
- **Night ambient lines for all remaining companions:** 12 new RTT_OneLiner ambient actions (`*_night_filler`) for Rosa var Attre, Tomira, Ciri, Syanna, Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita and Orianna. Same pattern as existing fillers: night‑gated, weight 8, cooldown 600s, minAffinity 0. Ciri uses barkMimic 'smile' (family register, not flirt). Every roster companion now has a night bark. New localization keys `ar_line_<npc>_night_filler` IDs `2118800278` through `2118800289` in en/pl/de/es/esmx CSVs (esmx reuses es text). Compiled .w3strings binaries rebuilt for all 17 locales (the 12 without a dedicated translation are English copies).
- **Lore‑friendly gating for care/allure gestures:** MCM_AR_Salma_Allure, MCM_AR_Priscilla_Care, MCM_AR_Edna_Care, MCM_AR_Fringilla_Care, MCM_AR_Margarita_Care, MCM_AR_Orianna_Care now require Geralt HP ≤ 60% AND combat ended < 300s ago (block reasons "hp_ok"/"no_recent_combat"); MCM_AR_Philippa_Care (previously HP‑only) gained the recent‑combat check. These Tier‑2 gestures now read as post‑combat care instead of firing unconditionally in the staged lottery.

## Fixes
- **Idle‑sit vs ambient sequence conflict fix:** ambient dance (`RunDanceSequence`) and drinking (`PlayDrinkingAnimation`) sequences now call `RemoveIdleJobFor(npc)` on start (NPC stands up from the campfire/idle sit pose) and hold an `MCM_AR_AmbientBusy` marker (90s self‑expiring) for the duration; `UpdateIdleSuspend` skips ambient‑busy NPCs so no new sit job can spawn mid‑performance. New core API: `MarkAmbientBusy`/`ClearAmbientBusy`/`IsAmbientBusy` + `MCM_AR_AmbientBusy` class + `arAmbientBusy` array + `skipAmbient` counter in the idle log line. Original bodies renamed `PlayDrinkingAnimationInner`/`RunDanceSequenceInner`. This also covers the gift‑request drink path (same public function).

## [2.2.0] - 2026-11-04 - Universal Romance Dispatcher & Campfire Intimacy

Universal outdoor intimacy for all companion roster members on the standard woman rig, independent per-companion cooldowns, faster campfire settling, and major code de-bloat.

## Features & Improvements
- **Universal Outdoor Intimacy (Tier 4):** All female companions on the standard woman rig (woman_base - including Tamara, Iris, Corinna, Jutta, Sasha, Tomira, Rosa var Attre, etc.) now have access to romantic intimacy near campfires and outdoor spots via the unified MCM_AR_Generic_IntimateInvite action.
- **Independent Cooldowns per Companion:** Generic/wildcard actions now maintain separate cooldown and rejection timers per companion (compCooldownTimes, compRejectTimes), preventing one companion's action from blocking others in multi-companion parties.
- **Campfire Idle Lifecycle:** Followers take a seat by lit campfires significantly faster (~6s instead of 50s) when Geralt pauses nearby.
- **Triple Appearance Fallback:** Smooth fallback hierarchy during romantic encounters (
naked -> underwear -> keep dressed) to avoid missing-mesh visual issues.
- **Codebase De-bloat:** Consolidated 13 duplicate per-companion action classes into the single generic dispatcher while preserving Ciri adult mode guards and specialized noble-rig routines (Anna Henrietta, Vivienne, Orianna).
- **Secondary Companion Intimacy & Template Mesh Stripping:** Roster companions lacking hardcoded specialData entries (Corinne Tilly, Ida Emean, Irina Renarde, Eveline Gallo, Anna Stenger, Birna Bran, Sasha, etc.) dynamically scan their template `.w2ent` meshes for naked and underwear appearances during intimate scenes, restoring their original clothes upon scene exit or skip.
- **HUD Afterglow Speaker Identification:** Fixed a bug where dynamic companion entities displayed empty speaker prefixes (`: "..."`) by routing name resolution through `MCM_AR_GetCompanionDisplayName` with a fallback to `niceName`.
- **Disambiguated Alias Resolution & Two-Pass Matching:** Resolved ambiguous alias clashes (e.g. `anna` between Anna Henrietta and Anna Stenger); implemented two-pass strict-to-substring matching in debug consoles (`ar_intimate`, `ar_kiss`) eliminating false-positive companion selection.

## Fixes
- **Ciri Adult Mode Isolation:** Ensured generic wildcard actions cannot match Ciri, keeping her strictly under the explicit MCM Adult Mode toggle.
- **Wildcard Cooldown Enforcement:** Fixed registry execution paths to properly record execution and rejection timestamps for wildcard actions.

# v2.1.0 - Downtime Reactions, Ambient Dance & Cinematic Scenes

Companion downtime reactions for meditation and sleep, ambient dances, all-day kiss invitations with cinematic variants, campfire intimate scenes, and idle pose transitions. Items listed under Known Limitations still need in-game verification before release.

## Features & Improvements
- **Downtime reactions (meditation & sleep):** when Geralt meditates or sleeps in the Corvo Bianco bed, every follower within 15 m settles into a relaxed pose on a ring around him (~1.4 m at meditation, ~1.9 m at the bed); when the session ends, the companion who stayed closest says a short line. The channel is consent-free, needs ~2 s of detected downtime so quick alchemy meditations do not trigger it (bed sessions skip the debounce), and re-arms ~60 s after a session (tracked separately for meditation and sleep; a combat break pauses meditation for ~5 min). The detector reads the player state/action - not the menu context - so alchemy, ordinary menus and clean idle never count as downtime. New console probe: `ar_downtime`.
  - **Positioning:** companions settle on a ring around Geralt instead of posing where they stood; each one keeps its own bearing.
  - **Bed partner:** during bed downtime the eligible follower with the highest affinity (female rigs) lies down on the free side of the bed next to Geralt for the whole sleep session. The free side is picked from Geralt's actual lying position, occupancy is checked with our own sweep, her position is re-pinned every tick and the lying loop is re-issued periodically so she never ends up standing on the bed. She swaps to underwear (unless `MCM_DisableAppearanceChanging` is on) and dresses back + returns to following when Geralt wakes. If no side is available, the companion falls back to a floor pose by the bed. This is the mod's own job state - no references to MCME job logic, so MCME job-system changes cannot break it.
- **Dance in taverns and by the campfire (`*_dance`):**
  - Priscilla, Triss, Keira, Shani, Cerys and Tomira dance (woman_dance); Philippa, Yennefer, Ves and Ciri answer with a short refusal line; Ciri dances in Adult mode only. Affinity 30, ~10 min cooldown. The gate is a tavern, or a campfire at night.
  - A performance is a sequence of animation steps (start, loops, stop). Combat or an interrupted step ends the sequence cleanly, the same way the drinking animation does.
  - Philippa, Yennefer, Ves and Ciri answer with a short refusal line instead of dancing.
- **Console command `ar_dance(name)`:** triggers one dance or refusal for a companion who is in the party, without waiting for an autonomous trigger and without the tavern or campfire gate. Names: `priscilla`, `triss`, `keira`, `shani`, `tomira`, `cerys`, `ves`, `ciri`, `philippa`, `yen`, `ciri_refuse`.
- **Intimate scenes ship with the mod:** the intimate-invitation scenes for Priscilla, Edna, Orianna, Fringilla and Margarita and for Cerys, Philippa, Ves, Salma, Anarietta and Vivienne (Anarietta & Vivienne) are now copies inside the mod's own `blob0.bundle`. They no longer need those packages installed, and the copies take precedence over the packages' own scene paths. Intimate scenes for the other companions are unchanged.
- **All-day kiss invitations:** Yennefer and Keira now have an autonomous kiss invitation that works at any time of day (affinity 50, `[C]` consent, ~30 min cooldown), matching the one Triss already had. Their night-gated invitations remain unchanged.
- **Cinematic kiss variants:** kisses for Triss, Yennefer, Keira and Shani can now play a cinematic camera scene, rotated ~50/50 with the standard per-companion scene. A dynamic action point is spawned at Geralt's feet so the scene plays where the couple stands. New scenes ship in the mod's own `blob0.bundle`.
- **Intimate invitations at campfires:** the Tier 4 invitations from Yennefer, Triss and Keira are now also eligible at an outdoor campfire, not just near a fixed NaughtyPoint. Away from a point they play a new dedicated outdoor scene (`ar_shani_intimate_outdoor`) with its own spawned action point instead of an MCME cutscene. Shani's and Ciri's invitations keep the NaughtyPoint requirement.
- **German (de) Localization:** Full translation of all 269 strings across prompts, menus, and companion dialogues into German (de.w3strings.csv and compiled de.w3strings).
- **Idle pose transitions:** companions in the sitting-on-ground and lying-on-grass poses enter through a start animation and leave through an end animation before they follow again. Other idle poses keep their previous behavior.
- **E2E checks:** the in-game test suite (dev builds only, ~90 live assertions) covers gate order, affinity edges, gifts, scene paths, config guards, consent timeout, the downtime channel, the dance whitelist and idle animation state.

## Fixes
- **Gameplay Scene Latch Fix:** Replaced stale actor flag `npc.IsInGameplayScene()` with `theGame.IsDialogOrCutscenePlaying()`. In REDengine 3, `IsInGameplayScene` could stay permanently true after any cutscene/dialogue, freezing companion autonomous ticks and ambient barks.
- **MCM_Other Companion Tag Integration:** Added `MCM_AR_GetActiveCompanions()` to combine `GeraltsBFF` with `MCM_Other`, fully enabling autonomous romance actions for Cerys (Becca), Tomira, Rosa, and other secondary companions.
- **Dance & Drinking AI Locomotion Suspension:** Wrapped dance routines and tavern drinking animations with `npc.scmcc.StopFollowing(true)` on entry and `StartFollowing()` on exit/interruption, preventing MCME foot-movement AI ticks from canceling slot animations after 1-2 seconds.
- **Ves Lore-Friendly Dance Refusal & Tavern Drink:** Replaced male-skeleton sword animations for Ves with an in-character dance refusal (*"I'm a soldier, Geralt. If you want dancing, find a bard."*) and a dedicated tavern toast (*"Pour one for Temeria. Then one for us."*).
- **Tavern Drinking Rebalance:** Shortened tavern drinking cooldown from 600s to 180s and increased weight from 6 to 14 across all companions.
- Bed/sleep safety gap: the pre-sleep lying phase (`PEA_GoToSleep`) reports player state `Exploration`, which previously let staged actions, consent prompts and ambient barks fire while the player was locked in the bed interaction. Both safety gates now treat the downtime state as blocked.
- The consent hint now substitutes the dynamic key glyph into every `[C]` anchor (was: first occurrence only), so the hold hint shows the real key instead of a literal "[C]".

## Known Limitations
- The 2.5 second duration of the start and end transitions is a first estimate, not measured.
- The dance clips for Tomira and the Ciri Adult variant are not yet verified in game.
- Orianna's intimate scene was checked against the game files, not yet played in game.
- Philippa's kiss scene (since v2.0.0) and her intimate-invitation copy (taken from the Anarietta & Vivienne pack) reference a character template path that the base game does not contain. Their in-game behavior is not verified.
- Salma's kiss scene references a scene file that is not present in any installed package. This dates from v2.0.0; its in-game behavior is not verified.
- The eleven intimate-invitation copies play through the manual path (a NaughtyPoint plus an action point). Where a companion pack previously supplied a registered scene path, that path is no longer used for these scenes. Please report any difference in the scene start, camera or cleanup.
- Yennefer was not observed taking an idle pose in the last test run.

## Affected Files
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceCore.ws`
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceInteraction.ws`
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceActions_Main.ws`
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceActions_DLC.ws`
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceE2EDev.ws` (new, dev builds only)
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceTw3seDev.ws` (E2E suite moved to `MCM_RomanceE2EDev.ws`)
- `Mods/modMCME_AutonomousRomance/content/blob0.bundle` + `metadata.store` (16 new scenes, 36 entries in total: `ar_cs_kiss_probe.w2scene`, `ar_shani_kiss_cinematic.w2scene`, `ar_shani_intimate_outdoor.w2scene`, `ar_shani_sex_outdoor.w2cutscene`, `ar_triss_kiss_cs.w2cutscene`, and the eleven intimate-invitation copies `naughty/{priscilla,edna,oriana,fringilla,margaritta,cerys,philippa,ves,salma,anarietta,vivienne}/anywhere.w2scene`)
- `Mods/modMCME_AutonomousRomance/content/en.w3strings.csv` (17 new strings: 11 dance and refusal lines for Priscilla, Cerys, Ves, Philippa, Triss, Keira, Shani, Tomira, Ciri and Yennefer; Yennefer and Keira kiss prompts and lines; two downtime lines; four unused v2.0.0 strings removed)
- `Mods/modMCME_AutonomousRomance/content/{pl,es,esmx}.w3strings.csv` (all v2.1 strings translated, same 267 keys as en); regenerated `.w3strings` binaries for en/pl/es/esmx, and the 13 other locale binaries are copies of the new en
- `scripts/tw3se/MCM_RomanceTw3seDev.dev.ws` (dev bridge source)
- `README.md` (MCMR prerequisite note + Almighty Geralt compatibility section)

# v2.0.0 - Universal Dispatcher, Expanded Roster & Immersive Gestures

Major integration update delivering universal clean scene dispatching, expanding the autonomous romance roster to 19 companions, adding physical drinking animations, and personalizing companion afterglow across the entire cast.

## Features & Improvements
- **Universal Kiss & Hug Dispatcher:**
  - Kiss interactions for Triss, Yennefer, Keira, Shani, Cerys, Syanna, Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita, Rosa var Attre and Tomira route to the universal clean scene `PlayKissScene(npc)` with no dialogue wheel prompts.
  - Ciri has a family hug via `PlayHugScene(npc)`. Her kiss is available only in Adult Mode of the MCM option `MCM_AR_CiriMode` (off by default).
  - Each kiss and hug plays a dedicated per-companion scene (`dlc\mod_mcme_autonomous_romance\dialogue\ar_*.w2scene`) built from that companion's own scene with the dialogue wheel removed. Scenes ship in the mod's own `blob0.bundle`, so MCME original resources are not shadowed.
  - Anna Henrietta, Vivienne and Orianna have no kiss interaction, because their `noble_woman_base` skeleton has no matching kiss animation. They keep their intimate invitations. Companions without a mapped scene are gated at eligibility (`blocked: no_scene`).
  - Companion post-scene reactions (`PlayPostKissReaction`, `PlayPostHugReaction`) with distinct, lore-friendly in-character lines for all companions.
- **Intimate invitations (T4):** affinity 80, NaughtyPoint-gated. Philippa, Ves, Salma, Priscilla, Edna, Fringilla and Margarita use naughty cutscenes from the MCME companion packs and are offered only when that scene is installed (`no_dlc_scene`). Rosa var Attre and Tomira have no intimate scene.
- **Ciri dual mode (`MCM_AR_CiriMode`, off by default):** Lore-Friendly keeps her family hug with no romantic or intimate interactions. Adult Mode unlocks `ciri_kiss` and `ciri_intimate_invite`.
- **Runtime name aliases:** scene routing resolves engine names that differ from companion names (`edna_var_attre`, `prologue_village_herbalist`, `mh303_succbus_v2`, `pryscilla`, `becca`).
- **Physical Drinking Animations (Gifts & Taverns):**
  - When Geralt accepts a drink request via `[C]` in `MCM_AR_GiftRequest_Base`, the companion now physically raises her bottle or goblet and drinks (`PlayDrinkingAnimation`) before speaking her thank-you line.
  - The same drinking animation triggers during tavern rounds in all `*_tavern_drink` interactions (Triss, Keira, Shani, Anna Henrietta, Vivienne, Cerys).
  - Safe fallback probe: models with non-standard skeletons (such as Salma's succubus model) skip the animation cleanly without errors or stalling.
- **Personalized Afterglow Walk (All 19 Companions):**
  - Replaced the generic line (*"That was... nice. Don't be a stranger."*) in `MCM_AR_AfterglowBark` with unique, authentic, in-character remarks for each companion during joint travel within 120s of a kiss or hug.
  - Specific lines tailored to each personality: Yennefer, Triss, Keira, Shani, Anna Henrietta, Vivienne, Cerys, Syanna, Ciri, Rosa var Attre, Tomira, Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita, and Orianna.
- **Roster Expansion (Strict Core CDPR Naked Mesh Audit):**
  - **Syanna:** Full T1-T4 romance including T1 banter, T2 post-combat reaction, T3 universal kiss, and T4 cloud sex intimate scene (`dlc\mod_spawn_companions\naughty\syanna\anywhere.w2scene`) using native Core CDPR appearances (`syanna_naked`).
  - **Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita:** Full T1 (ambient barks), T2 (care / help gestures), T3 (universal kiss), and custom gift requests (`MCM_AR_GiftRequest_Base`).
  - **Orianna:** T1 ambient barks, T2 care gestures and an intimate invitation. No kiss interaction.
  - **Rosa var Attre & Tomira:** Upgraded to include Tier 3 Universal Kiss interactions.
  - **Ciri:** Tier 3 family hug interaction.
- **Story Affinity Integration:**
  - Expanded `GetBaseStoryAffinity()` tracking quest milestones for Ciri, Syanna, Philippa, Salma, Ves, Priscilla, Edna, Fringilla, Margarita, and Orianna.
- **Automated In-Game E2E Test Suite (Dev CI/CD):**
  - Added `exec ar_test_e2e()` inside the TW3SE dev layer (`MCM_RomanceTw3seDev.ws`) (dev builds only).
  - Runs live assertions across player handle, core registry size (>=106 actions), affinity formula scaling, MCM config toggles, and dry-run action gating without polluting release builds.
- **Localization:**
  - 92 new strings added across English, Polish, Spanish (`es`), and Latin American Spanish (`esmx`): IDs `2118800143` through `2118800234` (254 entries in the English table). All 17 binary `.w3strings` files updated.

## Bug Fixes
- **Consent prompt after approach:** the `[C]` consent prompt now appears only after the companion actually walks up to Geralt, instead of instantly cancelling when she was selected 13-15m away and still walking over (the walk-away abort threshold no longer fires during her approach). A failed approach (pathing/timeout) no longer counts as a player rejection, so it doesn't trigger the escalating reject cooldown.
- **Staged channel watchdog:** the 300s stale-lock recovery now actually runs — it was placed where a busy channel could never reach it, meaning a latent abort (e.g. script reload) could silently wedge staged interactions for the whole session until `ar_devreset`.
- **Combat gate timing:** the "seconds since combat" timer no longer treats session start as a fresh combat end, so post-combat gates behave correctly during the first minutes after loading a save.
- **Greeting bookkeeping:** the "welcome back" bark's last-seen stamp now persists across ticks where the companion is busy/in a scene/out of range, so returning companions are greeted once they become eligible instead of losing the greeting window silently.
- **Debug HUD off by default:** `MCM_AR_DebugHud` now defaults to `0` (all presets), so fresh installs no longer get diagnostic `[AR]` messages on the HUD. Re-enable via MCM or `ar_debug`.
- **Keira actions fixed:** `keira_tavern_drink` and `keira_night_filler` now target `keira_metz` (the real MCME spawn name) instead of the `keira` alias — both actions can actually trigger now.
- **`ar_debug` toggle:** calling `ar_debug` with no argument now toggles debug mode (use `ar_debug(1)` to force on, `ar_debug(-1)` to force off); previously a bare call could only ever turn it off.
- **`ar_diag` no longer writes `MCM_AR_CooldownSlider=70`** into `user.settings` — the diagnostic marker channel no longer mutates a real user setting.
- **Release package compatibility:** the release ZIP now uses spec-compliant `/` path separators (previously `\` from `Compress-Archive`), which fixes "not detected as a valid mod" on Linux/Steam Deck installs via The Witcher 3 Mod Manager. The input bindings file is now `MCME_AR.input.settings.txt` — the `.txt` format is the one TW3 Mod Manager actually merges on install (Vortex does not auto-merge mod input files; consent still works via the sword-sheathe binding regardless).
- **Long silence after autonomous scenes:** the wait loop waited on `IsInGameplayScene`, which stays flagged long after a scene ends. It now exits on dialogue or speech silence, with a safety bail (about 16 s typical wrap-up).
- **Weapons and scabbards visible during intimate scenes:** equipped weapons and scabbards stayed visible in `naughty\*` cutscenes, which re-mount items mid-scene. `PlayIntimateScene` now hides them on both Geralt and the companion, re-applies the hide while the scene runs, and restores visibility afterwards. Script-side only, with no asset overrides.

---

# v1.1.0 - Quality & Content Pass (E1+E2)

Community-requested fixes and a broad companion-content expansion.

## Bug Fixes
- **Consent key fix:** consent prompts no longer depend on the vanilla `SwordSheathe` binding. New dedicated input action `MCM_AR_Consent` (keyboard **C**, gamepad **D-pad Left/Right**) via shipped `MCME_AR.input.settings`; prompts now render the actual bound key/glyph through `ReplaceTagsToIcons`. `SwordSheathe` remains as fallback. The binding covers the five base gameplay contexts (Exploration, Combat, Horse, Boat, Swimming) as well as overlay contexts that sit on top of the input stack while a prompt is showing: `Scene`, `ScriptedAction`, `SCENE_IS_STARTING_HACK`, `JumpClimb`, `Diving`, `ThrowHold`, `ThrowHoldChain`, `LootPopup`, `BoatPassenger` and the Ciri replacer contexts (gamepad bindings intentionally skip `Scene`, where the D-pad drives dialog choices). Manual installers must merge the shipped input file into `Documents\The Witcher 3\input.settings` (mod managers do it automatically).
- **Consent double-tap:** fast double-taps could be lost: the tap counter used only ~65-100ms key polling edges. It now takes `max(VK edges, input-event count)` so hardware presses always register; the input listener also deduplicates the same physical press firing both registered actions within 0.12s (prevents a single tap counting as two).
- **Consent hold & window:** the consent window is now at least 20s (was 10s): `DisplayHudMessage` queues behind the companion's spoken request line (~4-5s on screen), so the prompt often rendered at the end of the window and presses landed after the timeout. Hold detection uses a per-action event latch (`MCM_AR_Consent` / `SwordSheathe` separately) so a synthetic release from the gamepad `Duration` binding cannot cancel a real hold; in dev builds the VK probe and event latch work together, so gamepad hold works there too.
- **MCM header:** the mod section title showed the raw key (`##preset_Mods_AutonomousRomance`). Added the missing localization key with the mod name and version label.
- **Tavern detection:** `player_in_inn` does not fire in most inns (e.g. the Kingfisher / Dandelion's Chameleon, Velen bars). `MCM_AR_IsInTavern` falls back to an interior + entity scan at 18m with a 200-entity cap - dense inn interiors return 100+ entities in unsorted engine order, which previously truncated the `*_inn` community layers before they could be checked. Matches innkeeper tags and layer/template paths (`*_inn`, `inn_*`, `tavern`, `sit_drinking_bench` dining actionpoints). Also: candles and lamps (`CarriesOpenFire`) no longer count as campfires, so `campfire=true` no longer leaks into tavern interiors.

## Features
- **Scene availability gate:** new `MCM_AR_SceneExists` helper with a `path->bool` cache plus `no_dlc_scene` block reason: optional companion scene packs that are not installed are skipped cleanly instead of stalling evaluation.
- **Tavern banter for everyone:** `*_tavern_drink` actions for Triss, Keira, Shani, Anna Henrietta, Vivienne and Cerys (previously Yennefer-only).
- **Night ambience:** `*_night_filler` one-liners for all seven romanceable companions: companions no longer go silent after dark.
- **Context-aware chatter (Tier 1):** generic barks for bad weather, horseback riding, boat trips, and being indoors. Ambient barks now work while riding and sailing (`MCM_AR_IsSafeForAmbient`) while combat, swimming, and dialogues remain blocked; scenes and gestures still require safe footing.
- **Afterglow & jealousy aftermath:** companions remark after a successful scene (<=120 s window, same companion), and a rival (Yen <-> Triss) present at the scene can call Geralt out afterwards (<=300 s).
- **New MCM option - Companion Chatter:** Quiet / Default / Chatty presets (~30% / ~65% / ~100% ambient bark chance).
- **New companions:** **Rosa var Attre** and **Tomira** join the roster: recognition, display names, story affinity, a flirt line and a drink request each.

## Localization
- **Spanish (es) and Latin American Spanish (esmx)** full translations of all 139 strings (MCM options, HUD prompts, barks, gift lines). English and Polish updated with all new lines.

---

# v1.0.0 - Initial Release (The Witcher 3 Remastered v5.00+)

Initial public release of **MCME Autonomous Romance**, introducing autonomous companion initiative, context-aware banter, post-combat care, campfire drink sharing, and consent-guarded romantic dates for Multi Companion Mod Remastered companions.

## Features & Technical Highlights

### 1. Dynamic Interaction & Romance Progression
- **Exploration Banter & Flirting:** Over 30 authentic in-game voice lines and localized subtitles triggered dynamically while exploring the open world.
- **Post-Combat Care & Triage:** Companions react when weapons are sheathed after heavy combat damage. Yennefer scolds Geralt's recklessness and mends him, Triss rushes over with a healing hug, Shani performs field triage, Keira patches him up with a sorcerous flourish, and Anna Henrietta inspects Geralt with regal pride. The healers restore 20-25% of Geralt's Health bar in real-time.
- **Private Invitations:** Companions autonomously approach Geralt and invite him to pause their journey. A non-intrusive 10-second HUD prompt appears (`[C] Respond to <Companion>`).
- **Dates & Romantic Moments:** Romantic cutscenes and dates in private suites (Passiflora, Corvo Bianco guest bedroom, Kaer Morhen chambers). Kiss scenes play cleanly without requiring manual dialogue wheel selection, compatible across all game languages.

### 2. Quest-Aware Relationship (Affinity) Progression
- **Story Quest Tracking:** Evaluates vanilla quest decisions in real time (*The Last Wish*, *Now or Never*, Fyke Isle, Shani's wedding, Duchess banquet) without modifying quest states.
- **Clean Save Guarantee:** Earned relationship points are stored as native engine facts (`mcme_ar_<npc>_affinity`). No custom `saved var` objects; progress is stored as engine facts that stay in the save after uninstall.
- **In-Game Pacing Controls:** In-game MCM menu allows adjusting initiative cooldowns, affinity progression speed multipliers, jealousy mode, sandbox testing, and decision-tick intervals.

### 3. Non-Intrusive Interaction Prompts ([C] Key)
- Romance never abruptly hijacks camera or controls.
- Invitations display a subtle 10-second HUD prompt mapped to `'SwordSheathe'` (`[C]`). Accept by holding `[C]` ~1 s or double-tapping it.
- Walking away or letting the timer expire gracefully declines the invitation without penalties or affinity loss.

### 4. Rivalry & Jealousy System
- Traveling with multiple romantic partners (such as Yennefer and Triss together) triggers authentic rival banter and locks private intimate scenes until alone.
- The Jealousy Mode toggle in MCM controls whether rivals clash or coexist peacefully.

### 5. Wine & Spirits Gifting
- Companions autonomously request a drink in relaxed contexts only: taverns, Corvo Bianco, campfires, or idle rest stops (`blocked: not_relaxed` otherwise).
- Requests stay deliberately rare: low initiative weight and a 60-minute cooldown.
- Pressing `[C]` offers the beverage, consumes 1 bottle from inventory, awards **+3 Affinity**, and draws a thank-you line. Supported gifts: *Est Est*, *Erveluce*, *Beauclair White*, *Mettina Rose*, *Alcohest*, *Dwarven Spirit*.

### 6. Wardrobe & Appearance Controls
- Integrated into companion interaction menus and debug commands.
- Switch and persist companion outfits between default meshes, underwear, and naked models via companion edit UI and console commands (`ar_dress`, `ar_undress`, `ar_naked`).

### 7. Engine Compatibility & Zero Script Merger Conflicts
- Built using Remaster native annotations (`@wrapMethod`, `@addMethod`, `@addField`).
- Modifies zero vanilla script files, ensuring zero Script Merger conflicts.
- Bootstraps cleanly via `@wrapMethod(CR4Player) function InitRemasterSettings()` to bypass the Next-Gen/Remaster `@wrapMethod` shadowing priority bug.

### 8. Configurable Decision Tick & Split Timers
- The decision tick is player-tunable: MCM slider `MCM_AR_TickInterval`, 20-160 s in 10 s steps (default 30 s), under **Options -> Mods -> Autonomous Romance**.
- The ambient/bark channel runs on its own fixed 10 s timer, ensuring bark responsiveness and idle poses do not lag behind longer tick intervals.
- The timer interval is read on game session start: slider adjustments apply after a save reload.

### 9. Natural Idle Poses & Downtime
- When Geralt stands still for ~50 s, companions pause their follow routine, walk to a nearby spot, and settle into relaxed idle poses on a staggered delay.
- They wake instantly when Geralt moves (>1.5 m) or the context becomes unsafe. Idle jobs are fully lifecycle-safe around scenes and interactions.

### 10. Complete EN/PL Localization
- Every player-facing string (prompts, HUD messages, subtitles, gift requests, MCM labels) resolves through `en.w3strings.csv` / `pl.w3strings.csv` (87 keys) with defensive English fallbacks.
- Other game languages receive English text until community translations arrive. Gift item names resolve through the game's own item localization, matching inventory names in every language.

## Diagnostics & Dev Tools
- Shipped with 22 in-game debug console commands (`ar_status`, `ar_eval`, `ar_trigger`, `ar_force`, `ar_consent`, `ar_affinity`, `ar_gift`, `ar_dress`, `ar_undress`, `ar_logdump`).
- Release builds automatically decouple TW3SE via a lightweight C++ bridge stub (`MCM_RomanceTw3seDev.stub.ws`), ensuring players need zero external extenders.

## Affected Files
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceCore.ws`
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceAffinity.ws`
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceInteraction.ws`
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceActions_Main.ws`
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceActions_DLC.ws`
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceQoL.ws`
- `Mods/modMCME_AutonomousRomance/content/scripts/local/romance/MCM_RomanceTw3seDev.ws`
- `bin/config/r4game/user_config_matrix/pc/modMCME_AutonomousRomance.xml`
- `Mods/modMCME_AutonomousRomance/content/*.w3strings` (17 languages)

---

## [Nexus Mods Changelog Snippet]

> *Ready-to-paste text for the Nexus Mods "Change Log" tab:*

```text
v2.4.0 - Optional Unicorn Bridge
* New optional add-on (separate file): MCME AR - Unicorn Bridge hands Tier-4 intimate scenes to the Unicorn mod when installed - per-companion scene picks, bed/campfire context, foreplay lead-in scenes that flow into the main scene, clean fallback to the native scenes. Without the add-on everything works exactly as before.
* New: Ciri's intimate invite also works at campfires when the Unicorn bridge is installed and enabled.
* Fix: consent prompt hardening - dedicated MCM_AR_Consent action separates consent from sword sheathing, and no more misfires with a Steam Input controller attached.
* Fix: gamepad consent no longer swings your swords - the prompt advertises D-pad Down and blocks potion use while it is up (D-pad L/R still confirms).
* Fix: ar_kiss resolves the full companion roster including aliases and fails loudly on unknown names instead of silently retargeting.
* QoL: console commands accept the same companion aliases everywhere (cerys, pryscilla, salma...).
* Note: the bridge requires the Unicorn core mod plus a scene pack (tested with the Billyy pack).

v2.3.3 - Localization Hotfix
* Fix: all translated text rendered as garbage characters in 2.3.2 - the language string tables shipped in the wrong binary format. Re-encoded correctly; menu, prompts and companion lines display properly again.
* No code changes - same scripts as 2.3.2 (consent key fix included).

v2.3.2 - Consent Key Fix
* Fix: the consent key no longer breaks sword sheathing. The previous version hooked the vanilla sheathe action, which in this engine replaced the game's own sheathe handler and broke C. Consent is now read passively: C sheathes like vanilla and still confirms the prompt (hold ~1 s or tap twice).
* Fix: gamepad consent works again - one deliberate D-pad press confirms, and the prompt now shows your real bound keys for keyboard and pad side by side, so it follows whatever key you map sheathing to.
* Changed: input.settings.txt ships without bindings (they never took effect). Consent needs nothing merged; a dedicated consent key is optional - setup in README/description.
* If C stopped sheathing after the last update, restore IK_C=(Action=SwordSheathe) in Documents/The Witcher 3/input.settings or let your mod manager re-merge the vanilla line.

v2.3.1 - Input Bindings Packaging Fix
* Fix: the consent bindings file now uses the standard input.settings.txt name, so it merges automatically on every install path. Contents unchanged - C on keyboard and D-pad Left/Right still accept the prompt, and consent still works through the sword-sheathe key when the file is not merged.

v2.3.0 - Romance for the Extended Roster
* New: extended MCME followers (Tamara, Iris, Corinne, Jutta, Sasha and other standard-rig companions) now join the romance system - shared road flirt lines, comfort after tough fights, and a shared kiss at affinity 50.
* New: shared kiss scene fallback. Every woman_base companion without her own kiss scene now plays a warm shared kiss moment instead of being skipped.
* Changed: description corrections. Rosa var Attre and Tomira's intimate moments use the shared outdoor scene, not a bespoke bed cutscene.

v2.2.1 - Night Barks for the Full Roster & After-Combat Care
* New: night-time remarks for the rest of the roster - Rosa, Tomira, Ciri, Syanna, Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita and Orianna now have something to say after dark, each in her own voice. Every companion gets a night bark.
* Changed: comfort gestures from Philippa, Salma, Priscilla, Edna, Fringilla, Margarita and Orianna now wait until Geralt is actually hurt (health below 60% and a fight within the last five minutes) instead of firing at random on the road.
* Fix: companions no longer try to sit down mid-performance - dance and drinking sequences now take over cleanly from idle campfire poses.
* Fix: German localization was missing Priscilla's intimate prompt; Spanish and Latin American menus now show translated panel names, and the mod-menu title carries the current version again.

v2.2.0 - Universal Romance Dispatcher & Campfire Intimacy
* New: universal outdoor intimacy - female companions on the standard woman rig that had no intimate action of their own can now invite Geralt near campfires and outdoor resting spots. One shared dispatcher replaces the old per-companion classes; Anna Henrietta, Vivienne and Orianna keep their dedicated noble-rig routines.
* New: independent cooldowns per companion for the shared actions. In a multi-companion party, one companion's cooldown or rejection no longer blocks the others.
* Changed: companions settle by a lit campfire much faster when Geralt pauses nearby (about 6 seconds instead of 50).
* Fixed: intimate scenes fall back through appearances in order (naked, underwear, keep dressed) when a companion lacks a mesh, so characters with missing naked meshes no longer break the scene visually.
* New: secondary companion mesh stripping - roster companions without hardcoded specialData (Corinne Tilly, Ida Emean, Irina Renarde, Eveline Gallo, Anna Stenger, Birna Bran, etc.) dynamically query their template appearances for naked/underwear mesh variants and restore their outfits afterward.
* Fixed: post-scene afterglow barks on HUD now correctly display the speaker's name rather than an empty colon prefix.
* Fixed: disambiguated alias clashes (`anna` for Henrietta vs Stenger) and added two-pass strict-to-substring matching for console commands (`ar_intimate`, `ar_kiss`).
* Fixed: Tomira and Rosa var Attre fully unblocked for intimate invitations (Tier 4) via the universal dispatcher.
* Fixed: registered Syanna's missing Tier 4 intimate invitation action in the DLC registry.

v2.2.1 - Night Ambient Lines, Post-Combat Care Gating & Idle-Sit Fix
* New: night ambient lines for all remaining companions - Rosa var Attre, Tomira, Ciri, Syanna, Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita and Orianna now have night-time barks (same pattern as existing fillers). Every roster companion now has a night bark.
* Changed: lore-friendly gating for care/allure gestures - Salma's allure and Priscilla/Edna/Fringilla/Margarita/Orianna's care gestures now require Geralt HP ≤ 60% AND combat ended < 300s ago (post-combat care). Philippa's care gesture gained the recent-combat check (previously HP-only).
* Fixed: idle-sit vs ambient sequence conflict - ambient dance and drinking sequences now stand NPCs up from campfire/idle sit poses and block new sit jobs during performance, preventing visual conflicts.

v2.1.0 - Downtime Reactions, Ambient Dance & Cinematic Scenes
* New: downtime reactions - when Geralt meditates or sleeps in the Corvo Bianco bed, every follower within 15 m settles into a relaxed pose on a ring around him, and the closest companion says a line when the session ends. Consent-free, ~2 s debounce so quick alchemy meditations don't trigger it, ~60 s re-arm.
* New: bed partner - during bed downtime the highest-affinity female follower lies on the free side of the bed for the whole sleep session (underwear unless appearance changing is disabled), then dresses and follows again when Geralt wakes.
* New: ambient dances - Priscilla, Triss, Keira, Shani, Cerys and Tomira dance; Ciri dances in Adult mode. Philippa, Yennefer, Ves and Ciri answer with a refusal line. Taverns or a campfire at night.
* New: all-day kiss invitations for Yennefer and Keira (affinity 50) - Triss already had one.
* New: cinematic kiss variant for Triss, Yennefer, Keira and Shani - about half of kisses play the cinematic scene.
* New: intimate invitations from Yennefer, Triss and Keira now also work at an outdoor campfire and play a dedicated outdoor scene.
* New: sitting-on-ground and lying-on-grass idle poses now play start/end transition animations.
* New: German (de) localization with 269 translated strings.
* New: intimate invitations for Priscilla, Edna, Orianna, Fringilla, Margarita, Cerys, Philippa, Ves, Salma, Anarietta and Vivienne.
* Fix: the consent hold hint now shows the real bound key instead of a literal "[C]".
* Fix: staged actions, consent prompts and ambient barks no longer fire while Geralt is locked in the bed sleep interaction.

v2.0.0 - Universal Dispatcher, Expanded Roster & Immersive Gestures
* New: universal kiss and hug dispatcher. Kisses and hugs play through dedicated per-companion story scenes with the dialogue wheel removed; each companion keeps her own voice lines, animations and cameras.
* New: kisses for Triss, Yennefer, Keira, Shani, Cerys, Syanna, Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita, Rosa var Attre and Tomira. Anna Henrietta, Vivienne and Orianna have no kiss interaction; they get intimate invitations instead.
* New: Ciri has a family hug. The MCM option "Ciri: MCME Adult Mode" (off by default) unlocks her kiss and intimate invitation.
* New: intimate invitations (affinity 80) for companions with a naughty scene. Philippa, Ves, Salma, Priscilla, Edna, Fringilla and Margarita need their MCME companion pack installed; the invitation is skipped when the pack is missing. Rosa var Attre and Tomira have no intimate scene.
* New: Syanna fully integrated with Tier 1-4 interactions.
* New: Philippa, Ves, Salma, Priscilla, Edna, Fringilla and Margarita get banter, care reactions, kisses and gift requests. Orianna gets banter, care reactions and an intimate invitation.
* New: physical drinking animations when a gift drink is accepted and during tavern rounds.
* New: personalized afterglow lines for all 19 companions during the 120 seconds after a kiss or hug.
* New: 92 new localized lines in English, Polish, Spanish and Latin American Spanish.
* Fix: consent prompts appear only after the companion walks up to Geralt; a failed approach no longer counts as a rejection.
* Fix: the staged-channel watchdog now runs; combat cooldown and greeting bookkeeping corrected; Debug HUD is off by default.
* Fix: long silence after autonomous scenes (the wait now ends on speech silence); weapons and scabbards are hidden during intimate scenes.
* Fix: release package uses standard ZIP path separators and the W3MM-mergeable input file - installs correctly in Vortex and The Witcher 3 Mod Manager on Windows and Linux/Steam Deck.

v1.1.0 - Quality & Content Pass
* Fix: consent key no longer tied to the SwordSheathe binding: dedicated MCM_AR_Consent action (keyboard C / gamepad D-pad) with a dynamic key glyph in prompts. Manual install: merge MCME_AR.input.settings into Documents\The Witcher 3\input.settings (mod managers merge automatically).
* New: Spanish (es) + Latin American Spanish (esmx) localization: all 139 strings.
* New: tavern banter for Triss, Keira, Shani, Anarietta, Vivienne, Cerys (was Yennefer-only).
* New: night-time companion lines: no more silence after dark.
* New: context chatter: bad weather, horseback riding, interiors; afterglow lines after scenes and jealousy call-outs between rivals.
* New: MCM "Companion Chatter" preset (Quiet / Default / Chatty).
* New: Rosa var Attre & Tomira join the roster: banter + drink requests.

v1.0.0 - Initial Release
* Initial release for The Witcher 3 Remastered (v5.00+).
* Autonomous Companion Initiatives: Companions proactively interact with Geralt during exploration based on relationship level, surroundings, and combat events.
* Full companion agency for Yennefer, Triss, Keira, Shani, Anna Henrietta, Vivienne, and Cerys, with drink sharing for Philippa, Syanna, Ves, and Salma.
* Living Banter & Flirting: Over 30 authentic voice lines and localized subtitles triggered dynamically while traveling or exploring.
* Post-Combat Care & Triage: Companions react when weapons are sheathed after tough fights: checking wounds, sharing concern, and restoring 20-25% of Geralt's Health.
* Campfire & Tavern Downtime: Companions autonomously ask to share wine or spirits (Est Est, Erveluce, Mettina Rose, Dwarven Spirit) for +3 affinity and a thank-you.
* Natural Idle Moments: Companions pause following and settle into relaxed poses when Geralt idles, waking the moment he moves.
* Romantic Dates & Kisses: Unprompted invitations to private moments, garden strolls, and secluded suites (Passiflora, Corvo Bianco, Kaer Morhen). Kisses play cleanly without forcing manual dialogue choices.
* Player Control First: Discreet 10-second HUD prompt on [C] (SwordSheathe) - hold ~1s or double-tap to accept; walking away politely declines without penalties.
* Rivalry & Jealousy: Authentic banter friction between Yennefer and Triss when traveling together, with an in-game Jealousy Mode toggle.
* In-Game Mod Menu (MCM): Fully configurable pacing under Options -> Mods -> Autonomous Romance (initiative interval, decision tick slider, affinity speed, jealousy toggle, sandbox mode).
* Wardrobe & Underwear Controls: Convenient outfit toggling via companion interaction menus and console commands (ar_dress, ar_undress, ar_naked).
* Complete Localization: Full EN/PL localization for all prompts, HUD messages, subtitles, and menu labels (other languages fall back to English).
* Clean Architecture & Save Safety: Built with native Remaster annotations (@wrapMethod) with zero Script Merger conflicts. Progression stored in engine facts (no custom save objects; facts stay in the save).
* 24 debug console commands included (ar_status, ar_eval, ar_trigger, ar_force, ar_consent, ar_kiss, ar_hug, ar_logdump).
```