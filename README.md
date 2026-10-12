<a id="readme-top"></a>

<!-- PROJECT SHIELDS -->
[![Stargazers][stars-shield]][stars-url]
[![Forks][forks-shield]][forks-url]
[![Issues][issues-shield]][issues-url]
[![License][license-shield]][license-url]
[![Compatibility](https://img.shields.io/badge/Witcher%203-Next--Gen%20v5.00%2B-blue.svg)](https://github.com/kubainter/tw3-mcme-autonomous-romance#requirements)
[![Dependency](https://img.shields.io/badge/Dependency-MCME%20Remastered-orange.svg)](https://github.com/kubainter/tw3-mcme-autonomous-romance#requirements)
[![Script Merger](https://img.shields.io/badge/Script%20Merger-Zero%20Conflicts-brightgreen.svg)](https://github.com/kubainter/tw3-mcme-autonomous-romance#4-zero-script-merger-conflicts)

<!-- PROJECT HEADER -->
<br />
<div align="center">
  <!-- Add a screenshot/logo here: <img src="images/screenshot.png" alt="Screenshot" width="640"> -->

  <h3 align="center">MCME Autonomous Romance</h3>

  <p align="center">
    Autonomous, context-aware romantic initiative for companions in The Witcher 3 Next-Gen.<br />
    Companions observe, care, banter, tease. And they invite Geralt over on their own.
    <br />
    <a href="ARCHITECTURE.md"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/kubainter/tw3-mcme-autonomous-romance/issues/new">Report Bug</a>
    &middot;
    <a href="https://github.com/kubainter/tw3-mcme-autonomous-romance/issues/new">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About the project</a>
      <ul>
        <li><a href="#key-features">Key features</a></li>
        <li><a href="#supported-companions">Supported companions</a></li>
        <li><a href="#built-with">Built with</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting started</a>
      <ul>
        <li><a href="#requirements">Requirements</a></li>
        <li><a href="#installation">Installation</a></li>
        <li><a href="#uninstallation">Uninstallation</a></li>
      </ul>
    </li>
    <li>
      <a href="#usage">Usage</a>
      <ul>
        <li><a href="#in-game-configuration-mcm-menu">MCM configuration</a></li>
        <li><a href="#debug--diagnostics">Debug &amp; diagnostics</a></li>
      </ul>
    </li>
    <li><a href="#architecture--source-structure">Architecture</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#credits">Credits</a></li>
  </ol>
</details>

---

## About the project

In vanilla **Multi Companion Mod Enhanced (MCME)**, companions wait for you. Every conversation, gesture, or romance scene starts the same way: Geralt walks up, you pick a line from a dialog menu.

**MCME Autonomous Romance** flips that around. Companions get their own initiative: they watch what's going on, fuss over Geralt when he's wounded after a fight, settle in by the campfire at night, trade banter, tease him, and invite him to intimate moments.

*Remaster Native Architecture (v5.00+)*

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Key features

#### 1. 4-tier escalation ladder

* **Tier 1 (Flirt & Banter):** One-liners delivered with real in-game voice lines and subtitles while traveling or resting.
* **Tier 2 (Physical & Emotional Care):** Companions approach Geralt, express concern when he is wounded after combat, apply healing gestures, or sit down by campfires.
* **Tier 3 (Intimate Invitations):** Companions approach and invite Geralt to pause their journey. A discreet HUD prompt (`[C] Respond`) appears for 10 seconds, letting the player choose whether to accept.
* **Tier 4 (Full Story Scenes):** Relaxing in special locations (such as Corvo Bianco) can trigger intimate scenes with full consent safeguards.

#### 2. 3-pillar stateless affinity engine

* **Pillar 1 (Vanilla Story Projection):** Real-time evaluation of original story choices (e.g. *The Last Wish*, *Now or Never*, Fyke Isle, Shani's wedding) without altering quest states.
* **Pillar 2 (Safe Save Progress):** Dynamic relationship points are recorded via safe engine facts (`mcme_ar_<npc>_affinity`). Unlike `saved var` objects, removing the mod leaves save files 100% clean.
* **Pillar 3 (In-Game Menu Customization):** Full MCM control over pacing, affinity gains, and sandbox mode.

#### 3. Jealousy vs. polyamory mode

* **Jealousy Mode (Default):** Having multiple romantic partners (e.g., Yennefer and Triss) in the party causes them to exchange witty rival banter and prevents private intimacy unless alone.
* **Polyamory Mode:** Disables jealousy checks, allowing unrestricted intimacy regardless of party composition.

#### 4. Zero Script Merger conflicts

Built exclusively with native Remaster annotations (`@wrapMethod`, `@addMethod`, `@addField`). Does not overwrite any vanilla or MCME script files, eliminating merge conflicts.

### Supported companions

| Companion | Tiers | Key Triggers & Behaviors |
| :--- | :---: | :--- |
| **Yennefer of Vengerberg** | T1 – T4 | Post-combat concern & Quen, campfire evenings, Corvo Bianco intimacy, Triss jealousy snark. |
| **Triss Merigold** | T1 – T4 | Post-combat hugs, campfire warmth, garden kisses, Yen jealousy snark. |
| **Keira Metz** | T1 – T4 | Playful teasing, field medical checks, night proposals, witch-by-the-fire remarks. |
| **Shani** | T1 – T4 | Medic battlefield care, teasing compliments, late-night relaxation offers. |
| **Anna Henrietta** *(DLC)* | T1 – T4 | Regal wit, prideful wound checks, Duchess's private company invitations. |
| **Vivienne de Tabris** *(DLC)* | T1 – T4 | Subtle mystery flirts, reflective campfire moments. |
| **Cerys an Craite** *(DLC)* | T1 – T4 | Skellige-style direct banter, warrior honor wound checks, blunt nighttime invitations. |

### Built with

* [WitcherScript](WitcherScript_Synthesized.md): Next-Gen native scripting (`@wrapMethod` / `@addMethod` / `@addField`)
* [Multi Companion Mod Remastered (MCMR)](https://www.nexusmods.com/witcher3/mods/13144): companion framework & scene library
* MCM (Mod Configuration Menu): in-game settings
* TW3SE (Script Extender): optional dev layer, isolated in `MCM_RomanceTw3seDev.ws`

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Getting started

### Requirements

* **The Witcher 3: Wild Hunt**: Next-Gen update, **v5.00+**
* **Multi Companion Mod Remastered (MCMR)**: installed and working ([Nexus Mods](https://www.nexusmods.com/witcher3/mods/13144))

### Installation

1. Extract or copy the folders into your Witcher 3 root directory:
   * `Mods/modMCME_AutonomousRomance` → `<Witcher 3>/Mods/modMCME_AutonomousRomance`
   * `bin/config/r4game/user_config_matrix/pc/modMCME_AutonomousRomance.xml` → `<Witcher 3>/bin/config/r4game/user_config_matrix/pc/modMCME_AutonomousRomance.xml`
2. Launch the game. Witcher 3 will automatically compile the scripts on first startup.
3. No Script Merger run needed. The mod overwrites zero vanilla files.

### Uninstallation

1. Delete `Mods/modMCME_AutonomousRomance` and the `modMCME_AutonomousRomance.xml` config file.
2. That's it. Affinity progress lives in safe engine facts, so **your save files stay 100% clean**. No orphaned data, no corrupted saves.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Usage

### In-game configuration (MCM menu)

Navigate to **Options → Gameplay / Mods → MCME - Autonomous Romance**:

* **Enable Mod:** Toggle the entire autonomous system on/off.
* **Initiative Interval:** Slider from 60s (1 min) to 1200s (20 min). *Default: 720s (12 min)*.
* **Affinity Multiplier:** Adjust relationship progression speed from 0.5x to 5.0x.
* **Jealousy Mode:** Toggle between Jealousy (rivalry) and Polyamory (free love).
* **Sandbox Mode:** Instantly unlock all tiers and romantic scenes regardless of quest decisions.
* **Player Consent Prompt:** Toggle whether Tier 3 scenes require pressing `[C]` or trigger automatically upon approach (Tier 4 always requires `[C]`).

### Debug & diagnostics

Open the game console (`~`) and run `exec` functions. The most useful for checking why the mod is or isn't triggering:

| Command | What it does |
| :--- | :--- |
| `ar_status` | Mod state: enabled/sandbox/jealousy, game hour, per-NPC affinity |
| `ar_eval` | Dry-run: eligible + blocked reason for **every** action of every NPC |
| `ar_trigger` | Resets cooldowns and forces an immediate processing tick |
| `ar_debug` | Toggles on-HUD tick digest |
| `ar_logdump(N)` | Prints last N lines of the mod's log ring-buffer to HUD |

Runtime logs go to `Documents\The Witcher 3\scriptslog.txt` (requires launching with `-net -debugscripts`).

Full command list (~20 more, incl. `ar_force`, `ar_affinity`, `ar_gift`, `ar_dress`): **[ARCHITECTURE.md, §14 Diagnostyka](ARCHITECTURE.md#14-diagnostyka)**

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Architecture & source structure

> Full mod FLOW, gating, consent loop, MCME/vanilla API map & roadmap: **[ARCHITECTURE.md](ARCHITECTURE.md)**

```text
modMCME_AutonomousRomance/
└── content/
    └── scripts/
        └── local/
            └── romance/
                ├── MCM_RomanceCore.ws          # 4s game loop, safety checks, context tracker, input listener
                ├── MCM_RomanceAffinity.ws      # Stateless 3-pillar affinity resolver & MCM config wrapper
                ├── MCM_RomanceInteraction.ws   # Interaction base classes, Action Registry, consent loop
                ├── MCM_RomanceActions_Main.ws  # Actions & authentic voice lines for Yen, Triss, Keira, Shani
                ├── MCM_RomanceActions_DLC.ws   # Modular actions for Anna Henrietta, Vivienne, Cerys
                ├── MCM_RomanceQoL.ws           # Flash UI outfit injection in MCME, outfit persistence, gifts
                └── MCM_RomanceTw3seDev.ws      # TW3SE developer layer (native C++ imports, IPC pipe, key polling)
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Roadmap

- [ ] Stabilize & verify the base release in-game (diagnostics via `ar_status` / `ar_eval` + `scriptslog.txt`)
- [ ] Gift mechanic: companions request a drink, player accepts with `[C]` (+affinity, per-NPC preferences)
- [ ] Night-time Tier-1 flirt filler (whispered one-liners when daytime scenes are filtered out)
- [ ] Extend roster toward all romance-capable MCME companions (see ARCHITECTURE §16.C)

See [TODO.md](TODO.md) and [ARCHITECTURE.md, §16 Roadmapa](ARCHITECTURE.md#16-roadmapa) for the full plan, plus the [open issues](https://github.com/kubainter/tw3-mcme-autonomous-romance/issues) for proposed features and known bugs.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Contributing

Contributions are welcome, especially new companion actions, curated voice lines, and testing. The codebase is WitcherScript (Next-Gen), so a few project rules apply:

1. Read the extension conventions in [ARCHITECTURE.md, §17 Konwencje i jak rozszerzać](ARCHITECTURE.md#17-konwencje-i-jak-rozszerza%C4%87) and the language reference [WitcherScript_Synthesized.md](WitcherScript_Synthesized.md).
2. **Always compile-check your `.ws` changes** before submitting. The repo ships a zero-error toolchain:
   * `scripts/precheck_syntax.ps1`: sub-second structural check
   * `scripts/test_compile.ps1`: full game-engine compile test (exit code 0 = clean)
3. Fork the project, create a feature branch, open a Pull Request. Or skip the ceremony and just open an [issue](https://github.com/kubainter/tw3-mcme-autonomous-romance/issues) with the "enhancement" tag.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## License

Distributed under the **Apache License 2.0**. See [LICENSE](LICENSE) for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---

## Credits

* Developed for the Witcher 3 modding community.
* Built on top of **Multi Companion Mod Remastered**, which continues the lineage of *Jamezo97*'s Multi Companion Mod and *Kingsegg*'s MCME.
* README structure inspired by [Best-README-Template](https://github.com/othneildrew/Best-README-Template).

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- MARKDOWN LINKS & IMAGES -->
[stars-shield]: https://img.shields.io/github/stars/kubainter/tw3-mcme-autonomous-romance.svg?style=for-the-badge
[stars-url]: https://github.com/kubainter/tw3-mcme-autonomous-romance/stargazers
[forks-shield]: https://img.shields.io/github/forks/kubainter/tw3-mcme-autonomous-romance.svg?style=for-the-badge
[forks-url]: https://github.com/kubainter/tw3-mcme-autonomous-romance/network/members
[issues-shield]: https://img.shields.io/github/issues/kubainter/tw3-mcme-autonomous-romance.svg?style=for-the-badge
[issues-url]: https://github.com/kubainter/tw3-mcme-autonomous-romance/issues
[license-shield]: https://img.shields.io/github/license/kubainter/tw3-mcme-autonomous-romance.svg?style=for-the-badge
[license-url]: https://github.com/kubainter/tw3-mcme-autonomous-romance/blob/main/LICENSE
