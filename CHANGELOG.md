# MCME Autonomous Romance - Changelog

All notable changes to this project will be documented in this file.

# v2.0.0 - Universal Dispatcher, Expanded Roster & Immersive Gestures

Major integration update delivering universal clean scene dispatching, expanding the autonomous romance roster to 19 companions, adding physical drinking animations, and personalizing companion afterglow across the entire cast.

## Features & Improvements
- **Universal Kiss & Hug Dispatcher (Zero Soft-Locks):**
  - Kiss interactions for all companions (Triss, Yennefer, Keira, Shani, Anna Henrietta, Vivienne, Cerys, Syanna, Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita, Orianna, Rosa, Tomira) route to the universal clean scene `PlayKissScene(npc)` with zero dialogue wheel prompts.
  - Ciri joins the roster with a warm family embrace via `PlayHugScene(npc)` using `ciriFollowWithHug.w2scene` cleaned of `PChoice` blocks and injected into `DLCmod_spawn_companions\content\blob0.bundle`.
  - Companion post-scene reactions (`PlayPostKissReaction`, `PlayPostHugReaction`) with distinct, lore-friendly in-character lines for all companions.
- **Physical Drinking Animations (Gifts & Taverns):**
  - When Geralt accepts a drink request via `[C]` in `MCM_AR_GiftRequest_Base`, the companion now physically raises her bottle or goblet and drinks (`PlayDrinkingAnimation` probing `woman_wine_tasting` / `man_work_drinking`) before speaking her thank-you line.
  - The same drinking animation triggers during tavern rounds in all `*_tavern_drink` interactions (Triss, Keira, Shani, Anna Henrietta, Vivienne, Cerys).
  - Safe fallback probe: models with non-standard skeletons (such as Salma's succubus model) skip the animation cleanly without errors or stalling.
- **Personalized Afterglow Walk (All 19 Companions):**
  - Replaced the generic line (*"That was... nice. Don't be a stranger."*) in `MCM_AR_AfterglowBark` with unique, authentic, in-character remarks for each companion during joint travel within 120s of a kiss or hug.
  - Specific lines tailored to each personality: Yennefer, Triss, Keira, Shani, Anna Henrietta, Vivienne, Cerys, Syanna, Ciri, Rosa var Attre, Tomira, Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita, and Orianna.
- **Roster Expansion (Strict Core CDPR Naked Mesh Audit):**
  - **Syanna:** Full T1-T4 romance including T1 banter, T2 post-combat reaction, T3 universal kiss, and T4 cloud sex intimate scene (`dlc\mod_spawn_companions\naughty\syanna\anywhere.w2scene`) using native Core CDPR appearances (`syanna_naked`).
  - **Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita, Orianna:** Full T1 (ambient barks), T2 (care / help gestures), T3 (universal kiss), and custom gift requests (`MCM_AR_GiftRequest_Base`). Strictly no fake T4 requiring third-party nude mods.
  - **Rosa var Attre & Tomira:** Upgraded to include Tier 3 Universal Kiss interactions.
  - **Ciri:** Tier 3 family hug interaction.
- **Story Affinity Integration:**
  - Expanded `GetBaseStoryAffinity()` tracking quest milestones for Ciri, Syanna, Philippa, Salma, Ves, Priscilla, Edna, Fringilla, Margarita, and Orianna.
- **Localization:**
  - 92 new strings added across English, Polish, Spanish (`es`), and Latin American Spanish (`esmx`): IDs `2118800143` through `2118800234` (total 231 localized entries). All binary `.w3strings` updated.

---

# v1.1.0 - Quality & Content Pass (E1+E2)

Community-requested fixes and a broad companion-content expansion.

## Bug Fixes
- **Consent key fix:** consent prompts no longer depend on the vanilla `SwordSheathe` binding. New dedicated input action `MCM_AR_Consent` (keyboard **C**, gamepad **D-pad Left/Right**) via shipped `MCME_AR.input.settings`; prompts now render the actual bound key/glyph through `ReplaceTagsToIcons`. `SwordSheathe` remains as fallback. The binding covers the five base gameplay contexts (Exploration, Combat, Horse, Boat, Swimming) as well as overlay contexts that sit on top of the input stack while a prompt is showing: `Scene`, `ScriptedAction`, `SCENE_IS_STARTING_HACK`, `JumpClimb`, `Diving`, `ThrowHold`, `ThrowHoldChain`, `LootPopup`, `BoatPassenger` and the Ciri replacer contexts (gamepad bindings intentionally skip `Scene`, where the D-pad drives dialog choices). Manual installers must merge the shipped input file into `Documents\The Witcher 3\input.settings` (mod managers do it automatically).
- **Consent double-tap:** fast double-taps could be lost: the tap counter used only ~65-100ms key polling edges. It now takes `max(VK edges, input-event count)` so hardware presses always register; the input listener also deduplicates the same physical press firing both registered actions within 0.12s (prevents a single tap counting as two).
- **Consent hold & window:** the consent window is now at least 20s (was 10s): `DisplayHudMessage` queues behind the companion's spoken request line (~4-5s on screen), so the prompt often rendered at the end of the window and presses landed after the timeout. Hold detection uses a per-action event latch (`MCM_AR_Consent` / `SwordSheathe` separately) so a synthetic release from the gamepad `Duration` binding cannot cancel a real hold; in dev builds the VK probe and event latch work together, so gamepad hold works there too.
- **MCM header:** the mod section title showed the raw key (`##preset_Mods_AutonomousRomance`). Added the missing localization key with the mod name and version label.
- **Tavern detection:** `player_in_inn` does not fire in all taverns (e.g. Dandelion's Chameleon). `MCM_AR_IsInTavern` now falls back to an interior + innkeeper entity scan (entity tags / `*_inn*` template paths) so `*_tavern_drink` actions work in uncovered inns.

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
- **Clean Save Guarantee:** Earned relationship points are stored as native engine facts (`mcme_ar_<npc>_affinity`). Zero `saved var` objects, leaving `.sav` files 100% clean upon uninstallation.
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
- `Mods/modMCME_AutonomousRomance/content/*.w3strings` (18 languages)

---

## [Nexus Mods Changelog Snippet]

> *Ready-to-paste text for the Nexus Mods "Change Log" tab:*

```text
v2.0.0 - Universal Dispatcher, Expanded Roster & Immersive Gestures
* New: Universal Kiss & Hug Dispatcher: all kiss interactions play via a universal clean scene with zero dialogue wheel prompts.
* New: Ciri joins the roster with a warm family embrace interaction (PlayHugScene) without dialogue wheels.
* New: Physical Drinking Animations: companions physically raise a bottle or goblet and drink during wine gifting ([C]) and tavern rounds.
* New: Personalized Afterglow Walk: every one of the 19 companions speaks a unique, in-character line during joint travel in the 120-second window after a romantic scene or embrace.
* New: Lore-friendly afterglow remarks after kisses and hugs for every companion.
* New: Syanna fully integrated into Autonomous Romance with full Tier 1-4 interactions, including cloud sex date at NaughtyPoints with native CDPR assets.
* New: 8 core companions expanded to T1 (banter), T2 (care), T3 (universal kiss), and custom gift requests: Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita, Orianna.
* New: Rosa var Attre and Tomira upgraded to Tier 3 Universal Kiss.
* New: 92 new localized lines in English, Polish, Spanish, and Latin American Spanish (total 231 localized strings across 18 game languages).

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
* Clean Architecture & Save Safety: Built with native Remaster annotations (@wrapMethod) with zero Script Merger conflicts. Progression stored in engine facts (100% clean saves on uninstall).
* 24 debug console commands included (ar_status, ar_eval, ar_trigger, ar_force, ar_consent, ar_kiss, ar_hug, ar_logdump).
```
