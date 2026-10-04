/*****************************************************************************/
/* MCME Autonomous Romance - Main NPC Actions                                */
/* Konkretne zestawy zachowań dla Yennefer, Triss, Keira, Shani             */
/*****************************************************************************/

// ---------------------------------------------------------------------------
// Rejestracja wszystkich akcji w czasie init Core
// Używamy @wrapMethod żeby nie modyfikować żadnego pliku bazowego
// ---------------------------------------------------------------------------

@wrapMethod(MCM_RomanceActionRegistry)
function InitDefaultActions()
{
	wrappedMethod();

	// ===== YENNEFER =====
	RegisterAction(new MCM_AR_Yen_OneLinerFlirt        in this);
	RegisterAction(new MCM_AR_Yen_PostCombatCare        in this);
	RegisterAction(new MCM_AR_Yen_NightInvitation       in this);
	RegisterAction(new MCM_AR_Yen_CampfireEvening       in this);
	RegisterAction(new MCM_AR_Yen_CorvoKiss             in this);
	RegisterAction(new MCM_AR_Yen_JealousySnark         in this);
	RegisterAction(new MCM_AR_Yen_TavernWine            in this);

	// ===== TRISS =====
	RegisterAction(new MCM_AR_Triss_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Triss_PostCombatHug       in this);
	RegisterAction(new MCM_AR_Triss_NightWhisper        in this);
	RegisterAction(new MCM_AR_Triss_CampfireWarmth      in this);
	RegisterAction(new MCM_AR_Triss_GardenKiss          in this);
	RegisterAction(new MCM_AR_Triss_JealousySnark       in this);

	// ===== KEIRA =====
	RegisterAction(new MCM_AR_Keira_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Keira_PostCombatHeal      in this);
	RegisterAction(new MCM_AR_Keira_NightProposal       in this);
	RegisterAction(new MCM_AR_Keira_CampfireWitch       in this);

	// ===== SHANI =====
	RegisterAction(new MCM_AR_Shani_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Shani_PostCombatMedic     in this);
	RegisterAction(new MCM_AR_Shani_NightRelax          in this);
}

//=============================================================================
//  YENNEFER – Tier 1: Autonomiczny flirt / one-liner
//=============================================================================

class MCM_AR_Yen_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'yen_oneliner_flirt';
	default targetNpc       = 'yennefer';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;  // 5 minut
	default triggerType     = RTT_OneLiner;
	default weight          = 10;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		// Dostępny tylko podczas spaceru (nie w nocy, nie przy ognisku – te mają wyższe akcje)
		if (ctx.isNight || ctx.isNearCampfire) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// ID 336583: "Perhaps it's strange, but I like watching you work. Especially when you're so good at it."
		PlayOneLiner(npc, 336583, "Perhaps it's strange, but I like watching you work. Especially when you're so good at it.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  YENNEFER – Tier 2: Reakcja po walce (troska)
//=============================================================================

class MCM_AR_Yen_PostCombatCare extends MCM_RomanceInteraction
{
	default id              = 'yen_postcombat_care';
	default targetNpc       = 'yennefer';
	default minAffinity     = 20;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		// Gracz musi być ranny (< 55% HP)
		if (ctx.playerHealthRatio > 0.55) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		ApproachPlayer(npc, player, 1.8);
		PlayMimic(npc, 'concern');
		// ID 336587: "Next time stand behind me, all right? I'd rather defend you than have to patch you up afterwards."
		PlayOneLiner(npc, 336587, "Next time stand behind me, all right? I'd rather defend you than have to patch you up afterwards.");
		Sleep(3.0);
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  YENNEFER – Tier 3: Nocne zaproszenie (prompt HUD)
//=============================================================================

class MCM_AR_Yen_NightInvitation extends MCM_RomanceInteraction
{
	default id              = 'yen_night_invitation';
	default targetNpc       = 'yennefer';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0; // 30 min
	default triggerType     = RTT_Prompt;
	default weight          = 5;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (!ctx.isNight) return false;
		if (ctx.hasRivals && MCM_AR_GetConfig().IsJealousyModeOn()) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;

		ApproachPlayer(npc, player, 1.5);
		PlayMimic(npc, 'flirt');
		// ID 1123812: "Moments like this."
		PlayOneLiner(npc, 1123812, "Moments like this.");
		Sleep(2.5);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[E] Zbliż się do Yennefer", 8.0);
			if (!consent)
			{
				LogChannel('MCM_AR', "[AR] Gracz odrzucił zaproszenie Yen");
				return false;
			}
		}

		// Uruchom scenę pocałunku z MCME
		PlayScene(npc, "dlc\\mod_spawn_companions\\dialogue\\yenneferFollowWithKiss.w2scene");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  YENNEFER – Tier 2: Przy ognisku (wieczorny)
//=============================================================================

class MCM_AR_Yen_CampfireEvening extends MCM_RomanceInteraction
{
	default id              = 'yen_campfire_evening';
	default targetNpc       = 'yennefer';
	default minAffinity     = 30;
	default cooldownSeconds = 900.0;
	default triggerType     = RTT_Gesture;
	default weight          = 7;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (!ctx.isNearCampfire) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		ApproachPlayer(npc, player, 2.0);
		PlayAnimSimple(npc, 'woman_sit_stump_idle');
		Sleep(1.0);
		// ID 1002979: "Splendid. We finally got the chance to talk."
		PlayOneLiner(npc, 1002979, "Splendid. We finally got the chance to talk.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  YENNEFER – Tier 4: Corvo Bianco (tylko w rezydencji)
//=============================================================================

class MCM_AR_Yen_CorvoKiss extends MCM_RomanceInteraction
{
	default id              = 'yen_corvo_kiss';
	default targetNpc       = 'yennefer';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;  // 1h
	default triggerType     = RTT_Scene;
	default weight          = 3;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		// Tylko w Toussaint (Corvo Bianco)
		if (!ctx.isInCorvo) return false;
		if (ctx.hasRivals && MCM_AR_GetConfig().IsJealousyModeOn()) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;

		// ID 1123805: "That I regret we didn't try that earlier. Much earlier."
		PlayOneLiner(npc, 1123805, "That I regret we didn't try that earlier. Much earlier.");
		Sleep(3.0);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[E] Zareaguj na Yennefer", 8.0);
			if (!consent) return false;
		}

		// Scena intymna anywhere z MCME
		PlayScene(npc, "dlc\\mod_spawn_companions\\naughty\\yennefer\\anywhere.w2scene");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  YENNEFER – Tier 1: Zazdrość (gdy Triss też jest w drużynie)
//=============================================================================

class MCM_AR_Yen_JealousySnark extends MCM_RomanceInteraction
{
	default id              = 'yen_jealousy_snark';
	default targetNpc       = 'yennefer';
	default minAffinity     = 0;
	default cooldownSeconds = 480.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 9;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		// Aktywne TYLKO gdy jest zazdrość i tryb zazdrości włączony
		if (!ctx.hasRivals || !MCM_AR_GetConfig().IsJealousyModeOn()) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// ID 1123826: "Come, now, Geralt. I know you. Well enough to know exactly what's going on with you and Triss."
		PlayOneLiner(npc, 1123826, "Come, now, Geralt. I know you. Well enough to know exactly what's going on with you and Triss.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  YENNEFER – Tier 1: Tawerna (propozycja wina)
//=============================================================================

class MCM_AR_Yen_TavernWine extends MCM_RomanceInteraction
{
	default id              = 'yen_tavern_wine';
	default targetNpc       = 'yennefer';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 6;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (!ctx.isInTavern) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// ID 1002979
		PlayOneLiner(npc, 1002979, "Splendid. We finally got the chance to talk.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  TRISS – Tier 1: Flirt w marszu
//=============================================================================

class MCM_AR_Triss_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'triss_oneliner_flirt';
	default targetNpc       = 'triss';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (ctx.isNight) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// ID 1009039: "Which doesn't mean I'm not happy to see you."
		PlayOneLiner(npc, 1009039, "Which doesn't mean I'm not happy to see you.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  TRISS – Tier 2: Objęcie po walce
//=============================================================================

class MCM_AR_Triss_PostCombatHug extends MCM_RomanceInteraction
{
	default id              = 'triss_postcombat_hug';
	default targetNpc       = 'triss';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (ctx.playerHealthRatio > 0.60) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		ApproachPlayer(npc, player, 1.5);
		PlayMimic(npc, 'concern');
		// ID 1127010: "Tsk… Oh Geralt… What've you gotten yourself into now?"
		PlayOneLiner(npc, 1127010, "Tsk… Oh Geralt… What've you gotten yourself into now?");
		Sleep(2.5);
		PlayAnimSimple(npc, 'woman_hug_idle');
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  TRISS – Tier 3: Nocna rozmowa (prompt)
//=============================================================================

class MCM_AR_Triss_NightWhisper extends MCM_RomanceInteraction
{
	default id              = 'triss_night_whisper';
	default targetNpc       = 'triss';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (!ctx.isNight) return false;
		if (ctx.hasRivals && MCM_AR_GetConfig().IsJealousyModeOn()) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;

		ApproachPlayer(npc, player, 1.5);
		PlayMimic(npc, 'flirt');
		// ID 1074691: "Gladly. I was about to ask the same."
		PlayOneLiner(npc, 1074691, "Gladly. I was about to ask the same.");
		Sleep(3.0);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[E] Zostań z Triss", 8.0);
			if (!consent) return false;
		}

		PlayScene(npc, "dlc\\mod_spawn_companions\\dialogue\\trissFollowWithKiss.w2scene");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  TRISS – Tier 2: Przy ognisku (ciepło)
//=============================================================================

class MCM_AR_Triss_CampfireWarmth extends MCM_RomanceInteraction
{
	default id              = 'triss_campfire_warmth';
	default targetNpc       = 'triss';
	default minAffinity     = 20;
	default cooldownSeconds = 900.0;
	default triggerType     = RTT_Gesture;
	default weight          = 7;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (!ctx.isNearCampfire) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		ApproachPlayer(npc, player, 2.0);
		PlayAnimSimple(npc, 'woman_sit_stump_idle');
		Sleep(1.0);
		// ID 480807: "Six months ago Triss Merigold parted with someone very dear to her and had to start anew."
		PlayOneLiner(npc, 480807, "Six months ago Triss Merigold parted with someone very dear to her and had to start anew.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  TRISS – Tier 3: Pocałunek w ogrodzie
//=============================================================================

class MCM_AR_Triss_GardenKiss extends MCM_RomanceInteraction
{
	default id              = 'triss_garden_kiss';
	default targetNpc       = 'triss';
	default minAffinity     = 70;
	default cooldownSeconds = 2400.0;
	default triggerType     = RTT_Prompt;
	default weight          = 4;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (ctx.hasRivals && MCM_AR_GetConfig().IsJealousyModeOn()) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;

		ApproachPlayer(npc, player, 1.2);
		// ID 1074691: "Gladly. I was about to ask the same."
		PlayOneLiner(npc, 1074691, "Gladly. I was about to ask the same.");
		Sleep(2.5);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[E] Pocałuj Triss", 8.0);
			if (!consent) return false;
		}

		PlayScene(npc, "dlc\\mod_spawn_companions\\dialogue\\trissFollowWithKiss.w2scene");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  TRISS – Tier 1: Zazdrość (gdy Yen jest w drużynie)
//=============================================================================

class MCM_AR_Triss_JealousySnark extends MCM_RomanceInteraction
{
	default id              = 'triss_jealousy_snark';
	default targetNpc       = 'triss';
	default minAffinity     = 0;
	default cooldownSeconds = 480.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 9;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (!ctx.hasRivals || !MCM_AR_GetConfig().IsJealousyModeOn()) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// ID 1008871: "Oh, you really want to talk about it? Maybe I should get Yennefer? Wouldn't want her to miss any of this."
		PlayOneLiner(npc, 1008871, "Oh, you really want to talk about it? Maybe I should get Yennefer? Wouldn't want her to miss any of this.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  KEIRA – Tier 1: Flirt / prowokacja
//=============================================================================

class MCM_AR_Keira_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'keira_oneliner_flirt';
	default targetNpc       = 'keira_metz';
	default minAffinity     = 0;
	default cooldownSeconds = 320.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (ctx.isNight) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// ID 588361: "Oh, you're definitely no boy. You're a strong, poised witcher who will surely help a woman in need."
		PlayOneLiner(npc, 588361, "Oh, you're definitely no boy. You're a strong, poised witcher who will surely help a woman in need.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  KEIRA – Tier 2: Komentarz medyczny / opatrzenie po walce
//=============================================================================

class MCM_AR_Keira_PostCombatHeal extends MCM_RomanceInteraction
{
	default id              = 'keira_postcombat_heal';
	default targetNpc       = 'keira_metz';
	default minAffinity     = 10;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 9;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (ctx.playerHealthRatio > 0.50) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		ApproachPlayer(npc, player, 1.8);
		PlayMimic(npc, 'concern');
		// ID 553849: "Whew, thank you."
		PlayOneLiner(npc, 553849, "Whew, thank you.");
		Sleep(2.5);
		// Keira rzuca Quen na gracza (efekt symboliczny)
		PlayAnimSimple(npc, 'cast_sign_quen_idle');
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  KEIRA – Tier 3: Nocna propozycja
//=============================================================================

class MCM_AR_Keira_NightProposal extends MCM_RomanceInteraction
{
	default id              = 'keira_night_proposal';
	default targetNpc       = 'keira_metz';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (!ctx.isNight) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;

		ApproachPlayer(npc, player, 1.5);
		PlayMimic(npc, 'flirt');
		// ID 589402: "I daresay this one, once sprung, would thrill you… Ah well, change your mind - come and see me."
		PlayOneLiner(npc, 589402, "I daresay this one, once sprung, would thrill you… Ah well, change your mind - come and see me.");
		Sleep(3.0);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[E] Przyjmij zaproszenie Keiry", 8.0);
			if (!consent) return false;
		}

		PlayScene(npc, "dlc\\mod_spawn_companions\\dialogue\\keira_metzFollowWithKiss.w2scene");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  KEIRA – Tier 1: Przy ognisku (komentarz czarodziejki)
//=============================================================================

class MCM_AR_Keira_CampfireWitch extends MCM_RomanceInteraction
{
	default id              = 'keira_campfire_witch';
	default targetNpc       = 'keira_metz';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 7;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (!ctx.isNearCampfire) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// ID 588324: "Perhaps… perhaps you'd stay just a bit longer? There's one small favor you might yet do for me."
		PlayOneLiner(npc, 588324, "Perhaps… perhaps you'd stay just a bit longer? There's one small favor you might yet do for me.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  SHANI – Tier 1: Flirt / lekarka na polu
//=============================================================================

class MCM_AR_Shani_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'shani_oneliner_flirt';
	default targetNpc       = 'shani';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (ctx.isNight) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// ID 1108852: "I think you look charming."
		PlayOneLiner(npc, 1108852, "I think you look charming.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  SHANI – Tier 2: Opatrzenie po walce (lekarka)
//=============================================================================

class MCM_AR_Shani_PostCombatMedic extends MCM_RomanceInteraction
{
	default id              = 'shani_postcombat_medic';
	default targetNpc       = 'shani';
	default minAffinity     = 10;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 9;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (ctx.playerHealthRatio > 0.55) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		ApproachPlayer(npc, player, 1.5);
		PlayMimic(npc, 'concern');
		// ID 1101758: "Do you need help?"
		PlayOneLiner(npc, 1101758, "Do you need help?");
		Sleep(3.0);
		PlayAnimSimple(npc, 'woman_tend_wounds_idle');
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  SHANI – Tier 3: Nocny relaks (prompt)
//=============================================================================

class MCM_AR_Shani_NightRelax extends MCM_RomanceInteraction
{
	default id              = 'shani_night_relax';
	default targetNpc       = 'shani';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (!ctx.isNight) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;

		ApproachPlayer(npc, player, 1.5);
		PlayMimic(npc, 'flirt');
		// ID 1108130: "It would do you good to be more relaxed sometimes."
		PlayOneLiner(npc, 1108130, "It would do you good to be more relaxed sometimes.");
		Sleep(3.0);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[E] Zostań ze Shani", 8.0);
			if (!consent) return false;
		}

		PlayScene(npc, "dlc\\mod_spawn_companions\\dialogue\\shaniFollowWithKiss.w2scene");
		super.Execute(npc, player, ctx);
		return true;
	}
}
