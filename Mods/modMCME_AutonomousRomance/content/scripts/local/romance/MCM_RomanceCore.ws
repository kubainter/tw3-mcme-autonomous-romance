/*****************************************************************************/
/* MCME Autonomous Romance - Core Module                                     */
/* Główna pętla, timery i context tracker                                    */
/* Wersja: 1.0.0  |  Wymaga: modMCME_Remastered 5.00+                       */
/*****************************************************************************/

// ---------------------------------------------------------------------------
// Singleton dostępny globalnie, inicjowany przy spawnie gracza
// ---------------------------------------------------------------------------

function MCM_AR_GetCore() : MCM_AutonomousRomanceCore
{
	return thePlayer.mcm_ar_core;
}

// ---------------------------------------------------------------------------
// Rozszerzenie CR4Player: dodanie pola core i timera
// ---------------------------------------------------------------------------

@addField(CR4Player)
public var mcm_ar_core : MCM_AutonomousRomanceCore;

@wrapMethod(CR4Player)
function OnSpawned(spawnData : SEntitySpawnData)
{
	wrappedMethod(spawnData);

	// Inicjalizacja modułów Autonomous Romance
	MCM_AR_InitCore();

	// Konfiguracja (Filar 3 - user.settings)
	if (!mcm_ar_config)
	{
		mcm_ar_config = new MCM_AR_ConfigWrapper in this;
	}

	// Rejestracja listenera klawisza zgody gracza [E] (natywna akcja Talk)
	theInput.RegisterListener(this, 'OnMCM_AR_ConsentKey', 'Talk');
}

@addMethod(CR4Player)
function MCM_AR_InitCore()
{
	if (!mcm_ar_core)
	{
		mcm_ar_core = new MCM_AutonomousRomanceCore in this;
		mcm_ar_core.Init();
	}
	AddTimer('MCM_AR_AutonomousTick', 4.0, true);
}

@addMethod(CR4Player)
timer function MCM_AR_AutonomousTick(dt : float, id : int)
{
	if (mcm_ar_core)
	{
		mcm_ar_core.OnTick();
	}
}

// ---------------------------------------------------------------------------
// Klasa główna – silnik decyzyjny
// ---------------------------------------------------------------------------

class MCM_AutonomousRomanceCore
{
	// Singleton rejestru akcji
	public var registry : MCM_RomanceActionRegistry;

	// Czas ostatniej inicjatywy w sekundach silnika (per NPC)
	private var lastInitiativeTime : array<float>;
	private var lastInitiativeNpc  : array<name>;

	// Wewnętrzny licznik: ile sekund upłynęło od ostatniej walki
	private var secondsSinceCombat : float;
	default secondsSinceCombat = 9999.0;

	private var isInit : bool;
	default isInit = false;

	public function Init()
	{
		if (isInit) return;
		isInit = true;

		registry = new MCM_RomanceActionRegistry in this;
		registry.Init();

		LogChannel('MCM_AR', "[AR] AutonomousRomanceCore zainicjalizowany.");
	}

	// -----------------------------------------------------------------------
	// Główny tick (wywoływany co 4s przez timer CR4Player)
	// -----------------------------------------------------------------------
	public function OnTick()
	{
		var companions : array<CNewNPC>;
		var npc        : CNewNPC;
		var ctx        : MCM_RomanceContext;
		var i          : int;

		if (!isInit) return;

		// Zabezpieczenie: nie rób nic poza eksploracją
		if (!MCM_AR_IsSafeToInitiate()) return;

		// Pobierz listę aktywnych towarzyszy MCME
		theGame.GetNPCsByTag('GeraltsBFF', companions);
		if (companions.Size() == 0) return;

		// Buduj kontekst globalny raz na tick
		ctx = BuildContext(companions);

		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc) continue;
			if (!npc.HasTag('mod_scm_IsFollowing')) continue;

			// Sprawdź cooldown per NPC
			if (!IsCooldownElapsed(npc.scmcc.data.nam, ctx)) continue;

			// Deleguj do rejestru – wybierze i wykona najlepszą akcję
			if (registry.TryExecute(npc, thePlayer, ctx))
			{
				SetLastInitiativeTime(npc.scmcc.data.nam);
				break; // Tylko jedna inicjatywa na tick
			}
		}
	}

	// -----------------------------------------------------------------------
	// Warunki bezpieczeństwa – żadna akcja nie zostanie wywołana, jeśli:
	// -----------------------------------------------------------------------
	private function MCM_AR_IsSafeToInitiate() : bool
	{
		// Gracz musi być w trybie eksploracji
		if (thePlayer.GetCurrentStateName() != 'Exploration')     return false;
		// Brak aktywnej walki
		if (thePlayer.IsInCombat())                               return false;
		// Brak aktywnego dialogu lub cutsceny
		if (theGame.IsDialogOrCutscenePlaying())                  return false;
		// DialogueManager MCME nie może być zajęty
		if (MCM_GetMCM().DialogueManager.IsBusy())                return false;
		// Gracz nie może pływać ani być na łodzi
		if (thePlayer.IsSwimming())                               return false;
		if (thePlayer.IsMountedToBoat())                          return false;

		return true;
	}

	// -----------------------------------------------------------------------
	// Budowanie kontekstu otoczenia
	// -----------------------------------------------------------------------
	private function BuildContext(companions : array<CNewNPC>) : MCM_RomanceContext
	{
		var ctx          : MCM_RomanceContext;
		var gt           : GameTime;
		var hourOfDay    : int;
		var npc          : CNewNPC;
		var i            : int;
		var rivalCount   : int;

		ctx = new MCM_RomanceContext in this;

		// Pora dnia (0-23)
		gt = theGame.GetGameTime();
		hourOfDay = GameTimeHours(gt);
		ctx.hourOfDay = hourOfDay;

		// Typy pory dnia
		ctx.isNight = (hourOfDay >= 22 || hourOfDay < 4);
		ctx.isDawn  = (hourOfDay >= 6  && hourOfDay < 9);

		// Zdrowie Geralta (0.0 - 1.0)
		ctx.playerHealthRatio = thePlayer.GetStat(BCS_Vitality) / thePlayer.GetStatMax(BCS_Vitality);

		// Obszar gry
		ctx.areaName = MCM_GetAreaName();

		// Czy gracz jest w Corvo Bianco? (Toussaint, obszar 11)
		ctx.isInCorvo = (ctx.areaName == (EAreaName)11);

		// Czy Geralt jest przy ognisku? (prosty promień)
		ctx.isNearCampfire = MCM_AR_IsNearCampfire();

		// Czy gracz jest w tawernie/karczmie?
		ctx.isInTavern = MCM_AR_IsInTavern();

		// Liczba rywalek (więcej niż 1 towarzyszka romansowa = zazdrość)
		rivalCount = 0;
		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc) continue;
			if (MCM_AR_IsRomanceNPC(npc.scmcc.data.nam))
			{
				rivalCount += 1;
			}
		}
		ctx.rivalCount = rivalCount;
		ctx.hasRivals  = (rivalCount > 1);

		return ctx;
	}

	// -----------------------------------------------------------------------
	// Sprawdzenie cooldownu dla danego NPC
	// -----------------------------------------------------------------------
	private function IsCooldownElapsed(npcName : name, ctx : MCM_RomanceContext) : bool
	{
		var i         : int;
		var cooldownS : float;
		var now       : float;

		now = theGame.GetEngineTimeAsSeconds();

		// Pobierz cooldown z konfiguracji MCM (domyślnie 720s = 12 minut)
		cooldownS = MCM_AR_GetConfig().GetInitiativeCooldown();

		for (i = 0; i < lastInitiativeNpc.Size(); i += 1)
		{
			if (lastInitiativeNpc[i] == npcName)
			{
				return (now - lastInitiativeTime[i]) >= cooldownS;
			}
		}
		// Nigdy nie miała inicjatywy – odczekaj 60s po spawnie gracza
		return now > 60.0;
	}

	private function SetLastInitiativeTime(npcName : name)
	{
		var i   : int;
		var now : float;
		now = theGame.GetEngineTimeAsSeconds();

		for (i = 0; i < lastInitiativeNpc.Size(); i += 1)
		{
			if (lastInitiativeNpc[i] == npcName)
			{
				lastInitiativeTime[i] = now;
				return;
			}
		}
		lastInitiativeNpc.PushBack(npcName);
		lastInitiativeTime.PushBack(now);
	}

	// -----------------------------------------------------------------------
	// Pomocnicze sprawdzenia środowiskowe
	// -----------------------------------------------------------------------
	private function MCM_AR_IsNearCampfire() : bool
	{
		var entities : array<CEntity>;
		var i        : int;
		var dist     : float;

		// Ogniska mają tag 'campfire' w silniku
		theGame.GetEntitiesByTag('campfire', entities);
		for (i = 0; i < entities.Size(); i += 1)
		{
			dist = VecDistance(thePlayer.GetWorldPosition(), entities[i].GetWorldPosition());
			if (dist < 6.0) return true;
		}
		return false;
	}

	private function MCM_AR_IsInTavern() : bool
	{
		// Sprawdź przez fact ustawiany przez vanilla przy wejściu do tawerny
		return FactsQuerySum('player_in_inn') > 0;
	}

	private function MCM_AR_IsRomanceNPC(npcName : name) : bool
	{
		switch(npcName)
		{
			case 'yennefer':
			case 'triss':
			case 'keira_metz':
			case 'shani':
			case 'anna_henrietta':
			case 'sq701_vivienne':
			case 'cerys':
				return true;
		}
		return false;
	}
}
