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
	RegisterAction(new MCM_AR_Yen_JealousySnark2        in this);
	RegisterAction(new MCM_AR_Yen_TavernWine            in this);
	RegisterAction(new MCM_AR_Yen_GiftRequest          in this);

	// ===== TRISS =====
	RegisterAction(new MCM_AR_Triss_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Triss_PostCombatHug       in this);
	RegisterAction(new MCM_AR_Triss_NightWhisper        in this);
	RegisterAction(new MCM_AR_Triss_CampfireWarmth      in this);
	RegisterAction(new MCM_AR_Triss_KissInvite          in this);
	RegisterAction(new MCM_AR_Triss_IntimateInvite      in this);
	RegisterAction(new MCM_AR_Triss_JealousySnark       in this);
	RegisterAction(new MCM_AR_Triss_GiftRequest        in this);

	// ===== KEIRA =====
	RegisterAction(new MCM_AR_Keira_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Keira_PostCombatHeal      in this);
	RegisterAction(new MCM_AR_Keira_NightProposal       in this);
	RegisterAction(new MCM_AR_Keira_CampfireWitch       in this);
	RegisterAction(new MCM_AR_Keira_IntimateInvite      in this);
	RegisterAction(new MCM_AR_Keira_GiftRequest        in this);

	// ===== SHANI =====
	RegisterAction(new MCM_AR_Shani_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Shani_PostCombatMedic     in this);
	RegisterAction(new MCM_AR_Shani_NightRelax          in this);
	RegisterAction(new MCM_AR_Shani_IntimateInvite      in this);
	RegisterAction(new MCM_AR_Shani_GiftRequest        in this);

	RegisterAction(new MCM_AR_Triss_TavernDrink         in this);
	RegisterAction(new MCM_AR_Keira_TavernDrink         in this);
	RegisterAction(new MCM_AR_Shani_TavernDrink         in this);
	RegisterAction(new MCM_AR_Yen_NightFiller           in this);
	RegisterAction(new MCM_AR_Triss_NightFiller         in this);
	RegisterAction(new MCM_AR_Keira_NightFiller         in this);
	RegisterAction(new MCM_AR_Shani_NightFiller         in this);
	RegisterAction(new MCM_AR_WeatherBark               in this);
	RegisterAction(new MCM_AR_HorseBark                 in this);
	RegisterAction(new MCM_AR_InteriorBark              in this);
	RegisterAction(new MCM_AR_BoatBark                  in this);
	RegisterAction(new MCM_AR_AfterglowBark             in this);
	RegisterAction(new MCM_AR_JealousyAftermath         in this);
	RegisterAction(new MCM_AR_Rosa_OneLinerFlirt        in this);
	RegisterAction(new MCM_AR_Tomira_OneLinerFlirt      in this);
	RegisterAction(new MCM_AR_Rosa_Kiss                 in this);
	RegisterAction(new MCM_AR_Tomira_Kiss               in this);
	RegisterAction(new MCM_AR_Ciri_Hug                  in this);
	RegisterAction(new MCM_AR_Rosa_GiftRequest          in this);
	RegisterAction(new MCM_AR_Tomira_GiftRequest        in this);
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
	default lineKey         = "ar_line_yen_oneliner_flirt";

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
	default cooldownSeconds = 900.0;  // 15 min (heal, cd liczony od proby)
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'concern';
	// ID 336587: "Next time stand behind me, all right? ..."
	default lineId          = 336587;
	default lineText        = "Next time stand behind me, all right? I'd rather defend you than have to patch you up afterwards.";
	default lineKey         = "ar_line_yen_postcombat_care";

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
		HealPlayer(npc, player, 0.20);
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
	default lineKey         = "ar_line_yen_night_invitation";

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
			consent = ShowConsentPrompt(AR_T("ar_prompt_yen_closer", "[C] Come closer to Yennefer"), 10.0, npc);
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
			MCM_AR_Log("[AR] Player declined/ignored Yen's invite");
			return false;
		}

		// FAZA 2 – staging dopiero po akceptacji (~1-2s locka), potem scena
		HardStage(npc, player, 1.5);
		ok = PlayKissScene(npc);
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
	default lineKey         = "ar_line_yen_campfire_evening";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNearCampfire) return "no_campfire";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// Model Keiry: brak podejscia i animacji (woman_sit_stump_idle
		// siadala w powietrzu bez propsa) – tylko lookat + bark.
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
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
	default lineKey         = "ar_line_yen_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		// Tylko obok punktu intymnego MCME (scena wymaga action pointu <=20m)
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		// NPC musi miec scene intymna + plik sceny musi istniec (DLC gate)
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4 = scena intymna: zgoda ZAWSZE wymagana ([C]), niezaleznie
		// od configu – autonomia konczy sie na propozycji, nie na scenie.
		consent = ShowConsentPrompt(AR_T("ar_prompt_yen_intimate", "[C] Stay alone with Yennefer"), 10.0, npc);

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
	default lineKey         = "ar_line_yen_jealousy_snark";

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
//  YENNEFER – Tier 1: Zazdrość #2 (gdy Triss też jest w drużynie) – ambient
//=============================================================================

class MCM_AR_Yen_JealousySnark2 extends MCM_RomanceInteraction
{
	default id              = 'yen_jealousy_snark2';
	default targetNpc       = 'yennefer';
	default minAffinity     = 0;
	default cooldownSeconds = 480.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 9;
	// ID 1123980: "If you think I can't see what's happening... you're wrong."
	default lineId          = 1123980;
	default lineText        = "If you think I can't see what's happening between you and that red-haired witch... you're wrong, Geralt.";
	default lineKey         = "ar_line_yen_jealousy_snark2";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!MCM_AR_GetConfig().IsJealousyModeOn()) return "jealousy_off";
		if (!ctx.hasRivals) return "no_rivals";
		if (!ctx.companionsInParty.Contains('triss')) return "no_triss";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var rival : CNewNPC;

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
	default lineKey         = "ar_line_yen_tavern_wine";

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
	default lineKey         = "ar_line_triss_oneliner_flirt";

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
	default cooldownSeconds = 900.0;  // 15 min (heal, cd liczony od proby)
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'concern';
	// ID 1127010: "Tsk… Oh Geralt… What've you gotten yourself into now?"
	default lineId          = 1127010;
	default lineText        = "Tsk... Oh Geralt... What've you gotten yourself into now?";
	default lineKey         = "ar_line_triss_postcombat_hug";

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
		Sleep(1.0);
		HealPlayer(npc, player, 0.20);
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
	default lineText        = "Hmmmm, Geraaalt...";
	default lineKey         = "ar_line_triss_night_whisper";

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
			consent = ShowConsentPrompt(AR_T("ar_prompt_triss_stay", "[C] Stay with Triss"), 10.0, npc);
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
			MCM_AR_Log("[AR] Player declined/ignored Triss' whisper");
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayKissScene(npc);
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
	default lineKey         = "ar_line_triss_campfire_warmth";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNearCampfire) return "no_campfire";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		// Model Keiry: brak podejscia i animacji (woman_sit_stump_idle
		// siadala w powietrzu bez propsa) – tylko lookat + bark.
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

//=============================================================================
//  TRISS – Tier 3: Pocałunek w ogrodzie (propozycja -> [C] -> scena dialogu)
//=============================================================================

class MCM_AR_Triss_KissInvite extends MCM_RomanceInteraction
{
	default id              = 'triss_kiss_invite';
	default targetNpc       = 'triss';
	default minAffinity     = 70;
	default cooldownSeconds = 2400.0;
	default triggerType     = RTT_Prompt;
	default weight          = 4;
	default barkMimic       = 'flirt';
	// 1074691 tez tu bylo bledne (odpowiedz jako zaproszenie) – voiceset.
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Come here, Geralt.";
	default lineKey         = "ar_line_triss_kiss_invite";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt(AR_T("ar_prompt_triss_kiss", "[C] Kiss Triss"), 10.0, npc);
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
		ok = PlayKissScene(npc);
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
	default lineText        = "Hmmmm, Geraaalt...";
	default lineKey         = "ar_line_triss_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4 = scena intymna: zgoda ZAWSZE wymagana ([C]), niezaleznie
		// od configu – autonomia konczy sie na propozycji, nie na scenie.
		consent = ShowConsentPrompt(AR_T("ar_prompt_triss_intimate", "[C] Stay alone with Triss"), 10.0, npc);

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
	default lineKey         = "ar_line_triss_jealousy_snark";

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
	default lineKey         = "ar_line_keira_oneliner_flirt";

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
	default cooldownSeconds = 900.0;  // 15 min (heal, cd liczony od proby)
	default triggerType     = RTT_Gesture;
	default weight          = 9;
	default barkMimic       = 'concern';
	// 553849 "Whew, thank you." bylo odwrotnie (ona dziekuje zamiast
	// pomagac) – voiceset + wlasny napis o opatrzeniu.
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Hold still, let me look at that wound.";
	default lineKey         = "ar_line_keira_postcombat_heal";

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
		// Keira rzuca Quen na gracza + realny heal (25% max HP)
		PlayAnimSimple(npc, 'cast_sign_quen_idle');
		Sleep(1.0);
		HealPlayer(npc, player, 0.25);
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
	default lineText        = "I daresay this one, once sprung, would thrill you... Ah well, change your mind - come and see me.";
	default lineKey         = "ar_line_keira_night_proposal";

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
			consent = ShowConsentPrompt(AR_T("ar_prompt_keira_invite", "[C] Accept Keira's invitation"), 10.0, npc);
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
		ok = PlayKissScene(npc);
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
	default lineText        = "Perhaps... perhaps you'd stay just a bit longer? There's one small favor you might yet do for me.";
	default lineKey         = "ar_line_keira_campfire_witch";

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
	default lineText        = "I daresay this one, once sprung, would thrill you... Ah well, change your mind - come and see me.";
	default lineKey         = "ar_line_keira_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4 = scena intymna: zgoda ZAWSZE wymagana ([C]), niezaleznie
		// od configu – autonomia konczy sie na propozycji, nie na scenie.
		consent = ShowConsentPrompt(AR_T("ar_prompt_keira_intimate", "[C] Stay alone with Keira"), 10.0, npc);

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
	default lineKey         = "ar_line_shani_oneliner_flirt";

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
	default cooldownSeconds = 900.0;  // 15 min (heal, cd liczony od proby)
	default triggerType     = RTT_Gesture;
	default weight          = 9;
	default barkMimic       = 'concern';
	// ID 1101758: "Do you need help?"
	default lineId          = 1101758;
	default lineText        = "Do you need help?";
	default lineKey         = "ar_line_shani_postcombat_medic";

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
		Sleep(1.0);
		HealPlayer(npc, player, 0.25);
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
	default lineKey         = "ar_line_shani_night_relax";

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
			consent = ShowConsentPrompt(AR_T("ar_prompt_shani_stay", "[C] Stay with Shani"), 10.0, npc);
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
		ok = PlayKissScene(npc);
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
	default lineKey         = "ar_line_shani_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4 = scena intymna: zgoda ZAWSZE wymagana ([C]), niezaleznie
		// od configu – autonomia konczy sie na propozycji, nie na scenie.
		consent = ShowConsentPrompt(AR_T("ar_prompt_shani_intimate", "[C] Stay alone with Shani"), 10.0, npc);

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
//  GIFT REQUESTS (Kierunek C1) – Yennefer, Triss, Keira, Shani
//=============================================================================

class MCM_AR_Yen_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'yen_gift_request';
	default targetNpc       = 'yennefer';
	default lineId          = 1064245;
	default lineText        = "A glass of good wine would be lovely, Geralt.";
	default lineKey         = "ar_line_yen_gift_request";
	default thanksLineText  = "Thank you, Geralt.";
	default thanksLineKey   = "ar_thanks_yen";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Est Est');
		gifts.PushBack('Beauclair White');
		gifts.PushBack('Erveluce');
	}
}

class MCM_AR_Triss_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'triss_gift_request';
	default targetNpc       = 'triss';
	default lineId          = 1064248;
	default lineText        = "Geralt, do you happen to have some wine?";
	default lineKey         = "ar_line_triss_gift_request";
	default thanksLineText  = "Thank you, that's wonderful.";
	default thanksLineKey   = "ar_thanks_triss";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Beauclair White');
		gifts.PushBack('Mettina Rose');
		gifts.PushBack('Erveluce');
	}
}

class MCM_AR_Keira_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'keira_gift_request';
	default targetNpc       = 'keira_metz';
	default lineId          = 1064251;
	default lineText        = "I could really use a sip of good wine right now.";
	default lineKey         = "ar_line_keira_gift_request";
	default thanksLineText  = "Mmm, you do know how to treat a lady.";
	default thanksLineKey   = "ar_thanks_keira";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Erveluce');
		gifts.PushBack('Est Est');
		gifts.PushBack('Mettina Rose');
	}
}

class MCM_AR_Shani_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'shani_gift_request';
	default targetNpc       = 'shani';
	default lineId          = 1064254;
	default lineText        = "A long day... Do you have anything to drink?";
	default lineKey         = "ar_line_shani_gift_request";
	default thanksLineText  = "Just what I needed, thank you Geralt.";
	default thanksLineKey   = "ar_thanks_shani";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Mettina Rose');
		gifts.PushBack('Beauclair White');
		gifts.PushBack('Erveluce');
	}
}


// --- Tavern banter ---

class MCM_AR_Triss_TavernDrink extends MCM_RomanceInteraction
{
	default id              = 'triss_tavern_drink';
	default targetNpc       = 'triss';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 6;
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Another round? This one's on me.";
	default lineKey         = "ar_line_triss_tavern_drink";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isInTavern) return "not_in_tavern";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayDrinkingAnimation(npc);
		PlayBark(npc);
		return true;
	}
}

class MCM_AR_Keira_TavernDrink extends MCM_RomanceInteraction
{
	default id              = 'keira_tavern_drink';
	default targetNpc       = 'keira';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 6;
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "A drink, Geralt? Even a sorceress needs to unwind.";
	default lineKey         = "ar_line_keira_tavern_drink";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isInTavern) return "not_in_tavern";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayDrinkingAnimation(npc);
		PlayBark(npc);
		return true;
	}
}

class MCM_AR_Shani_TavernDrink extends MCM_RomanceInteraction
{
	default id              = 'shani_tavern_drink';
	default targetNpc       = 'shani';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 6;
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Sit down, drink. Doctor's orders.";
	default lineKey         = "ar_line_shani_tavern_drink";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isInTavern) return "not_in_tavern";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayDrinkingAnimation(npc);
		PlayBark(npc);
		return true;
	}
}

// --- Night filler ---

class MCM_AR_Yen_NightFiller extends MCM_RomanceInteraction
{
	default id              = 'yen_night_filler';
	default targetNpc       = 'yennefer';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "The night suits us, witcher.";
	default lineKey         = "ar_line_yen_night_filler";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNight) return "not_night";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

class MCM_AR_Triss_NightFiller extends MCM_RomanceInteraction
{
	default id              = 'triss_night_filler';
	default targetNpc       = 'triss';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Quiet... I like the world better at this hour.";
	default lineKey         = "ar_line_triss_night_filler";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNight) return "not_night";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

class MCM_AR_Keira_NightFiller extends MCM_RomanceInteraction
{
	default id              = 'keira_night_filler';
	default targetNpc       = 'keira';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Can't sleep either? Village nights are so dull.";
	default lineKey         = "ar_line_keira_night_filler";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNight) return "not_night";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

class MCM_AR_Shani_NightFiller extends MCM_RomanceInteraction
{
	default id              = 'shani_night_filler';
	default targetNpc       = 'shani';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "A medic's work doesn't end at sundown.";
	default lineKey         = "ar_line_shani_night_filler";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNight) return "not_night";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

// --- Contextual barks ---

class MCM_AR_WeatherBark extends MCM_RomanceInteraction
{
	default id              = 'ar_weather_bark';
	default targetNpc       = '';
	default minAffinity     = 0;
	default cooldownSeconds = 900.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 5;
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "This weather... at least we're in it together.";
	default lineKey         = "ar_line_weather_bark";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (ctx.weatherName != 'WT_Rain_Storm' && ctx.weatherName != 'WT_Light_Rain' &&
		    ctx.weatherName != 'WT_Sun_Shower' && ctx.weatherName != 'WT_Snow' &&
		    ctx.weatherName != 'WT_Blizzard' && ctx.weatherName != 'WT_Fog')
		{
			return "weather_ok";
		}
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

class MCM_AR_HorseBark extends MCM_RomanceInteraction
{
	default id              = 'ar_horse_bark';
	default targetNpc       = '';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 6;
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Riding with you beats walking alone.";
	default lineKey         = "ar_line_horse_bark";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.playerMounted || ctx.playerOnBoat) return "not_mounted";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

class MCM_AR_InteriorBark extends MCM_RomanceInteraction
{
	default id              = 'ar_interior_bark';
	default targetNpc       = '';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 5;
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Nice to be out of the wind for a bit.";
	default lineKey         = "ar_line_interior_bark";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isInInterior || ctx.isInTavern) return "not_in_interior";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

class MCM_AR_BoatBark extends MCM_RomanceInteraction
{
	default id              = 'ar_boat_bark';
	default targetNpc       = '';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 5;
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Water, wind and you. Could be worse.";
	default lineKey         = "ar_line_boat_bark";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.playerOnBoat) return "not_on_boat";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

// --- Afterglow & Jealousy ---

class MCM_AR_AfterglowBark extends MCM_RomanceInteraction
{
	default id              = 'ar_afterglow';
	default targetNpc       = '';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 8;
	default isTimeCritical  = true;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "That was... nice. Don't be a stranger.";
	default lineKey         = "ar_line_afterglow";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		var core : MCM_AutonomousRomanceCore;
		core = MCM_AR_GetCore();
		if (!core || core.lastSceneOkNpc != npc.scmcc.data.nam) return "no_recent_scene";
		if (theGame.GetEngineTimeAsSeconds() - core.lastSceneOkTime > 120.0) return "no_recent_scene";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var nam : name;

		if (!npc || !npc.scmcc || !npc.scmcc.data) return false;
		nam = npc.scmcc.data.nam;

		switch (nam)
		{
			case 'yennefer':
				lineKey  = "ar_afterglow_walk_yen";
				lineText = "Still thinking about that, Geralt? Keep your eyes on the road.";
				break;
			case 'triss':
				lineKey  = "ar_afterglow_walk_triss";
				lineText = "My heart's still racing a bit... It's good to be with you.";
				break;
			case 'keira_metz':
			case 'keira':
				lineKey  = "ar_afterglow_walk_keira";
				lineText = "Mmm, that certainly put some color in my cheeks.";
				break;
			case 'shani':
				lineKey  = "ar_afterglow_walk_shani";
				lineText = "A moment like that makes the whole journey lighter.";
				break;
			case 'anna_henrietta':
				lineKey  = "ar_afterglow_walk_anarietta";
				lineText = "A delightful interlude, Geralt. Let us not neglect what lies ahead.";
				break;
			case 'sq701_vivienne':
			case 'vivienne':
				lineKey  = "ar_afterglow_walk_vivienne";
				lineText = "My thoughts are lighter now... Thank you, Geralt.";
				break;
			case 'becca':
			case 'cerys':
				lineKey  = "ar_afterglow_walk_cerys";
				lineText = "Ha! Not losing your step, are you, Geralt?";
				break;
			case 'rosa_var_attre':
				lineKey  = "ar_afterglow_walk_rosa";
				lineText = "Careful not to trip, witcher. Your head seems elsewhere.";
				break;
			case 'prologue_village_herbalist':
			case 'tomira':
				lineKey  = "ar_afterglow_walk_tomira";
				lineText = "The wild doesn't seem quite so harsh with you beside me.";
				break;
			case 'syanna':
				lineKey  = "ar_afterglow_walk_syanna";
				lineText = "Surprised you're still walking straight, witcher.";
				break;
			case 'philippa_eilhart':
			case 'filippa':
				lineKey  = "ar_afterglow_walk_philippa";
				lineText = "Satisfactory distraction. Now keep your guard up.";
				break;
			case 'ves':
				lineKey  = "ar_afterglow_walk_ves";
				lineText = "Don't lose your focus now. Miles to go.";
				break;
			case 'mh303_succbus_v2':
			case 'salma':
				lineKey  = "ar_afterglow_walk_salma";
				lineText = "Your warmth stays with me, witcher... Delicious.";
				break;
			case 'pryscilla':
			case 'priscilla':
				lineKey  = "ar_afterglow_walk_priscilla";
				lineText = "A melody in the middle of nowhere. Thank you, Geralt.";
				break;
			case 'edna_var_attre':
				lineKey  = "ar_afterglow_walk_edna";
				lineText = "Still smiling, witcher? It was just a taste.";
				break;
			case 'fringilla_vigo':
			case 'fringilla':
				lineKey  = "ar_afterglow_walk_fringilla";
				lineText = "A brief peace in a bitter war. Let's keep moving.";
				break;
			case 'margarita':
			case 'margaritta':
				lineKey  = "ar_afterglow_walk_margarita";
				lineText = "A rare touch of comfort on an endless road.";
				break;
			case 'vampire_diva':
			case 'oriana':
			case 'orianna':
				lineKey  = "ar_afterglow_walk_orianna";
				lineText = "That taste lingers delightfully. Let's see what else the road brings.";
				break;
			case 'cirilla':
			case 'ciri':
				lineKey   = "ar_afterglow_walk_ciri";
				lineText  = "Good to walk beside you, Geralt. Like old times.";
				barkMimic = 'smile';
				break;
			default:
				lineKey   = "ar_line_afterglow";
				lineText  = "That was... nice. Don't be a stranger.";
				barkMimic = 'flirt';
				break;
		}

		if (nam != 'cirilla' && nam != 'ciri')
		{
			barkMimic = 'flirt';
		}

		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

class MCM_AR_JealousyAftermath extends MCM_RomanceInteraction
{
	default id              = 'ar_jealousy_aftermath';
	default targetNpc       = '';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 7;
	default isTimeCritical  = true;
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "I saw that. You could at least pretend to be discreet.";
	default lineKey         = "ar_line_jealousy_aftermath";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		var core : MCM_AutonomousRomanceCore;
		core = MCM_AR_GetCore();
		if (!MCM_AR_GetConfig().IsJealousyModeOn()) return "jealousy_off";
		if (!core || !ctx.hasRivals) return "no_rivals";
		if (theGame.GetEngineTimeAsSeconds() - core.lastSceneOkTime > 300.0) return "no_recent_scene";
		if (!MCM_AR_AreRivals(npc.scmcc.data.nam, core.lastSceneOkNpc)) return "not_rival";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

// --- Rosa var Attre & Tomira ---

class MCM_AR_Rosa_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'rosa_oneliner_flirt';
	default targetNpc       = 'rosa_var_attre';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Careful, witcher. I bruise egos for sport.";
	default lineKey         = "ar_line_rosa_oneliner_flirt";

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

class MCM_AR_Tomira_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'tomira_oneliner_flirt';
	default targetNpc       = 'prologue_village_herbalist';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "The road suits you, Geralt. My door is open if you tire of it.";
	default lineKey         = "ar_line_tomira_oneliner_flirt";

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

class MCM_AR_Rosa_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'rosa_gift_request';
	default targetNpc       = 'rosa_var_attre';
	default lineText        = "Surely a witcher of your standing keeps a decent vintage on him?";
	default lineKey         = "ar_line_rosa_gift_request";
	default thanksLineText  = "Acceptable. For once.";
	default thanksLineKey   = "ar_thanks_rosa";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Est Est');
		gifts.PushBack('Erveluce');
		gifts.PushBack('Mettina Rose');
	}
}

class MCM_AR_Tomira_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'tomira_gift_request';
	default targetNpc       = 'prologue_village_herbalist';
	default lineText        = "I'm running low on spirits for my tinctures. Spare any?";
	default lineKey         = "ar_line_tomira_gift_request";
	default thanksLineText  = "This will help more than you know. Thank you, Geralt.";
	default thanksLineKey   = "ar_thanks_tomira";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Alcohest');
		gifts.PushBack('Dwarven spirit');
		gifts.PushBack('Temerian rye');
	}
}

//=============================================================================
//  ROSA VAR ATTRE – Tier 3: Universal Kiss
//=============================================================================

class MCM_AR_Rosa_Kiss extends MCM_RomanceInteraction
{
	default id              = 'rosa_kiss';
	default targetNpc       = 'rosa_var_attre';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	default lineText        = "Geralt... Not so fast. Let me look at you.";
	default lineKey         = "ar_line_rosa_kiss";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt(AR_T("ar_prompt_rosa_kiss", "[C] Kiss Rosa"), 10.0, npc);
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
		ok = PlayKissScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  TOMIRA – Tier 3: Universal Kiss
//=============================================================================

class MCM_AR_Tomira_Kiss extends MCM_RomanceInteraction
{
	default id              = 'tomira_kiss';
	default targetNpc       = 'prologue_village_herbalist';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	default lineText        = "Come here, Geralt. You've earned a moment of peace.";
	default lineKey         = "ar_line_tomira_kiss";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt(AR_T("ar_prompt_tomira_kiss", "[C] Kiss Tomira"), 10.0, npc);
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
		ok = PlayKissScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  CIRILLA (CIRI) – Tier 3: Universal Hug (Warm Family Embrace)
//=============================================================================

class MCM_AR_Ciri_Hug extends MCM_RomanceInteraction
{
	default id              = 'ciri_hug';
	default targetNpc       = 'cirilla';
	default minAffinity     = 30;
	default cooldownSeconds = 1200.0;
	default triggerType     = RTT_Prompt;
	default weight          = 8;
	default barkMimic       = 'smile';
	default lineText        = "Geralt... Good to have you beside me.";
	default lineKey         = "ar_line_ciri_hug";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;
		var ok      : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt(AR_T("ar_prompt_ciri_hug", "[C] Hug Ciri"), 10.0, npc);
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
		ok = PlayHugScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

