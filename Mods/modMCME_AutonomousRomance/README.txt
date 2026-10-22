================================================================================
MCME AUTONOMOUS ROMANCE
The Witcher 3: Wild Hunt - Remaster (v5.00+)
Version: 2.0.0
Author: kubai (kubainter)
================================================================================

Autonomous companion initiative, contextual banter, post-combat triage,
campfire relaxation, and consent-guarded romantic dates for Multi Companion Mod.

Companions no longer wait as silent bodyguards. They speak their minds, care
for Geralt when he's hurt, relax when you rest, react to the weather and world,
and invite you to intimate moments on their own terms.

================================================================================
REQUIREMENTS
================================================================================

  1. The Witcher 3: Wild Hunt - Remaster (v5.00+)
  2. Multi Companion Mod Remastered (MCMR) - installed and verified working
     (Nexus link: https://www.nexusmods.com/witcher3/mods/13144)
  3. Blood and Wine expansion (required for Anna Henrietta, Vivienne, Syanna,
     and Toussaint locations such as Corvo Bianco and Beauclair Palace).

  Note: Zero script conflicts with other mods. No Script Merger run required!

================================================================================
HOW IT WORKS IN GAME
================================================================================

  * Spontaneous Banter & Context Chatter:
    While exploring, riding horseback, sailing, or stepping inside an inn,
    companions chime in with authentic voice lines and localized subtitles.
    When bad weather hits or darkness falls, they comment naturally.

  * Combat Care & Real Healing:
    Take heavy damage in battle? When swords are sheathed, she reacts:
    Yennefer scolds your recklessness; Triss and Keira soothe and patch cuts;
    Shani applies brisk battlefield triage. Restores 20-25% of maximum Health.

  * Campfires & Tavern Drinks:
    When resting by a campfire or relaxing inside any tavern, she may ask for
    a bottle from your inventory (Est Est, Erveluce, Mettina Rose, Alcohest,
    Dwarven Spirit). Share a drink for +3 Affinity and a thank-you.

  * Natural Idle Moments:
    Stop moving for ~50s (consulting the map, crafting, inventory management),
    and she drops the follow routine to find a spot to sit or lean. She resumes
    following the instant you take a step.

  * Autonomous Dates & Kisses:
    As your bond grows, she steps forward to invite Geralt to private moments,
    quiet campfire evenings, or secluded suites (Passiflora, Corvo Bianco,
    Kaer Morhen). Kisses play cleanly without forcing dialogue tree choices.
    Expect an afterglow remark afterwards, and if a rival is present in the party,
    she will definitely make her opinion heard.

  * Player Control First (Consent Key):
    Romantic invitations display a subtle 20-second HUD prompt showing your
    actual bound button (keyboard [C] or gamepad D-pad Left / Right).
    Hold for about a second or double-tap to accept. Walk away or let the timer
    expire to decline gracefully with zero penalties, zero drama, and no lost
    affinity.

================================================================================
SUPPORTED COMPANIONS
================================================================================

  Full Romance & Intimacy (Tier 1 - Tier 4):
    - Yennefer of Vengerberg (Combat triage, tavern wine, Corvo Bianco dates, rivalry)
    - Triss Merigold (Combat hugs, Passiflora suite, kisses, tavern drinks, rivalry)
    - Keira Metz (Playful wit, field remedies, tavern drinks, night propositions)
    - Shani (Battlefield triage, sincere compliments, tavern drinks, night dates)
    - Anna Henrietta (Regal wit, wound inspection, tavern wine, private audiences)
    - Vivienne de Tabris (Gentle mystery, reflective campfire moments, tavern wine)
    - Cerys an Craite (Skellige honor, direct banter, hearty tavern drinking)
    - Syanna (Cynical wit, post-combat remarks, universal kiss, cloud sex dates)

  Romance, Universal Kisses & Drink Requests (Tier 1 - Tier 3):
    - Rosa var Attre (Fencing flirts, Nilfgaardian wine requests, universal kiss)
    - Tomira (Warm herbalist remarks, spirit requests, universal kiss)
    - Philippa Eilhart (Pragmatic triage, sharp condescending wit, universal kiss)
    - Ves (Blue Stripes frontline camaraderie, drink requests, universal kiss)
    - Salma (Succubus sensory allure, spirit requests, universal kiss)
    - Priscilla (Ballad care, road observations, fine wine requests, universal kiss)
    - Edna var Attre (Court fatigue banter, vintage requests, universal kiss)
    - Fringilla Vigo (Guarded Nilfgaardian flirts, warmth triage, universal kiss)
    - Margarita Laux-Antille (Comforting triage, spirit requests, universal kiss)
    - Orianna (Refined dark elegance, vintage requests, universal kiss)

  Family Bond & Warmth (Tier 1 - Tier 3):
    - Cirilla / Ciri (Warm family embrace without dialogue wheels, companion banter)

================================================================================
IN-GAME MENU SETTINGS (MCM)
================================================================================

  Located under: Options -> Mods -> Autonomous Romance

  [Pacing & Behavior]
    Initiative Interval    = 12 min   Cooldown between initiatives (1-20 min)
    Decision Interval      = 30 s     Scan frequency for initiative context (20-160 s)
                                      (Note: interval changes apply after a save reload)
    Affinity Multiplier    = 1.0x     Progression speed multiplier (0.5x to 5.0x)
    Jealousy Mode          = On       On: realistic rivalry banter & exclusivity locks
                                      Off: Polyamory Mode (free love, no partner locks)
    Companion Chatter      = Default  Ambient chatter frequency: Quiet (~30%),
                                      Default (~65%), Chatty (100%)
    Sandbox Mode           = Off      Bypasses story gates & maxes affinity for testing
    Consent Prompt         = On       Require consent prompt on romantic invitations
    Debug HUD Messages     = Off      Show on-screen action diagnostics (English dev)

  [Wardrobe Management]
    Managed directly through the in-game MCME companion menu. Switch and persist
    outfits (Default, Underwear, Nude) without console commands.

================================================================================
INSTALLATION & REMOVAL
================================================================================

  Install:
    1. Extract the archive into your The Witcher 3 root directory:
         Mods/modMCME_AutonomousRomance -> <The Witcher 3>/Mods/
         bin/config/.../modMCME_AutonomousRomance.xml -> <The Witcher 3>/bin/

    2. Input Bindings (Consent Key):
       The mod includes a custom input definition file (MCME_AR.input.settings)
       mapping [C] on keyboard and [D-pad Left / Right] on gamepad.

       - Vortex / TW3 Mod Manager: merges input settings automatically.
       - Manual Installers: the game does not merge mod input files on its own.
         Open Mods/modMCME_AutonomousRomance/MCME_AR.input.settings and copy its
         contents into Documents/The Witcher 3/input.settings under each matching
         section ([Exploration], [Combat], [Horse], [Boat], [Swimming], etc.).
         If skipped, consent falls back to your default sword sheathing key.

    3. Launch the game. Scripts compile automatically on first startup.
    4. No Script Merger run needed.

  Uninstall:
    Delete Mods/modMCME_AutonomousRomance and modMCME_AutonomousRomance.xml.
    All relationship progress is tracked cleanly by the game world itself,
    leaving zero orphaned script data in your save files.

================================================================================
LANGUAGES
================================================================================

  Full localization (subtitles, prompts, menus):
    - English
    - Polish
    - Spanish (es)
    - Latin American Spanish (esmx)
  Other game languages cleanly fall back to English subtitles.

================================================================================
TROUBLESHOOTING & REPORTING ISSUES
================================================================================

  Companions not initiating?

  Step 1: Check in-game settings (No console required)
    - Open: Options -> Mods -> Autonomous Romance
    - Enable "Sandbox Mode": Bypasses story progress and maxes affinity.
      If interactions start working, your companions were simply waiting on
      story gates or cooldowns.
    - Enable "Debug HUD Messages": Displays real-time notifications directly
      on your screen whenever a companion evaluates an initiative.

  Step 2: Quick Diagnostics via Console (Optional)
    If you have the debug console enabled (DBGConsoleOn=true in general.ini),
    press [~] (tilde) to run quick status checks:

      ar_status  - Displays active companions, current cooldowns, and affinity.
      ar_eval    - Evaluates every action and prints why it's eligible or blocked.
      ar_trigger - Forces an immediate decision tick without waiting for timers.

    When reporting an issue on Nexus, providing the output of ar_status and
    ar_eval helps diagnose the problem in seconds!

================================================================================
CREDITS
================================================================================

  CD Projekt Red      - The Witcher 3: Wild Hunt
  Jamezo97 & Kingsegg - Multi Companion Mod and MCME foundation
  RoyalFootman        - MCM Remastered
  W3 Modding Community- Script documentation, tools, and support

================================================================================
