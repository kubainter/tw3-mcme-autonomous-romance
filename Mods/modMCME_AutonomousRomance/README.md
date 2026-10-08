# MCME Autonomous Romance (Witcher 3 Next-Gen)

**Autonomous Romance Initiative for Multi Companion Mod Enhanced (MCME)**  
*Next-Gen Native Architecture (v4.04 / v5.00+)*

[![Compatibility](https://img.shields.io/badge/Witcher%203-Next--Gen%20v4.04%20%2F%20v5.00%2B-blue.svg)](#)
[![Dependency](https://img.shields.io/badge/Dependency-MCME%20Remastered-orange.svg)](#)
[![Scripts](https://img.shields.io/badge/Script%20Merger-Zero%20Conflicts-brightgreen.svg)](#)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](#)

---

## 📖 Overview

In vanilla **Multi Companion Mod Enhanced (MCME)**, companion interactions are purely passive: Geralt must manually approach a companion and navigate dialog menus to trigger conversations, gestures, or romantic scenes.

**MCME Autonomous Romance** brings companions to life by introducing **autonomous, context-aware romantic and emotional initiative**. Companions will naturally observe their surroundings, react to combat fatigue and low health, cozy up near campfires at night, exchange banter, playfully tease Geralt, and invite him to intimate moments.

---

## ✨ Key Features

### 1. 4-Tier Escalation Ladder
* **Tier 1 (Flirt & Banter):** Atmospheric one-liners spoken naturally with in-game voiced lines and subtitles while traveling or resting.
* **Tier 2 (Physical & Emotional Care):** Companions approach Geralt, express concern when he is wounded after combat, apply healing gestures, or sit down by campfires.
* **Tier 3 (Intimate Invitations):** Companions approach and invite Geralt to pause their journey. A discrete HUD prompt (`[C] Respond`) appears for 10 seconds, letting the player choose whether to accept.
* **Tier 4 (Full Story Scenes):** Relaxing in special locations (such as Corvo Bianco) can trigger intimate scenes with full consent safeguards.

### 2. 3-Pillar Stateless Affinity Engine
* **Pillar 1 (Vanilla Story Projection):** Real-time evaluation of original story choices (e.g. *The Last Wish*, *Now or Never*, Fyke Isle, Shani's wedding) without altering quest states.
* **Pillar 2 (Safe Save Progress):** Dynamic relationship points are recorded via safe engine facts (`mcme_ar_<npc>_affinity`). Unlike `saved var` objects, removing the mod leaves save files 100% clean and intact.
* **Pillar 3 (In-Game Menu Customization):** Full MCM control over pacing, affinity gains, and sandbox mode.

### 3. Jealousy vs. Polyamory Mode
* **Jealousy Mode (Default):** Having multiple romantic partners (e.g., Yennefer and Triss) in the party causes them to exchange witty rival banter and prevents private intimacy unless alone.
* **Polyamory Mode:** Disables jealousy checks, allowing unrestricted intimacy regardless of party composition.

### 4. Zero Script Merger Conflicts
Built exclusively with native Next-Gen annotations (`@wrapMethod`, `@addMethod`, `@addField`). Does not overwrite any vanilla or MCME script files, eliminating merge conflicts.

---

## 👥 Supported Companions

| Companion | Tiers | Key Triggers & Behaviors |
| :--- | :---: | :--- |
| **Yennefer of Vengerberg** | T1 – T4 | Post-combat concern & Quen, campfire evenings, Corvo Bianco intimacy, Triss jealousy snark. |
| **Triss Merigold** | T1 – T4 | Post-combat hugs, campfire warmth, garden kisses, Yen jealousy snark. |
| **Keira Metz** | T1 – T4 | Playful teasing, field medical checks, night proposals, witch-by-the-fire remarks. |
| **Shani** | T1 – T4 | Medic battlefield care, teasing compliments, late-night relaxation offers. |
| **Anna Henrietta** *(DLC)* | T1 – T4 | Regal wit, prideful wound checks, Duchess's private company invitations. |
| **Vivienne de Tabris** *(DLC)* | T1 – T4 | Subtle mystery flirts, reflective campfire moments. |
| **Cerys an Craite** *(DLC)* | T1 – T4 | Skellige-style direct banter, warrior honor wound checks, blunt nighttime invitations. |

---

## ⚙️ In-Game Configuration (MCM Menu)

Navigate to **Options → Gameplay / Mods → MCME - Autonomous Romance**:

* **Enable Mod:** Toggle the entire autonomous system on/off.
* **Initiative Interval:** Slider from 60s (1 min) to 1200s (20 min). *Default: 720s (12 min)*.
* **Affinity Multiplier:** Adjust relationship progression speed from 0.5x to 5.0x.
* **Jealousy Mode:** Toggle between Jealousy (rivalry) and Polyamory (free love).
* **Sandbox Mode:** Instantly unlock all tiers and romantic scenes regardless of quest decisions.
* **Player Consent Prompt:** Toggle whether Tier 3 scenes require pressing `[C]` or trigger automatically upon approach (Tier 4 always requires `[C]`).

---

## 📂 Installation

1. Make sure **Multi Companion Mod Enhanced (MCME)** Remastered is installed and working.
2. Extract or copy the folders into your Witcher 3 root directory:
   * `Mods/modMCME_AutonomousRomance` → `<Witcher 3>/Mods/modMCME_AutonomousRomance`
   * `bin/config/r4game/user_config_matrix/pc/modMCME_AutonomousRomance.xml` → `<Witcher 3>/bin/config/r4game/user_config_matrix/pc/modMCME_AutonomousRomance.xml`
3. Launch the game. Witcher 3 will automatically compile the scripts on first startup.

---

## 🧩 Architecture & Source Structure

> Full mod FLOW, gating, MCME/vanilla API map & roadmap: **[ARCHITECTURE.md](ARCHITECTURE.md)**

```
modMCME_AutonomousRomance/
└── content/
    └── scripts/
        └── local/
            └── romance/
                ├── MCM_RomanceCore.ws          # 4s game loop, safety checks, context tracker, input listener
                ├── MCM_RomanceAffinity.ws      # Stateless 3-pillar affinity resolver & MCM config wrapper
                ├── MCM_RomanceInteraction.ws   # Interaction base classes, Action Registry, consent loop
                ├── MCM_RomanceActions_Main.ws  # Actions & authentic voice lines for Yen, Triss, Keira, Shani
                └── MCM_RomanceActions_DLC.ws   # Modular actions for Anna Henrietta, Vivienne, Cerys
```

---

## 📜 Credits & License

* Developed for the Witcher 3 Next-Gen modding community.
* Built on top of **Multi Companion Mod Enhanced** by *Jamezo97* and contributors.
* Licensed under the **MIT License**.
