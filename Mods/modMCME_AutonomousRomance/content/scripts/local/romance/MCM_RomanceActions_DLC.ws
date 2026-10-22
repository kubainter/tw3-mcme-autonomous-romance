/*****************************************************************************/
/* MCME Autonomous Romance - DLC NPC Actions                                 */
/* Rozszerzenie dla Anna Henrietta, Vivienne, Cerys                          */
/* Te akcje korzystają z tej samej architektury co Main, lecz są w osobnym  */
/* pliku – można je wyłączyć bez wpływu na Yen/Triss/Keira/Shani           */
/*****************************************************************************/

// Rejestracja DLC akcji – rozszerzenie registry przez @wrapMethod

@wrapMethod(MCM_RomanceActionRegistry)
function InitDefaultActions()
{
	wrappedMethod();  // Najpierw rejestruje Main akcje

	// ===== ANNA HENRIETTA =====
	RegisterAction(new MCM_AR_Anarietta_OneLinerFlirt   in this);
	RegisterAction(new MCM_AR_Anarietta_PostCombatPride in this);
	RegisterAction(new MCM_AR_Anarietta_IntimateInvite  in this);
	RegisterAction(new MCM_AR_Anarietta_GiftRequest     in this);

	// ===== VIVIENNE =====
	RegisterAction(new MCM_AR_Vivienne_OneLinerFlirt    in this);
	RegisterAction(new MCM_AR_Vivienne_CampfireMystery  in this);
	RegisterAction(new MCM_AR_Vivienne_IntimateInvite   in this);
	RegisterAction(new MCM_AR_Vivienne_GiftRequest      in this);

	// ===== CERYS =====
	RegisterAction(new MCM_AR_Cerys_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Cerys_PostCombatSkellige  in this);
	RegisterAction(new MCM_AR_Cerys_NightInvitation     in this);
	RegisterAction(new MCM_AR_Cerys_IntimateInvite      in this);
	RegisterAction(new MCM_AR_Cerys_GiftRequest         in this);

	// ===== SYANNA =====
	RegisterAction(new MCM_AR_Syanna_OneLinerFlirt      in this);
	RegisterAction(new MCM_AR_Syanna_PostCombat        in this);
	RegisterAction(new MCM_AR_Syanna_Kiss              in this);
	RegisterAction(new MCM_AR_Syanna_IntimateInvite    in this);
	RegisterAction(new MCM_AR_Syanna_GiftRequest       in this);

	// ===== PHILIPPA =====
	RegisterAction(new MCM_AR_Philippa_OneLinerFlirt   in this);
	RegisterAction(new MCM_AR_Philippa_Care            in this);
	RegisterAction(new MCM_AR_Philippa_Kiss            in this);
	RegisterAction(new MCM_AR_Philippa_IntimateInvite  in this);
	RegisterAction(new MCM_AR_Philippa_GiftRequest     in this);

	// ===== VES =====
	RegisterAction(new MCM_AR_Ves_OneLinerFlirt        in this);
	RegisterAction(new MCM_AR_Ves_Campfire             in this);
	RegisterAction(new MCM_AR_Ves_Kiss                 in this);
	RegisterAction(new MCM_AR_Ves_IntimateInvite       in this);
	RegisterAction(new MCM_AR_Ves_GiftRequest          in this);

	// ===== SALMA =====
	RegisterAction(new MCM_AR_Salma_OneLinerFlirt      in this);
	RegisterAction(new MCM_AR_Salma_Allure             in this);
	RegisterAction(new MCM_AR_Salma_Kiss               in this);
	RegisterAction(new MCM_AR_Salma_IntimateInvite     in this);
	RegisterAction(new MCM_AR_Salma_GiftRequest        in this);

	// ===== PRISCILLA =====
	RegisterAction(new MCM_AR_Priscilla_OneLinerFlirt  in this);
	RegisterAction(new MCM_AR_Priscilla_Care           in this);
	RegisterAction(new MCM_AR_Priscilla_Kiss           in this);
	RegisterAction(new MCM_AR_Priscilla_IntimateInvite in this);
	RegisterAction(new MCM_AR_Priscilla_GiftRequest    in this);

	// ===== EDNA VAR ATTRE =====
	RegisterAction(new MCM_AR_Edna_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Edna_Care                in this);
	RegisterAction(new MCM_AR_Edna_Kiss                in this);
	RegisterAction(new MCM_AR_Edna_IntimateInvite      in this);
	RegisterAction(new MCM_AR_Edna_GiftRequest         in this);

	// ===== FRINGILLA VIGO =====
	RegisterAction(new MCM_AR_Fringilla_OneLinerFlirt  in this);
	RegisterAction(new MCM_AR_Fringilla_Care           in this);
	RegisterAction(new MCM_AR_Fringilla_Kiss           in this);
	RegisterAction(new MCM_AR_Fringilla_IntimateInvite in this);
	RegisterAction(new MCM_AR_Fringilla_GiftRequest    in this);

	// ===== MARGARITA =====
	RegisterAction(new MCM_AR_Margarita_OneLinerFlirt  in this);
	RegisterAction(new MCM_AR_Margarita_Care           in this);
	RegisterAction(new MCM_AR_Margarita_Kiss           in this);
	RegisterAction(new MCM_AR_Margarita_IntimateInvite in this);
	RegisterAction(new MCM_AR_Margarita_GiftRequest    in this);

	// ===== ORIANNA =====
	RegisterAction(new MCM_AR_Orianna_OneLinerFlirt    in this);
	RegisterAction(new MCM_AR_Orianna_Care             in this);
	RegisterAction(new MCM_AR_Orianna_IntimateInvite   in this);
	RegisterAction(new MCM_AR_Orianna_GiftRequest      in this);

	// ===== TAWERNA (Tier 1, ambient) =====
	RegisterAction(new MCM_AR_Anarietta_TavernDrink     in this);
	RegisterAction(new MCM_AR_Vivienne_TavernDrink      in this);
	RegisterAction(new MCM_AR_Cerys_TavernDrink         in this);

	// ===== NOC (Tier 1, filler) =====
	RegisterAction(new MCM_AR_Anarietta_NightFiller     in this);
	RegisterAction(new MCM_AR_Vivienne_NightFiller      in this);
	RegisterAction(new MCM_AR_Cerys_NightFiller         in this);
}

//  ANNA HENRIETTA – Tier 1: Krolewskie docinki – ambient

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

//  ANNA HENRIETTA – Tier 2: Po walce (królewska duma) – soft approach

class MCM_AR_Anarietta_PostCombatPride extends MCM_RomanceInteraction
{
	default id              = 'anarietta_postcombat_pride';
	default targetNpc       = 'anna_henrietta';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'concern';
	// ID 1199342: "...How can you be so damned calm?" - jej glos
	default lineId          = 1199342;
	default lineText        = "There's something I'd like to know... How can you be so damned calm?";
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

//  ANNA HENRIETTA – Tier 3: Nocna propozycja królewska (propozycja -> scena)

//  ANNA HENRIETTA – Tier 4: Zaproszenie intymne przy "sweet spot"

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
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4: scena intymna - zgoda gracza [C] zawsze wymagana.
		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_anarietta_intimate", "[C] Stay alone with the Duchess"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		// Anarietta bez specialData.naughtyScene - sciezka manualna (naughty\anarietta).
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//  VIVIENNE – Tier 1: Flirt z tajemnicą – ambient

class MCM_AR_Vivienne_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'vivienne_oneliner_flirt';
	default targetNpc       = 'sq701_vivienne';
	default minAffinity     = 0;
	default cooldownSeconds = 360.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	// 1208517 byla odpowiedzia na inne pytanie - voiceset + wlasny napis.
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

//  VIVIENNE – Tier 2: Przy ognisku (tajemnica Vivienne) – soft approach

class MCM_AR_Vivienne_CampfireMystery extends MCM_RomanceInteraction
{
	default id              = 'vivienne_campfire_mystery';
	default targetNpc       = 'sq701_vivienne';
	default minAffinity     = 20;
	default cooldownSeconds = 900.0;
	default triggerType     = RTT_Gesture;
	default weight          = 7;
	default barkMimic       = 'flirt';
	// ID 1197401: "Come." - jej glos
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

//  VIVIENNE – Tier 3: Nocne zaproszenie (propozycja -> scena)

//  VIVIENNE – Tier 4: Zaproszenie intymne przy "sweet spot"

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
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4: scena intymna - zgoda gracza [C] zawsze wymagana.
		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_vivienne_intimate", "[C] Stay alone with Vivienne"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		// Vivienne bez specialData.naughtyScene - sciezka manualna (forma ludzka).
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//  CERYS – Tier 1: Bezczelny flirt à la Skellige – ambient

class MCM_AR_Cerys_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'cerys_oneliner_flirt';
	default targetNpc       = 'becca';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	// ID 500732: "Show me what you've got, monster slayer!" - jej glos
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

//  CERYS – Tier 2: Po walce (Skellige honor) – soft approach

class MCM_AR_Cerys_PostCombatSkellige extends MCM_RomanceInteraction
{
	default id              = 'cerys_postcombat_skellige';
	default targetNpc       = 'becca';
	default minAffinity     = 20;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'concern';
	// 1000394 bylo o koronacji, nie o walce - voiceset + wlasny napis.
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

//  CERYS – Tier 3: Nocne zaproszenie po skelligeańsku (propozycja -> scena)

class MCM_AR_Cerys_NightInvitation extends MCM_RomanceInteraction
{
	default id              = 'cerys_night_invitation';
	default usesAutonomousKiss = true;
	default targetNpc       = 'becca';
	default minAffinity     = 60;
	default cooldownSeconds = 2400.0;
	default triggerType     = RTT_Prompt;
	default weight          = 4;
	default barkMimic       = 'flirt';
	// ID 429005: "Geralt! Come! Think I've got an idea!" - jej glos
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
		var ok : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.4, AR_T("ar_prompt_cerys_stay", "[C] Stay with Cerys"));
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayKissScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//  CERYS – Tier 4: Zaproszenie intymne przy "sweet spot"

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
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4: scena intymna - zgoda gracza [C] zawsze wymagana.
		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_cerys_intimate", "[C] Stay alone with Cerys"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		// Cerys MA specialData.naughtyScene (naughty\cerys) - pelny pipeline PreNaughtyWith.
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//  GIFT REQUESTS – Anna Henrietta, Vivienne, Cerys, Philippa, Syanna, Salma, Ves

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


// --- Tavern banter ---

class MCM_AR_Anarietta_TavernDrink extends MCM_RomanceInteraction
{
	default id              = 'anarietta_tavern_drink';
	default targetNpc       = 'anna_henrietta';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 6;
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "The Duchess allows herself this one indulgence.";
	default lineKey         = "ar_line_anarietta_tavern_drink";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isInTavern) return "not_in_tavern";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 10.0);
		PlayDrinkingAnimation(npc);
		PlayBark(npc);
		return true;
	}
}

class MCM_AR_Vivienne_TavernDrink extends MCM_RomanceInteraction
{
	default id              = 'vivienne_tavern_drink';
	default targetNpc       = 'sq701_vivienne';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 6;
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "A moment's peace and good wine. Rare gifts.";
	default lineKey         = "ar_line_vivienne_tavern_drink";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isInTavern) return "not_in_tavern";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 10.0);
		PlayDrinkingAnimation(npc);
		PlayBark(npc);
		return true;
	}
}

class MCM_AR_Cerys_TavernDrink extends MCM_RomanceInteraction
{
	default id              = 'cerys_tavern_drink';
	default targetNpc       = 'becca';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 6;
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Skellige mead beats this swill, but company helps.";
	default lineKey         = "ar_line_cerys_tavern_drink";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isInTavern) return "not_in_tavern";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 10.0);
		PlayDrinkingAnimation(npc);
		PlayBark(npc);
		return true;
	}
}

// --- Night filler ---

class MCM_AR_Anarietta_NightFiller extends MCM_RomanceInteraction
{
	default id              = 'anarietta_night_filler';
	default targetNpc       = 'anna_henrietta';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Toussaint nights were made for walking.";
	default lineKey         = "ar_line_anarietta_night_filler";

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

class MCM_AR_Vivienne_NightFiller extends MCM_RomanceInteraction
{
	default id              = 'vivienne_night_filler';
	default targetNpc       = 'sq701_vivienne';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "I used to fear the night. No longer.";
	default lineKey         = "ar_line_vivienne_night_filler";

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

class MCM_AR_Cerys_NightFiller extends MCM_RomanceInteraction
{
	default id              = 'cerys_night_filler';
	default targetNpc       = 'becca';
	default minAffinity     = 0;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default barkVoiceset    = 'greeting_geralt';
	default lineText        = "Skellige nights are colder. This is nothing.";
	default lineKey         = "ar_line_cerys_night_filler";

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

//  SYANNA – Tier 1..4 (pelna scena CDPR)

class MCM_AR_Syanna_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'syanna_oneliner_flirt';
	default targetNpc       = 'syanna';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	default lineText        = "You still staring, Geralt? Take a picture, it lasts longer.";
	default lineKey         = "ar_line_syanna_oneliner_flirt";

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

class MCM_AR_Syanna_PostCombat extends MCM_RomanceInteraction
{
	default id              = 'syanna_postcombat';
	default targetNpc       = 'syanna';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default lineText        = "Not bad with that silver sword. I almost felt safe for a second.";
	default lineKey         = "ar_line_syanna_postcombat";

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

class MCM_AR_Syanna_Kiss extends MCM_RomanceInteraction
{
	default id              = 'syanna_kiss';
	default usesAutonomousKiss = true;
	default targetNpc       = 'syanna';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	default lineText        = "Come here, Geralt. Don't play shy now.";
	default lineKey         = "ar_line_syanna_kiss";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.4, AR_T("ar_prompt_syanna_kiss", "[C] Kiss Syanna"));
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayKissScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Syanna_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'syanna_intimate_invite';
	default targetNpc       = 'syanna';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default lineText        = "I remember the clouds... and what we did above them. Want to remind me?";
	default lineKey         = "ar_line_syanna_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		// Tier 4: scena intymna - zgoda gracza [C] zawsze wymagana.
		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_syanna_intimate", "[C] Stay alone with Syanna"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//  PHILIPPA EILHART – Tier 1..4

class MCM_AR_Philippa_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'philippa_oneliner_flirt';
	default targetNpc       = 'philippa_eilhart';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	default lineText        = "Quiet, Geralt. Thinking never was your strong suit.";
	default lineKey         = "ar_line_philippa_oneliner_flirt";

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

class MCM_AR_Philippa_Care extends MCM_RomanceInteraction
{
	default id              = 'philippa_care';
	default targetNpc       = 'philippa_eilhart';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default lineText        = "Still breathing? Good. You're far more useful in one piece.";
	default lineKey         = "ar_line_philippa_care";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (ctx.playerHealthRatio > 0.60) return "hp_ok";
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

class MCM_AR_Philippa_Kiss extends MCM_RomanceInteraction
{
	default id              = 'philippa_kiss';
	default usesAutonomousKiss = true;
	default targetNpc       = 'philippa_eilhart';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	default lineText        = "Geralt. Step closer... and don't make me repeat myself.";
	default lineKey         = "ar_line_philippa_kiss";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.4, AR_T("ar_prompt_philippa_kiss", "[C] Kiss Philippa"));
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayKissScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Philippa_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'philippa_intimate_invite';
	default targetNpc       = 'philippa_eilhart';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default lineText        = "I don't make offers twice, witcher.";
	default lineKey         = "ar_line_philippa_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_philippa_intimate", "[C] Stay alone with Philippa"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//  VES – Tier 1..4

class MCM_AR_Ves_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'ves_oneliner_flirt';
	default targetNpc       = 'ves';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	default lineText        = "Eyes front, witcher. Vernon's got enough scouts without you watching my back.";
	default lineKey         = "ar_line_ves_oneliner_flirt";

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

class MCM_AR_Ves_Campfire extends MCM_RomanceInteraction
{
	default id              = 'ves_campfire';
	default targetNpc       = 'ves';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default lineText        = "Nothing like fire and a sharp blade. Sit down, catch your breath.";
	default lineKey         = "ar_line_ves_campfire";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!ctx.isNearCampfire) return "not_near_campfire";
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

class MCM_AR_Ves_Kiss extends MCM_RomanceInteraction
{
	default id              = 'ves_kiss';
	default usesAutonomousKiss = true;
	default targetNpc       = 'ves';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	default lineText        = "Quiet now. No commanders, no war... just us.";
	default lineKey         = "ar_line_ves_kiss";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.4, AR_T("ar_prompt_ves_kiss", "[C] Kiss Ves"));
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayKissScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Ves_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'ves_intimate_invite';
	default targetNpc       = 'ves';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default lineText        = "Off duty at last. Don't keep a soldier waiting.";
	default lineKey         = "ar_line_ves_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_ves_intimate", "[C] Stay alone with Ves"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//  SALMA (Succubus) – Tier 1..4

class MCM_AR_Salma_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'salma_oneliner_flirt';
	default targetNpc       = 'mh303_succbus_v2';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	default lineText        = "Your aura... it burns warmer than any mortal man's, witcher.";
	default lineKey         = "ar_line_salma_oneliner_flirt";

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

class MCM_AR_Salma_Allure extends MCM_RomanceInteraction
{
	default id              = 'salma_allure';
	default targetNpc       = 'mh303_succbus_v2';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default lineText        = "Tired, white wolf? Let my scent soothe your troubled thoughts.";
	default lineKey         = "ar_line_salma_allure";

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

class MCM_AR_Salma_Kiss extends MCM_RomanceInteraction
{
	default id              = 'salma_kiss';
	default usesAutonomousKiss = true;
	default targetNpc       = 'mh303_succbus_v2';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	default lineText        = "Come, sweet hunter. One touch won't hurt you...";
	default lineKey         = "ar_line_salma_kiss";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.4, AR_T("ar_prompt_salma_kiss", "[C] Kiss Salma"));
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayKissScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Salma_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'salma_intimate_invite';
	default targetNpc       = 'mh303_succbus_v2';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default lineText        = "Mmm... I can hear your pulse from here. Come.";
	default lineKey         = "ar_line_salma_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_salma_intimate", "[C] Stay alone with Salma"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

//  PRISCILLA – Tier 1..4 + Gift

class MCM_AR_Priscilla_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'priscilla_oneliner_flirt';
	default targetNpc       = 'priscilla';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	default lineText        = "The road with you feels like a ballad that's yet to be written.";
	default lineKey         = "ar_line_priscilla_oneliner_flirt";

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

class MCM_AR_Priscilla_Care extends MCM_RomanceInteraction
{
	default id              = 'priscilla_care';
	default targetNpc       = 'priscilla';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default lineText        = "Rest a moment, Geralt. Even heroes must pause between stanzas.";
	default lineKey         = "ar_line_priscilla_care";

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

class MCM_AR_Priscilla_Kiss extends MCM_RomanceInteraction
{
	default id              = 'priscilla_kiss';
	default usesAutonomousKiss = true;
	default targetNpc       = 'priscilla';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	default lineText        = "Geralt... Stay close. Let this moment linger.";
	default lineKey         = "ar_line_priscilla_kiss";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.4, AR_T("ar_prompt_priscilla_kiss", "[C] Kiss Priscilla"));
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayKissScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Priscilla_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'priscilla_intimate_invite';
	default targetNpc       = 'priscilla';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default lineText        = "Tonight's verse needs no audience. Just us.";
	default lineKey         = "ar_line_priscilla_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_priscilla_intimate", "[C] Stay alone with Priscilla"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Priscilla_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'priscilla_gift_request';
	default targetNpc       = 'priscilla';
	default lineText        = "My throat grows dry from the road. Do you carry any fine wine, Geralt?";
	default lineKey         = "ar_line_priscilla_gift_request";
	default thanksLineText  = "Exquisite. My voice thanks you, Geralt.";
	default thanksLineKey   = "ar_thanks_priscilla";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Beauclair White');
		gifts.PushBack('Est Est');
		gifts.PushBack('Erveluce');
	}
}

//  EDNA VAR ATTRE – Tier 1..4 + Gift

class MCM_AR_Edna_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'edna_oneliner_flirt';
	default targetNpc       = 'edna_var_attre';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	default lineText        = "My sister thinks she's the only one who appreciates your rough charm.";
	default lineKey         = "ar_line_edna_oneliner_flirt";

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

class MCM_AR_Edna_Care extends MCM_RomanceInteraction
{
	default id              = 'edna_care';
	default targetNpc       = 'edna_var_attre';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default lineText        = "You look weary, witcher. Nilfgaardian court etiquette is easier than your life.";
	default lineKey         = "ar_line_edna_care";

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

class MCM_AR_Edna_Kiss extends MCM_RomanceInteraction
{
	default id              = 'edna_kiss';
	default usesAutonomousKiss = true;
	default targetNpc       = 'edna_var_attre';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	default lineText        = "Let Rosa practice her parries. Come here, Geralt.";
	default lineKey         = "ar_line_edna_kiss";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.4, AR_T("ar_prompt_edna_kiss", "[C] Kiss Edna"));
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayKissScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Edna_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'edna_intimate_invite';
	default targetNpc       = 'edna_var_attre';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default lineText        = "My sister would die of envy. Come, witcher.";
	default lineKey         = "ar_line_edna_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_edna_intimate", "[C] Stay alone with Edna"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Edna_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'edna_gift_request';
	default targetNpc       = 'edna_var_attre';
	default lineText        = "Do you happen to have a vintage worth tasting in that leather pouch?";
	default lineKey         = "ar_line_edna_gift_request";
	default thanksLineText  = "Far better than I expected. Thank you, witcher.";
	default thanksLineKey   = "ar_thanks_edna";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Mettina Rose');
		gifts.PushBack('Est Est');
	}
}

//  FRINGILLA VIGO – Tier 1..4 + Gift

class MCM_AR_Fringilla_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'fringilla_oneliner_flirt';
	default targetNpc       = 'fringilla_vigo';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	default lineText        = "Still looking at me with that guarded Nilfgaardian gaze, Geralt?";
	default lineKey         = "ar_line_fringilla_oneliner_flirt";

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

class MCM_AR_Fringilla_Care extends MCM_RomanceInteraction
{
	default id              = 'fringilla_care';
	default targetNpc       = 'fringilla_vigo';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default lineText        = "Magic warms cold steel, witcher. Don't push yourself too hard.";
	default lineKey         = "ar_line_fringilla_care";

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

class MCM_AR_Fringilla_Kiss extends MCM_RomanceInteraction
{
	default id              = 'fringilla_kiss';
	default usesAutonomousKiss = true;
	default targetNpc       = 'fringilla_vigo';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	default lineText        = "The Lodge isn't watching, Geralt. Come closer.";
	default lineKey         = "ar_line_fringilla_kiss";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.4, AR_T("ar_prompt_fringilla_kiss", "[C] Kiss Fringilla"));
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayKissScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Fringilla_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'fringilla_intimate_invite';
	default targetNpc       = 'fringilla_vigo';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default lineText        = "Even a Nilfgaardian needs warmth. Somewhere private, Geralt.";
	default lineKey         = "ar_line_fringilla_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_fringilla_intimate", "[C] Stay alone with Fringilla"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Fringilla_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'fringilla_gift_request';
	default targetNpc       = 'fringilla_vigo';
	default lineText        = "A drop of strong southern wine would clear my head. Got any?";
	default lineKey         = "ar_line_fringilla_gift_request";
	default thanksLineText  = "Reminds me of home. Thank you, Geralt.";
	default thanksLineKey   = "ar_thanks_fringilla";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Beauclair White');
		gifts.PushBack('Est Est');
		gifts.PushBack('Erveluce');
	}
}

//  MARGARITA LAUX-ANTILLE – Tier 1..4 + Gift

class MCM_AR_Margarita_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'margarita_oneliner_flirt';
	default targetNpc       = 'margarita';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	default lineText        = "Aretuza taught me discipline, Geralt. You tempt me to forget it.";
	default lineKey         = "ar_line_margarita_oneliner_flirt";

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

class MCM_AR_Margarita_Care extends MCM_RomanceInteraction
{
	default id              = 'margarita_care';
	default targetNpc       = 'margarita';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default lineText        = "You carry too many wounds, old friend. Let yourself breathe.";
	default lineKey         = "ar_line_margarita_care";

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

class MCM_AR_Margarita_Kiss extends MCM_RomanceInteraction
{
	default id              = 'margarita_kiss';
	default usesAutonomousKiss = true;
	default targetNpc       = 'margarita';
	default minAffinity     = 50;
	default cooldownSeconds = 1800.0;
	default triggerType     = RTT_Prompt;
	default weight          = 5;
	default barkMimic       = 'flirt';
	default lineText        = "Come here, Geralt. We've both endured enough cold.";
	default lineKey         = "ar_line_margarita_kiss";

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.4, AR_T("ar_prompt_margarita_kiss", "[C] Kiss Margarita"));
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayKissScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Margarita_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'margarita_intimate_invite';
	default targetNpc       = 'margarita';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default lineText        = "Aretuza taught me discipline, not abstinence. Come.";
	default lineKey         = "ar_line_margarita_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_margarita_intimate", "[C] Stay alone with Margarita"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

class MCM_AR_Margarita_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'margarita_gift_request';
	default targetNpc       = 'margarita';
	default lineText        = "After Oxenfurt's dungeons, any warming spirit is a blessing. Spare some?";
	default lineKey         = "ar_line_margarita_gift_request";
	default thanksLineText  = "Warmth... true warmth. Thank you, Geralt.";
	default thanksLineKey   = "ar_thanks_margarita";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Dwarven spirit');
		gifts.PushBack('Erveluce');
		gifts.PushBack('Alcohest');
	}
}

//  ORIANNA – Tier 1..3 + Gift

class MCM_AR_Orianna_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'orianna_oneliner_flirt';
	default targetNpc       = 'vampire_diva';
	default minAffinity     = 0;
	default cooldownSeconds = 300.0;
	default triggerType     = RTT_OneLiner;
	default weight          = 10;
	default barkMimic       = 'flirt';
	default lineText        = "Your blood smells rich, witcher... but I prefer you alive and talking.";
	default lineKey         = "ar_line_orianna_oneliner_flirt";

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

class MCM_AR_Orianna_Care extends MCM_RomanceInteraction
{
	default id              = 'orianna_care';
	default targetNpc       = 'vampire_diva';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;
	default barkMimic       = 'flirt';
	default lineText        = "Rest, Geralt. Even a witcher's heart must weary under such strain.";
	default lineKey         = "ar_line_orianna_care";

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

class MCM_AR_Orianna_GiftRequest extends MCM_AR_GiftRequest_Base
{
	default id              = 'orianna_gift_request';
	default targetNpc       = 'vampire_diva';
	default lineText        = "Do you possess a vintage with enough depth to intrigue my palate?";
	default lineKey         = "ar_line_orianna_gift_request";
	default thanksLineText  = "Exquisite. You continue to exceed my expectations.";
	default thanksLineKey   = "ar_thanks_orianna";
	default thanksVoiceset  = 'greeting_geralt';

	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Est Est');
		gifts.PushBack('Erveluce');
	}
}

//  ORIANNA – Tier 4: Zaproszenie intymne przy "sweet spot"
//  Rig noble_woman_base nie ma animacji kiss – top tier to naughty cutscene
//  (jak w upstream paczce: opcja kiss -> sex scene).

class MCM_AR_Orianna_IntimateInvite extends MCM_RomanceInteraction
{
	default id              = 'orianna_intimate_invite';
	default targetNpc       = 'vampire_diva';
	default minAffinity     = 80;
	default cooldownSeconds = 3600.0;
	default triggerType     = RTT_Scene;
	default weight          = 3;
	default barkMimic       = 'flirt';
	default lineText        = "I have cultivated appetites far older than you, witcher. Indulge me somewhere private.";
	default lineKey         = "ar_line_orianna_intimate_invite";

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!IsOnNaughtyPoint()) return "no_naughty_point";
		return IntimateSceneBlockReason(npc);
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var ok : bool;

		SoftApproach(npc, player, 2.2);
		PlayBark(npc);

		ok = ApproachAndConsent(npc, player, 2.2, AR_T("ar_prompt_orianna_intimate", "[C] Stay alone with Orianna"), true);
		if (!ok)
		{
			return false;
		}

		HardStage(npc, player, 1.5);
		ok = PlayIntimateScene(npc);
		EndInteraction(npc, player);
		return ok;
	}
}

