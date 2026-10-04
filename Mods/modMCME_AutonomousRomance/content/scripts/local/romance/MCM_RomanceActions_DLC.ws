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

	// ===== VIVIENNE =====
	RegisterAction(new MCM_AR_Vivienne_OneLinerFlirt    in this);
	RegisterAction(new MCM_AR_Vivienne_CampfireMystery  in this);

	// ===== CERYS =====
	RegisterAction(new MCM_AR_Cerys_OneLinerFlirt       in this);
	RegisterAction(new MCM_AR_Cerys_PostCombatSkellige  in this);
	RegisterAction(new MCM_AR_Cerys_NightInvitation     in this);
}

//=============================================================================
//  ANNA HENRIETTA (Anarietta) – Tier 1: Królewskie docinki
//=============================================================================

class MCM_AR_Anarietta_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'anarietta_oneliner_flirt';
	default targetNpc       = 'anna_henrietta';
	default minAffinity     = 0;
	default cooldownSeconds = 350.0;
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
		// ID 1185354: "An excellent wine. You've good taste."
		PlayOneLiner(npc, 1185354, "An excellent wine. You've good taste.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  ANNA HENRIETTA – Tier 2: Po walce (królewska duma)
//=============================================================================

class MCM_AR_Anarietta_PostCombatPride extends MCM_RomanceInteraction
{
	default id              = 'anarietta_postcombat_pride';
	default targetNpc       = 'anna_henrietta';
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (ctx.playerHealthRatio > 0.60) return false;
		if (MCM_AR_GetCore().GetSecondsSinceCombat() > 300.0) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!ApproachPlayer(npc, player, 1.8)) return false;
		PlayMimic(npc, 'concern');
		// ID 1199342: "There's something I'd like to know… How can you be so damned calm?"
		PlayOneLiner(npc, 1199342, "There's something I'd like to know… How can you be so damned calm?");
		Sleep(3.0);
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  ANNA HENRIETTA – Tier 3: Nocna propozycja królewska
//=============================================================================

class MCM_AR_Anarietta_NightRoyal extends MCM_RomanceInteraction
{
	default id              = 'anarietta_night_royal';
	default targetNpc       = 'anna_henrietta';
	default minAffinity     = 60;
	default cooldownSeconds = 2400.0;
	default triggerType     = RTT_Prompt;
	default weight          = 4;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (!ctx.isNight) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;

		if (!ApproachPlayer(npc, player, 1.5)) return false;
		PlayMimic(npc, 'flirt');
		// ID 1192250: "Come, witcher."
		PlayOneLiner(npc, 1192250, "Come, witcher.");
		Sleep(3.0);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[E] Towarzysz Księżnej", 8.0);
			if (!consent) return false;
		}

		PlayScene(npc, "dlc\\mod_spawn_companions\\dialogue\\anariettaFollowWithKiss.w2scene");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  VIVIENNE – Tier 1: Flirt z tajemnicą
//=============================================================================

class MCM_AR_Vivienne_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'vivienne_oneliner_flirt';
	default targetNpc       = 'sq701_vivienne';
	default minAffinity     = 0;
	default cooldownSeconds = 360.0;
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
		// ID 1208517: "The explanation is disappointing, I'm afraid. The fragrance I use, it's mixed by a sorceress."
		PlayOneLiner(npc, 1208517, "The explanation is disappointing, I'm afraid. The fragrance I use, it's mixed by a sorceress.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  VIVIENNE – Tier 2: Przy ognisku (tajemnica Vivienne)
//=============================================================================

class MCM_AR_Vivienne_CampfireMystery extends MCM_RomanceInteraction
{
	default id              = 'vivienne_campfire_mystery';
	default targetNpc       = 'sq701_vivienne';
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
		if (!ApproachPlayer(npc, player, 2.0)) return false;
		// ID 1197401: "Come."
		PlayOneLiner(npc, 1197401, "Come.");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  CERYS – Tier 1: Bezczelny flirt à la Skellige
//=============================================================================

class MCM_AR_Cerys_OneLinerFlirt extends MCM_RomanceInteraction
{
	default id              = 'cerys_oneliner_flirt';
	default targetNpc       = 'cerys';
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
		// ID 500732: "Show me what you've got, monster slayer!"
		PlayOneLiner(npc, 500732, "Show me what you've got, monster slayer!");
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  CERYS – Tier 2: Po walce (Skellige honor)
//=============================================================================

class MCM_AR_Cerys_PostCombatSkellige extends MCM_RomanceInteraction
{
	default id              = 'cerys_postcombat_skellige';
	default targetNpc       = 'cerys';
	default minAffinity     = 20;
	default cooldownSeconds = 600.0;
	default triggerType     = RTT_Gesture;
	default weight          = 8;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (ctx.playerHealthRatio > 0.60) return false;
		if (MCM_AR_GetCore().GetSecondsSinceCombat() > 300.0) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!ApproachPlayer(npc, player, 1.8)) return false;
		PlayMimic(npc, 'concern');
		// ID 1000394: "C'mon, Geralt. I'm the same lass I was. Save for the title, not a thing's changed."
		PlayOneLiner(npc, 1000394, "C'mon, Geralt. I'm the same lass I was. Save for the title, not a thing's changed.");
		Sleep(2.5);
		super.Execute(npc, player, ctx);
		return true;
	}
}

//=============================================================================
//  CERYS – Tier 3: Nocne zaproszenie po skelligeańsku
//=============================================================================

class MCM_AR_Cerys_NightInvitation extends MCM_RomanceInteraction
{
	default id              = 'cerys_night_invitation';
	default targetNpc       = 'cerys';
	default minAffinity     = 60;
	default cooldownSeconds = 2400.0;
	default triggerType     = RTT_Prompt;
	default weight          = 4;

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		if (!super.CanExecute(npc, player, ctx)) return false;
		if (!ctx.isNight) return false;
		return true;
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var consent : bool;

		if (!ApproachPlayer(npc, player, 1.5)) return false;
		PlayMimic(npc, 'flirt');
		// ID 429005: "Geralt! Come! Think I've got an idea!"
		PlayOneLiner(npc, 429005, "Geralt! Come! Think I've got an idea!");
		Sleep(3.0);

		if (MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			consent = ShowConsentPrompt("[E] Zostań z Cerys", 8.0);
			if (!consent) return false;
		}

		// Scena ogólna dla BaW/ep1 postaci bez dedykowanej sceny pocałunku
		PlayScene(npc, "dlc\\mod_spawn_companions\\dialogue\\yenneferFollowWithKiss.w2scene");
		super.Execute(npc, player, ctx);
		return true;
	}
}
