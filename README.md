<a id="readme-top"></a>

<!-- PROJECT SHIELDS -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![License][license-shield]][license-url]
[![The Witcher 3: Remastered](https://img.shields.io/badge/Witcher%203-Remastered%20v5.00%2B-blue.svg?style=for-the-badge&logo=gogdotcom)](https://www.thewitcher.com/)
[![Dependency](https://img.shields.io/badge/Dependency-MCME%20Remastered-orange.svg?style=for-the-badge)](https://www.nexusmods.com/witcher3/mods/13144)
[![Script Merger](https://img.shields.io/badge/Script%20Merger-Zero%20Conflicts-brightgreen.svg?style=for-the-badge)](#zero-script-merger-conflicts)

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <h1 align="center">The Witcher 3: Wild Hunt</h1>
  <h2 align="center">MCME: Autonomous Romance</h2>

  <p align="center">
    <strong>Autonomous, context-aware romantic initiative for companions in The Witcher 3 Remastered (v5.00+).</strong>
    <br />
    Companions observe, care, banter, tease — and invite Geralt over on their own terms.
    <br />
    <br />
    <a href="CODEBASE.md"><strong>Explore the Architecture »</strong></a>
    &middot;
    <a href="WitcherScript_Synthesized.md"><strong>WitcherScript Reference »</strong></a>
    <br />
    <br />
    <a href="#key-features">View Features</a>
    &middot;
    <a href="https://github.com/kubainter/tw3-mcme-autonomous-romance/issues/new?labels=bug">Report Bug</a>
    &middot;
    <a href="https://github.com/kubainter/tw3-mcme-autonomous-romance/issues/new?labels=enhancement">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#autonomous-companion-initiative">Autonomous Companion Initiative</a></li>
        <li><a href="#key-features">Key Features</a></li>
        <li><a href="#supported-companions">Supported Companions</a></li>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
        <li><a href="#first-run--verification">First Run &amp; Verification</a></li>
        <li><a href="#uninstallation-clean-save-guarantee">Uninstallation (Clean Save Guarantee)</a></li>
      </ul>
    </li>
    <li>
      <a href="#usage--in-game-mechanics">Usage &amp; In-Game Mechanics</a>
      <ul>
        <li><a href="#in-game-configuration-mcm-menu">In-Game Configuration (MCM Menu)</a></li>
        <li><a href="#player-consent-safeguard-c-key">Player Consent Safeguard ([C] Key)</a></li>
        <li><a href="#companion-gifting-mechanic">Companion Gifting Mechanic</a></li>
        <li><a href="#developer--console-commands-exec-functions">Console Commands (Exec Functions)</a></li>
        <li><a href="#runtime-diagnostics--logging">Runtime Diagnostics &amp; Logging</a></li>
      </ul>
    </li>
    <li>
      <a href="#architecture--technical-highlights">Architecture &amp; Technical Highlights</a>
      <ul>
        <li><a href="#codebase-file-structure">Codebase File Structure</a></li>
        <li><a href="#zero-script-merger-conflicts">Zero Script Merger Conflicts</a></li>
        <li><a href="#3-pillar-affinity-engine">3-Pillar Affinity Engine</a></li>
      </ul>
    </li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

---

## About The Project

In vanilla **Multi Companion Mod Enhanced (MCME)**, companions are passive followers who only speak when spoken to through traditional dialogue menus. Every interaction, gesture, or romantic moment requires Geralt to initiate.

**MCME Autonomous Romance** flips that dynamic entirely. Companions are given dynamic initiative and behavioral agency:
- They actively watch Geralt's combat condition and rush over to patch up his wounds when he's injured.
- They warm up by campfires — sharing wine, remarks, and witty banter.
- They initiate authentic flirts and tease Geralt using genuine, context-aware voiced lines and subtitles.
- They invite Geralt to intimate romantic moments, dates at Corvo Bianco, or quiet evenings with full player consent safeguards.
- When Geralt pauses during a journey, companions stop following, find a spot, and settle into idle poses — resuming the moment he moves on.
- Companions can even ask Geralt for a bottle of wine or spirits while relaxing at a tavern, campfire, or at Corvo Bianco.

```text
               ┌────────────────────────────────────────────────────────┐
               │     Autonomous Loop (configurable tick, ~30s default)  │
               └──────────────────────────┬─────────────────────────────┘
                                          ▼
                         ┌───────────────────────────────────┐
                         │ Safety & Context Evaluation       │
                         │ (Combat, Cutscenes, Radial Menu)  │
                         └────────────────┬──────────────────┘
                                          ▼
                         ┌───────────────────────────────────┐
                         │ Companion Roster & State Scan     │
                         │ (Distance, Campfire, Health, Time)│
                         └────────────────┬──────────────────┘
                                          ▼
                         ┌───────────────────────────────────┐
                         │ 3-Pillar Affinity & Gating Check  │
                         │ (Story Flags + Facts + Cooldowns) │
                         └────────────────┬──────────────────┘
                                          ▼
            ┌─────────────────────────────┴─────────────────────────────┐
            ▼                                                           ▼
┌─────────────────────────┐                                 ┌─────────────────────────┐
│ Tier 1 / Tier 2 Actions │                                 │ Tier 3 / Tier 4 Actions │
│ (Ambient Banter, Care,  │                                 │ (Consent Prompt: [C],   │
│  Campfire, Teasing)     │                                 │  Intimacy, Dates, Gifts)│
└─────────────────────────┘                                 └─────────────────────────┘
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Key Features

#### 1. 4-Tier Escalation Ladder
* **Tier 1 (Flirt & Ambient Banter):** Spontaneous one-liners delivered with genuine in-game voice lines and subtitles while traveling the open world or resting.
* **Tier 2 (Physical & Emotional Care):** Companions approach Geralt, express concern when he takes heavy combat damage, heal his wounds, or share a moment by glowing campfires.
* **Tier 3 (Intimate Invitations):** Companions approach and discreetly invite Geralt to pause their journey. A non-intrusive 10-second HUD prompt (`[C] Respond`) allows the player to accept or decline.
* **Tier 4 (Full Story Intimacy & Dates):** Private chambers, Corvo Bianco estate relaxation, and custom romantic scenes with authentic dialogue trees and animations.

#### 2. 3-Pillar Stateless Affinity Engine
* **Pillar 1 (Vanilla Story Projection):** Real-time evaluation of original story choices (e.g. *The Last Wish*, *Now or Never*, Fyke Isle, Shani's wedding) without altering quest progression states.
* **Pillar 2 (Safe Save Progress):** Dynamic relationship points are recorded via native engine facts (`mcme_ar_<npc>_affinity`). Unlike `saved var` objects, removing the mod leaves save files 100% clean and free of orphaned data.
* **Pillar 3 (In-Game Menu Customization):** Full MCM control over initiative pacing, affinity multipliers, and sandbox modes.

#### 3. Jealousy vs. Polyamory Mode
* **Jealousy Mode (Default):** Traveling with multiple romantic partners (e.g., Yennefer and Triss) triggers authentic rival banter and blocks intimate private dates unless Geralt is alone with his partner.
* **Polyamory Mode:** Disables jealousy rivalry checks, permitting unrestricted romantic progression regardless of party composition.

#### 4. Non-Intrusive Player Consent Safeguard
* Tier 3 & Tier 4 romantic initiatives never hijack player controls abruptly.
* When a companion initiates, an on-screen HUD prompt appears: `[C] Respond`.
* Uses vanilla `'SwordSheathe'` ([C]), preventing conflicts with MCME's default dialogue activation (`[E]`). Walking away or waiting 10 seconds politely declines without penalties.

#### 5. Configurable Pacing & Full Localization
* A dedicated **Decision Tick Interval** slider (20–160 s, default 30 s) controls how often companions evaluate new initiatives — separate from the initiative cooldown per companion.
* All player-facing text (prompts, HUD messages, voiced-line subtitles, MCM labels) ships in **English and Polish** via W3Strings; other game languages fall back to English.

#### 6. Zero Script Merger Conflicts
* Built exclusively with native Remaster annotations (`@wrapMethod`, `@addMethod`, `@addField`).
* Modifies zero vanilla or MCME `.ws` script files, ensuring clean installation alongside other mods.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Supported Companions

| Companion | Tiers | Key Triggers & Dialogue Behaviors | Romance Spots & Scenarios |
| :--- | :---: | :--- | :--- |
| **Yennefer of Vengerberg** | T1 – T4 | Post-combat scolding and wound care, campfire evenings, Triss rivalry banter. | Corvo Bianco guest room, Kaer Morhen chambers, intimate dates. |
| **Triss Merigold** | T1 – T4 | Post-combat hugs, warm campfire closeness, garden teasing, Yen rivalry banter. | Passiflora private suite, Triss's Novigrad house, Corvo Bianco. |
| **Keira Metz** | T1 – T4 | Playful banter, field remedies with a sorcerous flourish, night proposals, witch-by-the-fire remarks. | Kaer Morhen chambers, Corvo Bianco, quiet evenings by the fire. |
| **Shani** | T1 – T4 | Field medic battlefield triage, teasing compliments, late-night relaxation invitations. | Shani's clinic in Oxenfurt, moonlit meadows. |
| **Anna Henrietta** *(DLC)* | T1 – T4 | Regal wit, wound inspection, Duchess's private company invitations. | Beauclair Palace, Corvo Bianco master bedroom. |
| **Vivienne de Tabris** *(DLC)* | T1 – T4 | Subtle mystery flirts, reflective campfire moments, quiet night conversations. | Tourney Grounds pavilion, secluded Toussaint groves. |
| **Cerys an Craite** *(DLC)* | T1 – T4 | Skellige-style direct banter, warrior honor checks, blunt nighttime drinking invitations. | Kaer Trolde keep, mountain campfires. |
| **Philippa / Syanna / Ves / Salma** | Gift | Autonomous drink requests (+3 affinity) when the party relaxes. | Campfires, taverns, Corvo Bianco, quiet rest stops. |

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Built With

* **[WitcherScript Remastered v5.00+](WitcherScript_Synthesized.md)**: Native Remaster script engine (`@wrapMethod`, `@addMethod`, `@addField`).
* **[REDengine 3](https://witcher-games.fandom.com/wiki/Modding_Scripts_in_The_Witcher_3)**: The Witcher 3 core game engine and facts subsystem.
* **[Multi Companion Mod Remastered (MCMR)](https://www.nexusmods.com/witcher3/mods/13144)**: Underlying companion spawning framework and animation scene libraries.
* **[Mod Configuration Menu (MCM)](bin/config/r4game/user_config_matrix/pc/modMCME_AutonomousRomance.xml)**: In-game Flash/Scaleform settings menu integration.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Getting Started

### Prerequisites

* **The Witcher 3: Wild Hunt**: Remastered update (**v5.00+**).
* **Multi Companion Mod Remastered (MCMR)**: Installed and functioning ([Nexus Mods](https://www.nexusmods.com/witcher3/mods/13144)).
* **Debug Console Enabled**: Add `DBGConsoleOn=true` under `[General]` in `<The Witcher 3>\bin\config\base\general.ini`.

### Installation

1. Download the latest release from the [Releases](https://github.com/kubainter/tw3-mcme-autonomous-romance/releases) page.
2. Copy the mod files into your Witcher 3 root directory:
   * `Mods/modMCME_AutonomousRomance` → `<Witcher 3>/Mods/modMCME_AutonomousRomance`
   * `bin/config/r4game/user_config_matrix/pc/modMCME_AutonomousRomance.xml` → `<Witcher 3>/bin/config/r4game/user_config_matrix/pc/modMCME_AutonomousRomance.xml`
3. Launch the game. Witcher 3 will automatically compile the scripts on first startup.
4. **No Script Merger is needed.** Because the mod uses `@wrapMethod` annotations and touches zero base files, no merging is required.

### First Run & Verification

1. Load your savegame with any MCME companion recruited (e.g., Yennefer or Triss).
2. Press `~` to open the in-game debug console.
3. Type:
   ```text
   ar_status
   ```
4. Verify that the console displays the mod state, companion detection, active hours, and affinity totals.

### Uninstallation (Clean Save Guarantee)

1. Delete `Mods/modMCME_AutonomousRomance` and `bin/config/r4game/user_config_matrix/pc/modMCME_AutonomousRomance.xml`.
2. All relationship affinity progress is stored via engine gameplay facts (`mcme_ar_*`). **No orphaned classes or variables remain in your `.sav` files**, ensuring zero risk of savegame corruption.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Usage & In-Game Mechanics

### In-Game Configuration (MCM Menu)

Navigate to **Options → Gameplay / Mods → MCME - Autonomous Romance**:

| Setting | Range / Options | Default | Description |
| :--- | :---: | :---: | :--- |
| **Enable Mod** | On / Off | `On` | Global master toggle for autonomous companion logic. |
| **Initiative Interval** | 60s – 1200s | `720s` (12 min) | Per-companion cooldown between autonomous initiatives. |
| **Decision Tick Interval** | 20s – 160s (step 10s) | `30s` | How often the mod evaluates the world and picks an initiative. The timer reads this value when a game session starts, so changes apply after a save reload. |
| **Affinity Multiplier** | 0.5x – 5.0x | `1.0x` | Adjusts how quickly dynamic relationship points are earned. |
| **Jealousy Mode** | Jealousy / Polyamory | `Jealousy` | Enables rivalry banter and exclusivity, or unlocks free love. |
| **Sandbox Mode** | On / Off | `Off` | Bypasses story quest gates and maximizes affinity for instant testing. |
| **Player Consent Prompt** | On / Off | `On` | Requires `[C]` key confirmation before triggering intimate scenes. |
| **Debug HUD Messages** | On / Off | `On` | Shows `[AR]` diagnostic notifications on the HUD. |

### Player Consent Safeguard ([C] Key)

When a companion approaches Geralt for a romantic date or intimate scene:
1. A subtle HUD notification appears: `[C] Respond to <Companion>` (with a reminder to hold `[C]` ~1s or tap it twice).
2. You have **10 seconds** to respond — hold `[C]` for about a second, or double-tap it quickly.
3. On accept, the cutscene or romantic dialogue smoothly initiates.
4. If you walk more than ~12 m away or let the timer expire, the companion offers an understanding remark and the mod enters a short grace cooldown without penalty.

### Companion Gifting Mechanic

Companions can autonomously request a drink or gift — but only when the mood is right: while relaxing in a tavern, at Corvo Bianco, around a campfire, or during an idle rest stop.
- When Geralt carries fine wine or spirits in his inventory (*Est Est*, *Erveluce*, *Beauclair White*, *Mettina Rosé*, *Alcohest*, *Dwarven Spirit*), the companion approaches and asks for a drink.
- Pressing `[C]` offers the gift, consuming one bottle from inventory and awarding **+3 Affinity Points** along with a thank-you remark.
- Requests are deliberately rare (long cooldown, low initiative weight) and never trigger during normal travel or combat.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Developer & Console Commands (Exec Functions)

Open the game console (`~`) to execute diagnostic commands:

#### Core Status & Controls
| Command | Parameters | Description |
| :--- | :--- | :--- |
| `ar_test` | None | Instant sanity test verifying player entity handle and mod presence. |
| `ar_status` | None | Displays overall status: companions present, safe state, affinity, jealousy mode. |
| `ar_eval` | None | **Dry-run gate evaluation**: inspects all actions and prints eligible vs blocked reasons. |
| `ar_trigger` | None | Clears internal timers and immediately forces an autonomous decision tick. |
| `ar_force` | None | Toggles Sandbox Mode on/off directly from console. |
| `ar_consent` | None | Programmatically triggers the `[C]` consent key via console. |
| `ar_reset` | None | Resets active timers, cooldowns, and action registries. |
| `ar_devreset` | None | Complete factory reset: wipes all stored affinity facts and restarts engine loop. |

#### Relationship & Appearance Management
| Command | Parameters | Description |
| :--- | :--- | :--- |
| `ar_affinity` | `name: string, points: int` | Adds or subtracts affinity points for a given companion (e.g., `ar_affinity('yen', 25)`). |
| `ar_gift` | None | Tests the gifting logic manually, consuming a drink and awarding affinity. |
| `ar_dress` | None | Restores default companion outfits. |
| `ar_undress` | None | Switches companion to underwear mesh for intimate scenes. |
| `ar_naked` | None | Switches companion to naked mesh. |

#### Diagnostics & Audio
| Command | Parameters | Description |
| :--- | :--- | :--- |
| `ar_debug` | None | Toggles real-time decision digest messages on the HUD. |
| `ar_logdump` | `lines: int` (default 25) | Dumps the last N lines of the internal diagnostic buffer to the HUD. |
| `ar_bootlog` | None | Prints the initialization sequence and registered companion count. |
| `ar_diag` | None | Detailed memory and state dump for all companion actors. |
| `ar_line` | `name: string, lineId: int` | Plays a specific voice line ID on the targeted companion for audio testing. |
| `ar_probeanim` | `name: string, anim: string` | Probes whether a specific animation slot is supported on the companion mesh. |

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Runtime Diagnostics & Logging

The mod logs through two independent channels:

1. **TW3SE dev channel (recommended for development):** every `[AR]` line lands in `bin\x64_dx12\tw3se\out\ar_log.txt` and on the `\\.\pipe\tw3se` named pipe — no launch flags needed. `scripts\run_game_dev.bat` starts the game plus a live-follow window; `scripts\tw3se_pipe.ps1 -Cmd "exec ar_status()"` runs console commands without opening `~`.
2. **Vanilla `scriptslog.txt`:** launch with `scripts\run_game_debug.bat` (`-debugscripts` only — **never add `-net`**, it redirects output to a dead debug socket and kills the file). Verify `user.settings` contains:
   ```ini
   [Scripts]
   DebugScriptsLogDir=Documents\The Witcher 3
   DebugScriptsForceFlush=true
   ```
3. Autonomous Romance logs under the channel `MCME_Romance`. Note: the `[AR]` diagnostic channel is intentionally English-only in every game language.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Architecture & Technical Highlights

For a complete architectural deep-dive, consult **[CODEBASE.md](CODEBASE.md)** and **[ARCHITECTURE.md](ARCHITECTURE.md)**.

### Codebase File Structure

```text
Mods/modMCME_AutonomousRomance/content/scripts/local/romance/
├── MCM_RomanceCore.ws          # Configurable decision tick + 10s ambient loop, idle-suspend jobs, safety checks, input listener
├── MCM_RomanceAffinity.ws      # Stateless 3-pillar affinity resolver & MCM config wrapper
├── MCM_RomanceInteraction.ws   # Interaction base classes, Action Registry, consent loop
├── MCM_RomanceActions_Main.ws  # Actions & authentic voice lines for Yen, Triss, Keira, Shani
├── MCM_RomanceActions_DLC.ws   # Modular actions for Anna Henrietta, Vivienne, Cerys
├── MCM_RomanceQoL.ws           # Flash UI outfit injection in MCME, outfit persistence, gifts
└── MCM_RomanceTw3seDev.ws      # TW3SE developer layer (native C++ imports, IPC pipe, key polling)
```

### Zero Script Merger Conflicts

By utilizing Remaster native annotations:
- `@wrapMethod(CR4Player) function InitRemasterSettings()` bootstraps the lifecycle cleanly without colliding with older mods wrapping `CPlayerInput.Initialize`.
- Base game script files remain untouched, leaving your Script Merger tree conflict-free.

### 3-Pillar Affinity Formula

$$\text{Affinity}_{\text{Total}} = \text{Base}_{\text{Story}} + \left(\text{Earned}_{\text{Facts}} \times \text{Multiplier}_{\text{MCM}}\right)$$

- **$\text{Base}_{\text{Story}}$:** Computed in real-time by inspecting vanilla quest choice facts (e.g., *The Last Wish*, *Now or Never*).
- **$\text{Earned}_{\text{Facts}}$:** Earned through companion gifts, campfire moments, and shared battles.
- **$\text{Multiplier}_{\text{MCM}}$:** Configured in the in-game MCM menu (0.5x to 5.0x).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Contributing

Contributions are welcome! Whether you have ideas for new companion interactions, dialogue lines, or bug reports, feel free to open an issue or submit a pull request:

1. Fork the project.
2. Create your feature branch (`git checkout -b feature/NewCompanionAction`).
3. Commit your changes (`git commit -m 'Add new campfire dialogue for Keira'`).
4. Push to the branch (`git push origin feature/NewCompanionAction`).
5. Open a Pull Request.

You can also suggest new companion ideas and report bugs directly via [GitHub Issues](https://github.com/kubainter/tw3-mcme-autonomous-romance/issues).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## License

Distributed under the **Apache License 2.0**. See [`LICENSE`](LICENSE) for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Acknowledgments

* **[CD Projekt Red](https://www.cdprojektred.com/)** for creating *The Witcher 3: Wild Hunt* and REDengine 3.
* **Jamezo97 & Kingsegg** for creating the original *Multi Companion Mod* and *MCME*.
* **The Witcher 3 Modding Community** on Nexus Mods, Discord, and Fandom Wiki.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/kubainter/tw3-mcme-autonomous-romance.svg?style=for-the-badge
[contributors-url]: https://github.com/kubainter/tw3-mcme-autonomous-romance/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/kubainter/tw3-mcme-autonomous-romance.svg?style=for-the-badge
[forks-url]: https://github.com/kubainter/tw3-mcme-autonomous-romance/network/members
[stars-shield]: https://img.shields.io/github/stars/kubainter/tw3-mcme-autonomous-romance.svg?style=for-the-badge
[stars-url]: https://github.com/kubainter/tw3-mcme-autonomous-romance/stargazers
[issues-shield]: https://img.shields.io/github/issues/kubainter/tw3-mcme-autonomous-romance.svg?style=for-the-badge
[issues-url]: https://github.com/kubainter/tw3-mcme-autonomous-romance/issues
[license-shield]: https://img.shields.io/github/license/kubainter/tw3-mcme-autonomous-romance.svg?style=for-the-badge
[license-url]: https://github.com/kubainter/tw3-mcme-autonomous-romance/blob/main/LICENSE
