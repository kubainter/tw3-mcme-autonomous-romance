/*****************************************************************************/
/* MCME Autonomous Romance - Core Module                                     */
/* Główna pętla, timery i context tracker                                    */
/* Wersja: 1.0.0  |  Wymaga: modMCME_Remastered 5.00+                       */
/*****************************************************************************/

// ---------------------------------------------------------------------------
// Singleton dostępny globalnie, inicjowany przy spawnie gracza
// ---------------------------------------------------------------------------

@addField(CR4Player)
public var mcm_ar_core : MCM_AutonomousRomanceCore;

@addField(CR4Player)
public var mcm_ar_ambient : MCM_AmbientRomanceChannel;

// Bootlog: wiadomosci zapisane ZANIM powstal core (scriptslog.txt umiera
// po burstcie startowym na tej instalacji - obejscie diagnostyki przez HUD).
@addField(CR4Player)
public var mcm_ar_bootlog : array<string>;

@addMethod(CR4Player)
function MCM_AR_GetCore() : MCM_AutonomousRomanceCore
{
	if (!mcm_ar_core)
	{
		MCM_AR_InitCore();
	}
	return mcm_ar_core;
}

function MCM_AR_GetCore() : MCM_AutonomousRomanceCore
{
	return thePlayer.MCM_AR_GetCore();
}

@addMethod(CR4Player)
function MCM_AR_OnPlayerReady()
{
	// Inicjalizacja modułów Autonomous Romance
	MCM_AR_InitCore();

	// Konfiguracja (Filar 3 - user.settings)
	if (!mcm_ar_config)
	{
		mcm_ar_config = new MCM_AR_ConfigWrapper in this;
	}

	// Rejestracja listenera klawisza zgody gracza [C].
	// NIE uzywamy E/Interaction/Talk/Interact – to klawisze interakcji
	// vanilla, wiec akceptacja promptu jednoczesnie odpalala dialog MCME
	// z towarzyszem. MCM_K_C = custom akcja MCME zbindowana na IK_C
	// (input.settings), nie ma innej funkcji w eksploracji.
	// Uwaga: MCM_K_C z input.settings siedzi w sekcji [SCMMenuBase] –
	// dispatchuje TYLKO w kontekscie menu MCME, nigdy w eksploracji.
	// [C] w kontekscie Exploration = akcja 'SwordSheathe' (juz zbindowana),
	// wiec nasluchujemy jej zamiast; efekt uboczny to zapiecie/schowanie
	// miecza przy akceptacji – akceptowalne w kontekscie promptu.
	// Stare rejestracje NIE sa derejestrowywane –
	// UnregisterListener(this,'Talk') na CR4Player zdjeloby tez vanilla-owe
	// handlery interakcji gracza. Listenery rejestruja sie swiezo na spawnie.
	theInput.RegisterListener(this, 'OnMCM_AR_ConsentKey', 'SwordSheathe');

	// Bezpiecznik: latent-abort ShowConsentPrompt mogl zostawic fakty
	// (obiekt zniszczony w trakcie Sleep - cleanup petli nie strzeli).
	FactsRemove('mcme_ar_awaiting_consent');
	FactsRemove('mcme_ar_consent_given');

	if (mcm_ar_core)
	{
		mcm_ar_core.ResetAllCooldowns();
	}
}


exec function ar_test()
{
	MCM_AR_Log("Manualny test konsoli - dziala!", true);
	if (thePlayer)
	{
		thePlayer.MCM_AR_OnPlayerReady();
		MCM_AR_Log("thePlayer OK, Core zainicjalizowany!", true);
	}
	else
	{
		MCM_AR_Log("thePlayer == NULL", true);
	}
}

// Marker diagnostyczny zapisywany do user.settings przez config wrapper.
// Kanal niezalezny od scriptslog.txt (ktory umiera po burstcie startowym
// na tej instalacji). Zapis idzie wylacznie do surowej sekcji [AR_Diag] -
// NIE ruszamy realnych varow MCM (wczesniej SetVarValue na CooldownSlider
// nadpisywal cooldown gracza przy kazdym spawnie).
// W przyszlosci usunac albo zastapic trwalym kanalem logowania.
function MCM_AR_DiagMark(code : int)
{
	var wrapper : CInGameConfigWrapper;

	wrapper = theGame.GetInGameConfigWrapper();
	if (wrapper)
	{
		wrapper.SetRawConfigValueByStr("AR_Diag", "last", "" + code);
		wrapper.SetRawConfigValueByStr("AR_Diag", "t" + code, "" + RoundMath(theGame.GetEngineTimeAsSeconds()));
	}
	// Flush wewnatrz markera: DiagMark to kanar na crash - gdyby caller
	// umarl przed wlasnym zapisem, marker musi juz byc na dysku, inaczej
	// diagnoza "gdzie zdechlo" jest niemozliwa (CR agy).
	theGame.SaveUserSettings();
}

// Inicjalizacja wewnatrz bazowego cyklu OnSpawned gracza.
// InitRemasterSettings() jest wolana na koncu bazowego OnSpawned w content0 (linia 740).
// Zaden inny mod (w tym BIA) jej nie wrapuje, wiec wywolanie ZAWSZE dociera tutaj!
@wrapMethod(CR4Player)
function InitRemasterSettings()
{
	MCM_AR_Log("InitRemasterSettings - wrap entered");
	MCM_AR_DiagMark(1);
	wrappedMethod();
	MCM_AR_Log("InitRemasterSettings - Autonomous Romance session ready");
	MCM_AR_DiagMark(2);
	this.MCM_AR_OnPlayerReady();
	MCM_AR_DiagMark(3);
}

// Sonda diagnostyczna: wrap na metodzie z gwarantowanym dispatchem.
// BIA wrapuje to samo CPlayerInput.Initialize i jego logi sa widoczne
// w scriptslog.txt - jesli nasz log tu nie strzeli, nasze @wrapMethod
// nie rejestruja sie w ogole (problem kompilacji/mounta, nie kodu).
// isFromLoad=true oznacza spawnData.restored - prawdziwy load save'a.
// Uwaga: samo LogChannel, bez MCM_AR_Log/FactsAdd - za wczesny etap
// spawnu na thePlayer/config/facts (powodowalo CTD przy loadzie).
@wrapMethod(CPlayerInput)
function Initialize(isFromLoad : bool, optional previousInput : CPlayerInput)
{
	LogChannel('MCM_AR', "AR probe: CPlayerInput.Initialize fired, isFromLoad=" + isFromLoad);
	wrappedMethod(isFromLoad, previousInput);
}

@addMethod(CR4Player)
function MCM_AR_InitCore()
{
	MCM_AR_Log("InitCore entered");
	if (!mcm_ar_core)
	{
		mcm_ar_core = new MCM_AutonomousRomanceCore in this;
		mcm_ar_core.Init();
	}
	if (!mcm_ar_ambient)
	{
		mcm_ar_ambient = new MCM_AmbientRomanceChannel in this;
		mcm_ar_ambient.Init();
	}
	AddTimer('MCM_AR_AutonomousTick', 4.0, true);
	AddTimer('MCM_AR_AmbientTick', 10.0, true);
}

@addMethod(CR4Player)
timer function MCM_AR_AutonomousTick(dt : float, id : int)
{
	if (mcm_ar_core && mcm_ar_core.GetCurrentStateName() == 'Idle')
	{
		mcm_ar_core.GotoState('ProcessingTick');
	}
}

// Kanał ambient (barki/zazdrość) – osobny timer i osobna maszyna stanów,
// więc latent staged tick nigdy nie blokuje harmonogramu barków.
@addMethod(CR4Player)
timer function MCM_AR_AmbientTick(dt : float, id : int)
{
	if (mcm_ar_ambient && mcm_ar_ambient.GetCurrentStateName() == 'Idle')
	{
		mcm_ar_ambient.GotoState('AmbientTick');
	}
}

// ---------------------------------------------------------------------------
// Klasa główna – silnik decyzyjny
// ---------------------------------------------------------------------------

statemachine class MCM_AutonomousRomanceCore
{
	default autoState = 'Idle';

	// Singleton rejestru akcji
	public var registry : MCM_RomanceActionRegistry;

	// Czas ostatniej inicjatywy w sekundach silnika (per NPC)
	private var lastInitiativeTime : array<float>;
	private var lastInitiativeNpc  : array<name>;

	// Wewnętrzny licznik: ile sekund upłynęło od ostatniej walki
	private var timeOfLastCombatEnd : float;
	default timeOfLastCombatEnd = -9999.0;

	// Anty-chaos: tylko jedna staged interakcja naraz (propozycja/scena);
	// ambient barki działają równolegle przez osobny kanał (MCM_AmbientRomanceChannel).
	private var interactionBusy : bool;
	private var busyNpc         : CNewNPC;
	private var lastStagedTime  : float;
	// Timestamp acquire locka – watchdog zdejmuje martwy lock >300s
	private var busyStartTime   : float;
	default interactionBusy = false;
	default lastStagedTime = -9999.0;
	default busyStartTime = -9999.0;

	// Jednorazowy notifier "sweet spot" (reset po wyjściu z zasiegu, histereza)
	public var naughtySpotNotified : bool;
	default naughtySpotNotified = false;

	// Auto-pick opcji w naszych scenach *FollowWithKiss: wrap OnDialogChoicesSet
	// (HUD) wybiera opcje kiss, WaitForSceneEnd wykonuje select+accept z krotkim
	// opoznieniem (wzorcem tw3-automatic-dialog-picker). Phase 0 = kiss
	// (strukturalnie: opcja romansu = index 1 szablonu hub-menu, walidacja po
	// ikonie EXIT na ostatniej pozycji – niezaleznie od lokalizacji; keywords
	// w tekscie opcji sa tylko fallbackiem dla scen o odmiennym ukladzie).
	// Phase 1 = po kiss wybierz exit gdy menu wraca (scena pokazuje hub w petli).
	public var arAutoPick       : bool;
	public var arPickPhase      : int;
	public var arPendingPickIdx : int;
	public var arPendingPickAt  : float;
	default arAutoPick       = false;
	default arPickPhase      = 0;
	default arPendingPickIdx = -1;
	default arPendingPickAt  = 0.0;

	public var isInit : bool;
	default isInit = false;

	// Ostatni wypisany digest ticku w trybie debug (deduplikacja spamu HUD)
	public var lastDebugDigest : string;

	// Ring buffer ostatnich linii diagnostycznych (dump przez ar_logdump)
	public var debugLog : array<string>;

	public function PushDebugLine(msg : string)
	{
		debugLog.PushBack("" + RoundMath(theGame.GetEngineTimeAsSeconds()) + "s " + msg);
		if (debugLog.Size() > 60)
		{
			debugLog.Erase(0);
		}
	}

	// -----------------------------------------------------------------------
	// Wywolywane z wrapa OnDialogChoicesSet (CR4HudModuleDialog) za kazdym
	// pokazaniem menu wyborow podczas uzbrojonej sceny (arAutoPick). Tylko
	// ustawia pending pick – faktyczny select/accept robi WaitForSceneEnd
	// (latent, z opoznieniem jak u gracza). Nie-latent!
	// -----------------------------------------------------------------------
	public function MCM_AR_OnDialogChoices(choices : array<SSceneChoice>)
	{
		var i, idx : int;
		var desc : string;

		// DIAG: entry log pokazuje ze wrap strzelil i stan flag –
		// rozstrzyga "wrap nie strzela" vs "arAutoPick false".
		MCM_AR_Log("[AR] OnDialogChoices entry: n=" + choices.Size() +
		           " autoPick=" + arAutoPick + " phase=" + arPickPhase);
		// Pending juz ustawiony = drugi wrap (SendDialogChoicesToUI)
		// strzelil dla tego samego zestawu – nie nadpisuj picku.
		if (!arAutoPick || arPendingPickIdx >= 0) return;
		idx = -1;

		for (i = 0; i < choices.Size(); i += 1)
		{
			MCM_AR_Log("[AR] dlg choice[" + i + "] '" + choices[i].description +
			           "' act=" + (int)choices[i].dialogAction +
			           " emph=" + choices[i].emphasised +
			           " seen=" + choices[i].previouslyChoosen);
		}

		if (arPickPhase == 0)
		{
			// Wszystkie sceny *FollowWithKiss dziela jeden szablon hub-menu
			// (auto-generowane): [0] wyjscie-link, [1] linia romansu = kiss,
			// [2] wejscie do menu naughty, [3] hub pytan, [4] wyjscie z ikona
			// EXIT. Opcja romansu to zawsze index 1 – identyfikujemy ja
			// STRUKTURALNIE po szablonie, nie po tekscie: ostatnia opcja musi
			// miec ikone DialogAction_EXIT (enum, locale-free). Dziala w kazdej
			// lokalizacji bez znajomosci tlumaczen.
			if (choices.Size() >= 3 &&
			    choices[choices.Size() - 1].dialogAction == DialogAction_EXIT &&
			    choices[1].dialogAction != DialogAction_EXIT && !choices[1].disabled)
			{
				idx = 1;
			}
			// Fallback dla scen o odmiennym ukladzie – match keywords po tekscie
			// (EN/PL/DE/FR/ES/CZ). Opcja kiss kryje sie pod linia romansu
			// ("Kocham cie, Yen", "I love you"), wiec matchujemy frazy milosne.
			// Nie matchujemy "ustrone miejsce" – to wejscie do menu naughty.
			if (idx < 0)
			{
				for (i = 0; i < choices.Size(); i += 1)
				{
					if (choices[i].disabled) continue;
					desc = StrLower(choices[i].description);
					// "amo" bound-owane spacja (IT andiamo/vamos, ES lasciamo
					// nie maja spacji przed -amo/-amos), 'aime z apostrofem
					// (FR vraiment nie ma apostrofu).
					if (StrContains(desc, "kiss") || StrContains(desc, "poca") ||
					    StrContains(desc, "caluj") || StrContains(desc, "hug") ||
					    StrContains(desc, "przytul") || StrContains(desc, "embrace") ||
					    StrContains(desc, "kuss") || StrContains(desc, "beso") ||
					    StrContains(desc, "baiser") || StrContains(desc, "kocham") ||
					    StrContains(desc, "love") || StrContains(desc, "liebe") ||
					    StrContains(desc, "'aime") || StrContains(desc, " amo") ||
					    StrContains(desc, "quiero") || StrContains(desc, "miluj") ||
					    StrContains(desc, "adore"))
					{
						idx = i;
						break;
					}
				}
			}
			if (idx >= 0)
			{
				arPickPhase = 1;
			}
			else
			{
				MCM_AR_Log("[AR] autoPick: brak opcji kiss/romans – wybor zostaje reczny");
				arAutoPick = false;
				return;
			}
		}
		else
		{
			// Po kiss scena wraca do hub-menu – wybierz wyjscie, zeby sie skonczyla.
			for (i = 0; i < choices.Size(); i += 1)
			{
				if (choices[i].dialogAction == DialogAction_EXIT && !choices[i].disabled)
				{
					idx = i;
					break;
				}
			}
			if (idx < 0)
			{
				for (i = 0; i < choices.Size(); i += 1)
				{
					if (choices[i].disabled) continue;
					desc = StrLower(choices[i].description);
					if (StrContains(desc, "leave") || StrContains(desc, "wyjd") ||
					    StrContains(desc, "zegnaj") || StrContains(desc, "farewell") ||
					    StrContains(desc, "nevermind") || StrContains(desc, "never mind"))
					{
						idx = i;
						break;
					}
				}
			}
			if (idx < 0)
			{
				MCM_AR_Log("[AR] autoPick: brak opcji wyjscia po kiss – wybor zostaje reczny");
				arAutoPick = false;
				return;
			}
		}

		arPendingPickIdx = idx;
		arPendingPickAt  = theGame.GetEngineTimeAsSeconds();
		MCM_AR_Log("[AR] autoPick -> opcja " + idx + " '" + choices[idx].description + "'");
	}

	public function Init()
	{
		MCM_AR_Log("Init entered, isInit=" + isInit);
		if (isInit) return;
		isInit = true;

		registry = new MCM_RomanceActionRegistry in this;
		registry.Init();

		GotoState('Idle');

		MCM_AR_Log("AutonomousRomanceCore zainicjalizowany.");
	}

	public function UpdateCombatStatus()
	{
		if (thePlayer.IsInCombat())
		{
			timeOfLastCombatEnd = -9999.0;
		}
		else if (timeOfLastCombatEnd == -9999.0)
		{
			// Combat just finished
			timeOfLastCombatEnd = theGame.GetEngineTimeAsSeconds();
		}
	}

	public function GetSecondsSinceCombat() : float
	{
		if (thePlayer.IsInCombat()) return 0.0;
		if (timeOfLastCombatEnd < 0.0) return 9999.0;
		return theGame.GetEngineTimeAsSeconds() - timeOfLastCombatEnd;
	}

	public function ResetAllCooldowns()
	{
		var i   : int;
		var amb : MCM_AmbientRomanceChannel;

		for (i = 0; i < lastInitiativeNpc.Size(); i += 1)
		{
			lastInitiativeTime[i] = -9999.0;
		}

		lastStagedTime = -9999.0;
		interactionBusy = false;
		busyNpc = NULL;
		busyStartTime = -9999.0;
		naughtySpotNotified = false;
		arAutoPick = false;
		arPickPhase = 0;
		arPendingPickIdx = -1;

		amb = thePlayer.mcm_ar_ambient;
		if (amb)
		{
			amb.lastBarkTime = -9999.0;
		}

		if (registry)
		{
			registry.ResetAllCooldowns();
		}
	}

	// -----------------------------------------------------------------------
	// Warunki bezpieczeństwa – żadna akcja nie zostanie wywołana, jeśli:
	// -----------------------------------------------------------------------
	public function MCM_AR_IsSafeToInitiate(optional out reason : string) : bool
	{
		// Gracz musi być w trybie eksploracji
		if (thePlayer.GetCurrentStateName() != 'Exploration')
		{
			reason = "stan gracza=" + thePlayer.GetCurrentStateName() + " (wym. Exploration)";
			return false;
		}
		// Kontekst input musi być eksploracyjny – w menu (SCMMenuBase,
		// RadialMenu itd.) prompt consent bylby niewidoczny, a sceny
		// strzelalyby "pod" otwartym UI. Player state zostaje Exploration
		// przy otwartych menu, wiec sam state-check tego nie lapi e.
		if (theInput.GetContext() != 'Exploration')
		{
			reason = "inputContext=" + NameToString(theInput.GetContext());
			return false;
		}
		// Brak aktywnej walki
		if (thePlayer.IsInCombat())
		{
			reason = "IsInCombat";
			return false;
		}
		// Brak aktywnego dialogu lub cutsceny
		if (theGame.IsDialogOrCutscenePlaying())
		{
			reason = "DialogOrCutscenePlaying";
			return false;
		}
		// Uwaga: DialogueManager.IsBusy MCME celowo NIE jest tu gate'em –
		// to stan MCM_DM_Talking (kolejka onelinerow/banteru), w ktorej
		// nasze barki i ambient same sie kolejkuja. Sceny maja wlasny
		// gate WaitForDialogueFree w PlayScene/PlayDialogueScene/
		// PlayIntimateScene (stale>20s przepuszcza martwa kolejke).
		// Gracz nie może pływać ani być na łodzi
		if (thePlayer.IsSwimming())
		{
			reason = "IsSwimming";
			return false;
		}
		if (thePlayer.IsOnBoat())
		{
			reason = "IsOnBoat";
			return false;
		}

		reason = "";
		return true;
	}

	private var cachedContext : MCM_RomanceContext;

	// -----------------------------------------------------------------------
	// Budowanie kontekstu otoczenia
	// -----------------------------------------------------------------------
	public function BuildContext(companions : array<CNewNPC>) : MCM_RomanceContext
	{
		var gt           : GameTime;
		var hourOfDay    : int;
		var npc          : CNewNPC;
		var i            : int;
		var rivalCount   : int;
		var naughtyPt    : mod_scm_NaughtyPoint;

		if (!cachedContext)
		{
			cachedContext = new MCM_RomanceContext in this;
		}

		// Pora dnia (0-23)
		gt = theGame.GetGameTime();
		hourOfDay = GameTimeHours(gt) % 24;
		cachedContext.hourOfDay = hourOfDay;

		// Typy pory dnia
		cachedContext.isNight = (hourOfDay >= 22 || hourOfDay < 4);
		cachedContext.isDawn  = (hourOfDay >= 6  && hourOfDay < 9);

		// Zdrowie Geralta (0.0 - 1.0)
		cachedContext.playerHealthRatio = thePlayer.GetStat(BCS_Vitality) / thePlayer.GetStatMax(BCS_Vitality);

		// Obszar gry
		cachedContext.areaName = MCM_GetAreaName();

		// Czy gracz jest w Corvo Bianco? (Toussaint, obszar 11)
		cachedContext.isInCorvo = (cachedContext.areaName == (EAreaName)11);

		cachedContext.companionsInParty.Clear();

		// Czy Geralt jest przy ognisku? (prosty promień)
		cachedContext.isNearCampfire = MCM_AR_IsNearCampfire();

		// Czy gracz jest w tawernie/karczmie?
		cachedContext.isInTavern = MCM_AR_IsInTavern();

		// "Sweet spot" MCME – punkt intymny w zasiegu 30m. Zaproszenie pada
		// zanim staniemy na punkcie; sama scena intymna wymaga <=20m.
		cachedContext.isNearNaughtySpot = false;
		if (mod_scm_GetSCM() && mod_scm_GetSCM().NaughtyManager && mod_scm_GetSCM().NaughtyManager.naughtyPoints)
		{
			naughtyPt = mod_scm_GetSCM().NaughtyManager.naughtyPoints.GetClosestPoint(30.0);
			if (naughtyPt)
			{
				cachedContext.isNearNaughtySpot = true;
			}
		}

		// Liczba rywalek (więcej niż 1 towarzyszka romansowa = zazdrość)
		rivalCount = 0;
		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc) continue;
			if (MCM_AR_IsRomanceNPC(npc.scmcc.data.nam))
			{
				cachedContext.companionsInParty.PushBack(npc.scmcc.data.nam);
				rivalCount += 1;
			}
		}
		cachedContext.rivalCount = rivalCount;
		cachedContext.hasRivals  = (rivalCount > 1);

		return cachedContext;
	}

	// -----------------------------------------------------------------------
	// Sprawdzenie cooldownu dla danego NPC
	// -----------------------------------------------------------------------
	public function IsCooldownElapsed(npcName : name, ctx : MCM_RomanceContext) : bool
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
		// Nigdy nie miała inicjatywy – gotowa natychmiast
		return true;
	}

	// Pozostały czas cooldownu inicjatywy dla NPC (0 = gotowa)
	public function GetCooldownRemaining(npcName : name) : float
	{
		var i         : int;
		var left      : float;
		var cooldownS : float;
		var now       : float;

		now = theGame.GetEngineTimeAsSeconds();
		cooldownS = MCM_AR_GetConfig().GetInitiativeCooldown();

		for (i = 0; i < lastInitiativeNpc.Size(); i += 1)
		{
			if (lastInitiativeNpc[i] == npcName)
			{
				left = cooldownS - (now - lastInitiativeTime[i]);
				if (left < 0.0) left = 0.0;
				return left;
			}
		}
		return 0.0;
	}

	public function SetLastInitiativeTime(npcName : name)
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
	// Anty-chaos: globalny lock staged interakcji + post-staged cooldown (~90s)
	// Wołane przez registry.TryExecute wokół Execute akcji staged.
	// -----------------------------------------------------------------------
	public function BeginStagedInteraction(npc : CNewNPC) : bool
	{
		var now : float;

		now = theGame.GetEngineTimeAsSeconds();

		// Watchdog: latent Execute moze abortowac w polowie –
		// EndStagedInteraction nigdy nie strzeli i kanal staged
		// bylby martwy do ar_reset. Lock starszy niz 300s traktujemy
		// jako stary, logujemy i uwalniamy przed normalnym acquire.
		// (300s > najdluzsza legitna sciezka: approach + prompt 10s
		// + WaitForSceneEnd do 90s; 120s byloby za ciasne i zdjeloby
		// zywy lock -> nakladajace sie staged interakcje.)
		if (interactionBusy && now - busyStartTime > 300.0)
		{
			if (busyNpc && busyNpc.scmcc)
			{
				MCM_AR_Log("[AR] Watchdog: interactionBusy martwy (" + IntToString(RoundMath(now - busyStartTime)) +
				           "s, npc=" + NameToString(busyNpc.scmcc.data.nam) + ") – wymuszone zwolnienie");
			}
			else
			{
				MCM_AR_Log("[AR] Watchdog: interactionBusy martwy (" + IntToString(RoundMath(now - busyStartTime)) +
				           "s) – wymuszone zwolnienie");
			}
			interactionBusy = false;
			busyNpc = NULL;
			// Martwy lock oznacza latent-abort – auto-pick tez nie zyje.
			arAutoPick = false;
			arPickPhase = 0;
			arPendingPickIdx = -1;
		}

		if (interactionBusy) return false;
		interactionBusy = true;
		busyNpc = npc;
		busyStartTime = now;
		return true;
	}

	public function EndStagedInteraction()
	{
		interactionBusy = false;
		busyNpc = NULL;
		busyStartTime = -9999.0;
		lastStagedTime = theGame.GetEngineTimeAsSeconds();
		// Bezpiecznik: gdy scena z auto-pick przerwie sie w polowie,
		// flaga nie moze przeciec do kolejnych, nie naszych dialogow.
		arAutoPick = false;
		arPickPhase = 0;
		arPendingPickIdx = -1;
	}

	public function IsStagedBusy() : bool
	{
		return interactionBusy;
	}

	public function IsNpcBusy(npc : CNewNPC) : bool
	{
		return interactionBusy && busyNpc == npc;
	}

	// Globalny oddech po jakiejkolwiek staged inicjatywie (tez odmowionej)
	public function GetStagedCooldownRemaining() : float
	{
		var left : float;
		left = 90.0 - (theGame.GetEngineTimeAsSeconds() - lastStagedTime);
		if (left < 0.0) left = 0.0;
		return left;
	}

	// -----------------------------------------------------------------------
	// Pomocnicze sprawdzenia środowiskowe
	// -----------------------------------------------------------------------
	public function MCM_AR_IsNearCampfire() : bool
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

	public function MCM_AR_IsInTavern() : bool
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
			case 'becca':
				return true;
		}
		return false;
	}

	public function ShuffleCompanions(out arr : array<CNewNPC>)
	{
		var i, j : int;
		var temp : CNewNPC;

		for (i = arr.Size() - 1; i > 0; i -= 1)
		{
			j = RandRange(i + 1, 0);
			if (i != j)
			{
				temp = arr[i];
				arr[i] = arr[j];
				arr[j] = temp;
			}
		}
	}
}

state Idle in MCM_AutonomousRomanceCore
{
}

state ProcessingTick in MCM_AutonomousRomanceCore
{
	event OnEnterState( prevStateName : name )
	{
		ProcessTickEntry();
	}

	entry function ProcessTickEntry()
	{
		ProcessTick();
	}

	// -----------------------------------------------------------------------
	// Główny tick (wywoływany co 4s przez timer CR4Player za pomocą stanu)
	// -----------------------------------------------------------------------
	latent function ProcessTick()
	{
		var companions : array<CNewNPC>;
		var npc        : CNewNPC;
		var ctx        : MCM_RomanceContext;
		var i          : int;
		var eligCount  : int;
		var executed   : bool;
		var dbg        : bool;
		var digest     : string;
		var safeReason : string;

		if (!parent.isInit)
		{
			parent.GotoState('Idle');
			return;
		}

		parent.UpdateCombatStatus();
		dbg = MCM_AR_IsDebugOn();

		// Zabezpieczenie: nie rób nic poza eksploracją
		if (!parent.MCM_AR_IsSafeToInitiate(safeReason))
		{
			if (dbg) MCM_AR_Log("[AR tick] blokada bezpieczenstwa: " + safeReason);
			parent.GotoState('Idle');
			return;
		}

		// Pobierz listę aktywnych towarzyszy MCME
		theGame.GetNPCsByTag('GeraltsBFF', companions);
		if (companions.Size() == 0)
		{
			if (dbg) MCM_AR_Log("[AR tick] brak towarzyszy (tag 'GeraltsBFF' pusty)");
			parent.GotoState('Idle');
			return;
		}

		// Buduj kontekst globalny raz na tick
		ctx = parent.BuildContext(companions);

		// Notifier "sweet spot": jednorazowy HUD przy wejściu w zasięg punktu
		// intymnego, reset dopiero po wyjściu >40m (histereza anti-flap).
		if (ctx.isNearNaughtySpot)
		{
			if (!parent.naughtySpotNotified && ctx.companionsInParty.Size() > 0)
			{
				parent.naughtySpotNotified = true;
				thePlayer.DisplayHudMessage("[AR] Klimat sprzyja bliskosci...");
			}
		}
		else if (parent.naughtySpotNotified)
		{
			if (mod_scm_GetSCM() && mod_scm_GetSCM().NaughtyManager && mod_scm_GetSCM().NaughtyManager.naughtyPoints &&
			    !mod_scm_GetSCM().NaughtyManager.naughtyPoints.GetClosestPoint(40.0))
			{
				parent.naughtySpotNotified = false;
			}
		}

		parent.ShuffleCompanions(companions);

		if (dbg)
		{
			digest = "[AR tick] h=" + ctx.hourOfDay +
			         " noc=" + ctx.isNight +
			         " ogn=" + ctx.isNearCampfire +
			         " taw=" + ctx.isInTavern +
			         " corvo=" + ctx.isInCorvo +
			         " ryw=" + ctx.rivalCount;
		}

		// Anty-chaos: staged channel wzajemnie się wyklucza –
		// jedna interakcja naraz + globalny post-staged cooldown (~90s).
		// Ambient barki lecą równolegle przez MCM_AmbientRomanceChannel.
		// (Dopisujemy do digestu zamiast logować – deduplikacja na końcu.)
		if (parent.IsStagedBusy() || parent.GetStagedCooldownRemaining() > 0.0)
		{
			if (dbg)
			{
				// Statyczny marker (bez odliczanego czasu) – inaczej digest
				// zmienialby sie co tick i deduplikacja by nie zadzialala.
				digest += " | staged{busy=" + parent.IsStagedBusy() + "}";
				if (digest != parent.lastDebugDigest)
				{
					MCM_AR_Log(digest);
					parent.lastDebugDigest = digest;
				}
			}
			parent.GotoState('Idle');
			return;
		}

		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc) continue;
			if (!npc.HasTag('mod_scm_IsFollowing'))
			{
				if (dbg) digest += " | " + NameToString(npc.scmcc.data.nam) + "{!follow}";
				continue;
			}

			// Staged cooldown także W PĘTLI: odmowa/fail poprzedniej akcji
			// stempluje lastStagedTime – następna towarzyszka nie może
			// strzelić swoim promptem w tym samym ticku.
			if (parent.IsStagedBusy() || parent.GetStagedCooldownRemaining() > 0.0)
			{
				if (dbg) digest += " | " + NameToString(npc.scmcc.data.nam) + "{staged-cd}";
				break;
			}

			// Sprawdź cooldown per NPC
			if (!parent.IsCooldownElapsed(npc.scmcc.data.nam, ctx))
			{
				if (dbg) digest += " | " + NameToString(npc.scmcc.data.nam) + "{cd}";
				continue;
			}

			// Deleguj do rejestru – wybierze i wykona najlepszą akcję
			executed = parent.registry.TryExecute(npc, thePlayer, ctx, eligCount);
			if (dbg) digest += " | " + NameToString(npc.scmcc.data.nam) + "{elig=" + eligCount + " run=" + executed + "}";
			if (executed)
			{
				parent.SetLastInitiativeTime(npc.scmcc.data.nam);
				break; // Tylko jedna inicjatywa na tick
			}
		}

		// Wypisz digest tylko gdy cos sie zmienilo od poprzedniego ticku
		if (dbg && digest != parent.lastDebugDigest)
		{
			MCM_AR_Log(digest);
			parent.lastDebugDigest = digest;
		}

		parent.GotoState('Idle');
	}
}

// ===========================================================================
// Kanał ambient – barki RTT_OneLiner (w tym zazdrość Yen<->Triss) lecą
// równolegle do staged channel przez osobną maszynę stanów i timer.
// ===========================================================================

statemachine class MCM_AmbientRomanceChannel
{
	default autoState = 'Idle';

	public var lastBarkTime : float;
	default lastBarkTime = -9999.0;

	// Tracking widzianych towarzyszy do powitan po absencji:
	// npcName -> czas ostatniego widzenia w tagu 'GeraltsBFF'
	public var greetSeenNpc  : array<name>;
	public var greetSeenTime : array<float>;
	// npcName -> czas ostatniego powitania (cooldown 300s per NPC)
	public var greetDoneNpc  : array<name>;
	public var greetDoneTime : array<float>;

	public var isInit : bool;
	default isInit = false;

	public function Init()
	{
		if (isInit) return;
		isInit = true;
		GotoState('Idle');
	}

	// Globalny bark cooldown (~90s) – jeden bark na raz, nigdy spam
	public function GetBarkCooldownRemaining() : float
	{
		var left : float;
		left = 90.0 - (theGame.GetEngineTimeAsSeconds() - lastBarkTime);
		if (left < 0.0) left = 0.0;
		return left;
	}
}

state Idle in MCM_AmbientRomanceChannel
{
}

state AmbientTick in MCM_AmbientRomanceChannel
{
	event OnEnterState( prevStateName : name )
	{
		AmbientTickEntry();
	}

	entry function AmbientTickEntry()
	{
		ProcessAmbient();
	}

	// Ambient bark: lekki – bez locka gracza, bez zatrzymywania NPC.
	// Pomija NPC zajętą staged interakcją i te grające scenę/MCME-dialog.
	latent function ProcessAmbient()
	{
		var companions : array<CNewNPC>;
		var npc        : CNewNPC;
		var ctx        : MCM_RomanceContext;
		var core       : MCM_AutonomousRomanceCore;
		var i, idx, g  : int;
		var elig       : int;
		var executed   : bool;
		var safeReason : string;
		var now        : float;
		var gap        : float;
		var nam        : name;
		var dist       : float;
		var canBark    : bool;

		core = MCM_AR_GetCore();
		if (!core || !core.isInit || !parent.isInit)
		{
			parent.GotoState('Idle');
			return;
		}

		// Ta sama bramka bezpieczeństwa co staged (walka/dialog/pływanie/łódź)
		if (!core.MCM_AR_IsSafeToInitiate(safeReason))
		{
			parent.GotoState('Idle');
			return;
		}

		theGame.GetNPCsByTag('GeraltsBFF', companions);
		if (companions.Size() == 0)
		{
			parent.GotoState('Idle');
			return;
		}

		ctx = core.BuildContext(companions);
		core.ShuffleCompanions(companions);

		now = theGame.GetEngineTimeAsSeconds();

		// Globalny bark cooldown (~90s) bramkuje TYLKO strzal barku/powitania.
		// UWAGA: bookkeeping greetSeenTime musi biec CO TICK – wczesny return
		// na cooldown zamrozilby stemple i po ~90s kazdy obecny NPC mialby
		// gap>60s -> masa falszywych "powitan po absencji".
		canBark = (parent.GetBarkCooldownRemaining() <= 0.0);

		// ---------------------------------------------------------------
		// Powitanie po absencji: NPC wypadl z tagu 'GeraltsBFF' (despawn/
		// teleport) na >60s i wrocil w <10m -> greeting voiceset (w jej
		// glosie). Powitanie ZJADA turke barku (canBark=false+lastBarkTime),
		// ale petla DOKONCZUJE stemplowanie pozostalych (brak return).
		// Pierwsze zauwazenie w sesji nie strzela (baseline).
		// ---------------------------------------------------------------
		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc) continue;
			nam = npc.scmcc.data.nam;

			idx = parent.greetSeenNpc.FindFirst(nam);
			if (idx == -1)
			{
				// Baseline: pierwsze zauwazenie – zapamietaj bez powitania
				parent.greetSeenNpc.PushBack(nam);
				parent.greetSeenTime.PushBack(now);
				continue;
			}

			gap = now - parent.greetSeenTime[idx];
			parent.greetSeenTime[idx] = now;

			if (!canBark) continue;
			if (gap <= 60.0) continue;
			if (!npc.HasTag('mod_scm_IsFollowing')) continue;
			if (core.IsNpcBusy(npc)) continue;
			if (npc.IsInGameplayScene() || npc.IsSpeaking()) continue;

			dist = VecDistance(thePlayer.GetWorldPosition(), npc.GetWorldPosition());
			if (dist > 10.0) continue;

			// Cooldown powitania 300s per NPC
			g = parent.greetDoneNpc.FindFirst(nam);
			if (g != -1 && (now - parent.greetDoneTime[g]) < 300.0) continue;

			npc.EnableDynamicLookAt(thePlayer, 6.0);
			npc.PlayVoiceset(100, 'greeting_geralt');
			MCM_AR_Log("[AR] Powitanie po absencji " + RoundMath(gap) + "s: " + NameToString(nam));

			if (g == -1)
			{
				parent.greetDoneNpc.PushBack(nam);
				parent.greetDoneTime.PushBack(now);
			}
			else
			{
				parent.greetDoneTime[g] = now;
			}

			parent.lastBarkTime = now;
			canBark = false; // powitanie zjadlo turke barku – petla dalej stempluje
		}

		// Cooldown aktywny albo powitanie zjadlo turke – konczymy tick
		if (!canBark)
		{
			parent.GotoState('Idle');
			return;
		}

		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc) continue;

			// Nie zagłuszaj NPC w trakcie staged interakcji
			if (core.IsNpcBusy(npc)) continue;

			if (!npc.HasTag('mod_scm_IsFollowing')) continue;

			// NPC gra scenę albo właśnie mówi (np. dialog MCME)
			if (npc.IsInGameplayScene() || npc.IsSpeaking()) continue;

			executed = core.registry.TryExecute(npc, thePlayer, ctx, elig, true);
			if (executed)
			{
				parent.lastBarkTime = theGame.GetEngineTimeAsSeconds();
				break; // jeden bark na tick
			}
		}

		parent.GotoState('Idle');
	}
}

// ===========================================================================
//  Komendy Konsoli Deweloperskiej (Debug & Testing)
// ===========================================================================

exec function ar_status()
{
	var core       : MCM_AutonomousRomanceCore;
	var config     : MCM_AR_ConfigWrapper;
	var affinity   : MCM_RomanceAffinityResolver;
	var companions : array<CNewNPC>;
	var npc        : CNewNPC;
	var i          : int;
	var nam        : name;
	var score      : int;
	var gt         : GameTime;
	var h          : int;
	var safe       : bool;
	var safeReason : string;
	var campfire   : bool;
	var stateName  : string;

	// Markery diagnostyczne - jesli exec spowoduje CTD, scriptslog.txt
	// pokaze dokladnie ktory krok zabil gre (LogChannel flushuje na biezaco)
	LogChannel('MCM_AR', "[AR status] step1: get core");
	core = MCM_AR_GetCore();
	if (!thePlayer || !core)
	{
		LogChannel('MCM_AR', "[AR status] no player/core - abort");
		return;
	}
	LogChannel('MCM_AR', "[AR status] step2: get config/affinity");
	config = MCM_AR_GetConfig();
	affinity = MCM_AR_GetAffinity();
	if (!config || !affinity)
	{
		thePlayer.DisplayHudMessage("[AR] Config/Affinity niezainicjalizowane!");
		LogChannel('MCM_AR', "[AR status] no config/affinity - abort");
		return;
	}

	LogChannel('MCM_AR', "[AR status] step3: game time");
	gt = theGame.GetGameTime();
	h = GameTimeHours(gt) % 24;
	LogChannel('MCM_AR', "[AR status] step4: campfire");
	campfire = core.MCM_AR_IsNearCampfire();
	LogChannel('MCM_AR', "[AR status] step5: state name");
	stateName = NameToString(core.GetCurrentStateName());
	LogChannel('MCM_AR', "[AR status] step6: isSafe");
	safe = core.MCM_AR_IsSafeToInitiate(safeReason);
	LogChannel('MCM_AR', "[AR status] step7: hud messages");

	thePlayer.DisplayHudMessage("--- [AR STATUS] ---");
	thePlayer.DisplayHudMessage("Wlaczony: " + config.IsEnabled() + " | Sandbox: " + config.IsForceRomanceOn() + " | Zazdrosc: " + config.IsJealousyModeOn());
	thePlayer.DisplayHudMessage("Godzina: " + h + ":00 (Noc: " + (h >= 22 || h < 4) + ") | Ognisko: " + campfire + " | Stan: " + stateName);
	thePlayer.DisplayHudMessage("Bezpiecznie: " + safe + " (" + safeReason + ") | Cooldown: " + config.GetInitiativeCooldown() + "s");

	LogChannel('MCM_AR', "[AR status] step8: GetNPCsByTag");
	theGame.GetNPCsByTag('GeraltsBFF', companions);
	LogChannel('MCM_AR', "[AR status] step9: loop, n=" + companions.Size());
	thePlayer.DisplayHudMessage("Aktywni towarzysze: " + companions.Size());

	for (i = 0; i < companions.Size(); i += 1)
	{
		npc = companions[i];
		if (!npc || !npc.scmcc) continue;
		nam = npc.scmcc.data.nam;
		score = affinity.GetAffinity(nam);
		thePlayer.DisplayHudMessage("-> " + NameToString(nam) + " | Following: " + npc.HasTag('mod_scm_IsFollowing') + " | Zazylosc: " + score + " (Base: " + affinity.GetBaseStoryAffinity(nam) + ", Earned: " + affinity.GetEarnedAffinity(nam) + ")");
	}
	LogChannel('MCM_AR', "[AR status] step10: done");
}

exec function ar_reset()
{
	var core : MCM_AutonomousRomanceCore;
	core = MCM_AR_GetCore();
	if (core)
	{
		core.ResetAllCooldowns();
		thePlayer.DisplayHudMessage("[AR] Wszystkie cooldowny zostaly zresetowane (-9999s)!");
	}
}

exec function ar_force()
{
	var wrapper : CInGameConfigWrapper;
	var curVal  : string;
	wrapper = theGame.GetInGameConfigWrapper();
	if (wrapper)
	{
		curVal = wrapper.GetVarValue('MCM_AR', 'MCM_AR_ForceRomance');
		if (curVal == "1" || curVal == "true")
		{
			wrapper.SetVarValue('MCM_AR', 'MCM_AR_ForceRomance', "0");
			thePlayer.DisplayHudMessage("[AR] Sandbox/ForceRomance: WYLACZONY");
		}
		else
		{
			wrapper.SetVarValue('MCM_AR', 'MCM_AR_ForceRomance', "1");
			thePlayer.DisplayHudMessage("[AR] Sandbox/ForceRomance: WLACZONY (Wymogi zazylosci pominiete)");
		}
	}
}

exec function ar_affinity(npcStr : string, amount : int)
{
	var npc : CNewNPC;

	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc)
	{
		thePlayer.DisplayHudMessage("[AR] Bledna nazwa NPC lub brak w druzynie: " + npcStr);
		return;
	}
	MCM_AR_GetAffinity().AddAffinityPoints(npc.scmcc.data.nam, amount);
	thePlayer.DisplayHudMessage("[AR] Dodano +" + amount + " affinity dla " + npcStr + " (Lacznie: " + MCM_AR_GetAffinity().GetAffinity(npc.scmcc.data.nam) + ")");
}

exec function ar_trigger()
{
	var core : MCM_AutonomousRomanceCore;
	core = MCM_AR_GetCore();
	if (core)
	{
		core.ResetAllCooldowns();
		core.GotoState('ProcessingTick');
		thePlayer.DisplayHudMessage("[AR] Wymuszono natychmiastowy ProcessingTick!");
	}
}

// Dump ostatnich N linii diagnostyki (domyslnie 15) z ring buffera core
exec function ar_logdump(optional count : int)
{
	var core : MCM_AutonomousRomanceCore;
	var i    : int;
	var from : int;

	core = MCM_AR_GetCore();
	if (!core)
	{
		thePlayer.DisplayHudMessage("[AR] Core nie jest zainicjalizowany!");
		return;
	}
	if (count <= 0) count = 15;

	from = core.debugLog.Size() - count;
	if (from < 0) from = 0;
	thePlayer.DisplayHudMessage("=== AR LOGDUMP (ostatnie " + (core.debugLog.Size() - from) + " z " + core.debugLog.Size() + ") ===");
	for (i = from; i < core.debugLog.Size(); i += 1)
	{
		thePlayer.DisplayHudMessage(core.debugLog[i]);
	}
	if (core.debugLog.Size() == 0)
	{
		thePlayer.DisplayHudMessage("(pusty - wlacz ar_debug i poczekaj na ticki)");
	}
}

// Dump bootloga (linie zapisane zanim powstal core - glownie sciezka initu
// InitRemasterSettings). Niezalezne od scriptslog.txt - tylko HUD.
exec function ar_bootlog()
{
	var i : int;

	if (!thePlayer)
	{
		return;
	}
	thePlayer.DisplayHudMessage("=== AR BOOTLOG (" + thePlayer.mcm_ar_bootlog.Size() + ") ===");
	for (i = 0; i < thePlayer.mcm_ar_bootlog.Size(); i += 1)
	{
		thePlayer.DisplayHudMessage(thePlayer.mcm_ar_bootlog[i]);
	}
}

// Zapis markerow diagnostycznych do user.settings - kanal czytelny
// z dysku, gdy scriptslog.txt nie zapisuje po starcie. Po wykonaniu
// sprawdzamy sekcje [AR_Diag] i [MCM_AR] w user.settings.
exec function ar_diag()
{
	var wrapper : CInGameConfigWrapper;
	var core    : MCM_AutonomousRomanceCore;
	var i : int;

	MCM_AR_DiagMark(10);
	wrapper = theGame.GetInGameConfigWrapper();
	if (wrapper)
	{
		// Kanal gwarantowany: SetVarValue na istniejacym varze MCM na pewno
		// zapisuje sie do user.settings. Jednorazowo (tylko z ar_diag) -
		// przywracamy CooldownSlider recznie po sesji diagnostycznej.
		wrapper.SetVarValue('MCM_AR', 'MCM_AR_CooldownSlider', "70");
	}
	if (wrapper && thePlayer)
	{
		wrapper.SetRawConfigValueByStr("AR_Diag", "bootlog_size", "" + thePlayer.mcm_ar_bootlog.Size());
		for (i = 0; i < thePlayer.mcm_ar_bootlog.Size(); i += 1)
		{
			wrapper.SetRawConfigValueByStr("AR_Diag", "line" + i, thePlayer.mcm_ar_bootlog[i]);
		}

		// Ring buffer core (ticki, eval, trigger) - pelny dump do [AR_Diag]
		core = thePlayer.mcm_ar_core;
		if (core)
		{
			wrapper.SetRawConfigValueByStr("AR_Diag", "debuglog_size", "" + core.debugLog.Size());
			for (i = 0; i < core.debugLog.Size(); i += 1)
			{
				wrapper.SetRawConfigValueByStr("AR_Diag", "dbg" + i, core.debugLog[i]);
			}
		}
		else
		{
			wrapper.SetRawConfigValueByStr("AR_Diag", "debuglog_size", "-1");
		}
	}
	if (wrapper)
	{
		// Jeden flush na koncu - DiagMark/SetVarValue/SetRawConfigValue
		// tylko ustawiaja wartosci, zapis na dysk robimy raz.
		theGame.SaveUserSettings();
	}
	if (thePlayer)
	{
		thePlayer.DisplayHudMessage("[AR] diag marker zapisany do user.settings");
	}
}

// Audycja linii dialogowej na żywej towarzyszce: ar_line(yennefer, 420362)
// (konsola W3 nie parsuje parametru 'name' – przyjmujemy string i rzutujemy)
exec function ar_line(npcStr : string, lineID : int)
{
	var npc : CNewNPC;
	var txt : string;

	if (lineID <= 0)
	{
		thePlayer.DisplayHudMessage("[AR] Uzycie: ar_line(<npc>, <lineID>) np. ar_line(yennefer, 420362)");
		return;
	}

	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc)
	{
		thePlayer.DisplayHudMessage("[AR] Nie znaleziono towarzysza o nazwie: " + npcStr);
		return;
	}

	txt = GetLocStringById(lineID);
	npc.PlayLine(lineID, true);
	thePlayer.DisplayHudMessage("[AR] " + npcStr + ": \"" + txt + "\"");
}

// Sonda dostępności animacji na żywej towarzyszce: ar_probeanim(triss, woman_sit_stump_idle)
// true = animacja przyjęta przez slot; false = brak w animsecie NPC LUB slot
// zajęty (sondować, gdy NPC stoi w idle). Do audycji roostera, np. Salma
// (sukkubus) może nie mieć animów woman_* – patrz ARCHITECTURE §15.1.
exec function ar_probeanim(npcStr : string, animName : name)
{
	var npc    : CNewNPC;
	var played : bool;

	if (StrLen(npcStr) <= 0 || !IsNameValid(animName))
	{
		thePlayer.DisplayHudMessage("[AR] Uzycie: ar_probeanim(<npc>, <anim>) np. ar_probeanim(triss, woman_sit_stump_idle)");
		return;
	}

	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc)
	{
		thePlayer.DisplayHudMessage("[AR] Nie znaleziono towarzysza o nazwie: " + npcStr);
		return;
	}

	played = MCM_AR_ProbeAnim(npc, animName);
	MCM_AR_Log("[AR] ProbeAnim '" + NameToString(animName) + "' on " + NameToString(npc.scmcc.data.nam) + " -> " + played, true);
}

exec function ar_debug(optional mode : int)
{
	var on : bool;

	on = (FactsQuerySum('mcme_ar_debug') > 0);
	if (mode < 0 || mode > 1)
	{
		// ar_debug bez argumentu = toggle
		on = !on;
	}
	else
	{
		on = (mode == 1);
	}

	if (on)
	{
		FactsRemove('mcme_ar_debug');
		FactsAdd('mcme_ar_debug', 1);
		thePlayer.DisplayHudMessage("[AR] Debug ON - digest ticku co 4s na HUD. Wylaczenie: ar_debug(0). Analiza: ar_eval()");
	}
	else
	{
		FactsRemove('mcme_ar_debug');
		FactsAdd('mcme_ar_debug', 0);
		thePlayer.DisplayHudMessage("[AR] Debug OFF");
	}
}

// Pelny dry-run: dla kazdego towarzysza pokazuje affinity, cooldown
// oraz ktore akcje sa eligible / zablokowane - bez wykonywania czegokolwiek.
exec function ar_eval()
{
	var core       : MCM_AutonomousRomanceCore;
	var reg        : MCM_RomanceActionRegistry;
	var affinity   : MCM_RomanceAffinityResolver;
	var ctx        : MCM_RomanceContext;
	var companions : array<CNewNPC>;
	var npc        : CNewNPC;
	var act        : MCM_RomanceInteraction;
	var i, j       : int;
	var blocked    : int;
	var nam        : name;
	var eligStr    : string;
	var blockStr   : string;
	var safeReason : string;

	core = MCM_AR_GetCore();
	if (!core || !core.registry)
	{
		thePlayer.DisplayHudMessage("[AR eval] Core/registry niezainicjalizowane!");
		return;
	}
	reg = core.registry;
	affinity = MCM_AR_GetAffinity();

	theGame.GetNPCsByTag('GeraltsBFF', companions);
	ctx = core.BuildContext(companions);

	MCM_AR_Log("=== AR EVAL ===");
	MCM_AR_Log("h=" + ctx.hourOfDay + " noc=" + ctx.isNight + " ognisko=" + ctx.isNearCampfire + " tawerna=" + ctx.isInTavern + " corvo=" + ctx.isInCorvo + " rywalki=" + ctx.rivalCount + " naughty=" + ctx.isNearNaughtySpot);
	MCM_AR_Log("enabled=" + MCM_AR_GetConfig().IsEnabled() + " force=" + MCM_AR_GetConfig().IsForceRomanceOn() + " jealousy=" + MCM_AR_GetConfig().IsJealousyModeOn() + " consent=" + MCM_AR_GetConfig().RequiresPlayerConsent());

	core.MCM_AR_IsSafeToInitiate(safeReason);
	if (safeReason == "")
	{
		MCM_AR_Log("Bezpieczenstwo: OK");
	}
	else
	{
		MCM_AR_Log("Bezpieczenstwo: BLOKADA - " + safeReason);
	}

	MCM_AR_Log("Towarzysze: " + companions.Size() + " | Akcje w rejestrze: " + reg.GetActionCount());

	for (i = 0; i < companions.Size(); i += 1)
	{
		npc = companions[i];
		if (!npc || !npc.scmcc) continue;

		nam = npc.scmcc.data.nam;
		eligStr = "";
		blockStr = "";
		blocked = 0;

		for (j = 0; j < reg.GetActionCount(); j += 1)
		{
			act = reg.GetAction(j);
			if (!act) continue;
			if (IsNameValid(act.targetNpc) && act.targetNpc != nam) continue;

			if (act.CanExecute(npc, thePlayer, ctx))
			{
				eligStr += NameToString(act.id) + " ";
			}
			else
			{
				blocked += 1;
				blockStr += NameToString(act.id) + ":" + act.GetBlockReason(npc, thePlayer, ctx) + " ";
			}
		}

		MCM_AR_Log("-> " + NameToString(nam) +
			" | follow=" + npc.HasTag('mod_scm_IsFollowing') +
			" | aff=" + affinity.GetAffinity(nam) + "(b" + affinity.GetBaseStoryAffinity(nam) + "+e" + affinity.GetEarnedAffinity(nam) + ")" +
			" | cd=" + RoundMath(core.GetCooldownRemaining(nam)) + "s");
		MCM_AR_Log("   eligible: " + eligStr + "(blocked: " + blocked + ")");
		if (blockStr != "")
		{
			MCM_AR_Log("   blocked: " + blockStr);
		}
	}
}

