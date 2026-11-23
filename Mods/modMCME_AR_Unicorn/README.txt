================================================================================
MCME AUTONOMOUS ROMANCE - UNICORN BRIDGE
The Witcher 3: Wild Hunt - Remaster (v5.00+)
================================================================================

Optional add-on for MCME Autonomous Romance. It hands Tier 4 intimate
scenes to the Unicorn mod when one is installed, so companions can use
Unicorn's animated scene pool instead of the built-in .w2scene scenes.

The base mod never references Unicorn. It detects this package through
the MCM_AR_Unicorn config group, and with the package absent everything
works exactly as before. This package in turn needs the Unicorn core
mod and a scene pack (the Billyy pack provides 55 scenes and is what
the tag matrix was built against). Without modUnicornCore this package
fails to compile on purpose, so a broken install announces itself
instead of silently doing nothing.

================================================================================
REQUIREMENTS
================================================================================

  1. The Witcher 3: Wild Hunt - Remaster (v5.00+)
  2. MCME Autonomous Romance (modMCME_AutonomousRomance) - required
  3. Unicorn core (modUnicornCore) - required
  4. A Unicorn scene pack - required for anything to play.
     Tested against the Billyy pack (55 scenes).

================================================================================
HOW IT WORKS
================================================================================

  When a companion accepts a Tier 4 invitation, the bridge picks a
  Unicorn scene that fits her instead of running the default .w2scene.
  Scene choice runs through a per-character tag matrix: each companion
  has a row of included tags (acts and moods that fit her character)
  plus personal vetoes, and companions without a row fall back to a
  conservative default. A few global rules sit on top:

    * 'Sex' is always required, so kiss-only and spanking-only scenes
      are never picked for an intimate invitation.
    * Allow Rough = off vetoes aggressive, bondage, anal and similar
      tags across every row.
    * Location matters. Outdoor scenes exclude furniture-bound scenes,
      and SweetSpot furniture spots exclude standing, kneeling and
      squatting scenes. The bridge does this filtering itself because
      the engine's own furniture preference does not apply on the
      StartSceneEx path it uses.

  If scene selection or scene start fails for any reason, the
  invitation falls back to the native .w2scene. The bridge can add
  options, never remove them.

  While a Unicorn scene runs, the bridge holds two game facts:
  'mcme_ar_uc_active' (any scene live, plus a short grace period) and
  'mcme_ar_uc_on_<name>' per actor. The base mod reads these to keep
  its own NPC actions from colliding with the scene, and they expire on
  their own so a crash cannot lock anything forever.

================================================================================
IN-GAME SETTINGS
================================================================================

  Options -> Mods -> Autonomous Romance - Unicorn

    Unicorn scene backend   0=Off / 1=Prefer+fallback / 2=Unicorn only / 3=Mix
    Allow rougher scene tags  On/Off - gates the aggressive tag group above

  Mode notes:
    0  Bridge installed but inactive; native scenes only.
    1  Default. Unicorn scene when one fits, native scene otherwise.
    2  Unicorn or nothing; if the gate fails, no scene plays.
    3  Random mix of Unicorn and native scenes.

================================================================================
DIAGNOSTICS
================================================================================

  Console commands (need the debug console enabled):

    ar_uc_status   Bridge state: mode, Unicorn version, scene count,
                   live threads, busy-fact value.
    ar_uc_mode N   Set the backend mode (0-3) without opening MCM.
    ar_uc_eval     Per companion, prints how many scenes the current
                   tag set and location context would allow. This is
                   the same count the dispatcher sees, furniture
                   context included. Use it to check a companion's
                   scene pool before testing live.

================================================================================
KNOWN GAPS
================================================================================

  - Voice lines and cinematic lead-in polish are planned, not built.
  - The custom pack scaffold (MCM_AR_UnicornPacks.ws) registers zero
    scenes today. It exists so our own .w2anims content can be added
    later without touching the bridge.
  - Bondage and device scenes stay excluded by design, even with
    Allow Rough on.

================================================================================
CREDITS
================================================================================

  MCME Autonomous Romance   - base mod and consent/affinity pipeline
  Unicorn mod               - scene engine this bridge drives
  Billyy scene pack         - the 55-scene pool the tag matrix targets
  CD Projekt Red            - The Witcher 3: Wild Hunt

================================================================================
