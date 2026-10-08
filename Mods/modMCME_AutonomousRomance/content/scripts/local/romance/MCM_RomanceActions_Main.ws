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
	RegisterAction(new MCM_AR_Yen_IntimateInvite        in this);
	RegisterAction(new MCM_AR_Yen_JealousySnark         in this);
	RegisterAction(new MCM_AR_Yen_TavernWine            in this);

	// ===== TRISS =====
	RegisterAction(new MCM_AR_Triss_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Triss_PostCombatHug       in this);
	RegisterAction(new MCM_AR_Triss_NightWhisper        in this);
	RegisterAction(new MCM_AR_Triss_CampfireWarmth      in this);
	RegisterAction(new MCM_AR_Triss_GardenKiss          in this);
	RegisterAction(new MCM_AR_Triss_IntimateInvite      in this);
	RegisterAction(new MCM_AR_Triss_JealousySnark       in this);

	// ===== KEIRA =====
	RegisterAction(new MCM_AR_Keira_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Keira_PostCombatHeal      in this);
	RegisterAction(new MCM_AR_Keira_NightProposal       in this);
	RegisterAction(new MCM_AR_Keira_CampfireWitch       in this);
	RegisterAction(new MCM_AR_Keira_IntimateInvite      in this);

	// ===== SHANI =====
	RegisterAction(new MCM_AR_Shani_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Shani_PostCombatMedic     in this);
	RegisterAction(new MCM_AR_Shani_NightRelax          in this);
	RegisterAction(new MCM_AR_Shani_IntimateInvite      in this);
}

//=============================================================================
//  YENNEFER – Tier 1: Autonomiczny flirt / one-liner (kanał ambient)
//=============================================================================

class MCM_AR_Yen_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'yen_oneliner_flirt';
	default targetNpc       = 'yennefer';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;  // 5 minut
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	// ID 336583: "Perhaps it's strange, but I like watching you work..."
	default lineId          = 336583;
	default lineText        = "Perhaps it's strange, but I like watching you work.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		// Dostępny tylko podczas spaceru (nie w nocy, nie przy ognisku – te mają wyższe akcje)
		if (ctx.isNight || ctx.isNearCampfire) return "night_or_campfire";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// Tier 1: tylko bark – NPC idzie dalej, gracz nigdy nie jest lockowany.
		// Head look-at na ~6s – mówi W STRONĘ Geralta, nie w plecy.
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

//=============================================================================
//  YENNEFER – Tier 2: Reakcja po walce (troska) – soft approach, bez locka
//=============================================================================

class MCM_AR_Yen_PostCombatCare extends MCM_RomanceInteraction
{
	default id              = 'yen_postcombat_care';
	default targetNpc       = 'yennefer';
	default minAffinity     = 20;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'concern';
	// ID 336587: "Next time stand behind me, all right? ..."
	default lineId          = 336587;
	default lineText        = "Next time stand behind me, all right? I'd rather defend you than have to patch you up afterwards.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		// Gracz musi być ranny (< 55% HP) i niedawno walczyć
		if (ctx.playerHealthRatio > 0.55) return "hp_ok";
		if (MCM_AR_GetCore().GetSecondsSinceCombat() > 300.0) return "no_recent_combat"; // up to 5 min after combat
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// Soft approach: NPC goni ruchomego gracza async, zero locka.
		// Gracz odszedł/walka/timeout -> abort, wraca do follow.
		SoftApproach(npc, player, 1.8);
		approachOk = WaitForApproach(npc, player, 1.8, 8.0);
		if (!approachOk)
		{
			EndSoft(npc);
			return false;
		}
		PlayBark(npc);
		Sleep(2.5);
		EndSoft(npc);
		return true;
	}
}

//=============================================================================
//  YENNEFER – Tier 3: Nocne zaproszenie (propozycja -> [C] -> scena dialogu)
//=============================================================================

class MCM_AR_Yen_NightInvitation extends MCM_RomanceInteraction
{
	default id              = 'yen_night_invitation';
	default targetNpc       = 'yennefer';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0; // 30 min
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	// ID 420362: "Come, Geralt." – kuratorowana przez MCME linia Yen
	default lineId          = 420362;
	default lineText        = "Come, Geralt.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNight) return "not_night";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		// FAZA 1 – propozycja: bark + soft approach, gracz NIE jest lockowany
		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[C] Zbliz sie do Yennefer", 10.0, npc);
		}
		else
		{
			consent = WaitForApproach(npc, player, 2.4, 8.0);
		}

		if (!consent)
		{
			EndSoft(npc);
			if (MCM_AR_GetConfig().RequiresPlayerConsent())
			{
				MarkRejected();
			}
			MCM_AR_Log("[AR] Gracz odrzucil/ignorowal zaproszenie Yen");
			return false;
		}

		// FAZA 2 – staging dopiero po akceptacji (~1-2s locka), potem scena
		HardStage(npc, player, 1.5);
		ok = PlayDialogueScene(npc, "dlc\mod_spawn_companions\dialogue\yenneferFollowWithKiss.w2scene", true);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  YENNEFER – Tier 2: Przy ognisku (wieczorny) – soft approach
//=============================================================================

class MCM_AR_Yen_CampfireEvening extends MCM_RomanceInteraction
{
	default id              = 'yen_campfire_evening';
	default targetNpc       = 'yennefer';
	default minAffinity     = 30;
	default cooldownSeconds = 900.0;
	default triggerType     = RTT_Gesture;
	default weight          = 7;
	// ID 1002979: "Splendid. We finally got the chance to talk."
	default lineId          = 1002979;
	default lineText        = "Splendid. We finally got the chance to talk.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNearCampfire) return "no_campfire";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		SoftApproach(npc, player, 2.0);
		approachOk = WaitForApproach(npc, player, 2.0, 8.0);
		if (!approachOk)
		{
			EndSoft(npc);
			return false;
		}
		PlayAnimSimple(npc, 'woman_sit_stump_idle');
		Sleep(1.0);
		PlayBark(npc);
		EndSoft(npc);
		return true;
	}
}

//=============================================================================
//  YENNEFER – Tier 4: Zaproszenie intymne przy "sweet spot" (NaughtyPoint)
//=============================================================================

class MCM_AR_Yen_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'yen_intimate_invite';
	default targetNpc       = 'yennefer';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;  // 1h
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	// ID 1123805: "That I regret we didn't try that earlier. Much earlier."
	default lineId          = 1123805;
	default lineText        = "That I regret we didn't try that earlier. Much earlier.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		// Tylko obok punktu intymnego MCME (scena wymaga action pointu <=20m)
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		// NPC musi miec scene intymna (rejestracja specialData lub plik)
		if (!HasIntimateScene(npc)) return "no_scene";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4 = scena intymna: zgoda ZAWSZE wymagana ([C]), niezaleznie
		// od configu – autonomia konczy sie na propozycji, nie na scenie.
		consent = ShowConsentPrompt("[C] Zostan z Yennefer na osobnosci", 10.0, npc);

		if (!consent)
		{
			EndSoft(npc);
			MarkRejected();
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  YENNEFER – Tier 1: Zazdrość (gdy Triss też jest w drużynie) – ambient
//=============================================================================

class MCM_AR_Yen_JealousySnark extends MCM_RomanceInteraction
{
	default id              = 'yen_jealousy_snark';
	default targetNpc       = 'yennefer';
	default minAffinity     = 0;
	default cooldownSeconds = 480.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 9;
	// ID 1123826: "Come, now, Geralt. I know you... what's going on with you and Triss."
	default lineId          = 1123826;
	default lineText        = "Come, now, Geralt. I know you. Well enough to know exactly what's going on with you and Triss.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		// Aktywne TYLKO gdy jest zazdrość i tryb zazdrości włączony, i Triss jest obecna
		if (!MCM_AR_GetConfig().IsJealousyModeOn()) return "jealousy_off";
		if (!ctx.hasRivals) return "no_rivals";
		if (!ctx.companionsInParty.Contains('triss')) return "no_triss";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var rival : CNewNPC;

		// Dogryzanie skierowane do RYVALKI: Yen patrzy na Triss, nie na Geralta
		rival = MCM_AR_FindCompanion("triss");
		if (rival)
			npc.EnableDynamicLookAt(rival, 6.0);
		else
			npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

//=============================================================================
//  YENNEFER – Tier 1: Tawerna (propozycja wina) – ambient
//=============================================================================

class MCM_AR_Yen_TavernWine extends MCM_RomanceInteraction
{
	default id              = 'yen_tavern_wine';
	default targetNpc       = 'yennefer';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 6;
	// ID 373572: "Geralt?" – kuratorowana przez MCME linia Yen (przywolanie)
	default lineId          = 373572;
	default lineText        = "Geralt?";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isInTavern) return "not_in_tavern";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

//=============================================================================
//  TRISS – Tier 1: Flirt w marszu – ambient
//=============================================================================

class MCM_AR_Triss_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'triss_oneliner_flirt';
	default targetNpc       = 'triss';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	// 1009039 "Which doesn't mean..." to byla urwana odpowiedz – zamienione
	// na voiceset NPC: cieple przywitanie zawsze w JEJ glosie.
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "It's good to have you near, Geralt.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (ctx.isNight) return "night";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

//=============================================================================
//  TRISS – Tier 2: Objęcie po walce – soft approach
//=============================================================================

class MCM_AR_Triss_PostCombatHug extends MCM_RomanceInteraction
{
	default id              = 'triss_postcombat_hug';
	default targetNpc       = 'triss';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'concern';
	// ID 1127010: "Tsk… Oh Geralt… What've you gotten yourself into now?"
	default lineId          = 1127010;
	default lineText        = "Tsk… Oh Geralt… What've you gotten yourself into now?";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (ctx.playerHealthRatio > 0.60) return "hp_ok";
		if (MCM_AR_GetCore().GetSecondsSinceCombat() > 300.0) return "no_recent_combat";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		SoftApproach(npc, player, 1.5);
		approachOk = WaitForApproach(npc, player, 1.5, 8.0);
		if (!approachOk)
		{
			EndSoft(npc);
			return false;
		}
		PlayBark(npc);
		Sleep(2.0);
		PlayAnimSimple(npc, 'woman_hug_idle');
		EndSoft(npc);
		return true;
	}
}

//=============================================================================
//  TRISS – Tier 3: Nocna rozmowa (propozycja -> [C] -> scena dialogu)
//=============================================================================

class MCM_AR_Triss_NightWhisper extends MCM_RomanceInteraction
{
	default id              = 'triss_night_whisper';
	default targetNpc       = 'triss';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	// ID 1000783: "Hmmmm Geraaalt" – kuratorowana przez MCME linia Triss.
	// (1074691 "Gladly. I was about to ask the same." byla ODPOWIEDZIA
	//  na zaproszenie – zla jako zaproszenie, zamieniona.)
	default lineId          = 1000783;
	default lineText        = "Hmmmm, Geraaalt…";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNight) return "not_night";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[C] Zostan z Triss", 10.0, npc);
		}
		else
		{
			consent = WaitForApproach(npc, player, 2.4, 8.0);
		}

		if (!consent)
		{
			EndSoft(npc);
			if (MCM_AR_GetConfig().RequiresPlayerConsent())
			{
				MarkRejected();
			}
			MCM_AR_Log("[AR] Gracz odrzucil/ignorowal szept Triss");
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayDialogueScene(npc, "dlc\mod_spawn_companions\dialogue\trissFollowWithKiss.w2scene", true);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  TRISS – Tier 2: Przy ognisku (ciepło) – soft approach
//=============================================================================

class MCM_AR_Triss_CampfireWarmth extends MCM_RomanceInteraction
{
	default id              = 'triss_campfire_warmth';
	default targetNpc       = 'triss';
	default minAffinity     = 20;
	default cooldownSeconds = 900.0;
	default triggerType     = RTT_Gesture;
	default weight          = 7;
	// 480807 byl narracja 3. osoby ("Six months ago Triss Merigold parted...")
	// – zamienione na voiceset NPC + wlasny napis.
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Stay by the fire a while, Geralt.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNearCampfire) return "no_campfire";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		SoftApproach(npc, player, 2.0);
		approachOk = WaitForApproach(npc, player, 2.0, 8.0);
		if (!approachOk)
		{
			EndSoft(npc);
			return false;
		}
		PlayAnimSimple(npc, 'woman_sit_stump_idle');
		Sleep(1.0);
		PlayBark(npc);
		EndSoft(npc);
		return true;
	}
}

//=============================================================================
//  TRISS – Tier 3: Pocałunek w ogrodzie (propozycja -> [C] -> scena dialogu)
//=============================================================================

class MCM_AR_Triss_GardenKiss extends MCM_RomanceInteraction
{
	default id              = 'triss_garden_kiss';
	default targetNpc       = 'triss';
	default minAffinity     = 70;
	default cooldownSeconds = 2400.0;
	default triggerType     = RTT_Prompt;
	default weight          = 4;
	default barkMimic       = 'flirt';
	// 1074691 tez tu bylo bledne (odpowiedz jako zaproszenie) – voiceset.
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Come here, Geralt.";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[C] Pocaluj Triss", 10.0, npc);
		}
		else
		{
			consent = WaitForApproach(npc, player, 2.2, 8.0);
		}

		if (!consent)
		{
			EndSoft(npc);
			if (MCM_AR_GetConfig().RequiresPlayerConsent())
			{
				MarkRejected();
			}
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayDialogueScene(npc, "dlc\mod_spawn_companions\dialogue\trissFollowWithKiss.w2scene", true);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  TRISS – Tier 4: Zaproszenie intymne przy "sweet spot"
//=============================================================================

class MCM_AR_Triss_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'triss_intimate_invite';
	default targetNpc       = 'triss';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	// "Hmmmm Geraaalt" – ciepla, wymowna linia Triss
	default lineId          = 1000783;
	default lineText        = "Hmmmm, Geraaalt…";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		if (!HasIntimateScene(npc)) return "no_scene";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4 = scena intymna: zgoda ZAWSZE wymagana ([C]), niezaleznie
		// od configu – autonomia konczy sie na propozycji, nie na scenie.
		consent = ShowConsentPrompt("[C] Zostan z Triss na osobnosci", 10.0, npc);

		if (!consent)
		{
			EndSoft(npc);
			MarkRejected();
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  TRISS – Tier 1: Zazdrość (gdy Yen jest w drużynie) – ambient
//=============================================================================

class MCM_AR_Triss_JealousySnark extends MCM_RomanceInteraction
{
	default id              = 'triss_jealousy_snark';
	default targetNpc       = 'triss';
	default minAffinity     = 0;
	default cooldownSeconds = 480.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 9;
	// ID 1008871: "Oh, you really want to talk about it? Maybe I should get Yennefer?..."
	default lineId          = 1008871;
	default lineText        = "Oh, you really want to talk about it? Maybe I should get Yennefer? Wouldn't want her to miss any of this.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!MCM_AR_GetConfig().IsJealousyModeOn()) return "jealousy_off";
		if (!ctx.hasRivals) return "no_rivals";
		if (!ctx.companionsInParty.Contains('yennefer')) return "no_yennefer";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var rival : CNewNPC;

		// Dogryzanie skierowane do RYVALKI: Triss patrzy na Yen, nie na Geralta
		rival = MCM_AR_FindCompanion("yennefer");
		if (rival)
			npc.EnableDynamicLookAt(rival, 6.0);
		else
			npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

//=============================================================================
//  KEIRA – Tier 1: Flirt / prowokacja – ambient
//=============================================================================

class MCM_AR_Keira_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'keira_oneliner_flirt';
	default targetNpc       = 'keira_metz';
	default minAffinity     = 0;
	default cooldownSeconds = 320.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	// ID 588361: "Oh, you're definitely no boy. You're a strong, poised witcher..."
	default lineId          = 588361;
	default lineText        = "Oh, you're definitely no boy. You're a strong, poised witcher who will surely help a woman in need.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (ctx.isNight) return "night";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

//=============================================================================
//  KEIRA – Tier 2: Komentarz medyczny / opatrzenie po walce – soft approach
//=============================================================================

class MCM_AR_Keira_PostCombatHeal extends MCM_RomanceInteraction
{
	default id              = 'keira_postcombat_heal';
	default targetNpc       = 'keira_metz';
	default minAffinity     = 10;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 9;
	default barkMimic       = 'concern';
	// 553849 "Whew, thank you." bylo odwrotnie (ona dziekuje zamiast
	// pomagac) – voiceset + wlasny napis o opatrzeniu.
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Hold still, let me look at that wound.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (ctx.playerHealthRatio > 0.50) return "hp_ok";
		if (MCM_AR_GetCore().GetSecondsSinceCombat() > 300.0) return "no_recent_combat";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		SoftApproach(npc, player, 1.8);
		approachOk = WaitForApproach(npc, player, 1.8, 8.0);
		if (!approachOk)
		{
			EndSoft(npc);
			return false;
		}
		PlayBark(npc);
		Sleep(2.0);
		// Keira rzuca Quen na gracza (efekt symboliczny)
		PlayAnimSimple(npc, 'cast_sign_quen_idle');
		EndSoft(npc);
		return true;
	}
}

//=============================================================================
//  KEIRA – Tier 3: Nocna propozycja (propozycja -> [C] -> scena dialogu)
//=============================================================================

class MCM_AR_Keira_NightProposal extends MCM_RomanceInteraction
{
	default id              = 'keira_night_proposal';
	default targetNpc       = 'keira_metz';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	// ID 589402: "I daresay this one, once sprung, would thrill you…
	//  Ah well, change your mind - come and see me." (jej linia)
	default lineId          = 589402;
	default lineText        = "I daresay this one, once sprung, would thrill you… Ah well, change your mind - come and see me.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNight) return "not_night";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[C] Przyjmij zaproszenie Keiry", 10.0, npc);
		}
		else
		{
			consent = WaitForApproach(npc, player, 2.4, 8.0);
		}

		if (!consent)
		{
			EndSoft(npc);
			if (MCM_AR_GetConfig().RequiresPlayerConsent())
			{
				MarkRejected();
			}
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayDialogueScene(npc, "dlc\mod_spawn_companions\dialogue\keiraFollowWithKiss.w2scene", true);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  KEIRA – Tier 1: Przy ognisku (komentarz czarodziejki) – ambient
//=============================================================================

class MCM_AR_Keira_CampfireWitch extends MCM_RomanceInteraction
{
	default id              = 'keira_campfire_witch';
	default targetNpc       = 'keira_metz';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 7;
	// ID 588324: "Perhaps… perhaps you'd stay just a bit longer?..."
	default lineId          = 588324;
	default lineText        = "Perhaps… perhaps you'd stay just a bit longer? There's one small favor you might yet do for me.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNearCampfire) return "no_campfire";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

//=============================================================================
//  KEIRA – Tier 4: Zaproszenie intymne przy "sweet spot"
//=============================================================================

class MCM_AR_Keira_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'keira_intimate_invite';
	default targetNpc       = 'keira_metz';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	// "...thrill you... come and see me" – dwoista propozycja pasuje idealnie
	default lineId          = 589402;
	default lineText        = "I daresay this one, once sprung, would thrill you… Ah well, change your mind - come and see me.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		if (!HasIntimateScene(npc)) return "no_scene";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4 = scena intymna: zgoda ZAWSZE wymagana ([C]), niezaleznie
		// od configu – autonomia konczy sie na propozycji, nie na scenie.
		consent = ShowConsentPrompt("[C] Zostan z Keira na osobnosci", 10.0, npc);

		if (!consent)
		{
			EndSoft(npc);
			MarkRejected();
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  SHANI – Tier 1: Flirt / lekarka na polu – ambient
//=============================================================================

class MCM_AR_Shani_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'shani_oneliner_flirt';
	default targetNpc       = 'shani';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	// ID 1108852: "I think you look charming."
	default lineId          = 1108852;
	default lineText        = "I think you look charming.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (ctx.isNight) return "night";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

//=============================================================================
//  SHANI – Tier 2: Opatrzenie po walce (lekarka) – soft approach
//=============================================================================

class MCM_AR_Shani_PostCombatMedic extends MCM_RomanceInteraction
{
	default id              = 'shani_postcombat_medic';
	default targetNpc       = 'shani';
	default minAffinity     = 10;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 9;
	default barkMimic       = 'concern';
	// ID 1101758: "Do you need help?"
	default lineId          = 1101758;
	default lineText        = "Do you need help?";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (ctx.playerHealthRatio > 0.55) return "hp_ok";
		if (MCM_AR_GetCore().GetSecondsSinceCombat() > 300.0) return "no_recent_combat";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		SoftApproach(npc, player, 1.5);
		approachOk = WaitForApproach(npc, player, 1.5, 8.0);
		if (!approachOk)
		{
			EndSoft(npc);
			return false;
		}
		PlayBark(npc);
		Sleep(2.5);
		PlayAnimSimple(npc, 'woman_tend_wounds_idle');
		EndSoft(npc);
		return true;
	}
}

//=============================================================================
//  SHANI – Tier 3: Nocny relaks (propozycja -> [C] -> scena dialogu)
//=============================================================================

class MCM_AR_Shani_NightRelax extends MCM_RomanceInteraction
{
	default id              = 'shani_night_relax';
	default targetNpc       = 'shani';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	// ID 1108130: "It would do you good to be more relaxed sometimes."
	default lineId          = 1108130;
	default lineText        = "It would do you good to be more relaxed sometimes.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNight) return "not_night";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[C] Zostan ze Shani", 10.0, npc);
		}
		else
		{
			consent = WaitForApproach(npc, player, 2.4, 8.0);
		}

		if (!consent)
		{
			EndSoft(npc);
			if (MCM_AR_GetConfig().RequiresPlayerConsent())
			{
				MarkRejected();
			}
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayDialogueScene(npc, "dlc\mod_spawn_companions\dialogue\shaniFollowWithKiss.w2scene", true);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  SHANI – Tier 4: Zaproszenie intymne przy "sweet spot"
//=============================================================================

class MCM_AR_Shani_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'shani_intimate_invite';
	default targetNpc       = 'shani';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	// "It would do you good to be more relaxed" – pasuje tez do intymnosci
	default lineId          = 1108130;
	default lineText        = "It would do you good to be more relaxed sometimes.";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		if (!HasIntimateScene(npc)) return "no_scene";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4 = scena intymna: zgoda ZAWSZE wymagana ([C]), niezaleznie
		// od configu – autonomia konczy sie na propozycji, nie na scenie.
		consent = ShowConsentPrompt("[C] Zostan ze Shani na osobnosci", 10.0, npc);

		if (!consent)
		{
			EndSoft(npc);
			MarkRejected();
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}
