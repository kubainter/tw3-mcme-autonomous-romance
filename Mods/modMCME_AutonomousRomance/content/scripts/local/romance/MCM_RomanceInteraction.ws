/*****************************************************************************/
/* MCME Autonomous Romance - Interaction Framework                           */
/* Struktura kontekstu, klasy bazowe akcji, rejestr i procedury wykonawcze  */
/*****************************************************************************/

// ---------------------------------------------------------------------------
// Typ wyzwalacza interakcji (4 tiery z planu)
// ---------------------------------------------------------------------------

enum ERomanceTriggerType
{
	RTT_OneLiner,   // Tier 1: autonomiczny komentarz głosowy
	RTT_Gesture,    // Tier 2: podejście + gest / pocałunek w świecie
	RTT_Prompt,     // Tier 3: zaproszenie przez HUD prompt [E]
	RTT_Scene,      // Tier 4: pełna scena CStoryScene (tylko w strefach relaksu)
}

// ---------------------------------------------------------------------------
// Kontekst otoczenia przekazywany do każdej akcji
// ---------------------------------------------------------------------------

class MCM_RomanceContext
{
	public var hourOfDay       : int;
	public var isNight         : bool;
	public var isDawn          : bool;
	public var playerHealthRatio : float;
	public var areaName        : EAreaName;
	public var isInCorvo       : bool;
	public var isNearCampfire  : bool;
	public var isInTavern      : bool;
	public var rivalCount      : int;
	public var hasRivals       : bool;
	public var companionsInParty : array<name>;
}

// ---------------------------------------------------------------------------
// Klasa bazowa pojedynczej interakcji romantycznej
// ---------------------------------------------------------------------------

class MCM_RomanceInteraction
{
	public var id              : name;
	public var targetNpc       : name;   // '' = dowolny towarzysz romansowy
	public var minAffinity     : int;
	public var cooldownSeconds : float;
	public var triggerType     : ERomanceTriggerType;
	public var weight          : int;    // priorytet losowania (wyższy = częściej)

	// Czas ostatniego wykonania (czas silnika, tylko RAM – nie zaśmieca save)
	private var lastExecTime   : float;
	default lastExecTime = -9999.0;

	public function ResetCooldown()
	{
		lastExecTime = theGame.GetEngineTimeAsSeconds();
	}

	// Sprawdź, czy interakcja może zostać uruchomiona
	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var now : float;

		now = theGame.GetEngineTimeAsSeconds();

		// Cooldown własny akcji
		if ((now - lastExecTime) < cooldownSeconds) return false;

		// Sprawdź zażyłość
		if (minAffinity > 0)
		{
			if (!MCM_AR_GetAffinity().MeetsMinAffinity(npc.scmcc.data.nam, minAffinity))
				return false;
		}

		// Tryb zazdrości: akcje Tier2+ wymagają braku rywalek
		if (ctx.hasRivals && MCM_AR_GetConfig().IsJealousyModeOn())
		{
			if (triggerType == RTT_Gesture || triggerType == RTT_Prompt || triggerType == RTT_Scene)
				return false;
		}

		// Sprawdź odległość NPC od gracza
		if (VecDistance(player.GetWorldPosition(), npc.GetWorldPosition()) > 12.0)
			return false;

		return true;
	}

	// Placeholder – nadpisywany w podklasach
	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		lastExecTime = theGame.GetEngineTimeAsSeconds();
		return false;
	}

	// Skrót: jeden liner przez DialogueManager MCME
	protected function PlayOneLiner(npc : CNewNPC, lineID : int, lineText : string)
	{
		var el  : mod_scm_NPCChatElement;
		var dm  : MCM_DialogueManager;

		dm = MCM_GetMCM().DialogueManager;
		if (!dm) return;

		el = new mod_scm_NPCChatElement in npc;
		el.entSpecialID   = npc.scmcc.data.nam;
		el.talkingID      = lineID;
		el.talkingString  = lineText;
		el.time           = 4.0 + 0.07 * StrLen(lineText);

		dm.AddChat(el);
	}

	// Skrót: przesuń NPC do gracza (ActionMoveToNode)
	protected latent function ApproachPlayer(npc : CNewNPC, player : CR4Player, targetDist : float) : bool
	{
		if (VecDistance(player.GetWorldPosition(), npc.GetWorldPosition()) <= targetDist)
			return true;

		npc.ActionMoveToNode(player, MT_Walk, 1.0, targetDist);

		// Note: ActionMoveToNode is latent, meaning it blocks here until target is reached or pathing fails.
		// So we just check distance after it unblocks.

		if (VecDistance(player.GetWorldPosition(), npc.GetWorldPosition()) <= targetDist + 1.0)
		{
			return true;
		}

		return false;
	}

	// Bezpieczne odtworzenie mimiki twarzy przez scmcc
	protected function PlayMimic(npc : CNewNPC, mimicName : name)
	{
		if (npc && npc.scmcc)
		{
			npc.scmcc.PlayMimic(mimicName);
		}
	}

	// Bezpieczne odtworzenie prostej animacji przez scmcc
	protected function PlayAnimSimple(npc : CNewNPC, animName : name)
	{
		if (npc && npc.scmcc)
		{
			npc.scmcc.PlayAnimSimple(animName);
		}
	}

	// Skrót: pokaż prompt HUD i poczekaj na odpowiedź gracza (Tier 3)
	protected latent function ShowConsentPrompt(promptText : string, timeoutSec : float) : bool
	{
		var elapsed : float;
		var step    : float;

		step = 0.15;
		elapsed = 0.0;

		FactsSet('mcme_ar_consent_given', 0);
		FactsSet('mcme_ar_awaiting_consent', 1);

		thePlayer.DisplayHudMessage(promptText);

		while (elapsed < timeoutSec)
		{
			Sleep(step);
			elapsed += step;

			if (FactsQuerySum('mcme_ar_consent_given') > 0)
			{
				FactsSet('mcme_ar_awaiting_consent', 0);
				FactsSet('mcme_ar_consent_given', 0);
				return true;
			}
		}

		FactsSet('mcme_ar_awaiting_consent', 0);
		FactsSet('mcme_ar_consent_given', 0);
		return false;
	}

	// Skrót: odpal scenę .w2scene przez istniejące API MCME
	protected function PlayScene(npc : CNewNPC, scenePath : string)
	{
		mod_scm_GetSCMEntity().mod_scm_delayedDialogue(scenePath, 0.05);
		LogChannel('MCM_AR', "[AR] PlayScene: " + scenePath + " dla " + npc.scmcc.data.nam);
	}
}

// ---------------------------------------------------------------------------
// Centralny rejestr akcji (Action Registry Pattern)
// ---------------------------------------------------------------------------

class MCM_RomanceActionRegistry
{
	public var affinity  : MCM_RomanceAffinityResolver;
	private var actions  : array<MCM_RomanceInteraction>;
	private var isInit   : bool;
	default isInit = false;

	public function Init()
	{
		if (isInit) return;
		isInit = true;

		affinity = new MCM_RomanceAffinityResolver in this;

		// Zarejestruj akcje (konkretne klasy z MCM_RomanceActions_Main.ws)
		InitDefaultActions();
	}

	// Rejestracja akcji – może być rozszerzana przez @wrapMethod z zewnętrznych paczek
	public function InitDefaultActions()
	{
		// Akcje są rejestrowane w pliku MCM_RomanceActions_Main.ws przez:
		// RegisterAction(new MCM_AR_Yen_OneLinerFlirt in this)
	}

	// Zewnętrzne mini-paczki rejestrują swoje akcje tą metodą
	public function RegisterAction(action : MCM_RomanceInteraction)
	{
		if (action)
		{
			actions.PushBack(action);
			LogChannel('MCM_AR', "[AR] Zarejestrowano akcję: " + action.id);
		}
	}

	// -----------------------------------------------------------------------
	// Główna pętla selekcji i wykonania
	// -----------------------------------------------------------------------
	public latent function TryExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var eligible    : array<MCM_RomanceInteraction>;
		var action      : MCM_RomanceInteraction;
		var totalWeight : int;
		var roll        : int;
		var i           : int;
		var npcName     : name;
		var result      : bool;

		if (!MCM_AR_GetConfig().IsEnabled()) return false;

		npcName = npc.scmcc.data.nam;

		// Zbierz kwalifikujące się akcje dla tego NPC
		for (i = 0; i < actions.Size(); i += 1)
		{
			action = actions[i];
			if (!action) continue;

			// Filtr: akcja musi pasować do NPC lub być ogólna
			if (IsNameValid(action.targetNpc) && action.targetNpc != npcName) continue;

			if (action.CanExecute(npc, player, ctx))
			{
				eligible.PushBack(action);
				totalWeight += action.weight;
			}
		}

		if (eligible.Size() == 0) return false;

		// Ważone losowanie akcji
		roll = RandRange(totalWeight, 0);
		for (i = 0; i < eligible.Size(); i += 1)
		{
			roll -= eligible[i].weight;
			if (roll < 0)
			{
				result = eligible[i].Execute(npc, player, ctx);
				if (result)
				{
					// Przyznaj punkty zażyłości
					affinity.AddAffinityPoints(npcName, 1);
				}
				return result;
			}
		}

		return false;
	}

	public function ResetAllCooldowns()
	{
		var i : int;
		for (i = 0; i < actions.Size(); i += 1)
		{
			if (actions[i])
			{
				actions[i].ResetCooldown();
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Specjalna akcja: HUD Prompt Input Listener
// (zarejestruj odpowiedź gracza na prompt [E])
// ---------------------------------------------------------------------------

@addMethod(CR4Player)
event OnMCM_AR_ConsentKey(action : SInputAction)
{
	if (IsPressed(action))
	{
		if (FactsQuerySum('mcme_ar_awaiting_consent') > 0)
		{
			FactsSet('mcme_ar_consent_given', 1);
		}
	}
}

// Uwaga: RegisterListener('OnMCM_AR_ConsentKey', 'Talk') 
// wywoływane jest z MCM_RomanceCore.ws @wrapMethod(CR4Player) OnSpawned.

