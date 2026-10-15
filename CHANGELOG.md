# MCME Autonomous Romance — Changelog

All notable changes to this project will be documented in this file.

---

# v1.0.0 — Initial Release (The Witcher 3 Remastered v5.00+)

Initial public release of **MCME Autonomous Romance**, introducing autonomous companion initiative, context-aware banter, post-combat care, campfire drink sharing, and consent-guarded romantic dates for Multi Companion Mod Remastered companions.

## Features & Technical Highlights

### 1. Dynamic Interaction & Romance Progression
- **Exploration Banter & Flirting:** Over 30 authentic in-game voice lines and localized subtitles triggered dynamically while exploring the open world.
- **Post-Combat Care & Triage:** Companions react when weapons are sheathed after heavy combat damage. Yennefer scolds Geralt's recklessness and mends him, Triss rushes over with a healing hug, Shani performs field triage, Keira patches him up with a sorcerous flourish, and Anna Henrietta inspects Geralt with regal pride. The healers restore 20–25% of Geralt's Health bar in real-time.
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
- Companions autonomously request a drink in relaxed contexts only — taverns, Corvo Bianco, campfires, or idle rest stops (`blocked: not_relaxed` otherwise).
- Requests stay deliberately rare: low initiative weight and a 60-minute cooldown.
- Pressing `[C]` offers the beverage, consumes 1 bottle from inventory, awards **+3 Affinity**, and draws a thank-you line. Supported gifts: *Est Est*, *Erveluce*, *Beauclair White*, *Mettina Rosé*, *Alcohest*, *Dwarven Spirit*.

### 6. Wardrobe & Appearance Controls
- Integrated directly into the MCM options menu.
- Switch and persist companion outfits between default meshes, underwear, and naked models without manual console typing.

### 7. Engine Compatibility & Zero Script Merger Conflicts
- Built using Remaster native annotations (`@wrapMethod`, `@addMethod`, `@addField`).
- Modifies zero vanilla script files, ensuring zero Script Merger conflicts.
- Bootstraps cleanly via `@wrapMethod(CR4Player) function InitRemasterSettings()` to bypass the Next-Gen/Remaster `@wrapMethod` shadowing priority bug.

### 8. Configurable Decision Tick & Split Timers
- The decision tick is player-tunable: MCM slider `MCM_AR_TickInterval`, 20–160 s in 10 s steps (default 30 s), under **Options → Mods → Autonomous Romance**.
- The ambient/bark channel runs on its own fixed 10 s timer, ensuring bark responsiveness and idle poses do not lag behind longer tick intervals.
- The timer interval is read on game session start — slider adjustments apply after a save reload.

### 9. Natural Idle Poses & Downtime
- When Geralt stands still for ~50 s, companions pause their follow routine, walk to a nearby spot, and settle into relaxed idle poses on a staggered delay.
- They wake instantly when Geralt moves (>1.5 m) or the context becomes unsafe. Idle jobs are fully lifecycle-safe around scenes and interactions.

### 10. Complete EN/PL Localization
- Every player-facing string — prompts, HUD messages, subtitles, gift requests, MCM labels — resolves through `en.w3strings.csv` / `pl.w3strings.csv` (87 keys) with defensive English fallbacks.
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
v1.0.0 — Initial Release
* Initial release for The Witcher 3 Remastered (v5.00+).
* Autonomous Companion Initiatives: Companions proactively interact with Geralt during exploration based on relationship level, surroundings, and combat events.
* Full companion agency for Yennefer, Triss, Keira, Shani, Anna Henrietta, Vivienne, and Cerys, with drink sharing for Philippa, Syanna, Ves, and Salma.
* Living Banter & Flirting: Over 30 authentic voice lines and localized subtitles triggered dynamically while traveling or exploring.
* Post-Combat Care & Triage: Companions react when weapons are sheathed after tough fights — checking wounds, sharing concern, and restoring 20–25% of Geralt's Health.
* Campfire & Tavern Downtime: Companions autonomously ask to share wine or spirits (Est Est, Erveluce, Mettina Rosé, Dwarven Spirit) for +3 affinity and a thank-you.
* Natural Idle Moments: Companions pause following and settle into relaxed poses when Geralt idles, waking the moment he moves.
* Seamless Romantic Dates & Kisses: Unprompted invitations to private moments, garden strolls, and secluded suites (Passiflora, Corvo Bianco, Kaer Morhen). Kisses play cleanly without forcing manual dialogue choices.
* Player Control First: Discreet 10-second HUD prompt on [C] (SwordSheathe) - hold ~1s or double-tap to accept; walking away politely declines without penalties.
* Rivalry & Jealousy: Authentic banter friction between Yennefer and Triss when traveling together, with an in-game Jealousy Mode toggle.
* In-Game Mod Menu (MCM): Fully configurable pacing under Options -> Mods -> Autonomous Romance (initiative interval, decision tick slider, affinity speed, jealousy toggle, sandbox mode).
* Wardrobe & Underwear Controls: Integrated cleanly into the in-game MCM options menu.
* Complete Localization: Full EN/PL localization for all prompts, HUD messages, subtitles, and menu labels (other languages fall back to English).
* Clean Architecture & Save Safety: Built with native Remaster annotations (@wrapMethod) with zero Script Merger conflicts. Progression stored in engine facts (100% clean saves on uninstall).
* 22 debug console commands included (ar_status, ar_eval, ar_trigger, ar_force, ar_consent, ar_logdump).
```
