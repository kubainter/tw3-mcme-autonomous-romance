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

// Bufor komunikatów diagnostycznych przed inicjalizacją obiektu core.
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

	theInput.RegisterListener(this, 'OnMCM_AR_ConsentKey', 'MCM_AR_Consent');
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
		MCM_AR_Log("thePlayer OK, Core initialized!", true);
	}
	else
	{
		MCM_AR_Log("thePlayer == NULL", true);
	}
}

// Marker diagnostyczny sekcji [AR_Diag] (aktywny w trybie ar_debug).
function MCM_AR_DiagMark(code : int)
{
	var wrapper : CInGameConfigWrapper;

	if (!MCM_AR_IsDebugOn())
	{
		return;
	}

	wrapper = theGame.GetInGameConfigWrapper();
	if (wrapper)
	{
		wrapper.SetRawConfigValueByStr("AR_Diag", "last", "" + code);
		wrapper.SetRawConfigValueByStr("AR_Diag", "t" + code, "" + RoundMath(theGame.GetEngineTimeAsSeconds()));
	}
	// Zapis synchroniczny tylko w trybie diagnostycznym (ar_debug).
	theGame.SaveUserSettings();
}

// Inicjalizacja moda w cyklu OnSpawned gracza.
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

// Sonda inicjalizacji wejścia gracza (CPlayerInput).
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
	// Interwał timera decyzyjnego z konfiguracji MCM (domyślnie 30s).
	AddTimer('MCM_AR_AutonomousTick', MCM_AR_GetConfig().GetTickIntervalSeconds(), true);
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
	// Szybki timer ambientu (~10s) do aktualizacji póz postoju.
	if (mcm_ar_core)
	{
		mcm_ar_core.UpdateIdleAmbient();
	}
	if (mcm_ar_ambient && mcm_ar_ambient.GetCurrentStateName() == 'Idle')
	{
		mcm_ar_ambient.GotoState('AmbientTick');
	}
}

// ---------------------------------------------------------------------------
// Klasa główna – silnik decyzyjny
// ---------------------------------------------------------------------------

// Zadanie postoju: faza 0=ruch ku pozycji, faza 1=animacja postoju w slocie.
class MCM_AR_IdleJob
{
	var npc       : CNewNPC;
	var spot      : Vector;
	var heading   : float;
	var anim      : name;
	var phase     : int;
	var deadline  : float;
	// Losowe opoznienie pozy (0-10s) - rozrzuca moment "siadania"
	// miedzy NPC, unikajac efektu "flash mob".
	var poseDelay : float;
}

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

	public var lastSceneOkNpc  : name;
	private var missingVoicesetNpcs : array<name>;

	public function MCM_AR_IsVoicesetMissing(npcNam : name) : bool
	{
		return missingVoicesetNpcs.Contains(npcNam);
	}

	public function MCM_AR_MarkVoicesetMissing(npcNam : name)
	{
		if (!missingVoicesetNpcs.Contains(npcNam))
		{
			missingVoicesetNpcs.PushBack(npcNam);
		}
	}
	public var lastSceneOkTime : float;
	default lastSceneOkTime = -9999.0;

	// Pasywny przyrost Affinity ze wspólnej podróży:
	// Co 600s (~10 min) aktywnego podążania za Geraltem -> +1 Affinity
	private var arTravelNpcNames : array<name>;
	private var arTravelSeconds  : array<float>;
	private var arLastTravelTime : float;
	default arLastTravelTime     = -9999.0;

	// W2/I1 idle-suspend: companion "zyje" gdy gracz stoi w miejscu.
	// Detektor postoju (kotwica + czas ostatniego ruchu) i lista NPC
	// zawieszonych przez nas (StopFollowing(true) - tag/flaga zostaja).
	private var arIdleAnchor : Vector;
	private var arIdleSince  : float;
	private var arIdleJobs   : array<MCM_AR_IdleJob>;
	default arIdleSince = -9999.0;

	// Zawieszenie podążania towarzyszki na czas postoju gracza.
	// Wybudzenie następuje po ruchu gracza (>1.5m) lub wejściu w stan unsafe.
	private function WakeIdleJobs()
	{
		var i     : int;
		var npc   : CNewNPC;
		var nowT  : float;
		var woken : int;
		var kept  : int;

		if (arIdleJobs.Size() <= 0) return;

		nowT = theGame.GetEngineTimeAsSeconds();
		for (i = arIdleJobs.Size() - 1; i >= 0; i -= 1)
		{
			npc = arIdleJobs[i].npc;
			// NPC w trakcie interakcji lub sceny - lokomocję przywraca EndInteraction.
			if (npc && (npc.wasInTalkInteraction || npc.IsInGameplayScene() || npc == busyNpc))
			{
				if (nowT >= arIdleJobs[i].deadline)
				{
					arIdleJobs.Erase(i);
				}
				else
				{
					kept += 1;
				}
				continue;
			}
			arIdleJobs.Erase(i);
			woken += 1;
			if (npc && npc.scmcc)
			{
				// CancelAll zdejmuje slot-anime/move zanim lokomocja
				// przejmie kontrole (inaczej NPC "sunalby" w idle-pose).
				npc.ActionCancelAll();
				npc.scmcc.StartFollowing(true);
			}
		}
		MCM_AR_Log("[AR] idle: waking " + woken + " NPCs (busyKept=" + kept + ")");
	}

	// Usuwa rekord postoju dla danego NPC bez modyfikacji lokomocji.
	public function RemoveIdleJobFor(npc : CNewNPC)
	{
		var i : int;
		if (!npc) return;
		for (i = arIdleJobs.Size() - 1; i >= 0; i -= 1)
		{
			if (arIdleJobs[i].npc == npc)
			{
				arIdleJobs.Erase(i);
			}
		}
	}

	// Cykl ambient (~10s): wykrywa ruch gracza i aktualizuje fazy postoju.
	public function UpdateIdleAmbient()
	{
		var i          : int;
		var job        : MCM_AR_IdleJob;
		var nowT       : float;
		var playerPos  : Vector;
		var dist       : float;
		var slotOk     : bool;
		var safeReason : string;

		if (!isInit) return;

		nowT      = theGame.GetEngineTimeAsSeconds();
		playerPos = thePlayer.GetWorldPosition();

		// Koniec postoju: gracz ruszyl z kotwicy albo kontekst niebezpieczny.
		if (!MCM_AR_IsSafeToInitiate(safeReason) || VecDistance(playerPos, arIdleAnchor) > 1.5)
		{
			arIdleAnchor = playerPos;
			arIdleSince  = nowT;
			WakeIdleJobs();
			return;
		}

		// Joby aktywne: tick faz moving->posed + prune martwych wpisow.
		if (arIdleJobs.Size() > 0)
		{
			for (i = arIdleJobs.Size() - 1; i >= 0; i -= 1)
			{
				job = arIdleJobs[i];
				if (!job.npc || !job.npc.scmcc)
				{
					arIdleJobs.Erase(i);
					continue;
				}
				if (job.phase == 2) continue;
				// NPC w scenie nie otrzymuje pozy postoju.
				if (job.npc.wasInTalkInteraction || job.npc.IsInGameplayScene() || job.npc == busyNpc)
				{
					if (nowT >= job.deadline)
					{
						arIdleJobs.Erase(i);
						MCM_AR_Log("[AR] idle: pruned stale job " + NameToString(job.npc.scmcc.data.nam));
					}
					continue;
				}
				dist = VecDistance2D(job.npc.GetWorldPosition(), job.spot);
				if (dist <= 0.7 || nowT >= job.deadline)
				{
					if (job.phase == 0)
					{
						job.phase = 1;
						// CancelAll tylko przy timeout - gdy dojscie zakonczylo
						// sie naturalnie mover juz wszedl w idle.
						if (dist > 0.7) job.npc.ActionCancelAll();
					}
					// Rozrzut czasowy: nie wszyscy "siadaja" w tym samym
					// momencie - poseDelay losuje 0-10s per NPC.
					if (nowT >= job.poseDelay)
					{
						job.phase = 2;
						slotOk = PlayIdleSlotAnim(job.npc, job.anim);
						if (!slotOk)
						{
							// Nazwa z puli nie przeszla w slocie (brak w animsecie
							// lub slot zajety) - fallback na sprawdzona poza.
							slotOk = PlayIdleSlotAnim(job.npc, 'low_sitting_ground_leaning_back_bored_idle');
							MCM_AR_Log("[AR] idle: " + NameToString(job.npc.scmcc.data.nam) +
							           " FALLBACK anim=" + NameToString(job.anim) +
							           " slotAnim=" + slotOk);
						}
						else
						{
							MCM_AR_Log("[AR] idle: " + NameToString(job.npc.scmcc.data.nam) +
							           " posed, anim=" + NameToString(job.anim) +
							           " slotAnim=" + slotOk +
							           " (dist=" + dist + ")");
						}
					}
				}
			}
		}
	}

	public function UpdateIdleSuspend(safe : bool)
	{
		var i          : int;
		var j          : int;
		var npc        : CNewNPC;
		var job        : MCM_AR_IdleJob;
		var nowT       : float;
		var playerPos  : Vector;
		var companions : array<CNewNPC>;
		var dist       : float;
		var away       : Vector;
		var suspendedThisTick : int;
		var hasJob     : bool;
		var skipNoTag  : int;
		var skipFar    : int;
		var skipBusy   : int;
		var skipDelay  : int;
		var skipNull   : int;

		nowT      = theGame.GetEngineTimeAsSeconds();
		playerPos = thePlayer.GetWorldPosition();

		// Koniec postoju: gracz ruszyl z kotwicy albo kontekst niebezpieczny.
		// (Bezpiecznik - ten sam check robi UpdateIdleAmbient co ~10s.)
		if (!safe || VecDistance(playerPos, arIdleAnchor) > 1.5)
		{
			arIdleAnchor = playerPos;
			arIdleSince  = nowT;
			WakeIdleJobs();
			return;
		}

		// Prog postoju 50s - za krotko, czekamy.
		if (nowT - arIdleSince < 50.0) return;

		// (Fazy jobow moving->posed: UpdateIdleAmbient na timerze ~10s.)

		// Staged interakcja w toku - nie zawieszaj w trakcie podejscia/sceny.
		if (IsStagedBusy()) return;

		theGame.GetNPCsByTag('GeraltsBFF', companions);
		// Per-NPC logi skip zastapione licznikami - przy ~40 companions
		// seria skipow (gl. no-follow) zalewala log co tick (spam).
		suspendedThisTick = 0;
		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc)
			{
				skipNull += 1;
				continue;
			}
			if (!npc.HasTag('mod_scm_IsFollowing'))
			{
				skipNoTag += 1;
				continue;
			}
			dist = VecDistance(npc.GetWorldPosition(), playerPos);
			if (dist > 15.0)
			{
				skipFar += 1;
				continue;
			}
			// NPC w stagingu/scenie/dialogu - job utworzony teraz bylby
			// wiecznie guarded (ambient+wake go omijaja, hasJob blokuje nowy).
			if (npc.wasInTalkInteraction || npc.IsInGameplayScene() || npc == busyNpc)
			{
				skipBusy += 1;
				continue;
			}
			// Losowa szansa na "teraz" (70%) lub "poczekaj kolejny tick"
			if (RandRange(100, 0) >= 70 && suspendedThisTick > 0)
			{
				skipDelay += 1;
				continue;
			}
			if (suspendedThisTick >= 2)
			{
				skipDelay += 1;
				continue;
			}
			// Guard: nie duplikuj jobow dla tego samego NPC
			hasJob = false;
			for (j = 0; j < arIdleJobs.Size(); j += 1)
			{
				if (arIdleJobs[j].npc == npc)
				{
					hasJob = true;
					break;
				}
			}
			if (hasJob) continue;

			npc.scmcc.StopFollowing(true);
			suspendedThisTick += 1;

			job = new MCM_AR_IdleJob in this;
			job.npc  = npc;
			job.anim = IdleAnimFor(npc.scmcc.data.nam);
			// Wyznaczenie pozycji odpoczynku w odległości ~1.6m.
			away = npc.GetWorldPosition() - playerPos;
			away.Z = 0;
			if (VecLength(away) < 0.5) away = VecFromHeading(thePlayer.GetHeading() + 180.0);
			job.spot    = npc.GetWorldPosition() + VecNormalize(away) * 1.6;
			job.heading = VecHeading(playerPos - job.spot);
			job.phase   = 0;
			// Losowy deadline (spacer 6-12s) i poseDelay (0-10s) - rozrzut
			// czasowy miedzy towarzyszami unikajac synchronicznego "siadania".
			job.deadline  = nowT + 6.0 + RandRange(60, 0) / 10.0;
			job.poseDelay = nowT + RandRange(100, 0) / 10.0;
			// Juz daleko od gracza - bez spaceru, prosto w poze (ale z delay).
			if (VecDistance2D(npc.GetWorldPosition(), job.spot) < 0.9)
			{
				job.phase = 1;
				MCM_AR_Log("[AR] idle: " + NameToString(npc.scmcc.data.nam) +
				           " in-place, delay=" + (int)(job.poseDelay - nowT) + "s");
			}
			else
			{
				npc.ActionMoveToWithHeadingAsync(job.spot, job.heading);
			}
			arIdleJobs.PushBack(job);
		}
		MCM_AR_Log("[AR] idle: t=" + (int)(nowT - arIdleSince) + "s jobs=" + arIdleJobs.Size() +
		           "/" + companions.Size() + " susp=" + suspendedThisTick +
		           " skip{noFollow=" + skipNoTag + ",far=" + skipFar + ",busy=" + skipBusy +
		           ",delay=" + skipDelay + ",null=" + skipNull + "}");
	}

	// -----------------------------------------------------------------------
	// Pasywny przyrost Affinity z czasu podróży:
	// Towarzyszki podążające za Geraltem (mod_scm_IsFollowing, dist <= 25m)
	// zyskują +1 Affinity za każde 600s (~10 min) aktywnego marszu/biegu.
	// Ignoruje postoje (idle-suspend) oraz skoki czasu (load/medytacja).
	// -----------------------------------------------------------------------
	public function UpdatePassiveTravelAffinity(companions : array<CNewNPC>)
	{
		var i, j, idx : int;
		var npc       : CNewNPC;
		var nam       : name;
		var nowT      : float;
		var dt        : float;
		var dist      : float;
		var playerPos : Vector;

		nowT = theGame.GetEngineTimeAsSeconds();
		if (arLastTravelTime < 0.0)
		{
			arLastTravelTime = nowT;
			return;
		}

		dt = nowT - arLastTravelTime;
		arLastTravelTime = nowT;

		// Odrzuc anomalie czasowe (np. wczytanie save'a, pauza w menu, medytacja)
		if (dt <= 0.0 || dt > 180.0)
		{
			return;
		}

		// Gracz stoi w miejscu (idle-suspend) – nie naliczaj za bezczynny afk
		if (GetIdleSuspendCount() > 0)
		{
			return;
		}

		playerPos = thePlayer.GetWorldPosition();

		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc || !npc.scmcc.data) continue;
			if (!npc.HasTag('mod_scm_IsFollowing')) continue;

			nam = npc.scmcc.data.nam;
			if (!MCM_AR_IsRomanceNPC(nam)) continue;

			dist = VecDistance(npc.GetWorldPosition(), playerPos);
			if (dist > 25.0) continue;

			idx = -1;
			for (j = 0; j < arTravelNpcNames.Size(); j += 1)
			{
				if (arTravelNpcNames[j] == nam)
				{
					idx = j;
					break;
				}
			}

			if (idx < 0)
			{
				arTravelNpcNames.PushBack(nam);
				arTravelSeconds.PushBack(0.0);
				idx = arTravelNpcNames.Size() - 1;
			}

			arTravelSeconds[idx] += dt;

			// Co 600s (~10 minut) aktywnej drogi: +1 Affinity
			if (arTravelSeconds[idx] >= 600.0)
			{
				arTravelSeconds[idx] = 0.0;
				if (registry && registry.affinity)
				{
					registry.affinity.AddAffinityPoints(nam, 1);
					thePlayer.DisplayHudMessage("[AR] " + AR_Fmt(AR_T("ar_msg_travel_aff", "Your bond with {1} grows through journey (+1)"), MCM_AR_GetCompanionDisplayName(npc)));
					MCM_AR_Log("[AR] Travel affinity +1 for " + NameToString(nam));
				}
			}
		}
	}

	// Odtworzenie animacji postoju przez CMovingPhysicalAgentComponent.
	private function PlayIdleSlotAnim(npc : CNewNPC, anim : name) : bool
	{
		var animComp : CMovingPhysicalAgentComponent;
		var settings : SAnimatedComponentSlotAnimationSettings;

		if (!npc || !IsNameValid(anim)) return false;
		animComp = (CMovingPhysicalAgentComponent)npc.GetComponentByClassName('CMovingPhysicalAgentComponent');
		if (!animComp) return false;
		settings.blendIn  = 1.2;
		settings.blendOut = 0.8;
		if (animComp.PlaySlotAnimationAsync(anim, 'NPC_ANIM_SLOT', settings)) return true;
		return animComp.PlaySlotAnimationAsync(anim, 'GAMEPLAY_SLOT', settings);
	}

	// Ilu towarzyszow jest obecnie zawieszonych (digest debug).
	public function GetIdleSuspendCount() : int
	{
		return arIdleJobs.Size();
	}

	// Dobór animacji postoju dopasowanej do postaci (pozy na ziemi bez rekwizytów).
	private function IdleAnimFor(nam : name) : name
	{
		var pool : array<name>;
		pool = IdleAnimPool();
		return pool[RandRange(pool.Size(), 0)];
	}

	// Pula animacji odpoczynku na ziemi do losowego wyboru.
	private function IdleAnimPool() : array<name>
	{
		var pool : array<name>;
		pool.PushBack('low_sitting_ground_leaning_back_bored_idle');
		pool.PushBack('low_sitting_ground_happy_idle');
		pool.PushBack('high_sitting_ground_determined_idle');
		pool.PushBack('woman_work_sitting_on_ground_loop');
		pool.PushBack('woman_noble_lying_relaxed_on_grass_loop_01');
		pool.PushBack('woman_work_standing_in_a_cold_fire_loop');
		pool.PushBack('woman_crouch_loop_3');
		return pool;
	}

	// Guard w wake-loop: NPC w stagingu/scenie zostaje w arIdleJobs i jest pomijana,
	// co zabezpiecza przed przerwaniem stanu przez latent-abort.

	// Wymusza suspend przy nastepnym ticku (debug - bez czekania 50s).
	// Respektuje safe/dystans/tagi; do sondy w parze z ar_diag.
	public function ForceIdleSuspendNow()
	{
		arIdleAnchor = thePlayer.GetWorldPosition();
		arIdleSince = theGame.GetEngineTimeAsSeconds() - 60.0;
		MCM_AR_Log("[AR] idle: threshold forced (ar_idlenow) - suspend on next tick");
	}

	// Automatyczny wybór opcji w scenach FollowWithKiss (faza 0=kiss, faza 1=exit).
	public var arAutoPick       : bool;
	public var arPickPhase      : int;
	public var arPendingPickIdx : int;
	public var arPendingPickAt  : float;
	default arAutoPick       = false;
	default arPickPhase      = 0;
	default arPendingPickIdx = -1;
	default arPendingPickAt  = 0.0;

	public var debugForceAction : name;
	public var debugForceTarget : name;
	default debugForceAction = '';
	default debugForceTarget = '';

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

	// Oblicza indeks opcji do natychmiastowego auto-picku (faza 0=kiss, faza 1=exit).
	public function MCM_AR_ResolveAutoPickIdx(choices : array<SSceneChoice>) : int
	{
		var i, idx : int;
		var desc : string;

		idx = -1;
		if (arPickPhase == 0)
		{
			// Wybór opcji romansu (indeks 1 w szablonie menu).
			if (choices.Size() >= 3 &&
			    choices[choices.Size() - 1].dialogAction == DialogAction_EXIT &&
			    choices[1].dialogAction != DialogAction_EXIT && !choices[1].disabled)
			{
				idx = 1;
			}
			// Fallback dopasowania opcji po słowach kluczowych dialogu.
			if (idx < 0)
			{
				for (i = 0; i < choices.Size(); i += 1)
				{
					if (choices[i].disabled) continue;
					desc = StrLower(choices[i].description);
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
				MCM_AR_Log("[AR] autoPick: no kiss/romance option - choice stays manual");
				arAutoPick = false;
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
			if (idx >= 0)
			{
				arAutoPick = false;
				arPickPhase = 0;
			}
			else
			{
				MCM_AR_Log("[AR] autoPick: no exit option after kiss - choice stays manual");
				arAutoPick = false;
			}
		}
		return idx;
	}

	// Rejestruje oczekujący wybór dialogowy podczas uzbrojonej sceny (arAutoPick).
	public function MCM_AR_OnDialogChoices(choices : array<SSceneChoice>)
	{
		var i, idx : int;

		MCM_AR_Log("[AR] OnDialogChoices entry: n=" + choices.Size() +
		           " autoPick=" + arAutoPick + " phase=" + arPickPhase);
		if (!arAutoPick || arPendingPickIdx >= 0) return;

		for (i = 0; i < choices.Size(); i += 1)
		{
			MCM_AR_Log("[AR] dlg choice[" + i + "] '" + choices[i].description +
			           "' act=" + (int)choices[i].dialogAction +
			           " emph=" + choices[i].emphasised +
			           " seen=" + choices[i].previouslyChoosen);
		}

		idx = MCM_AR_ResolveAutoPickIdx(choices);
		if (idx >= 0)
		{
			arPendingPickIdx = idx;
			arPendingPickAt  = theGame.GetEngineTimeAsSeconds();
			MCM_AR_Log("[AR] autoPick -> opcja " + idx + " '" + choices[idx].description + "'");
		}
	}

	public function Init()
	{
		MCM_AR_Log("Init entered, isInit=" + isInit);
		if (isInit) return;
		isInit = true;

		registry = new MCM_RomanceActionRegistry in this;
		registry.Init();

		GotoState('Idle');

		MCM_AR_Log("AutonomousRomanceCore initialized.");
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
		arTravelNpcNames.Clear();
		arTravelSeconds.Clear();
		arLastTravelTime = -9999.0;

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
			reason = "player state=" + thePlayer.GetCurrentStateName() + " (req. Exploration)";
			return false;
		}
		// Blokada w menu oraz radial menu (wymagany kontekst Exploration).
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
		// DialogueManager.IsBusy jest sprawdzany dedykowanie w PlayScene.
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

	public function MCM_AR_IsSafeForAmbient(optional out reason : string) : bool
	{
		var st  : name;
		var ict : name;

		st = thePlayer.GetCurrentStateName();
		if (st != 'Exploration' && st != 'HorseRiding' && st != 'Sailing' && st != 'BoatPassenger')
		{
			reason = "player state=" + st + " (req. Exploration|HorseRiding|Sailing|BoatPassenger)";
			return false;
		}
		ict = theInput.GetContext();
		if (ict != 'Exploration' && ict != 'Horse' && ict != 'Boat')
		{
			reason = "inputContext=" + NameToString(ict);
			return false;
		}
		if (thePlayer.IsInCombat())
		{
			reason = "IsInCombat";
			return false;
		}
		if (theGame.IsDialogOrCutscenePlaying())
		{
			reason = "DialogOrCutscenePlaying";
			return false;
		}
		if (thePlayer.IsSwimming())
		{
			reason = "IsSwimming";
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

		// Kontekstowe T1: pogoda silnikowa + pojazd + wnętrze
		cachedContext.weatherName  = GetWeatherConditionName();
		cachedContext.playerOnBoat = thePlayer.IsOnBoat();
		cachedContext.playerMounted = (thePlayer.GetUsedVehicle() && !cachedContext.playerOnBoat);
		cachedContext.isInInterior = thePlayer.IsInInterior();

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

		// Romansowalne towarzyszki AKTYWNIE podazajace (mod_scm_IsFollowing):
		// zaparkowana lub spawnana ale nie-followujaca NPC (np. Ves) jest
		// skipowana przy wykonywaniu akcji (tick), wiec nie moze tez brac
		// udzialu w zazdrosci ani odpalac notifiera naughty.
		rivalCount = 0;
		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc) continue;
			if (!npc.HasTag('mod_scm_IsFollowing')) continue;
			if (MCM_AR_IsRomanceNPC(npc.scmcc.data.nam))
			{
				cachedContext.companionsInParty.PushBack(npc.scmcc.data.nam);
				rivalCount += 1;
			}
		}
		cachedContext.rivalCount = rivalCount;
		// Rywalizacja: kanoniczny trójkąt Yennefer vs Triss.
		cachedContext.hasRivals  = cachedContext.companionsInParty.Contains('yennefer') &&
		                           cachedContext.companionsInParty.Contains('triss');

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

		// Watchdog: uwalnia przedawniony lock interakcji (>300s).
		if (interactionBusy && now - busyStartTime > 300.0)
		{
			if (busyNpc && busyNpc.scmcc)
			{
				MCM_AR_Log("[AR] Watchdog: interactionBusy martwy (" + IntToString(RoundMath(now - busyStartTime)) +
				           "s, npc=" + NameToString(busyNpc.scmcc.data.nam) + ") - forced release");
			}
			else
			{
				MCM_AR_Log("[AR] Watchdog: interactionBusy martwy (" + IntToString(RoundMath(now - busyStartTime)) +
				           "s) - forced release");
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

	// Awaryjny reset stanu RUNTIME (nie cooldownow/affinity): po
	// TW3SE_ReloadScripts (latent-loope umieraja bez cleanupu) lub gdy
	// latent-abort zostawil osierocony lock / zawieszonego NPC.
	public function ForceResetRuntimeState()
	{
		var i   : int;
		var npc : CNewNPC;

		// Wbudz idle-suspend (ta sama sekwencja co UpdateIdleSuspend resume).
		for (i = arIdleJobs.Size() - 1; i >= 0; i -= 1)
		{
			npc = arIdleJobs[i].npc;
			arIdleJobs.Erase(i);
			if (npc && npc.scmcc)
			{
				npc.ActionCancelAll();
				npc.scmcc.StartFollowing(true);
			}
		}
		// Zwolnij NPC po przerwanej interakcji (lustro EndInteraction).
		// busyNpc to towarzyszka w stagingu -> scena mogla zdjac follow
		// calkowicie (toggle_follow) - restore dwutorowo jak w
		// EndInteraction, inaczej zostalaby zaparkowana.
		if (busyNpc)
		{
			busyNpc.DisableLookAt();
			busyNpc.EnableCharacterCollisions(true);
			busyNpc.wasInTalkInteraction = false;
			if (busyNpc.scmcc)
			{
				if (busyNpc.scmcc.IsFollowing())
				{
					busyNpc.scmcc.StartFollowing(true);
				}
				else
				{
					busyNpc.scmcc.StartFollowing();
				}
			}
		}
		if (thePlayer)
		{
			thePlayer.UnblockAction(EIAB_Movement, 'MCM_AR_interaction');
			thePlayer.DisableLookAt();
		}
		interactionBusy = false;
		busyNpc = NULL;
		busyStartTime = -9999.0;
		arAutoPick = false;
		arPickPhase = 0;
		arPendingPickIdx = -1;
		GotoState('Idle');
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

		// Ogniska: tag 'campfire' lub silnikowy 'CarriesOpenFire' (palone light entities)
		theGame.GetEntitiesByTag('campfire', entities);
		for (i = 0; i < entities.Size(); i += 1)
		{
			dist = VecDistance(thePlayer.GetWorldPosition(), entities[i].GetWorldPosition());
			if (dist < 6.0) return true;
		}

		entities.Clear();
		theGame.GetEntitiesByTag(theGame.params.TAG_OPEN_FIRE, entities);
		for (i = 0; i < entities.Size(); i += 1)
		{
			if ((CActor)entities[i]) continue;
			dist = VecDistance(thePlayer.GetWorldPosition(), entities[i].GetWorldPosition());
			if (dist < 6.0) return true;
		}
		return false;
	}

	public function MCM_AR_IsInTavern() : bool
	{
		// 1. Vanilla fact 'player_in_inn' - ustawiany przez trigger-area gospod,
		//    ale NIE pokrywa wszystkich tawern (np. Kameleon Jaskra, czesc lokacji questowych).
		if (FactsQuerySum('player_in_inn') > 0) return true;
		// 2. Fallback: wnetrze + encja karczmarza/barmaidki w poblizu.
		//    Karczmarze istnieja tylko w tawernach, wiec interior+innkeeper ~zero false-positive.
		if (!thePlayer.IsInInterior()) return false;
		return MCM_AR_IsInnkeeperNearby();
	}

	// Skan encji w promieniu 15m: tagi karczmarza lub sciezka szablonu w2ent
	// (np. gameplay/community/shops_and_craftsmen/.../fat_catch_inn/..., *_innkeeper.w2ent).
	private function MCM_AR_IsInnkeeperNearby() : bool
	{
		var entities : array<CGameplayEntity>;
		var ent      : CGameplayEntity;
		var entStr   : string;
		var i        : int;

		FindGameplayEntitiesInRange(entities, thePlayer, 15.0, 60);
		for (i = 0; i < entities.Size(); i += 1)
		{
			ent = entities[i];
			if (!ent || ent == (CGameplayEntity)thePlayer) continue;
			if (ent.HasTag('innkeep') || ent.HasTag('innkeeper') || ent.HasTag('barkeep')
				|| ent.HasTag('barmaid') || ent.HasTag('bartender') || ent.HasTag('tavern_keeper')
				|| ent.HasTag('tavernkeeper') || ent.HasTag('tavern'))
			{
				return true;
			}
			entStr = StrLower("" + ent);
			if (StrContains(entStr, "innkeep") || StrContains(entStr, "innkeeper")
				|| StrContains(entStr, "barkeep") || StrContains(entStr, "barmaid")
				|| StrContains(entStr, "inn\\") || StrContains(entStr, "inn/")
				|| StrContains(entStr, "inns\\") || StrContains(entStr, "inns/"))
			{
				return true;
			}
		}
		return false;
	}

	private function MCM_AR_IsRomanceNPC(npcName : name) : bool
	{
		switch(npcName)
		{
			case 'yennefer':
			case 'triss':
			case 'keira_metz':
			case 'keira':
			case 'shani':
			case 'anna_henrietta':
			case 'sq701_vivienne':
			case 'vivienne':
			case 'becca':
			case 'cerys':
			case 'philippa_eilhart':
			case 'philippa':
			case 'filippa':
			case 'syanna':
			case 'mh303_succbus_v2':
			case 'salma':
			case 'ves':
			case 'rosa_var_attre':
			case 'rosa':
			case 'prologue_village_herbalist':
			case 'tomira':
			case 'cirilla':
			case 'ciri':
			case 'pryscilla':
			case 'priscilla':
			case 'edna_var_attre':
			case 'edna':
			case 'fringilla_vigo':
			case 'fringilla':
			case 'margaritta':
			case 'margarita':
			case 'vampire_diva':
			case 'oriana':
			case 'orianna':
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
	// Główny tick (wywoływany cyklicznie przez timer CR4Player za pomocą stanu)
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
			parent.UpdateIdleSuspend(false);
			parent.GotoState('Idle');
			return;
		}

		// Pobierz listę aktywnych towarzyszy MCME
		theGame.GetNPCsByTag('GeraltsBFF', companions);
		if (companions.Size() == 0)
		{
			if (dbg) MCM_AR_Log("[AR tick] no companions (tag 'GeraltsBFF' empty)");
			parent.GotoState('Idle');
			return;
		}

		// Buduj kontekst globalny raz na tick
		ctx = parent.BuildContext(companions);

		// Wymuszenie konkretnej akcji z konsoli (np. ar_kiss)
		if (parent.debugForceAction != '')
		{
			for (i = 0; i < companions.Size(); i += 1)
			{
				npc = companions[i];
				if (npc && npc.scmcc && npc.scmcc.data && npc.scmcc.data.nam == parent.debugForceTarget)
				{
					parent.registry.TryExecuteSpecificAction(parent.debugForceAction, npc, thePlayer, ctx);
					break;
				}
			}
			parent.debugForceAction = '';
			parent.debugForceTarget = '';
			parent.GotoState('Idle');
			return;
		}

		// W2/I1 idle-suspend: przy postoju gracza ~50s followerzy
		// przestaja chodzic za Geralta i graja swoja idle-anim;
		// wznowienie przy ruchu gracza albo unsafe.
		parent.UpdateIdleSuspend(true);

		// Pasywny przyrost Affinity za czas wspólnej aktywnej podróży
		parent.UpdatePassiveTravelAffinity(companions);

		// Notifier "sweet spot": jednorazowy HUD przy wejściu w zasięg punktu
		// intymnego, reset dopiero po wyjściu >40m (histereza anti-flap).
		if (ctx.isNearNaughtySpot)
		{
			if (!parent.naughtySpotNotified && ctx.companionsInParty.Size() > 0)
			{
				parent.naughtySpotNotified = true;
				thePlayer.DisplayHudMessage("[AR] " + AR_T("ar_msg_naughty_near", "The mood is right for intimacy..."));
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
			if (parent.GetIdleSuspendCount() > 0)
			{
				digest += " idle=" + parent.GetIdleSuspendCount();
			}
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
		var barkPreset : int;
		var barkChance : int;
		var hasTimeCritical : bool;

		core = MCM_AR_GetCore();
		if (!core || !core.isInit || !parent.isInit)
		{
			parent.GotoState('Idle');
			return;
		}

		// Bramka ambient: jak staged, ale dopuszcza jazdę konną
		// (barki T1 mogą lecieć w marszu; łódź/walka/dialog nadal blok)
		if (!core.MCM_AR_IsSafeForAmbient(safeReason))
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

		// Akcje okienkowe (isTimeCritical): wyprzedzaja zwykle barki i omijaja
		// los presetu gadatliwosci – bez tego ich okno czasowe wygasa bez strzalu.
		// Filtry te same co petla barkow nizej (busy/follow/scene/speaking).
		hasTimeCritical = false;
		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc) continue;
			if (core.IsNpcBusy(npc)) continue;
			if (!npc.HasTag('mod_scm_IsFollowing')) continue;
			if (npc.IsInGameplayScene() || npc.IsSpeaking()) continue;
			if (core.registry.HasTimeCriticalEligible(npc, thePlayer, ctx))
			{
				hasTimeCritical = true;
				break;
			}
		}

		now = theGame.GetEngineTimeAsSeconds();

		// Globalny cooldown barków (~90s) bramkuje odtworzenie kwestii (omijany dla time-critical).
		canBark = (parent.GetBarkCooldownRemaining() <= 0.0) || hasTimeCritical;

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

			if (!canBark || hasTimeCritical) continue;
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
			MCM_AR_Log("[AR] Greeting after " + RoundMath(gap) + "s absence: " + NameToString(nam));

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

		barkPreset = MCM_AR_GetConfig().GetBarkPreset();
		barkChance = 65;
		if (barkPreset <= 1)
		{
			barkChance = 30;
		}
		else if (barkPreset >= 3)
		{
			barkChance = 100;
		}
		if (!hasTimeCritical && RandRange(100, 0) >= barkChance)
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

			// Prio dla akcji okienkowych – przed ważonym losem zwykłych barków
			executed = core.registry.TryExecuteTimeCritical(npc, thePlayer, ctx);
			if (executed)
			{
				parent.lastBarkTime = theGame.GetEngineTimeAsSeconds();
				break;
			}

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
	var followN    : int;
	var worldAff   : string;

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
		thePlayer.DisplayHudMessage("[AR] Config/Affinity not initialized!");
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
	thePlayer.DisplayHudMessage("Enabled: " + config.IsEnabled() + " | Sandbox: " + config.IsForceRomanceOn() + " | Jealousy: " + config.IsJealousyModeOn());
	thePlayer.DisplayHudMessage("Hour: " + h + ":00 (Night: " + (h >= 22 || h < 4) + ") | Campfire: " + campfire + " | State: " + stateName);
	thePlayer.DisplayHudMessage("Safe: " + safe + " (" + safeReason + ") | Cooldown: " + config.GetInitiativeCooldown() + "s");

	LogChannel('MCM_AR', "[AR status] step8: GetNPCsByTag");
	theGame.GetNPCsByTag('GeraltsBFF', companions);
	LogChannel('MCM_AR', "[AR status] step9: loop, n=" + companions.Size());

	// Tag 'GeraltsBFF' nosi kazdy NPC zarzadzany przez MCME, w tym
	// swiatowe spawny stojace w miastach (nie podazaja za graczem).
	// Realnego followera rozroznia dopiero 'mod_scm_IsFollowing'.
	followN = 0;
	for (i = 0; i < companions.Size(); i += 1)
	{
		npc = companions[i];
		if (npc && npc.scmcc && npc.HasTag('mod_scm_IsFollowing'))
		{
			followN += 1;
		}
	}
	thePlayer.DisplayHudMessage("Following companions: " + followN + " | world NPCs tagged: " + (companions.Size() - followN));

	worldAff = "";
	for (i = 0; i < companions.Size(); i += 1)
	{
		npc = companions[i];
		if (!npc || !npc.scmcc) continue;
		nam = npc.scmcc.data.nam;
		if (npc.HasTag('mod_scm_IsFollowing'))
		{
			score = affinity.GetAffinity(nam);
			thePlayer.DisplayHudMessage("-> " + NameToString(nam) + " | Affinity: " + score + " (Base: " + affinity.GetBaseStoryAffinity(nam) + ", Earned: " + affinity.GetEarnedAffinity(nam) + ")");
		}
		else
		{
			worldAff += NameToString(nam) + "=" + affinity.GetAffinity(nam) + " ";
		}
	}
	if (worldAff != "")
	{
		MCM_AR_Log("[AR status] world NPC affinity: " + worldAff);
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
		thePlayer.DisplayHudMessage("[AR] All cooldowns reset (-9999s)!");
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
			thePlayer.DisplayHudMessage("[AR] Sandbox/ForceRomance: OFF");
		}
		else
		{
			wrapper.SetVarValue('MCM_AR', 'MCM_AR_ForceRomance', "1");
			thePlayer.DisplayHudMessage("[AR] Sandbox/ForceRomance: ON (affinity requirements bypassed)");
		}
	}
}

// Awaryjny reset stanu sesji AR (odblokowanie locków i faktów).
exec function ar_devreset()
{
	var core : MCM_AutonomousRomanceCore;

	FactsRemove('mcme_ar_awaiting_consent');
	FactsRemove('mcme_ar_consent_given');
	core = MCM_AR_GetCore();
	if (core)
	{
		core.ForceResetRuntimeState();
	}
	if (thePlayer)
	{
		thePlayer.DisplayHudMessage("[AR] devreset: consent facts + runtime state cleared");
	}
}

// Sonda I1: wymusza prog postoju - nastepny tick (<=4s) zawiesi
// towarzyszki bez czekania 50s. Wynik w ar_diag / ar_logdump.
exec function ar_idlenow()
{
	var core : MCM_AutonomousRomanceCore;
	core = MCM_AR_GetCore();
	if (core)
	{
		core.ForceIdleSuspendNow();
		thePlayer.DisplayHudMessage("[AR] idle: suspend forced - see ar_diag in ~10s");
	}
}

exec function ar_consent()
{
	var wrapper : CInGameConfigWrapper;
	var curVal  : string;
	wrapper = theGame.GetInGameConfigWrapper();
	if (wrapper)
	{
		curVal = wrapper.GetVarValue('MCM_AR', 'MCM_AR_RequireConsent');
		if (curVal == "1" || curVal == "true")
		{
			wrapper.SetVarValue('MCM_AR', 'MCM_AR_RequireConsent', "0");
			thePlayer.DisplayHudMessage("[AR] RequireConsent: OFF (Tier3=approach, Tier4=prompt)");
		}
		else
		{
			wrapper.SetVarValue('MCM_AR', 'MCM_AR_RequireConsent', "1");
			thePlayer.DisplayHudMessage("[AR] RequireConsent: ON (prompt [C] for Tier3+4)");
		}
	}
}

exec function ar_affinity(npcStr : string, amount : int)
{
	var npc : CNewNPC;

	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc)
	{
		thePlayer.DisplayHudMessage("[AR] Invalid NPC name or not in party: " + npcStr);
		return;
	}
	MCM_AR_GetAffinity().AddAffinityPoints(npc.scmcc.data.nam, amount);
	thePlayer.DisplayHudMessage("[AR] Added +" + amount + " affinity for " + npcStr + " (total: " + MCM_AR_GetAffinity().GetAffinity(npc.scmcc.data.nam) + ")");
}

exec function ar_trigger()
{
	var core : MCM_AutonomousRomanceCore;
	var amb  : MCM_AmbientRomanceChannel;
	core = MCM_AR_GetCore();
	if (core)
	{
		core.ResetAllCooldowns();
		core.GotoState('ProcessingTick');
		amb = thePlayer.mcm_ar_ambient;
		if (amb && amb.GetCurrentStateName() == 'Idle')
		{
			amb.GotoState('AmbientTick');
		}
		thePlayer.DisplayHudMessage("[AR] Forced immediate ProcessingTick!");
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
		thePlayer.DisplayHudMessage("[AR] Core is not initialized!");
		return;
	}
	if (count <= 0) count = 15;

	from = core.debugLog.Size() - count;
	if (from < 0) from = 0;
	thePlayer.DisplayHudMessage("=== AR LOGDUMP (last " + (core.debugLog.Size() - from) + " of " + core.debugLog.Size() + ") ===");
	for (i = from; i < core.debugLog.Size(); i += 1)
	{
		thePlayer.DisplayHudMessage(core.debugLog[i]);
	}
	if (core.debugLog.Size() == 0)
	{
		thePlayer.DisplayHudMessage("(empty - enable ar_debug and wait for ticks)");
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
	var dump    : string;
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
	// DEV (TW3SE): pelny ring do tw3se\out\ar_diag.txt - czytelny plik
	// zamiast parsowania user.settings. Release stub = noop.
	core = thePlayer.mcm_ar_core;
	if (core)
	{
		dump = "";
		for (i = 0; i < core.debugLog.Size(); i += 1)
		{
			dump += core.debugLog[i] + "\n";
		}
		MCM_AR_DevWriteFile("ar_diag.txt", dump);
	}
	if (thePlayer)
	{
		thePlayer.DisplayHudMessage("[AR] diag marker written to user.settings");
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
		thePlayer.DisplayHudMessage("[AR] Usage: ar_line(<npc>, <lineID>) e.g. ar_line(yennefer, 420362)");
		return;
	}

	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc)
	{
		thePlayer.DisplayHudMessage("[AR] Companion not found: " + npcStr);
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
		thePlayer.DisplayHudMessage("[AR] Usage: ar_probeanim(<npc>, <anim>) e.g. ar_probeanim(triss, woman_sit_stump_idle)");
		return;
	}

	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc)
	{
		thePlayer.DisplayHudMessage("[AR] Companion not found: " + npcStr);
		return;
	}

	played = MCM_AR_ProbeAnim(npc, animName);
	MCM_AR_Log("[AR] ProbeAnim '" + NameToString(animName) + "' on " + NameToString(npc.scmcc.data.nam) + " -> " + played, true);
}

// Macierzowa sonda animacji na towarzyszce LUB graczu (cel: seamless kiss v2.0).
// Kazdy bool = silnik przyjal anim przez dane API; ostatnia przyjeta zostaje
// na aktorze (wizualne potwierdzenie). Przyklad:
//   ar_probeanim2(triss, determined_gesture_passionate_kiss_f)
//   ar_probeanim2(player, determined_gesture_passionate_kiss_m)
exec function ar_probeanim2(targetStr : string, animName : name)
{
	var actor    : CActor;
	var mac      : CMovingPhysicalAgentComponent;
	var comp     : CAnimatedComponent;
	var settings : SAnimatedComponentSlotAnimationSettings;
	var report   : string;
	var label    : string;
	var ok, anyOk : bool;

	if (StrLen(targetStr) <= 0 || !IsNameValid(animName))
	{
		thePlayer.DisplayHudMessage("[AR] Usage: ar_probeanim2(<npc|player>, <anim>)");
		return;
	}
	if (StrLower(targetStr) == "player")
	{
		actor = thePlayer;
		label = "player";
	}
	else
	{
		actor = (CActor)MCM_AR_FindCompanion(targetStr);
		label = targetStr;
	}
	if (!actor)
	{
		thePlayer.DisplayHudMessage("[AR] Target not found: " + targetStr);
		return;
	}

	settings.blendIn  = 0.2;
	settings.blendOut = 0.2;
	report = "";
	anyOk = false;
	mac = (CMovingPhysicalAgentComponent)actor.GetComponentByClassName('CMovingPhysicalAgentComponent');
	comp = actor.GetRootAnimatedComponent();

	if (mac)
	{
		ok = mac.PlaySlotAnimationAsync(animName, 'GAMEPLAY_SLOT', settings);
		report += "gameplay=" + ok + " ";
		anyOk = anyOk || ok;
		ok = mac.PlaySlotAnimationAsync(animName, 'NPC_ANIM_SLOT', settings);
		report += "npcanim=" + ok + " ";
		anyOk = anyOk || ok;
		ok = mac.PlaySlotAnimationAsync(animName, 'PLAYER_SLOT', settings);
		report += "playerslot=" + ok + " ";
		anyOk = anyOk || ok;
	}
	else report += "mac=NULL ";

	ok = actor.ActionPlaySlotAnimationAsync('GAMEPLAY_SLOT', animName, 0.2f, 0.2f);
	report += "actorSlot=" + ok + " ";
	anyOk = anyOk || ok;

	if (comp)
	{
		ok = comp.PlaySkeletalAnimationAsync(animName);
		report += "skeletal=" + ok;
		anyOk = anyOk || ok;
	}
	else report += "comp=NULL";

	MCM_AR_Log("[AR] ProbeAnim2 '" + NameToString(animName) + "' on " + label + ": " + report, true);
	if (!anyOk)
	{
		thePlayer.DisplayHudMessage("[AR] No API accepted '" + NameToString(animName) + "' on " + label);
	}
}

// Sonda injekcji animsetu na ZYWEJ encji (czysty WS - zero TW3SE):
// doklada zaladowany CSkeletalAnimationSet do comp.animationSets i probuje
// PlaySkeletalAnimationAsync. Odpowiada na pytanie, czy tracki cutscen
// (cs704, sex_pre/do/after) odpala na istniejacej towarzyszce/graczu.
// Przyklad (z paczka TGL w Mods jako zrodlem animsetow):
//   ar_probeinject triss "gameplay/tgl_replay/catalog/cs704_sex_with_syanna.w2cutscene" "syanna:Root:cs704_sex_with_syanna"
exec function ar_probeinject(targetStr : string, animsetPath : string, animName : name)
{
	var actor       : CActor;
	var comp        : CAnimatedComponent;
	var mac         : CMovingPhysicalAgentComponent;
	var animset     : CSkeletalAnimationSet;
	var settings    : SAnimatedComponentSlotAnimationSettings;
	var report      : string;
	var before, after : int;
	var played      : bool;
	var label       : string;

	if (StrLen(targetStr) <= 0 || StrLen(animsetPath) <= 0 || !IsNameValid(animName))
	{
		thePlayer.DisplayHudMessage("[AR] Usage: ar_probeinject(<npc|player>, <animsetPath>, <anim>)");
		return;
	}
	if (StrLower(targetStr) == "player")
	{
		actor = thePlayer;
		label = "player";
	}
	else
	{
		actor = (CActor)MCM_AR_FindCompanion(targetStr);
		label = targetStr;
	}
	if (!actor)
	{
		thePlayer.DisplayHudMessage("[AR] Target not found: " + targetStr);
		return;
	}

	animset = (CSkeletalAnimationSet)LoadResource(animsetPath, true);
	if (!animset)
	{
		MCM_AR_Log("[AR] ProbeInject load FAILED (nie CSkeletalAnimationSet?): " + animsetPath, true);
		thePlayer.DisplayHudMessage("[AR] Animset not found: " + animsetPath);
		return;
	}

	// Diagnoza: ktory komponent trzyma animsety (root moze miec 0!)
	settings.blendIn  = 0.2;
	settings.blendOut = 0.2;
	mac = (CMovingPhysicalAgentComponent)actor.GetComponentByClassName('CMovingPhysicalAgentComponent');
	comp = actor.GetRootAnimatedComponent();

	// Proba 1: root component
	if (comp)
	{
		before = comp.animationSets.Size();
		comp.animationSets.PushBack(animset);
		after = comp.animationSets.Size();
		played = comp.PlaySkeletalAnimationAsync(animName);
		report = "skeletal=" + played;
		played = comp.PlaySlotAnimationAsync(animName, 'NPC_ANIM_SLOT', settings);
		report += " npcanim=" + played;
		played = comp.PlaySlotAnimationAsync(animName, 'GAMEPLAY_SLOT', settings);
		report += " gameplay=" + played;
		MCM_AR_Log("[AR] ProbeInject ROOT on " + label + ": sets " + before + "->" + after
			+ "; " + report, true);
	}

	// Proba 2: moving agent component (tam siedza ambient animsety)
	if (mac)
	{
		before = mac.animationSets.Size();
		mac.animationSets.PushBack(animset);
		after = mac.animationSets.Size();
		played = mac.PlaySkeletalAnimationAsync(animName);
		report = "skeletal=" + played;
		played = mac.PlaySlotAnimationAsync(animName, 'NPC_ANIM_SLOT', settings);
		report += " npcanim=" + played;
		played = mac.PlaySlotAnimationAsync(animName, 'GAMEPLAY_SLOT', settings);
		report += " gameplay=" + played;
		MCM_AR_Log("[AR] ProbeInject MAC on " + label + ": sets " + before + "->" + after
			+ "; " + report, true);
		thePlayer.DisplayHudMessage("[AR] inject " + label + " macSets=" + after);
	}
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
		thePlayer.DisplayHudMessage("[AR] Debug ON - tick digest on HUD. Disable: ar_debug(0). Analysis: ar_eval()");
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
	var skipped    : int;
	var nam        : name;
	var eligStr    : string;
	var blockStr   : string;
	var safeReason : string;

	core = MCM_AR_GetCore();
	if (!core || !core.registry)
	{
		thePlayer.DisplayHudMessage("[AR eval] Core/registry not initialized!");
		return;
	}
	reg = core.registry;
	affinity = MCM_AR_GetAffinity();

	theGame.GetNPCsByTag('GeraltsBFF', companions);
	ctx = core.BuildContext(companions);

	MCM_AR_Log("=== AR EVAL ===");
	MCM_AR_Log("h=" + ctx.hourOfDay + " night=" + ctx.isNight + " campfire=" + ctx.isNearCampfire + " tavern=" + ctx.isInTavern + " corvo=" + ctx.isInCorvo + " rivals=" + ctx.rivalCount + " naughty=" + ctx.isNearNaughtySpot);
	MCM_AR_Log("enabled=" + MCM_AR_GetConfig().IsEnabled() + " force=" + MCM_AR_GetConfig().IsForceRomanceOn() + " jealousy=" + MCM_AR_GetConfig().IsJealousyModeOn() + " consent=" + MCM_AR_GetConfig().RequiresPlayerConsent());

	core.MCM_AR_IsSafeToInitiate(safeReason);
	if (safeReason == "")
	{
		MCM_AR_Log("Safety: OK");
	}
	else
	{
		MCM_AR_Log("Safety: BLOCKED - " + safeReason);
	}

	MCM_AR_Log("Companions: " + companions.Size() + " | Actions in registry: " + reg.GetActionCount());

	// Tick pominie NPC bez 'mod_scm_IsFollowing' - eval robi to samo,
	// zeby dry-run pokazywal dokladnie to, co silnik realnie odpali.
	skipped = 0;
	for (i = 0; i < companions.Size(); i += 1)
	{
		npc = companions[i];
		if (!npc || !npc.scmcc) continue;
		if (!npc.HasTag('mod_scm_IsFollowing'))
		{
			skipped += 1;
			continue;
		}

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
	MCM_AR_Log("(skipped " + skipped + " world NPCs not following)");
}

// Debug: wypisuje tagi encji w promieniu 10m (audyt wykrywania 'campfire')
exec function ar_neartags()
{
	var entities  : array<CGameplayEntity>;
	var ent       : CGameplayEntity;
	var tags      : array<name>;
	var tagStr    : string;
	var i, j      : int;
	var logged    : int;
	var campfires : int;

	if (!thePlayer) return;

	FindGameplayEntitiesInRange(entities, thePlayer, 10.0, 100);
	MCM_AR_Log("=== AR NEARTAGS (10m) === encje: " + entities.Size());

	for (i = 0; i < entities.Size(); i += 1)
	{
		ent = entities[i];
		if (!ent || ent == (CGameplayEntity)thePlayer) continue;

		tags = ent.GetTags();
		tagStr = "";
		for (j = 0; j < tags.Size(); j += 1)
		{
			if (tagStr != "") tagStr += ", ";
			tagStr += NameToString(tags[j]);
		}

		if (ent.HasTag('campfire') || ent.HasTag(theGame.params.TAG_OPEN_FIRE))
		{
			campfires += 1;
			tagStr += "  <<<<< FIRE";
		}

		if (ent.HasTag('innkeep') || ent.HasTag('innkeeper') || ent.HasTag('barkeep')
			|| ent.HasTag('barmaid') || ent.HasTag('bartender') || ent.HasTag('tavern_keeper')
			|| ent.HasTag('tavernkeeper') || ent.HasTag('tavern'))
		{
			tagStr += "  <<<<< INN?";
		}

		MCM_AR_Log("[near] " + RoundMath(VecDistance(thePlayer.GetWorldPosition(), ent.GetWorldPosition())) + "m | " + ent + " | tags=" + tagStr);
		logged += 1;

		if (logged >= 25)
		{
			MCM_AR_Log("[near] capped, " + entities.Size() + " entities in range");
			break;
		}
	}

	MCM_AR_Log("encje z tagiem 'campfire': " + campfires);
}

// Natychmiastowy test bezokienkowego pocałunku z dowolną towarzyszką
exec function ar_kiss(optional npcStr : string)
{
	var core : MCM_AutonomousRomanceCore;
	core = MCM_AR_GetCore();
	if (core)
	{
		npcStr = StrLower(npcStr);
		if (npcStr == "yen" || npcStr == "yennefer")
		{
			core.debugForceAction = 'yen_night_invitation';
			core.debugForceTarget = 'yennefer';
		}
		else if (npcStr == "keira" || npcStr == "keira_metz")
		{
			core.debugForceAction = 'keira_night_proposal';
			core.debugForceTarget = 'keira_metz';
		}
		else if (npcStr == "shani")
		{
			core.debugForceAction = 'shani_night_relax';
			core.debugForceTarget = 'shani';
		}
		else if (npcStr == "anarietta" || npcStr == "anna" || npcStr == "anna_henrietta")
		{
			core.debugForceAction = 'anarietta_night_royal';
			core.debugForceTarget = 'anna_henrietta';
		}
		else if (npcStr == "vivienne" || npcStr == "sq701_vivienne")
		{
			core.debugForceAction = 'vivienne_night_invitation';
			core.debugForceTarget = 'sq701_vivienne';
		}
		else if (npcStr == "cerys" || npcStr == "becca")
		{
			core.debugForceAction = 'cerys_night_invitation';
			core.debugForceTarget = 'becca';
		}
		else if (npcStr == "syanna")
		{
			core.debugForceAction = 'syanna_kiss';
			core.debugForceTarget = 'syanna';
		}
		else if (npcStr == "philippa" || npcStr == "filippa" || npcStr == "philippa_eilhart")
		{
			core.debugForceAction = 'philippa_kiss';
			core.debugForceTarget = 'philippa_eilhart';
		}
		else if (npcStr == "ves")
		{
			core.debugForceAction = 'ves_kiss';
			core.debugForceTarget = 'ves';
		}
		else if (npcStr == "salma" || npcStr == "mh303_succbus_v2")
		{
			core.debugForceAction = 'salma_kiss';
			core.debugForceTarget = 'mh303_succbus_v2';
		}
		else if (npcStr == "priscilla" || npcStr == "pryscilla")
		{
			core.debugForceAction = 'priscilla_kiss';
			core.debugForceTarget = 'pryscilla';
		}
		else if (npcStr == "edna" || npcStr == "edna_var_attre")
		{
			core.debugForceAction = 'edna_kiss';
			core.debugForceTarget = 'edna_var_attre';
		}
		else if (npcStr == "fringilla" || npcStr == "fringilla_vigo")
		{
			core.debugForceAction = 'fringilla_kiss';
			core.debugForceTarget = 'fringilla_vigo';
		}
		else if (npcStr == "margarita" || npcStr == "margaritta")
		{
			core.debugForceAction = 'margarita_kiss';
			core.debugForceTarget = 'margarita';
		}
		else if (npcStr == "orianna" || npcStr == "oriana" || npcStr == "vampire_diva")
		{
			core.debugForceAction = 'orianna_kiss';
			core.debugForceTarget = 'vampire_diva';
		}
		else if (npcStr == "rosa" || npcStr == "rosa_var_attre")
		{
			core.debugForceAction = 'rosa_kiss';
			core.debugForceTarget = 'rosa_var_attre';
		}
		else if (npcStr == "tomira" || npcStr == "prologue_village_herbalist")
		{
			core.debugForceAction = 'tomira_kiss';
			core.debugForceTarget = 'prologue_village_herbalist';
		}
		else if (npcStr == "ciri" || npcStr == "cirilla")
		{
			core.debugForceAction = 'ciri_hug';
			core.debugForceTarget = 'cirilla';
		}
		else
		{
			core.debugForceAction = 'triss_kiss_invite';
			core.debugForceTarget = 'triss';
		}
		core.ResetAllCooldowns();
		core.GotoState('ProcessingTick');
		thePlayer.DisplayHudMessage("[AR] Bezposredni pocalunek: " + core.debugForceTarget);
	}
}

// Natychmiastowy test bezokienkowego uścisku Ciri
exec function ar_hug()
{
	var core : MCM_AutonomousRomanceCore;
	core = MCM_AR_GetCore();
	if (core)
	{
		core.debugForceAction = 'ciri_hug';
		core.debugForceTarget = 'cirilla';
		core.ResetAllCooldowns();
		core.GotoState('ProcessingTick');
		thePlayer.DisplayHudMessage("[AR] Bezposredni uscisk: Ciri");
	}
}


