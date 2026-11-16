================================================================================
MCME AUTONOMOUS ROMANCE
The Witcher 3: Wild Hunt - Remaster (v5.00+)
Version: 2.0.0
Author: Botan
================================================================================

Autonomous companion initiative, contextual banter, post-combat triage,
campfire relaxation, and consent-guarded romantic dates for Multi Companion Mod.

Companions do more than follow. They talk on the road, look after Geralt when he is hurt,
relax when you rest, react to the weather, and invite you to intimate moments on their
own terms.

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
    a bottle from your inventory (Est Est, Erveluce, Beauclair White, Mettina Rose, Alcohest,
    Dwarven Spirit). Share a drink for +3 Affinity (+4 in total with the standard action bonus) and a thank-you.

  * Natural Idle Moments:
    Stop moving for ~50s (consulting the map, crafting, inventory management),
    and she drops the follow routine to find a spot to sit or lean. She resumes
    following the instant you take a step.

  * Autonomous Dates & Kisses:
    As your bond grows, she steps forward to invite Geralt to private moments,
    quiet campfire evenings, or secluded suites (Passiflora, Corvo Bianco,
    Kaer Morhen). Kisses play cleanly without forcing dialogue tree choices.
    Expect an afterglow remark afterwards, if a rival is in the party,
    she will make her opinion heard.

  * Player Control First (Consent Key):
    Romantic invitations display a 20-second HUD prompt showing your
    actual bound button (keyboard [C] or gamepad D-pad Left / Right).
    Hold for about a second or double-tap to accept. Walk away or let the timer
    expire to decline. No affinity is lost; ignoring the prompt starts a rejection cooldown for that action.

================================================================================
SUPPORTED COMPANIONS
================================================================================

  Full Romance & Intimacy (Tier 1 - Tier 4):
    - Yennefer of Vengerberg (Combat triage, tavern wine, Corvo Bianco dates, rivalry)
    - Triss Merigold (Combat hugs, Passiflora suite, kisses, tavern drinks, rivalry)
    - Keira Metz (Playful wit, field remedies, tavern drinks, night propositions)
    - Shani (Battlefield triage, sincere compliments, tavern drinks, night dates)
    - Anna Henrietta (Regal wit, wound inspection, tavern wine, private audiences, no kiss tier)
    - Vivienne de Tabris (Gentle mystery, reflective campfire moments, tavern wine, no kiss tier)
    - Orianna (Refined dark elegance, vintage requests, intimate invitation; no kiss tier)
    - Cerys an Craite (Skellige honor, direct banter, hearty tavern drinking)
    - Syanna (Cynical wit, post-combat remarks, universal kiss, cloud sex dates)

  Romance, Universal Kisses & Drink Requests (Tier 1 - Tier 3; Tier 4 with MCME companion packs):
    - Rosa var Attre (Fencing flirts, Nilfgaardian wine requests, universal kiss)
    - Tomira (Warm herbalist remarks, spirit requests, universal kiss)
    - Philippa Eilhart (Pragmatic triage, sharp condescending wit, universal kiss)
    - Ves (Blue Stripes frontline camaraderie, drink requests, universal kiss)
    - Salma (Succubus sensory allure, spirit requests, universal kiss)
    - Priscilla (Ballad care, road observations, fine wine requests, universal kiss)
    - Edna var Attre (Court fatigue banter, vintage requests, universal kiss)
    - Fringilla Vigo (Guarded Nilfgaardian flirts, warmth triage, universal kiss)
    - Margarita Laux-Antille (Comforting triage, spirit requests, universal kiss)

  Family Bond & Warmth (Tier 1 - Tier 3):
    - Cirilla / Ciri (Warm family embrace without dialogue wheels, companion banter)

================================================================================
IN-GAME MENU SETTINGS (MCM)
================================================================================

  Located under: Options -> Mods -> Autonomous Romance

  [Pacing & Behavior]
    Cooldown between initiatives = 720 s (12 min)   Range 60-1200 s (1-20 min)
    Decision tick interval       = 30 s             Range 20-160 s, step 10 s
                                   (applied after a save reload)
    Affinity Multiplier          = 1.0x             Range 0.5x-5.0x
    Jealousy Mode                = On               On: jealousy banter and rivalry
                                   Off: Polyamory (jealousy-only actions are skipped)
    Companion chatter            = Default          Quiet (~30%), Default (~65%), Chatty (100%)
                                   of ambient bark opportunities
    Sandbox Mode                 = Off              Bypasses story gates & maxes affinity for testing
    Require Player Consent [C]   = On               Requires [C] confirmation before romantic
                                   invitations and intimate scenes
    Debug HUD messages           = Off              Shows [AR] diagnostic messages on screen

  [Ciri]
    Ciri: MCME Adult Mode        = Off              Off: lore-friendly family bond only.
                                   On: unlocks her kiss and intimate invitation.

  [Wardrobe Management]
    Managed directly through the in-game MCME companion menu. Switch and persist
    outfits (Default, Underwear, Nude) without console commands.

================================================================================
INSTALLATION & REMOVAL
================================================================================

  Install:
    1. Install the release archive (MCME_AutonomousRomance_vX.Y.Z.zip) with
       Vortex or The Witcher 3 Mod Manager, or extract it manually into your
       The Witcher 3 root directory:
         Mods/modMCME_AutonomousRomance -> <The Witcher 3>/Mods/
         bin/config/.../modMCME_AutonomousRomance.xml -> <The Witcher 3>/bin/

       NOTE: Only the release ZIP is a valid mod package. A GitHub source ZIP
       (Code -> Download ZIP) wraps everything in an extra top-level folder and
       will not install correctly in Vortex.

    2. Input Bindings (Consent Key):
       Consent works out of the box: [C] on keyboard and [D-pad Left / Right]
       on gamepad are detected via the standard sword-sheathe binding.

       The mod also ships an optional dedicated binding file
       (MCME_AR.input.settings.txt) that registers a separate MCM_AR_Consent
       action:
       - The Witcher 3 Mod Manager: merges it automatically on install.
       - Vortex / manual install: copy the file's contents into
         Documents/The Witcher 3/input.settings under each matching section
         ([Exploration], [Combat], [Horse], [Boat], [Swimming], etc.).

    3. Launch the game. Scripts compile automatically on first startup.
    4. No Script Merger run needed.

  Uninstall:
    Delete Mods/modMCME_AutonomousRomance and modMCME_AutonomousRomance.xml.
    Relationship progress is stored as game facts, not as custom save objects.
    These facts stay in the save after uninstall; they are harmless.

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
  Companion packs (kiss scenes adapted from): Spawn Control Girls, Romance Anarietta and Vivienne plus2, Even More Companions
  Deadly Delights - Salma companion

================================================================================
