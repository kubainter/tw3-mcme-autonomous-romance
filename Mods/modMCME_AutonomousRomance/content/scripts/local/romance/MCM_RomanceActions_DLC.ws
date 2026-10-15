/*****************************************************************************/
/* MCME Autonomous Romance - DLC NPC Actions                                 */
/* Rozszerzenie dla Anna Henrietta, Vivienne, Cerys                          */
/* Te akcje korzystają z tej samej architektury co Main, lecz są w osobnym  */
/* pliku – można je wyłączyć bez wpływu na Yen/Triss/Keira/Shani           */
/*****************************************************************************/

// ---------------------------------------------------------------------------
// Rejestracja DLC akcji – rozszerzenie registry przez @wrapMethod
// ---------------------------------------------------------------------------

@wrapMethod(MCM_RomanceActionRegistry)
function InitDefaultActions()
{
	wrappedMethod();  // Najpierw rejestruje Main akcje

	// ===== ANNA HENRIETTA =====
	RegisterAction(new MCM_AR_Anarietta_OneLinerFlirt   in this);
	RegisterAction(new MCM_AR_Anarietta_PostCombatPride in this);
	RegisterAction(new MCM_AR_Anarietta_NightRoyal      in this);
	RegisterAction(new MCM_AR_Anarietta_IntimateInvite  in this);
	RegisterAction(new MCM_AR_Anarietta_GiftRequest     in this);

	// ===== VIVIENNE =====
	RegisterAction(new MCM_AR_Vivienne_OneLinerFlirt    in this);
	RegisterAction(new MCM_AR_Vivienne_CampfireMystery  in this);
	RegisterAction(new MCM_AR_Vivienne_NightInvitation  in this);
	RegisterAction(new MCM_AR_Vivienne_IntimateInvite   in this);
	RegisterAction(new MCM_AR_Vivienne_GiftRequest      in this);

	// ===== CERYS =====
	RegisterAction(new MCM_AR_Cerys_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Cerys_PostCombatSkellige  in this);
	RegisterAction(new MCM_AR_Cerys_NightInvitation     in this);
	RegisterAction(new MCM_AR_Cerys_IntimateInvite      in this);
	RegisterAction(new MCM_AR_Cerys_GiftRequest         in this);

	// ===== INNE TOWARZYSZKI (DLC / ROOSTER) =====
	RegisterAction(new MCM_AR_Philippa_GiftRequest      in this);
	RegisterAction(new MCM_AR_Syanna_GiftRequest        in this);
	RegisterAction(new MCM_AR_Salma_GiftRequest         in this);
	RegisterAction(new MCM_AR_Ves_GiftRequest           in this);
}

//=============================================================================
//  ANNA HENRIETTA (Anarietta) – Tier 1: Królewskie docinki – ambient
//=============================================================================

class MCM_AR_Anarietta_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'anarietta_oneliner_flirt';
	default targetNpc       = 'anna_henrietta';
	default minAffinity     = 0;
	default cooldownSeconds = 350.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	// ID 1185354: "An excellent wine. You've good taste." – księżna wina
	default lineId          = 1185354;
	default lineText        = "An excellent wine. You've good taste.";
	default lineKey         = "ar_line_anarietta_oneliner_flirt";

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
//  ANNA HENRIETTA – Tier 2: Po walce (królewska duma) – soft approach
//=============================================================================

class MCM_AR_Anarietta_PostCombatPride extends MCM_RomanceInteraction
{
	default id              = 'anarietta_postcombat_pride';
	default targetNpc       = 'anna_henrietta';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'concern';
	// ID 1199342: "...How can you be so damned calm?" – idealne po walce
	default lineId          = 1199342;
	default lineText        = "There's something I'd like to know… How can you be so damned calm?";
	default lineKey         = "ar_line_anarietta_postcombat_pride";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (ctx.playerHealthRatio > 0.60) return "hp_ok";
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
		Sleep(2.5);
		EndSoft(npc);
		return true;
	}
}

//=============================================================================
//  ANNA HENRIETTA – Tier 3: Nocna propozycja królewska (propozycja -> scena)
//=============================================================================

class MCM_AR_Anarietta_NightRoyal extends MCM_RomanceInteraction
{
	default id              = 'anarietta_night_royal';
	default targetNpc       = 'anna_henrietta';
	default minAffinity     = 60;
	default cooldownSeconds = 2400.0;
	default triggerType     = RTT_Prompt;
	default weight          = 4;
	default barkMimic       = 'flirt';
	// ID 1192250: "Come, witcher." – jej głos, idealne zaproszenie
	default lineId          = 1192250;
	default lineText        = "Come, witcher.";
	default lineKey         = "ar_line_anarietta_night_royal";

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
			consent = ShowConsentPrompt(AR_T("ar_prompt_anarietta_escort", "[C] Accompany the Duchess"), 10.0, npc);
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
		ok = PlayDialogueScene(npc, "dlc\mod_spawn_companions\dialogue\anariettaFollowWithKiss.w2scene", true);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  ANNA HENRIETTA – Tier 4: Zaproszenie intymne przy "sweet spot"
//=============================================================================

class MCM_AR_Anarietta_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'anarietta_intimate_invite';
	default targetNpc       = 'anna_henrietta';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default lineId          = 1192250;
	default lineText        = "Come, witcher.";
	default lineKey         = "ar_line_anarietta_intimate_invite";

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
		consent = ShowConsentPrompt(AR_T("ar_prompt_anarietta_intimate", "[C] Stay alone with the Duchess"), 10.0, npc);

		if (!consent)
		{
			EndSoft(npc);
			MarkRejected();
			return false;
		}

		HardStage(npc, player, 1.5);
		// Anarietta nie ma rejestracji specialData.naughtyScene –
		// PlayIntimateScene użyje ścieżki manualnej (naughty\anarietta).
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  VIVIENNE – Tier 1: Flirt z tajemnicą – ambient
//=============================================================================

class MCM_AR_Vivienne_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'vivienne_oneliner_flirt';
	default targetNpc       = 'sq701_vivienne';
	default minAffinity     = 0;
	default cooldownSeconds = 360.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	// 1208517 byla odpowiedzia na niezaskladane pytanie o perfumy –
	// zamieniona na voiceset + wlasny napis.
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "A fine day for a ride, don't you think?";
	default lineKey         = "ar_line_vivienne_oneliner_flirt";

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
//  VIVIENNE – Tier 2: Przy ognisku (tajemnica Vivienne) – soft approach
//=============================================================================

class MCM_AR_Vivienne_CampfireMystery extends MCM_RomanceInteraction
{
	default id              = 'vivienne_campfire_mystery';
	default targetNpc       = 'sq701_vivienne';
	default minAffinity     = 20;
	default cooldownSeconds = 900.0;
	default triggerType     = RTT_Gesture;
	default weight          = 7;
	default barkMimic       = 'flirt';
	// ID 1197401: "Come." – lapidarne, ale w jej glosie i pasuje przy ognisku
	default lineId          = 1197401;
	default lineText        = "Come.";
	default lineKey         = "ar_line_vivienne_campfire_mystery";

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
		PlayBark(npc);
		Sleep(2.0);
		EndSoft(npc);
		return true;
	}
}

//=============================================================================
//  VIVIENNE – Tier 3: Nocne zaproszenie (propozycja -> scena)
//=============================================================================

class MCM_AR_Vivienne_NightInvitation extends MCM_RomanceInteraction
{
	default id              = 'vivienne_night_invitation';
	default targetNpc       = 'sq701_vivienne';
	default minAffinity     = 60;
	default cooldownSeconds = 2400.0;
	default triggerType     = RTT_Prompt;
	default weight          = 4;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Will you walk with me, Geralt?";
	default lineKey         = "ar_line_vivienne_night_invitation";

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
			consent = ShowConsentPrompt(AR_T("ar_prompt_vivienne_stay", "[C] Stay with Vivienne"), 10.0, npc);
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
		ok = PlayDialogueScene(npc, "dlc\mod_spawn_companions\dialogue\vivienneFollowWithKiss.w2scene", true);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  VIVIENNE – Tier 4: Zaproszenie intymne przy "sweet spot"
//=============================================================================

class MCM_AR_Vivienne_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'vivienne_intimate_invite';
	default targetNpc       = 'sq701_vivienne';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "The night is kind to us, Geralt.";
	default lineKey         = "ar_line_vivienne_intimate_invite";

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
		consent = ShowConsentPrompt(AR_T("ar_prompt_vivienne_intimate", "[C] Stay alone with Vivienne"), 10.0, npc);

		if (!consent)
		{
			EndSoft(npc);
			MarkRejected();
			return false;
		}

		HardStage(npc, player, 1.5);
		// Vivienne bez rejestracji specialData.naughtyScene – sciezka
		// manualna: naughty\vivienne\anywhere.w2scene (forma ludzka).
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  CERYS – Tier 1: Bezczelny flirt à la Skellige – ambient
//=============================================================================

class MCM_AR_Cerys_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'cerys_oneliner_flirt';
	default targetNpc       = 'becca';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	// ID 500732: "Show me what you've got, monster slayer!" – w 100% Cerys
	default lineId          = 500732;
	default lineText        = "Show me what you've got, monster slayer!";
	default lineKey         = "ar_line_cerys_oneliner_flirt";

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
//  CERYS – Tier 2: Po walce (Skellige honor) – soft approach
//=============================================================================

class MCM_AR_Cerys_PostCombatSkellige extends MCM_RomanceInteraction
{
	default id              = 'cerys_postcombat_skellige';
	default targetNpc       = 'becca';
	default minAffinity     = 20;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'concern';
	// 1000394 bylo o koronacji ("same lass I was, save for the title") –
	// nie o walce. Zamienione na voiceset + wlasny napis.
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Still standing? Good. Skellige needs no widows.";
	default lineKey         = "ar_line_cerys_postcombat_skellige";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (ctx.playerHealthRatio > 0.60) return "hp_ok";
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
		Sleep(2.5);
		EndSoft(npc);
		return true;
	}
}

//=============================================================================
//  CERYS – Tier 3: Nocne zaproszenie po skelligeańsku (propozycja -> scena)
//=============================================================================

class MCM_AR_Cerys_NightInvitation extends MCM_RomanceInteraction
{
	default id              = 'cerys_night_invitation';
	default targetNpc       = 'becca';
	default minAffinity     = 60;
	default cooldownSeconds = 2400.0;
	default triggerType     = RTT_Prompt;
	default weight          = 4;
	default barkMimic       = 'flirt';
	// ID 429005: "Geralt! Come! Think I've got an idea!" – energiczna Cerys
	default lineId          = 429005;
	default lineText        = "Geralt! Come! Think I've got an idea!";
	default lineKey         = "ar_line_cerys_night_invitation";

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
			consent = ShowConsentPrompt(AR_T("ar_prompt_cerys_stay", "[C] Stay with Cerys"), 10.0, npc);
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
		ok = PlayDialogueScene(npc, "dlc\mod_spawn_companions\dialogue\cerysFollowWithKiss.w2scene", true);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  CERYS – Tier 4: Zaproszenie intymne przy "sweet spot"
//=============================================================================

class MCM_AR_Cerys_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'cerys_intimate_invite';
	default targetNpc       = 'becca';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default lineId          = 429005;
	default lineText        = "Geralt! Come! Think I've got an idea!";
	default lineKey         = "ar_line_cerys_intimate_invite";

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
		consent = ShowConsentPrompt(AR_T("ar_prompt_cerys_intimate", "[C] Stay alone with Cerys"), 10.0, npc);

		if (!consent)
		{
			EndSoft(npc);
			MarkRejected();
			return false;
		}

		HardStage(npc, player, 1.5);
		// Cerys MA rejestracje specialData.naughtyScene (naughty\cerys) –
		// PlayIntimateScene pojdzie pełnym pipeline MCME PreNaughtyWith.
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//=============================================================================
//  GIFT REQUESTS (Kierunek C1) – Anna Henrietta, Vivienne, Cerys,
//                               Philippa, Syanna, Salma, Ves
//=============================================================================

class MCM_AR_Anarietta_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'anarietta_gift_request';
	default targetNpc       = 'anna_henrietta';
	default lineId          = 1185354;
	default lineText        = "An excellent wine. You've good taste.";
	default lineKey         = "ar_line_anarietta_gift_request";
	default thanksLineId    = 0;
	default thanksLineText  = "You have my sincere gratitude, witcher.";
	default thanksLineKey   = "ar_thanks_anarietta";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Est Est');
		gifts.PushBack('Erveluce');
	}
}

class MCM_AR_Vivienne_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'vivienne_gift_request';
	default targetNpc       = 'sq701_vivienne';
	default lineId          = 1185355;
	default lineText        = "Would you share a drink with me, witcher?";
	default lineKey         = "ar_line_vivienne_gift_request";
	default thanksLineText  = "You are very kind, Geralt.";
	default thanksLineKey   = "ar_thanks_vivienne";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Mettina Rose');
		gifts.PushBack('Beauclair White');
	}
}

class MCM_AR_Cerys_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'cerys_gift_request';
	default targetNpc       = 'becca';
	default lineId          = 1064257;
	default lineText        = "Got something strong in that pack of yours, witcher?";
	default lineKey         = "ar_line_cerys_gift_request";
	default thanksLineText  = "Hah, that's what I'm talking about!";
	default thanksLineKey   = "ar_thanks_cerys";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Dwarven spirit');
		gifts.PushBack('Alcohest');
	}
}

class MCM_AR_Philippa_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'philippa_gift_request';
	default targetNpc       = 'philippa_eilhart';
	default lineText        = "Pour me something decent, Geralt.";
	default lineKey         = "ar_line_philippa_gift_request";
	default thanksLineText  = "Acceptable. You've learned some manners.";
	default thanksLineKey   = "ar_thanks_philippa";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Est Est');
		gifts.PushBack('Beauclair White');
		gifts.PushBack('Alcohest');
	}
}

class MCM_AR_Syanna_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'syanna_gift_request';
	default targetNpc       = 'syanna';
	default lineText        = "Spare a drink, witcher? Walking builds a thirst.";
	default lineKey         = "ar_line_syanna_gift_request";
	default thanksLineText  = "Thanks. I needed that.";
	default thanksLineKey   = "ar_thanks_syanna";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Erveluce');
		gifts.PushBack('Dwarven spirit');
	}
}

class MCM_AR_Salma_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'salma_gift_request';
	default targetNpc       = 'mh303_succbus_v2';
	default lineText        = "Do you have any sweet wine on you?";
	default lineKey         = "ar_line_salma_gift_request";
	default thanksLineText  = "Mmm, delightful. Thank you.";
	default thanksLineKey   = "ar_thanks_salma";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Mettina Rose');
		gifts.PushBack('Est Est');
	}
}

class MCM_AR_Ves_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'ves_gift_request';
	default targetNpc       = 'ves';
	default lineText        = "Got any spirits to wash down the road dust?";
	default lineKey         = "ar_line_ves_gift_request";
	default thanksLineText  = "Good stuff. Much appreciated, Geralt.";
	default thanksLineKey   = "ar_thanks_ves";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Dwarven spirit');
		gifts.PushBack('Alcohest');
		gifts.PushBack('Erveluce');
	}
}

