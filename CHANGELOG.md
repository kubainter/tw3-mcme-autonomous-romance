# MCME Autonomous Romance - Changelog

All notable changes to this project will be documented in this file.

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
