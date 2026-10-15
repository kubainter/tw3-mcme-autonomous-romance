================================================================================
MCME AUTONOMOUS ROMANCE
The Witcher 3: Wild Hunt — Next-Gen Remaster (v5.00+)
Version: 1.0.0
Author: kubai (kubainter)
================================================================================

Autonomous companion initiative, contextual banter, post-combat triage,
campfire relaxation, and consent-guarded romantic dates for Multi Companion Mod.

Companions no longer wait as silent bodyguards. They speak their minds, care
for Geralt when he's hurt, relax when you rest, and invite you to intimate
moments on their own terms.

================================================================================
REQUIREMENTS
================================================================================

  1. The Witcher 3: Wild Hunt — Next-Gen / Remaster (v5.00+)
  2. Multi Companion Mod Remastered (MCMR) — installed and verified working
     (Nexus link: https://www.nexusmods.com/witcher3/mods/13144)

  Note: Built with native Remaster annotations (@wrapMethod). Zero vanilla
  scripts modified. NO Script Merger conflicts!

================================================================================
HOW IT WORKS IN GAME
================================================================================

  * Spontaneous Banter:
    While exploring, riding, or sailing, companions chime in with over 30
    authentic, fully voiced lines with localized subtitles.

  * Combat Care & Real Healing:
    Take heavy damage in battle? When swords are sheathed, she reacts:
    Yennefer casts protective Quen; Triss and Keira patch your wounds; Shani
    applies battlefield triage. Actually restores 20–25% of your Health.

  * Campfires & Tavern Drinks:
    When relaxing by an open fire or inside a tavern, she may ask for a drink
    from your inventory (Est Est, Erveluce, Fiorano, Dwarven Spirit). Press [C]
    to share a bottle for +3 Affinity and a voiced thank-you.

  * Natural Idle Moments:
    Stop moving for ~50s (consulting map, crafting), and she drops the follow
    routine to find a nearby bench, stump, or spot to sit or lean. Wakes the
    instant you take a step.

  * Autonomous Dates & Kisses:
    As your bond grows, she will step forward to invite Geralt to private
    moments, Corvo Bianco garden strolls, or secluded suites (Passiflora,
    Kaer Morhen). Kisses play cleanly without forcing dialogue tree choices.

  * Player Control First ([C] Key):
    Romantic invitations display a subtle 10-second HUD prompt:
      [C] Respond to <Companion>
    Hold ~1s or double-tap [C] to accept. Walk away or ignore the timer to
    decline gracefully with zero penalties, zero drama, and no lost affinity.
    Uses 'SwordSheathe' input to prevent conflicts with MCME's [E] menu.

================================================================================
SUPPORTED COMPANIONS
================================================================================

  Full Romance Progression:
    - Yennefer of Vengerberg (Wound checks, Quen, Corvo Bianco, Triss rivalry)
    - Triss Merigold (Combat hugs, Passiflora suite, garden kisses, Yen rivalry)
    - Keira Metz (Playful wit, medical remedies, late-night propositions)
    - Shani (Battlefield triage, sincere compliments, quiet evening dates)
    - Anna Henrietta (Regal wit, proud wound inspections, private audiences)
    - Vivienne de Tabris (Subtle mystery, quiet moments, secluded dates)
    - Cerys an Craite (Skellige honor, direct banter, hearty hearth drinks)

  Ambient & Drink Sharing:
    - Philippa Eilhart, Syanna, Ves, Salma (Exploration barks & drink requests)

================================================================================
IN-GAME MENU SETTINGS (MCM)
================================================================================

  Located under: Options -> Mods -> Autonomous Romance

  [Pacing & Behavior]
    Initiative Interval    = 12 min   Cooldown between companion initiatives (1-20 min)
    Decision Tick Interval = 30 s     Scan frequency for initiative context (20-160 s)
                                      (Note: Tick changes take effect after save reload)
    Affinity Multiplier    = 1.0x     Progression speed multiplier (0.5x to 5.0x)
    Jealousy Mode          = On       On: realistic rivalry banter & locks when together
                                      Off: Polyamory Mode (free love, no partner locks)
    Sandbox Mode           = Off      Bypasses story gates & maxes affinity for testing
    Consent Prompt         = On       Require the [C] prompt on tier 3 invitations
    Debug HUD Messages     = Off      Show [AR] engine diagnostics on HUD (English dev)

  [Wardrobe Management]
    Managed directly through the in-game MCME companion menu. Switch and persist
    outfits (Default, Underwear, Nude) without console commands.

================================================================================
TROUBLESHOOTING & REPORTING ISSUES
================================================================================

  Nothing happening? Companions not initiating?

  Step 1: Check in-game settings (No console required)
    - Open: Options -> Mods -> Autonomous Romance
    - Enable "Sandbox Mode": Bypasses story progress and maxes affinity.
      If interactions start working, your companions were simply gated by story
      or cooldowns.
    - Enable "Debug HUD Messages": Displays real-time [AR] engine notifications
      directly on your screen whenever a companion evaluates an initiative.

  Step 2: Quick Diagnostics via Console (Optional)
    If you have the in-game debug console enabled (DBGConsoleOn=true in general.ini),
    press [~] (tilde) to run quick status checks:

      ar_status  - Displays active companions, current cooldowns, and affinity.
      ar_eval    - Evaluates every action and prints why it's eligible or blocked.
      ar_trigger - Forces an immediate decision tick without waiting for timers.

    When reporting an issue on Nexus, providing the output of ar_status and
    ar_eval will help diagnose the problem in seconds!

================================================================================
INSTALLATION & REMOVAL
================================================================================

  Install:
    1. Extract the archive into your The Witcher 3 root directory:
         Mods/modMCME_AutonomousRomance -> <The Witcher 3>/Mods/
         bin/config/.../modMCME_AutonomousRomance.xml -> <The Witcher 3>/bin/
    2. Launch the game. Scripts compile automatically on first boot.
    3. No Script Merger run needed.

  Uninstall:
    Delete Mods/modMCME_AutonomousRomance and modMCME_AutonomousRomance.xml.
    Safe save guarantee: All relationship progress lives in native engine facts
    (mcme_ar_*), leaving zero orphaned script data in your .sav files.

================================================================================
CREDITS
================================================================================

  CD Projekt Red      - The Witcher 3: Wild Hunt and REDengine
  Jamezo97 & Kingsegg - Multi Companion Mod and MCME foundation
  W3 Modding Community- Script documentation, tools, and support

================================================================================
