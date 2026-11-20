/*****************************************************************************/
/* MCME Autonomous Romance - Core Module                                     */
/* Główna pętla, timery i context tracker                                    */
/* Wersja: 2.3.3  |  Wymaga: modMCME_Remastered 5.00+                       */
/*****************************************************************************/

// Singleton dostępny globalnie, inicjowany przy spawnie gracza

@addField(CR4Player)
public var mcm_ar_core : MCM_AutonomousRomanceCore;

@addField(CR4Player)
public var mcm_ar_ambient : MCM_AmbientRomanceChannel;

// Bufor komunikatów diagnostycznych przed inicjalizacją obiektu core.
@addField(CR4Player)
public var mcm_ar_bootlog : array<string>;

// Pobiera wszystkich companions MCME - zarowno 'GeraltsBFF' (glowne) jak i 'MCM_Other' (Cerys, Tomira, Rosa itp.)
function MCM_AR_GetActiveCompanions(out companions : array<CNewNPC>)
{
	var others : array<CNewNPC>;
	var i      : int;

	theGame.GetNPCsByTag('GeraltsBFF', companions);
	theGame.GetNPCsByTag('MCM_Other', others);
	for (i = 0; i < others.Size(); i += 1)
	{
		if (others[i] && !companions.Contains(others[i]))
		{
			companions.PushBack(others[i]);
		}
	}
}

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
	MCM_AR_InitCore();

	if (!mcm_ar_config)
	{
		mcm_ar_config = new MCM_AR_ConfigWrapper in this;
	}

	theInput.RegisterListener(this, 'OnMCM_AR_ConsentKey', 'MCM_AR_Consent');
	// NIGDY nie rejestruj listenera na vanilla akcji na CR4Player: rejestracja
	// na (obiekt, akcja) ZASTEPUJE natywny handler gry (playerInput.ws:91,
	// OnCommSheatheAny na SwordSheathe) i zabija sheathing (W3-TIK-021 §9).
	// SwordSheathe obserwujemy wylacznie pollingiem w petli zgody.

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

// Inicjalizacja moda w cyklu OnSpawned gracza.
@wrapMethod(CR4Player)
function InitRemasterSettings()
{
	wrappedMethod();
	MCM_AR_Log("InitRemasterSettings - Autonomous Romance session ready");
	this.MCM_AR_OnPlayerReady();
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
	RemoveTimer('MCM_AR_AutonomousTick');
	RemoveTimer('MCM_AR_AmbientTick');
	RemoveTimer('MCM_AR_DowntimeTick');
	RemoveTimer('MCM_AR_IdlePhaseTick');
	RemoveTimer('MCM_AR_AnimPumpTick');
	AddTimer('MCM_AR_AutonomousTick', MCM_AR_GetConfig().GetTickIntervalSeconds(), true);
	AddTimer('MCM_AR_AmbientTick', 10.0, true);
	AddTimer('MCM_AR_DowntimeTick', 1.0, true);
	AddTimer('MCM_AR_IdlePhaseTick', 1.0, true);
	// Szybka pompa manual-slot sync-instancji poz (0.01s = 100Hz >=
	// per-frame Update z W3SyncAnimationManager.state Active; silnik
	// uzywa timerow sub-frame rutynowo: actor.ws 0.001s). Rejestrowana
	// na zadanie przez EnsureAnimPump przy pierwszym jobie - zadnych
	// 100 Hz w tle, gdy pozy nie dzialaja.
}

// Konsolowy start ticku staged: GotoState na aktywny stan ubilby trwajacego
// latenta (osierocony lock). Poza Idle odrzucamy i czyscimy wymuszenie.
function MCM_AR_KickStagedTick(core : MCM_AutonomousRomanceCore)
{
	if (!core) return;
	if (core.GetCurrentStateName() != 'Idle')
	{
		core.debugForceAction = '';
		core.debugForceTarget = '';
		thePlayer.DisplayHudMessage("[AR] Another interaction is in progress - try again in a moment.");
		return;
	}
	core.GotoState('ProcessingTick');
}

@addMethod(CR4Player)
timer function MCM_AR_AutonomousTick(dt : float, id : int)
{
	if (mcm_ar_core && mcm_ar_core.GetCurrentStateName() == 'Idle')
	{
		mcm_ar_core.GotoState('ProcessingTick');
	}
}

// Kanał ambient: osobny timer i maszyna stanow - latent staged tick
// nigdy nie blokuje harmonogramu barkow.
@addMethod(CR4Player)
timer function MCM_AR_AmbientTick(dt : float, id : int)
{
	// Szybki timer (~10s) aktualizuje tez fazy poz postoju.
	if (mcm_ar_core)
	{
		// dtDetected ustawia MCM_AR_DowntimeTick (1s) - UpdateIdleAmbient
		// rozroznia czysty IDLE od medytacji/snu.
		mcm_ar_core.UpdateIdleAmbient();
	}
	if (mcm_ar_ambient && mcm_ar_ambient.GetCurrentStateName() == 'Idle')
	{
		mcm_ar_ambient.GotoState('AmbientTick');
	}
}

@addMethod(CR4Player)
timer function MCM_AR_DowntimeTick(dt : float, id : int)
{
	if (mcm_ar_core)
	{
		mcm_ar_core.UpdateDowntimeWatch();
	}
}

@addMethod(CR4Player)
timer function MCM_AR_IdlePhaseTick(dt : float, id : int)
{
	if (mcm_ar_core)
	{
		mcm_ar_core.AdvanceIdlePhases();
	}
}

@addMethod(CR4Player)
timer function MCM_AR_AnimPumpTick(dt : float, id : int)
{
	if (mcm_ar_core)
	{
		mcm_ar_core.PumpIdleAnims(dt);
	}
}

// Klasa główna – silnik decyzyjny

// Zadanie postoju: faza 0=ruch ku pozycji, faza 1=animacja postoju w slocie.
class MCM_AR_IdleJob
{
	var npc       : CNewNPC;
	var spot      : Vector;
	var heading   : float;
	var anim      : name;
	var phase     : int;
	var deadline  : float;
	// Losowe opoznienie pozy (0-10s) - rozrzuca "siadanie" miedzy NPC.
	var poseDelay : float;
	var animStart : name;
	var animEnd   : name;
	var animPhase : int;
	var animAt    : float;
	var reissueAt : float;
	// Job lozkowy (downtime ar_dt_bed): NPC teleportuje sie na materac
	// w trakcie snu Geralta (spot = punkt NA lozku), bedFloor = punkt
	// podlogi przy lozku (podejscie + snap wyjsciowy). WLASNE stale -
	// zero referencji do MCME JobManager.
	var isBed        : bool;
	var bedFloor     : Vector;
	// Manual slot sync instance (wzorzec engine W3SyncAnimationManager +
	// worker MCME): klip leci w GAMEPLAY_SLOT POZA kolejka akcji aktora,
	// ktora w stanie PlayerDialogScene jest wstrzymana (dlatego
	// ActionPlaySlotAnimationAsync zwracal false na wszystkim podczas
	// medytacji/snu). Sekwencje pogania timer MCM_AR_AnimPumpTick.
	var syncInst : CAnimationManualSlotSyncInstance;
	var syncSeq  : int;
	default syncSeq = -1;
}

// Marker sekwencji ambientowej (taniec/picie z MCM_AR_ProbeAnim): na czas
// trwania nowy idle-job nie moze powstac - sync-instancja siedzenia
// walczylaby z probe-animacjami o te same sloty. `until` = auto-zwolnienie
// przy latent-abort (scena/ReloadScripts), bo Clear moze nie dojsc.
class MCM_AR_AmbientBusy
{
	var npcNam : name;
	var until  : float;
}

statemachine class MCM_AutonomousRomanceCore
{
	default autoState = 'Idle';

	public var registry : MCM_RomanceActionRegistry;

	// Czas ostatniej inicjatywy w sekundach silnika (per NPC)
	private var lastInitiativeTime : array<float>;
	private var lastInitiativeNpc  : array<name>;

	// Wewnętrzny licznik: ile sekund upłynęło od ostatniej walki
	private var timeOfLastCombatEnd : float;
	default timeOfLastCombatEnd = -9999.0;
	private var wasInCombat : bool;

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

	// Idle-suspend: detektor postoju (kotwica + czas ruchu) i lista NPC
	// zawieszonych przez StopFollowing(true) - tag/flaga zostaja.
	private var arIdleAnchor : Vector;
	private var arIdleSince  : float;
	private var arIdleJobs   : array<MCM_AR_IdleJob>;
	private var arAmbientBusy : array<MCM_AR_AmbientBusy>;
	default arIdleSince = -9999.0;

	// Kanal downtime (medytacja / sen)
	public var dtDetected    : bool;   // wynik klasyfikatora z biezacego ticku
	public var dtKind        : name;   // 'ar_dt_meditation' | 'ar_dt_bed'
	public var dtCount       : int;    // debounce: kolejne ticki w downtime
	public var dtMiss        : int;    // exit-debounce: kolejne ticki poza downtime
	public var dtActive      : bool;   // czy downtime-join jest w toku
	public var dtBarker      : CNewNPC;// NPC od join-barka (do end-barka)
	public var dtBedPartner  : CNewNPC;// partner lozki (ar_dt_bed, max affinity)
	public var dtCooldownEnd : float;
	default dtCooldownEnd = -9999.0;
	public var dtBedCooldownEnd : float;
	default dtBedCooldownEnd = -9999.0;

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
			if (npc && (npc.wasInTalkInteraction || theGame.IsDialogOrCutscenePlaying() || npc == busyNpc))
			{
				if (nowT >= arIdleJobs[i].deadline)
				{
					StopIdleSyncAnim(arIdleJobs[i]);
					if (arIdleJobs[i].isBed)
					{
						// Snap z materaca na podloge - inaczej NPC zostaje
						// fizycznie na lozku po deadline (scena-flaga moze
						// byc 'zacieta' i EndInteraction nigdy nie przyjdzie).
						npc.TeleportWithRotation(arIdleJobs[i].bedFloor,
							EulerAngles(0, arIdleJobs[i].heading, 0));
						DowntimeBedUndress(npc);
						npc.scmcc.StartFollowing(true);
					}
					arIdleJobs.Erase(i);
				}
				else
				{
					kept += 1;
				}
				continue;
			}
			if (arIdleJobs[i].animPhase == 2 && IsNameValid(arIdleJobs[i].animEnd) && npc && npc.scmcc)
			{
				StartIdleSyncAnim(arIdleJobs[i], arIdleJobs[i].animEnd);
				arIdleJobs[i].animPhase = 3;
				if (arIdleJobs[i].isBed) arIdleJobs[i].animAt = nowT + 4.2;
				else arIdleJobs[i].animAt = nowT + 2.5;
				continue;
			}
			woken += 1;
			ReleaseIdleJob(i);
		}
		MCM_AR_Log("[AR] idle: waking " + woken + " NPCs (busyKept=" + kept + ")");
	}

	private function ReleaseIdleJob(i : int)
	{
		var npc : CNewNPC;
		var job : MCM_AR_IdleJob;
		var rot : EulerAngles;

		job = arIdleJobs[i];
		npc = job.npc;
		arIdleJobs.Erase(i);
		if (npc && npc.scmcc)
		{
			StopIdleSyncAnim(job);
			npc.ActionCancelAll();
			if (job.isBed)
			{
				// Zdjecie pina: snap z powrotem na PODLOGE przy lozku
				// (bedFloor - spot jest na materacu), ubranie, follow.
				npc.TeleportWithRotation(job.bedFloor, EulerAngles(0, job.heading, 0));
				DowntimeBedUndress(npc);
			}
			else
			{
				// Wzorzec MCME resetRotation: manual-slot poza moze zostawic
				// przechylona kapsule (pitch/roll) - zerujemy przy release.
				rot = npc.GetWorldRotation();
				rot.Pitch = 0;  rot.Roll = 0;
				npc.TeleportWithRotation(npc.GetWorldPosition(), rot);
			}
			npc.scmcc.StartFollowing(true);
		}
	}

	// --- Manual slot sync instance (poza kolejka akcji aktora) -----------
	// Wzorzec: engine W3SyncAnimationManager (CreateNewSyncInstance +
	// state Active Run() pompie Update per-frame) oraz worker MCME
	// (PlayAnimGood). ActionPlaySlotAnimationAsync w stanie gracza
	// PlayerDialogScene zwraca false na kazdym animie - dlatego pozy
	// downtime leca przez GAMEPLAY_SLOT rejestrowany recznie.
	private function StartIdleSyncAnim(job : MCM_AR_IdleJob, anim : name) : bool
	{
		var part      : SAnimationSequencePartDefinition;
		var masterDef : SAnimationSequenceDefinition;
		var mac       : CMovingPhysicalAgentComponent;

		if (!job.npc || !IsNameValid(anim)) return false;
		// Unicorn bridge: aktor w scenie UC / grace - syncAnim nie moze
		// przetrzymac go w pozie (mode-1 freeze z reconu).
		if (IsUcMarkedNpc(job.npc)) return false;
		StopIdleSyncAnim(job);

		job.syncInst = new CAnimationManualSlotSyncInstance in job.npc;

		part.animation     = anim;
		part.syncType      = AMST_SyncBeginning;
		part.syncEventName = 'SyncEvent';
		part.shouldSlide   = false;
		part.shouldRotate  = false;
		part.blendInTime   = 0.4;
		part.blendOutTime  = 0.4;
		part.blendTransitionTime = 0.4;
		part.sequenceIndex = 0;
		masterDef.parts.PushBack(part);
		masterDef.entity         = job.npc;
		masterDef.manualSlotName = 'GAMEPLAY_SLOT';
		masterDef.freezeAtEnd    = true;

		job.syncSeq = job.syncInst.RegisterMaster(masterDef);
		if (job.syncSeq == -1)
		{
			job.syncInst = NULL;
			return false;
		}
		job.syncInst.Update(0);

		mac = (CMovingPhysicalAgentComponent)job.npc.GetComponentByClassName('CMovingPhysicalAgentComponent');
		if (mac) mac.SetEnabledFeetIK(false);
		return true;
	}

	private function StopIdleSyncAnim(job : MCM_AR_IdleJob)
	{
		var mac : CMovingPhysicalAgentComponent;

		if (job.syncInst)
		{
			// StopSequence zawsze (red-team #6): na skonczonej sekwencji
			// to no-op, a gwarantuje zwolnienie manual-slotu.
			if (job.syncSeq >= 0)
			{
				job.syncInst.StopSequence(job.syncSeq);
			}
			// BreakIfPossible wymusza zwolnienie natywnej rejestracji
			// gameplay-scene na aktorze (IsInGameplayScene) - samo
			// StopSequence moze zostawic flage do GC instancji.
			if (job.npc)
			{
				job.syncInst.BreakIfPossible(job.npc);
			}
			job.syncInst = NULL;
			job.syncSeq  = -1;
		}
		if (job.npc)
		{
			mac = (CMovingPhysicalAgentComponent)job.npc.GetComponentByClassName('CMovingPhysicalAgentComponent');
			if (mac) mac.SetEnabledFeetIK(true);
		}
	}

	// Sonda sync-instancji: tworzy prawdziwy idle-job (phase=2) i strzela
	// StartIdleSyncAnim - test nowego mechanizmu bez medytacji/snu.
	public function MCM_AR_ProbeSyncAnim(npc : CNewNPC, anim : name) : bool
	{
		var job : MCM_AR_IdleJob;
		var rot : EulerAngles;

		if (!npc || !npc.scmcc) return false;
		job = new MCM_AR_IdleJob in this;
		job.npc       = npc;
		job.anim      = anim;
		job.phase     = 2;
		job.animPhase = 2;
		job.isBed     = false;
		job.spot      = npc.GetWorldPosition();
		rot = npc.GetWorldRotation();
		job.heading   = rot.Yaw;
		job.deadline  = theGame.GetEngineTimeAsSeconds() + 300.0;
		arIdleJobs.PushBack(job);
		EnsureAnimPump();
		npc.scmcc.StopFollowing(true);
		return StartIdleSyncAnim(job, anim);
	}

	public function MCM_AR_ProbeSyncStop()
	{
		WakeIdleJobs();
	}

	// Rejestracja pompy na zadanie (tick 0.01s tylko gdy joby istnieja).
	// Samo-rozbrajanie: PumpIdleAnims zdejmuje timer, gdy lista spustoszeje.
	public function EnsureAnimPump()
	{
		thePlayer.RemoveTimer('MCM_AR_AnimPumpTick');
		thePlayer.AddTimer('MCM_AR_AnimPumpTick', 0.01, true);
	}

	// Pompa sync-instancji + pin lozkowy (~0.05s z MCM_AR_AnimPumpTick).
	public function PumpIdleAnims(dt : float)
	{
		var i   : int;
		var job : MCM_AR_IdleJob;

		if (!isInit || arIdleJobs.Size() <= 0)
		{
			thePlayer.RemoveTimer('MCM_AR_AnimPumpTick');
			return;
		}
		for (i = 0; i < arIdleJobs.Size(); i += 1)
		{
			job = arIdleJobs[i];
			if (!job.npc) continue;
			if (job.syncInst)
			{
				job.syncInst.Update(dt / MaxF(theGame.GetTimeScale(), 1.0));
			}
			if (job.isBed && job.phase >= 1 && job.animPhase != 3)
			{
				job.npc.TeleportWithRotation(job.spot, EulerAngles(0, job.heading, 0));
			}
		}
	}

	public function AdvanceIdlePhases()
	{
		var i    : int;
		var job  : MCM_AR_IdleJob;
		var nowT : float;

		if (!isInit || arIdleJobs.Size() <= 0) return;
		nowT = theGame.GetEngineTimeAsSeconds();
		for (i = arIdleJobs.Size() - 1; i >= 0; i -= 1)
		{
			job = arIdleJobs[i];
			if (!job.npc || !job.npc.scmcc)
			{
				ReleaseIdleJob(i);
				continue;
			}
			// Bed-pin per-pump (0.05s w PumpIdleAnims). Tu zostaje tylko
			// re-issue loopa co ~30s: gdyby anim umarl wczesniej, partnerka
			// nie zostaje stojaca na lozku; restart tej samej petli wyglada
			// jak wiercenie sie we snie.
			if (job.isBed && job.phase == 2 && job.animPhase == 2 && nowT >= job.reissueAt)
			{
				StartIdleSyncAnim(job, job.anim);
				job.reissueAt = nowT + 30.0;
			}
			if (job.animPhase == 1 && nowT >= job.animAt)
			{
				job.animPhase = 2;
								if (!StartIdleSyncAnim(job, job.anim))
				{
					job.animEnd = '';
					StartIdleSyncAnim(job, 'low_sitting_ground_leaning_back_bored_idle');
				}
			}
			else if (job.animPhase == 3 && nowT >= job.animAt)
			{
				ReleaseIdleJob(i);
			}
		}
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
				StopIdleSyncAnim(arIdleJobs[i]);
				arIdleJobs.Erase(i);
			}
		}
	}

	// Znacznik "NPC w sekwencji ambientowej" (taniec/picie). UpdateIdleSuspend
	// pomija takiego NPC-a - nowy sync-job walczylby z ProbeAnim o sloty.
	// Deadline 90s >> najdluzsza sekwencja (~25s): bezpiecznik na abort.
	public function MarkAmbientBusy(npc : CNewNPC)
	{
		var i    : int;
		var rec  : MCM_AR_AmbientBusy;
		var nowT : float;

		if (!npc || !npc.scmcc || !npc.scmcc.data) return;
		nowT = theGame.GetEngineTimeAsSeconds();
		for (i = 0; i < arAmbientBusy.Size(); i += 1)
		{
			if (arAmbientBusy[i].npcNam == npc.scmcc.data.nam)
			{
				arAmbientBusy[i].until = nowT + 90.0;
				return;
			}
		}
		rec = new MCM_AR_AmbientBusy in this;
		rec.npcNam = npc.scmcc.data.nam;
		rec.until  = nowT + 90.0;
		arAmbientBusy.PushBack(rec);
	}

	public function ClearAmbientBusy(npc : CNewNPC)
	{
		var i : int;
		if (!npc || !npc.scmcc || !npc.scmcc.data) return;
		for (i = arAmbientBusy.Size() - 1; i >= 0; i -= 1)
		{
			if (arAmbientBusy[i].npcNam == npc.scmcc.data.nam)
			{
				arAmbientBusy.Erase(i);
			}
		}
	}

	public function IsAmbientBusy(npc : CNewNPC) : bool
	{
		var i    : int;
		var nowT : float;

		if (!npc || !npc.scmcc || !npc.scmcc.data) return false;
		nowT = theGame.GetEngineTimeAsSeconds();
		for (i = arAmbientBusy.Size() - 1; i >= 0; i -= 1)
		{
			if (arAmbientBusy[i].npcNam == npc.scmcc.data.nam)
			{
				if (nowT < arAmbientBusy[i].until) return true;
				arAmbientBusy.Erase(i);
			}
		}
		return false;
	}

	// Klasyfikator downtime gracza: true gdy medytuje lub spi w lozku
	// (dowolna faza: lezenie pre-clock, menu zegara, fast-forward).
	// Patrzymy na STAN/AKCJE, nie na input-context – otwarte menu przestawia
	// kontekst na EMPTY_CONTEXT przy stanie nadal 'Meditation'.
	// kind out: 'ar_dt_meditation' | 'ar_dt_bed'.
	public function MCM_AR_IsPlayerInDowntime(optional out kind : name) : bool
	{
		var st  : name;
		var act : EPlayerExplorationAction;
		var bed : W3WitcherBed;

		if (!thePlayer)
		{
			kind = '';
			return false;
		}

		// Sen w lozku dzieli maszyne medytacji; akcja trzyma sie przez cala
		// sesje (do PlayerStopAction przy pobudce) i jest jedynym
		// dyskryminatorem fazy lezenia pre-clock (stan tam = 'Exploration').
		act = thePlayer.GetPlayerAction();
		if (act == PEA_GoToSleep)
		{
			kind = 'ar_dt_bed';
			return true;
		}
		if (act == PEA_Meditation)
		{
			kind = 'ar_dt_meditation';
			return true;
		}
		st = thePlayer.GetCurrentStateName();
		if (st == 'Meditation' || st == 'MeditationWaiting')
		{
			// Medytacja bez akcji (okno tranzycji/menu) – rozstrzyga tagowana
			// encja lozka (Corvo Bianco). GetWasUsed() trwa po sesji, wiec
			// wymagamy tez bliskosci gracza do lozka - inaczej pozniejsza
			// medytacja "na piechote" przy Corvo blednie klasyfikuje sie
			// jako sen.
			bed = (W3WitcherBed)theGame.GetEntityByTag('witcherBed');
			if (bed && bed.GetWasUsed() &&
			    VecDistance2D(thePlayer.GetWorldPosition(), bed.GetWorldPosition()) < 3.0)
			{
				kind = '';
				return false;
			}
			else
			{
				kind = 'ar_dt_meditation';
			}
			return true;
		}
		kind = '';
		return false;
	}

	// Edge-detect downtime – wywolywany z MCM_AR_DowntimeTick (1s)
	// PRZED UpdateIdleAmbient (ustawia dtDetected dla idle-gate'a). Debounce
	// 2 ticki (~2s) odfiltruje mikro-medytacje alchemiczne.
	public function UpdateDowntimeWatch()
	{
		var kind       : name;
		var nowT       : float;
		var i, j       : int;
		var dist, bd   : float;
		var playerPos  : Vector;
		var companions : array<CNewNPC>;
		var npc, best  : CNewNPC;
		var hasJob     : bool;
		var job        : MCM_AR_IdleJob;
		var away       : Vector;
		var spawned    : int;
		var inRange    : int;
		var bed        : W3WitcherBed;
		var lfPos      : Vector;
		var lfYaw      : float;
		var rfPos      : Vector;
		var rfYaw      : float;
		var bedSide    : name;
		var partnerAff : int;
		var aff        : int;
		var ringR      : float;

		if (!isInit) return;

		dtDetected = MCM_AR_IsPlayerInDowntime(kind);
		nowT = theGame.GetEngineTimeAsSeconds();

		if (!dtDetected)
		{
			dtCount = 0;
			if (dtActive)
			{
				if (thePlayer.IsInCombat())
				{
					dtActive = false;
					dtBarker = NULL;
					dtBedPartner = NULL;
					dtKind = '';
					dtMiss = 0;
					dtCooldownEnd = nowT + 300.0;
					MCM_AR_Log("[AR] downtime: combat-exit");
					WakeIdleJobs();
					return;
				}
				// Sticky-session: medytacja/sen jedzie na PlayerDialogScene
				// (menu zegara, time-pass) - stan NIE jest klasyfikowany jako
				// downtime, ale tez nie jest czystym Exploration. Koniec
				// sesji dopiero na powrocie do Exploration (+ debounce).
				if (thePlayer.GetCurrentStateName() != 'Exploration') return;
				dtMiss += 1;
				if (dtMiss < 3) return;
				dtMiss = 0;
				dtActive = false;
				MCM_AR_Log("[AR] downtime: end kind=" + NameToString(dtKind));
				// END edge: bark po-wyjsciu + cooldown kanalu (~30 min).
				// Same pozy budzi normalna maszyneria idle (ruch/unsafe).
				// Odswiezamy kotwice: sesja po medytacji zachowuje sie jak
				// swiezy postoj (pozy do pierwszego ruchu >1.5m), a nie po
				// anchorku sprzed downtime.
				arIdleAnchor = thePlayer.GetWorldPosition();
				arIdleSince  = nowT;
				WakeIdleJobs();
				if (dtBarker)
				{
					if (dtBarker.scmcc && !thePlayer.IsInCombat() &&
					    !dtBarker.IsInGameplayScene() && !dtBarker.IsSpeaking() &&
					    VecDistance(dtBarker.GetWorldPosition(), thePlayer.GetWorldPosition()) < 15.0)
					{
						DowntimeBark(dtBarker, dtKind);
					}
					dtBarker = NULL;
				}
				if (dtKind == 'ar_dt_bed') dtBedCooldownEnd = nowT + 60.0;
				else dtCooldownEnd = nowT + 60.0;
				dtKind = '';
				dtBedPartner = NULL;
			}
			return;
		}

		dtMiss = 0;
		if (dtActive)
		{
			// Force-exit: TYLKO walka. IsDialogOrCutscenePlaying zwraca TRUE
			// przez caly czas medytacji/snu (to cutscene-podobne stany
			// interakcji) - branie go tu zabijaloby kazda sesje po ~1 ticku.
			// Combat: stan moze zostac 'Meditation' przy agro bez zmiany -
			// bez guarda NPC zostaja przypieci do poz w trakcie walki.
			if (thePlayer.IsInCombat())
			{
				dtActive = false;
				dtBarker = NULL;
				dtBedPartner = NULL;
				dtKind = '';
				dtCooldownEnd = nowT + 300.0;
				MCM_AR_Log("[AR] downtime: combat-exit");
				WakeIdleJobs();
			}
			return;
		}
		dtCount += 1;
		dtKind = kind;
		if (dtCount < 2 && kind != 'ar_dt_bed') return;
		if (kind == 'ar_dt_bed' && nowT < dtBedCooldownEnd) return;
		if (kind != 'ar_dt_bed' && nowT < dtCooldownEnd) return;
		if (IsStagedBusy()) return;

		// Wszyscy followers <15m siadaja przez infra idle-job (anims z puli
		// downtime); najblizszy (<10m) mowi join-bark. Bez consentu.
		MCM_AR_GetActiveCompanions(companions);
		playerPos = thePlayer.GetWorldPosition();
		best = NULL;
		bd = 10.0;
		inRange = 0;
		spawned = 0;
		dtBedPartner = NULL;
		bedSide = '';
		ringR = 1.4;
		if (kind == 'ar_dt_bed')
		{
			ringR = 1.9;
			bed = (W3WitcherBed)theGame.GetEntityByTag('witcherBed');
			if (bed && DowntimeBedLookup(bed.GetWorldPosition(), lfPos, lfYaw, rfPos, rfYaw))
			{
				bedSide = DowntimeBedChooseSide(playerPos, lfPos, rfPos,
					DowntimeBedApFree(lfPos), DowntimeBedApFree(rfPos));
			}
			if (bedSide != '')
			{
				// Partner = najwyzszy affinity wsrod eligibility. Meski rig
				// w ogole nie kandyduje: poza lozkowa jest teleport na
				// materac + woman lying loop (meskie sleep-animy i tak
				// nie graja przez slot) - zostaje mu floor-fallback.
				partnerAff = -99999;
				for (i = 0; i < companions.Size(); i += 1)
				{
					npc = companions[i];
					if (!npc || !npc.scmcc || !npc.scmcc.data) continue;
					if (!npc.HasTag('mod_scm_IsFollowing')) continue;
					if (npc.wasInTalkInteraction || npc.IsInGameplayScene() || npc.IsSpeaking()) continue;
					if (IsNpcBusy(npc)) continue;
					if (DowntimeIsMaleRig(npc.scmcc.data.nam)) continue;
					aff = MCM_AR_GetAffinity().GetAffinity(npc.scmcc.data.nam);
					if (aff > partnerAff)
					{
						partnerAff = aff;
						dtBedPartner = npc;
					}
				}
			}
		}
		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc) continue;
			if (!npc.HasTag('mod_scm_IsFollowing')) continue;
			if (npc.wasInTalkInteraction || npc.IsInGameplayScene() || npc.IsSpeaking()) continue;
			if (IsNpcBusy(npc)) continue;
			if (IsUcMarkedNpc(npc)) continue;

			dist = VecDistance(npc.GetWorldPosition(), playerPos);
			if (dist > 15.0 && npc != dtBedPartner) continue;
			inRange += 1;
			if (dist < bd)
			{
				bd = dist;
				best = npc;
			}

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
			job = new MCM_AR_IdleJob in this;
			job.npc = npc;
			job.animPhase = 0;
			if (npc == dtBedPartner)
			{
				// Partner lozka: bedFloor = AP bocznej strony na PODLODZE
				// (podejscie + snap wyjsciowy), spot = ten sam AP (MCME pinuje
				// aktora na AP przez cala animacje, bez offsetu Z). Anim = woman_sleep_on_bed_*
				// (bank MCME, grany przez GAMEPLAY_SLOT sync-instancje jak
				// w jobach MCME): start -> loop -> end (wyjscie z lozka).
				job.isBed = true;
				if (bedSide == 'lf')
				{
					job.anim = 'woman_sleep_on_bed_lf_loop';
					job.animStart = 'woman_sleep_on_bed_lf_start';
					job.animEnd = 'woman_sleep_on_bed_lf_end';
					job.bedFloor = lfPos;
					job.heading = lfYaw;
					job.spot = lfPos;
				}
				else
				{
					job.anim = 'woman_sleep_on_bed_rf_loop';
					job.animStart = 'woman_sleep_on_bed_rf_start';
					job.animEnd = 'woman_sleep_on_bed_rf_end';
					job.bedFloor = rfPos;
					job.heading = rfYaw;
					job.spot = rfPos;
				}
			}
			else
			{
				job.anim = DowntimeAnimFor(npc, kind);
				job.animStart = IdleAnimStartFor(job.anim);
				job.animEnd = IdleAnimEndFor(job.anim);
				job.spot = DowntimeRingSpotFree(playerPos, npc.GetWorldPosition(), ringR);
				job.heading = VecHeading(playerPos - job.spot);
			}
			job.phase = 0;
			job.deadline = nowT + 8.0 + (RandRange(60, 0) / 10.0);
			job.poseDelay = nowT + (RandRange(60, 0) / 10.0);
			npc.ActionCancelAll();
			if (job.isBed)
			{
				// Teleport na PODLOGE przy lozku (nie na materac - spot
				// jest podniesiony o Z) - bez podchodzenia, tego nie widac.
				npc.TeleportWithRotation(job.bedFloor, EulerAngles(0, job.heading, 0));
				job.phase = 1;
				job.poseDelay = nowT;
			}
			else
			{
				npc.TeleportWithRotation(job.spot, EulerAngles(0, job.heading, 0));
				job.phase = 1;
				job.poseDelay = nowT;
			}
			arIdleJobs.PushBack(job);
			EnsureAnimPump();
			spawned += 1;
		}

		// Nikt w zasiegu albo nikt nowo ulozony (wszyscy mieli joby):
		// nie konsumuj sesji ani nie gadaj - retry kolejny tick.
		if (inRange <= 0 || spawned <= 0) return;

		dtActive = true;
		// Join-bark usuniety na zyczenie usera: pojawial sie spozniony /
		// nachodzil na poczatek sesji. dtBarker zostaje - od niego idzie
		// end/wake-bark na END edge.
		if (best)
		{
			dtBarker = best;
		}
		if (best && best.scmcc && best.scmcc.data)
		{
			MCM_AR_Log("[AR] downtime: join (" + NameToString(kind) + "), jobs+" + spawned +
			           ", followers=" + inRange + ", barker=" + NameToString(best.scmcc.data.nam));
		}
		else
		{
			MCM_AR_Log("[AR] downtime: join (" + NameToString(kind) + "), jobs+" + spawned +
			           ", followers=" + inRange + ", barker=none");
		}
	}

	// Pula poz downtime: medytacja -> siadanie wokol gracza; lozko ->
	// pozycje bardziej rozluznione. Nieprawidlowa nazwa animu na rigu NPC
	// i tak spadnie do fallbacku w petli faz idle (UpdateIdleAmbient).
	private function DowntimeAnimFor(npc : CNewNPC, kind : name) : name
	{
		var pool : array<name>;
		var nam  : name;

		if (npc && npc.scmcc && npc.scmcc.data) nam = npc.scmcc.data.nam;
		if (DowntimeIsMaleRig(nam))
		{
			// Meski rig: poza lozkowa obstawiana osobno (rf only); tu pula
			// floor bez woman_* (te by failowaly do generycznego fallbacku).
			pool.PushBack('man_work_sleep_ground_loop_1');
			pool.PushBack('man_work_sleep_ground_leaning_wall_loop_1');
			pool.PushBack('low_sitting_ground_leaning_back_bored_idle');
			return pool[RandRange(pool.Size(), 0)];
		}

		if (kind == 'ar_dt_bed')
		{
			pool.PushBack('woman_noble_lying_relaxed_on_grass_loop_01');
			pool.PushBack('low_sitting_ground_leaning_back_bored_idle');
			pool.PushBack('woman_work_sitting_on_ground_loop');
		}
		else
		{
			// Nazwy zweryfikowane w grze (slotAnim=true w logach);
			// high_sitting_ground_determined_idle padal z slotAnim=false.
			pool.PushBack('woman_work_sitting_on_ground_loop');
			pool.PushBack('low_sitting_ground_leaning_back_bored_idle');
			pool.PushBack('low_sitting_ground_happy_idle');
			pool.PushBack('woman_crouch_loop_3');
		}
		return pool[RandRange(pool.Size(), 0)];
	}

	// Minibark kanalu downtime: napis HUD + element czatu MCME (jak
	// PlayOneLiner w akcjach, ale bez voicesetu – linie neutralne dla
	// wszystkich followers, tez non-romance). Konsumuje slota barku
	// ambient, zeby kanaly nie gadaly przez siebie.
	private function DowntimeBark(npc : CNewNPC, kind : name)
	{
		var el          : mod_scm_NPCChatElement;
		var dm          : MCM_DialogueManager;
		var mcm         : mod_scm;
		var txt         : string;
		var speakerName : string;
		var amb         : MCM_AmbientRomanceChannel;

		if (!npc || !npc.scmcc || !npc.scmcc.data) return;

		if (kind == 'ar_dt_bed')
		{
			txt = AR_T("ar_line_dt_wake", "Morning. Sleep well?");
		}
		else
		{
			txt = AR_T("ar_line_dt_end", "Feeling better?");
		}
		if (StrLen(txt) <= 0) return;

		speakerName = MCM_AR_GetCompanionDisplayName(npc);
		thePlayer.DisplayHudMessage(speakerName + ": \"" + txt + "\"");

		mcm = MCM_GetMCM();
		if (mcm)
		{
			dm = mcm.DialogueManager;
			if (dm)
			{
				el = new mod_scm_NPCChatElement in npc;
				el.entSpecialID  = npc.scmcc.data.nam;
				el.talkingID     = 0;
				el.talkingString = txt;
				el.time          = 4.0 + 0.07 * StrLen(txt);
				dm.AddChat(el);
			}
		}

		amb = thePlayer.mcm_ar_ambient;
		if (amb)
		{
			amb.lastBarkTime = theGame.GetEngineTimeAsSeconds();
		}
	}

	// Meski rig: bed-sleep ma tylko wariant _right, a pula floor dla nich
	// to inne animy (bez woman_*). Nazwy = scmcc.data.nam companionow MCME.
	private function DowntimeIsMaleRig(nam : name) : bool
	{
		switch (nam)
		{
			case 'zoltan': case 'eskel': case 'lambert': case 'letho':
			case 'roche': case 'iorweth': case 'regis': case 'jaskier':
			case 'dandelion': case 'hattori': case 'emhyr': case 'avallach':
			case 'dijkstra': case 'crach_an_craite': case 'eimyr':
			case 'sigismund': case 'thaler': case 'declan':
				return true;
		}
		return false;
	}

	// WLASNA tabela znanych lozek downtime (koordynaty wzięte z pomiarow
	// AP MCME, trzymane u nas - zero referencji do JobManager w runtime).
	// AP stoi NA PODLODZE przy lozku; anim _start wnosi cialo root-motionem.
	// Dopasowanie po dystansie encji 'witcherBed' do srodka pary AP.
	public function DowntimeBedLookup(bedPos : Vector, out lfPos : Vector, out lfYaw : float,
	                                  out rfPos : Vector, out rfYaw : float) : bool
	{
		// Corvo Bianco - sypialnia Geralta (parter)
		if (VecDistance2D(bedPos, Vector(-400.18, -799.94, 0)) < 4.0 &&
		    AbsF(bedPos.Z - 35.2) < 1.5)
		{
			lfPos = Vector(-400.561, -799.693, 35.235); lfYaw = -114.0;
			rfPos = Vector(-399.806, -800.192, 35.235); rfYaw = 66.0;
			return true;
		}
		// Corvo - lozko goscinne na pietrze
		if (VecDistance2D(bedPos, Vector(-399.18, -804.24, 0)) < 4.0 &&
		    AbsF(bedPos.Z - 39.37) < 1.5)
		{
			lfPos = Vector(-398.906, -803.835, 39.372); lfYaw = 156.0;
			rfPos = Vector(-399.463, -804.643, 39.372); rfYaw = -24.0;
			return true;
		}
		return false;
	}

	// Wolna strona AP: brak CActor w sferze 0.25m (gracz lezy na lozku,
	// nie na punkcie AP na podlodze - ale wylaczamy go jawnie).
	public function DowntimeBedApFree(apPos : Vector) : bool
	{
		var ents : array<CGameplayEntity>;
		var i    : int;

		FindGameplayEntitiesInSphere(ents, apPos, 0.25, 16);
		for (i = 0; i < ents.Size(); i += 1)
		{
			if ((CActor)ents[i] && ents[i] != thePlayer) return false;
		}
		return true;
	}

	// Wybor strony lozka: dalsza od faktycznej pozycji lezacego Geralta,
	// jesli wolna. Pure-function (asercje downtime_bed_* w E2E).
	public function DowntimeBedChooseSide(playerPos : Vector, lfPos : Vector, rfPos : Vector,
	                                      lfFree : bool, rfFree : bool) : name
	{
		if (!lfFree && !rfFree) return '';
		if (!lfFree) return 'rf';
		if (!rfFree) return 'lf';
		if (VecDistance2D(playerPos, lfPos) > VecDistance2D(playerPos, rfPos))
			return 'lf';
		return 'rf';
	}

	// Pierscien wokol punktu (medytacja ~1.4m, floor przy lozku ~1.9m):
	// kazdy NPC trzyma wlasny bearing -> naturalny wachlarz wokol gracza.
	public function DowntimeRingSpot(anchor : Vector, npcPos : Vector, radius : float) : Vector
	{
		var away : Vector;

		away = npcPos - anchor;
		away.Z = 0;
		// NPC prawie na kotwicy: losowy bearing (nie heading gracza -
		// wszyscy dostawaliby ten sam punkt i zlewali sie w jedno).
		if (VecLength(away) < 0.5)
			away = VecFromHeading(RandRange(3600, 0) / 10.0);
		return anchor + VecNormalize(away) * radius;
	}

	private function DowntimeRingSpotFree(anchor : Vector, npcPos : Vector, radius : float) : Vector
	{
		var p    : Vector;
		var away : Vector;
		var i, k : int;
		var ok   : bool;

		p = DowntimeRingSpot(anchor, npcPos, radius);
		for (k = 0; k < 6; k += 1)
		{
			ok = true;
			for (i = 0; i < arIdleJobs.Size(); i += 1)
			{
				if (VecDistance2D(arIdleJobs[i].spot, p) < 0.9)
				{
					ok = false;
					break;
				}
			}
			if (ok) return p;
			away = p - anchor;
			away.Z = 0;
			p = anchor + VecFromHeading(VecHeading(away) + 60.0) * radius;
		}
		return p;
	}

	// Bed-dress: underwear jak w MCME sleep-jobach, honorujac flage usera.
	private function DowntimeBedDress(npc : CNewNPC)
	{
		if (npc && npc.scmcc && FactsQuerySum('MCM_DisableAppearanceChanging') == 0)
			npc.scmcc.applyUnderwearAppearance();
	}

	private function DowntimeBedUndress(npc : CNewNPC)
	{
		if (npc && npc.scmcc && FactsQuerySum('MCM_DisableAppearanceChanging') == 0)
			npc.scmcc.applyNormalAppearance();
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
		var startPlayed: bool;
		var safeReason : string;
		var inDowntime : bool;

		if (!isInit) return;

		nowT      = theGame.GetEngineTimeAsSeconds();
		playerPos = thePlayer.GetWorldPosition();

		// Koniec postoju: gracz ruszyl z kotwicy albo kontekst niebezpieczny.
		// WYJATEK downtime (medytacja/sen): gracz "stoi" ale NIE jest w czystym
		// idle ani unsafe - pozy trwaja, cyklem zarzadza UpdateDowntimeWatch.
		// Uzywamy STANU SESJI dtActive (exit-debouncowanego), nie swiezej
		// klasyfikacji: pojedynczy "flicker" stanu silnika w srodku medytacji
		// zabijal joby sciezka unsafe-wake (klasyfikator false + safe-gate
		// false = smierc co tick).
		inDowntime = dtActive;
		if (!inDowntime && (!MCM_AR_IsSafeToInitiate(safeReason) || VecDistance(playerPos, arIdleAnchor) > 1.5))
		{
			arIdleAnchor = playerPos;
			arIdleSince  = nowT;
			if (arIdleJobs.Size() > 0)
				MCM_AR_Log("[AR] idle: wake-check unsafe=" + safeReason);
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
					StopIdleSyncAnim(job);
					arIdleJobs.Erase(i);
					continue;
				}
				if (job.phase == 2) continue;
				// NPC w scenie nie otrzymuje pozy postoju.
				if (job.npc.wasInTalkInteraction || theGame.IsDialogOrCutscenePlaying() || job.npc == busyNpc)
				{
					if (nowT >= job.deadline)
					{
						// Stale-job: job juz zawiesil follow (StopFollowing
						// przy tworzeniu) - bez StartFollowing NPC zostaje
						// "zamrozony" na zawsze. Bez ActionCancelAll: gdyby
						// flaga sceny byla prawdziwa, cancel rozbilby scene.
						StopIdleSyncAnim(job);
						if (job.isBed)
						{
							job.npc.TeleportWithRotation(job.bedFloor, EulerAngles(0, job.heading, 0));
							DowntimeBedUndress(job.npc);
						}
						job.npc.scmcc.StartFollowing(true);
						arIdleJobs.Erase(i);
						MCM_AR_Log("[AR] idle: pruned stale job " + NameToString(job.npc.scmcc.data.nam));
					}
					continue;
				}
				if (job.isBed) dist = VecDistance2D(job.npc.GetWorldPosition(), job.bedFloor);
				else           dist = VecDistance2D(job.npc.GetWorldPosition(), job.spot);
				if (dist <= 0.7 || nowT >= job.deadline)
				{
					if (job.phase == 0)
					{
						job.phase = 1;
						// CancelAll tylko przy timeout - gdy dojscie zakonczylo
						// sie naturalnie mover juz wszedl w idle. Slot-anim
						// strzelony W TYM SAMYM ticku po CancelAll wpada w
						// czyszczona kolejke akcji i pada (slotAnim=false na
						// wszystkim) - czekamy do nastepnego ticku.
						if (dist > 0.7)
						{
							job.npc.ActionCancelAll();
							continue;
						}
					}
					// Rozrzut czasowy: nie wszyscy "siadaja" w tym samym
					// momencie - poseDelay losuje 0-10s per NPC.
					if (nowT >= job.poseDelay)
					{
						job.phase = 2;
						if (job.isBed) job.npc.TeleportWithRotation(job.bedFloor, EulerAngles(0, job.heading, 0));
						else job.npc.TeleportWithRotation(job.spot, EulerAngles(0, job.heading, 0));
						if (job.isBed)
						{
							// Snap prosto NA MATERAC (spot ma juz +Z) +
							// underwear jak MCME sleep-jobs. Loop lezacy
							// gra od razu (animPhase=2), pin AdvanceIdlePhases
							// trzyma ja na miejscu podczas snu Geralta.
							DowntimeBedDress(job.npc);
						}
						startPlayed = false;
						if (IsNameValid(job.animStart) && StartIdleSyncAnim(job, job.animStart))
						{
							startPlayed = true;
						}
						if (startPlayed)
						{
							job.animPhase = 1;
							job.animAt = nowT + 2.5;
							slotOk = true;
						}
						else
						{
							job.animPhase = 2;
							slotOk = StartIdleSyncAnim(job, job.anim);
						}
						if (job.isBed)
						{
							job.reissueAt = nowT + 30.0;
						}
						if (!slotOk)
						{
							// Nazwa z puli nie przeszla w sync-instalce (brak w
							// animsecie) - fallback na sprawdzona poza.
							job.animEnd = '';
							slotOk = StartIdleSyncAnim(job, 'low_sitting_ground_leaning_back_bored_idle');
							MCM_AR_Log("[AR] idle: " + NameToString(job.npc.scmcc.data.nam) +
							           " FALLBACK anim=" + NameToString(job.anim) +
							           " syncAnim=" + slotOk);
						}
						else
						{
							MCM_AR_Log("[AR] idle: " + NameToString(job.npc.scmcc.data.nam) +
							           " posed, anim=" + NameToString(job.anim) +
							           " syncAnim=" + slotOk +
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
		var skipTalk   : int;
		var skipScene  : int;
		var skipOwn    : int;
		var skipSpeak  : int;
		var skipAmbient : int;

		nowT      = theGame.GetEngineTimeAsSeconds();
		playerPos = thePlayer.GetWorldPosition();

		// Downtime jest swiadomie "unsafe" dla safe-gate'ow - ProcessingTick
		// wola UpdateIdleSuspend(false) i sciezka !safe->WakeIdleJobs morduje
		// downtime-joby co tick decyzyjny. Kanal downtime jest wlascicielem
		// arIdleJobs do konca sesji (czyszcza: combat-guard + END edge).
		if (dtActive) return;

		// Koniec postoju: gracz ruszyl z kotwicy albo unsafe
		// (bezpiecznik - UpdateIdleAmbient sprawdza to samo co ~10s).
		if (!safe || VecDistance(playerPos, arIdleAnchor) > 1.5)
		{
			arIdleAnchor = playerPos;
			arIdleSince  = nowT;
			WakeIdleJobs();
			return;
		}

		// Prog postoju 50s (lub 6s przy ognisku) - za krotko, czekamy.
		if (cachedContext.isNearCampfire || MCM_AR_IsNearCampfire())
		{
			if (nowT - arIdleSince < 6.0) return;
		}
		else
		{
			if (nowT - arIdleSince < 50.0) return;
		}

		// (Fazy jobow moving->posed: UpdateIdleAmbient na timerze ~10s.)

		// Staged interakcja w toku - nie zawieszaj w trakcie podejscia/sceny.
		if (IsStagedBusy()) return;

		MCM_AR_GetActiveCompanions(companions);
		// Liczniki skip zamiast per-NPC logow - przy ~40 companions
		// seria skipow zalewala log co tick.
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
			if (npc.wasInTalkInteraction || theGame.IsDialogOrCutscenePlaying() ||
			    npc.IsSpeaking() || npc == busyNpc)
			{
				if (npc.wasInTalkInteraction) skipTalk += 1;
				if (theGame.IsDialogOrCutscenePlaying()) skipScene += 1;
				if (npc.IsSpeaking())         skipSpeak += 1;
				if (npc == busyNpc)           skipOwn += 1;
				skipBusy += 1;
				if (skipBusy <= 3)
				{
					MCM_AR_Log("[AR] idle: busyNPC " + NameToString(npc.scmcc.data.nam) +
						" talk=" + npc.wasInTalkInteraction +
						" scene=" + theGame.IsDialogOrCutscenePlaying() +
						" speak=" + npc.IsSpeaking() +
						" own=" + (npc == busyNpc));
				}
				continue;
			}
			// Unicorn bridge: aktor w scenie UC / grace - nie claimuj do joba.
			if (IsUcMarkedNpc(npc))
			{
				skipBusy += 1;
				continue;
			}
			// Sekwencja ambientowa w toku (taniec/picie): ProbeAnim grywa
			// na slotach - nowy sync-job walczylby z nia o GAMEPLAY_SLOT.
			if (IsAmbientBusy(npc))
			{
				skipAmbient += 1;
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
			job.animStart = IdleAnimStartFor(job.anim);
			job.animEnd   = IdleAnimEndFor(job.anim);
			job.animPhase = 0;
			// Wyznaczenie pozycji odpoczynku w odległości ~1.6m.
			away = npc.GetWorldPosition() - playerPos;
			away.Z = 0;
			if (VecLength(away) < 0.5) away = VecFromHeading(thePlayer.GetHeading() + 180.0);
			job.spot    = npc.GetWorldPosition() + VecNormalize(away) * 1.6;
			job.heading = VecHeading(playerPos - job.spot);
			job.phase   = 0;
			// Losowy deadline (6-12s) i poseDelay (0-10s) - rozrzut
			// miedzy towarzyszami, bez synchronicznego "siadania".
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
			EnsureAnimPump();
		}
		MCM_AR_Log("[AR] idle: t=" + (int)(nowT - arIdleSince) + "s jobs=" + arIdleJobs.Size() +
		           "/" + companions.Size() + " susp=" + suspendedThisTick +
		           " skip{noFollow=" + skipNoTag + ",far=" + skipFar + ",busy=" + skipBusy +
		           "{talk=" + skipTalk + ",scene=" + skipScene + ",speak=" + skipSpeak +
		           ",own=" + skipOwn + "},delay=" + skipDelay + ",null=" + skipNull +
		           ",amb=" + skipAmbient + "}");
	}

	// Pasywny Affinity z podrozy: +1 za 600s aktywnego followa (<=25m).
	// Ignoruje postoje (idle-suspend) i skoki czasu (load/medytacja).
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
	// preferGameplay=true (joby lozkowe): GAMEPLAY_SLOT najpierw - anim
	// zostaje wizualny wzgledem encji (root motion nie niesie kapsuly),
	// encja pinn-owana na AP przez AdvanceIdlePhases.
	private function PlayIdleSlotAnimFor(npc : CNewNPC, anim : name, preferGameplay : bool) : bool
	{
		var ac  : CAnimatedComponent;
		var ass : SAnimatedComponentSlotAnimationSettings;

		if (!npc || !IsNameValid(anim)) return false;
		// Component-level API (GetRootAnimatedComponent.PlaySlotAnimationAsync):
		// omija kolejke akcji aktora. CActor.ActionPlaySlotAnimationAsync pada
		// gdy gracz jest w PlayerDialogScene (a cala medytacja/sen jedzie
		// w tym stanie) - co kazda probe animu downtime zamienialo w false.
		ac = npc.GetRootAnimatedComponent();
		if (!ac) return false;
		ResetAnimatedComponentSlotAnimationSettings(ass);
		ass.blendIn  = 0.9;
		ass.blendOut = 0.8;
		if (preferGameplay)
		{
			if (ac.PlaySlotAnimationAsync(anim, 'GAMEPLAY_SLOT', ass)) return true;
			return ac.PlaySlotAnimationAsync(anim, 'NPC_ANIM_SLOT', ass);
		}
		if (ac.PlaySlotAnimationAsync(anim, 'NPC_ANIM_SLOT', ass)) return true;
		return ac.PlaySlotAnimationAsync(anim, 'GAMEPLAY_SLOT', ass);
	}

	private function PlayIdleSlotAnim(npc : CNewNPC, anim : name) : bool
	{
		return PlayIdleSlotAnimFor(npc, anim, false);
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

	private function IdleAnimStartFor(anim : name) : name
	{
		if (anim == 'woman_work_sitting_on_ground_loop') return 'woman_work_sitting_on_ground_start';
		if (anim == 'woman_noble_lying_relaxed_on_grass_loop_01') return 'woman_noble_lying_relaxed_on_grass_start';
		return '';
	}

	private function IdleAnimEndFor(anim : name) : name
	{
		if (anim == 'woman_work_sitting_on_ground_loop') return 'woman_work_sitting_on_ground_end';
		if (anim == 'woman_noble_lying_relaxed_on_grass_loop_01') return 'woman_noble_lying_relaxed_on_grass_stop';
		return '';
	}

	// NPC w stagingu/scenie zostaje w arIdleJobs i jest pomijana w wake-loop
	// (guard przed przerwaniem stanu przez latent-abort).

	// Wymusza suspend przy nastepnym ticku (debug - bez czekania 50s).
	public function ForceIdleSuspendNow()
	{
		arIdleAnchor = thePlayer.GetWorldPosition();
		arIdleSince = theGame.GetEngineTimeAsSeconds() - 60.0;
		MCM_AR_Log("[AR] idle: threshold forced (ar_idlenow) - suspend on next tick");
	}

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
			wasInCombat = true;
		}
		else if (wasInCombat)
		{
			// Prawdziwe combat->peace: stempluj raz (inaczej fantomowe 0 przez ~5 min po spawnie).
			wasInCombat = false;
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
		dtDetected = false;
		dtKind = '';
		dtCount = 0;
		dtActive = false;
		dtBarker = NULL;
		dtCooldownEnd = -9999.0;
		dtBedCooldownEnd = -9999.0;
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

	// Warunki bezpieczenstwa - zadna akcja nie odpali, gdy:
	public function MCM_AR_IsSafeToInitiate(optional out reason : string) : bool
	{
		if (thePlayer.GetCurrentStateName() != 'Exploration')
		{
			reason = "player state=" + thePlayer.GetCurrentStateName() + " (req. Exploration)";
			return false;
		}
		if (theInput.GetContext() != 'Exploration')
		{
			reason = "inputContext=" + NameToString(theInput.GetContext());
			return false;
		}
		// Downtime: lezenie w lozku (PEA_GoToSleep) ma stan 'Exploration' -
		// bez tej bramki akcje/consent strzelalyby na unieruchomionym graczu.
		// dtActive (sesja z exit-debouncem) zamyka luki klasyfikatora na
		// podstanach medytacji, gdzie surowy check chwilowo zwraca false.
		if (dtActive || MCM_AR_IsPlayerInDowntime())
		{
			reason = "downtime (meditation/sleep)";
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
		// DialogueManager.IsBusy sprawdzany dedykowanie w PlayScene
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
		// Downtime (medytacja/sen w tym lozko pre-clock) - barki czuwaja,
		// reakcje trzyma wylacznie kanal UpdateDowntimeWatch. dtActive
		// zamyka luki klasyfikatora na podstanach (patrz IsSafeToInitiate).
		if (dtActive || MCM_AR_IsPlayerInDowntime())
		{
			reason = "downtime (meditation/sleep)";
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
		if (FactsQuerySum('mcme_ar_awaiting_consent') > 0)
		{
			reason = "awaiting_consent";
			return false;
		}
		reason = "";
		return true;
	}

	private var cachedContext : MCM_RomanceContext;

	// Budowanie kontekstu otoczenia
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

		gt = theGame.GetGameTime();
		hourOfDay = GameTimeHours(gt) % 24;
		cachedContext.hourOfDay = hourOfDay;
		cachedContext.isNight = (hourOfDay >= 22 || hourOfDay < 4);
		cachedContext.isDawn  = (hourOfDay >= 6  && hourOfDay < 9);
		cachedContext.playerHealthRatio = thePlayer.GetStat(BCS_Vitality) / thePlayer.GetStatMax(BCS_Vitality);
		cachedContext.areaName = MCM_GetAreaName();
		// Corvo Bianco = Toussaint (obszar 11)
		cachedContext.isInCorvo = (cachedContext.areaName == (EAreaName)11);

		cachedContext.companionsInParty.Clear();
		cachedContext.isNearCampfire = MCM_AR_IsNearCampfire();
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

		// Tylko AKTYWNIE podazajace: nie-followujaca NPC (np. Ves) nie bierze
		// udzialu w zazdrosci ani nie odpala notifiera naughty.
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

	// Sprawdzenie cooldownu dla danego NPC
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

	// Anty-chaos: globalny lock staged interakcji + post-staged cooldown (~90s)
	// Wołane przez registry.TryExecute wokół Execute akcji staged.
	public function BeginStagedInteraction(npc : CNewNPC) : bool
	{
		if (interactionBusy) return false;
		interactionBusy = true;
		busyNpc = npc;
		busyStartTime = theGame.GetEngineTimeAsSeconds();
		RemoveIdleJobFor(npc);
		return true;
	}

	public function EndStagedInteraction()
	{
		interactionBusy = false;
		busyNpc = NULL;
		busyStartTime = -9999.0;
		lastStagedTime = theGame.GetEngineTimeAsSeconds();
	}

	public function IsStagedBusy() : bool
	{
		var now : float;

		// Watchdog: lock osierocony = latent-abort mid-Execute (cleanup nigdy
		// nie strzelil). Zywy lock trzymany jest wylacznie w stanie
		// ProcessingTick (Execute/consent/scena siedza w jednym latencie) -
		// >15s poza nim = martwy. 300s = twardy backstop na wiszacy tick.
		// Miejsce: getter czytany co tick - jedyny punkt osiagalny przy locku.
		if (interactionBusy)
		{
			now = theGame.GetEngineTimeAsSeconds();
			if ((GetCurrentStateName() != 'ProcessingTick' && now - busyStartTime > 15.0) ||
			    now - busyStartTime > 300.0)
			{
				if (busyNpc && busyNpc.scmcc && busyNpc.scmcc.data)
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
			}
		}
		// Unicorn bridge (opcjonalny modMCME_AR_Unicorn): jakakolwiek scena
		// UC w toku = staged-busy globalnie. Bez mostu fakt nigdy nie
		// istnieje - check to czysty FactsQuerySum, zero kosztu.
		if (FactsQuerySum('mcme_ar_uc_active') > 0) return true;
		return interactionBusy;
	}

	public function IsNpcBusy(npc : CNewNPC) : bool
	{
		return interactionBusy && busyNpc == npc;
	}

	// Unicorn bridge: per-actor marker mcme_ar_uc_on_<nam> - aktor w scenie
	// UC albo w oknie grace po niej (fakt ma expires - crash nie zawiesi).
	public function IsUcMarkedNpc(npc : CNewNPC) : bool
	{
		if (!npc || !npc.scmcc || !npc.scmcc.data) return false;
		return FactsQuerySum("mcme_ar_uc_on_" + NameToString(npc.scmcc.data.nam)) > 0;
	}

	// Awaryjny reset stanu RUNTIME (nie cooldownow/affinity): po ReloadScripts
	// lub gdy latent-abort zostawil osierocony lock / zawieszonego NPC.
	// [E2E] odczyt: zgoda wisi (fakt awaiting albo latch klawisza)
	public function HasConsentLatch() : bool
	{
		return FactsQuerySum('mcme_ar_awaiting_consent') > 0 || thePlayer.mcm_ar_consentHeldC || thePlayer.mcm_ar_consentHeldS;
	}

	public function IdleAnimStateValid() : bool
	{
		var i   : int;
		var job : MCM_AR_IdleJob;

		for (i = 0; i < arIdleJobs.Size(); i += 1)
		{
			job = arIdleJobs[i];
			if (job.animPhase < 0 || job.animPhase > 3) return false;
			if (job.animPhase == 1 && !IsNameValid(job.animStart)) return false;
			if (job.animPhase == 3 && !IsNameValid(job.animEnd)) return false;
		}
		return true;
	}

		public function ForceResetRuntimeState()
	{
		var i      : int;
		var j      : int;
		var npc    : CNewNPC;
		var allNpc : array<CNewNPC>;

		// Wbudz idle-suspend (ta sama sekwencja co UpdateIdleSuspend resume).
		for (i = arIdleJobs.Size() - 1; i >= 0; i -= 1)
		{
			npc = arIdleJobs[i].npc;
			StopIdleSyncAnim(arIdleJobs[i]);
			if (arIdleJobs[i].isBed && npc) DowntimeBedUndress(npc);
			arIdleJobs.Erase(i);
			if (npc && npc.scmcc)
			{
				npc.ActionCancelAll();
				npc.scmcc.StartFollowing(true);
			}
		}
		// Zwolnij NPC po przerwanej interakcji (lustro EndInteraction);
		// scena mogla zdjac follow calkowicie - restore dwutorowo.
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
		// Zaciecie wasInTalkInteraction na companionach po przerwanych
		// interakcjach/scenach trzyma je trwale "busy" - sweep na wszystkich.
		MCM_AR_GetActiveCompanions(allNpc);
		for (j = 0; j < allNpc.Size(); j += 1)
		{
			if (allNpc[j])
			{
				allNpc[j].wasInTalkInteraction = false;
				// Zacieta natywna flaga sceny (po kiss/sync) trzyma NPC
				// trwale "busy" - wymus zwolnienie uchwytow scen.
				if (allNpc[j].IsInGameplayScene())
				{
					allNpc[j].StopAllScenes();
				}
			}
		}
		dtActive = false;
		dtBarker = NULL;
		dtCount = 0;
		dtDetected = false;
		dtKind = '';
		dtCooldownEnd = -9999.0;
		dtBedCooldownEnd = -9999.0;
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

	// Pomocnicze sprawdzenia środowiskowe
	public function MCM_AR_IsNearCampfire() : bool
	{
		var entities : array<CEntity>;
		var fireEnts : array<CGameplayEntity>;
		var entStr   : string;
		var i        : int;
		var dist     : float;

		// Ogniska spawnowane przez mody bez tagow (np. Chill Out CO_Campfire extends W3Campfire)
		FindGameplayEntitiesInSphere(fireEnts, thePlayer.GetWorldPosition(), 6.0, 1,,,,'W3Campfire');
		if (fireEnts.Size() > 0) return true;

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
			// Wykluczenie czarow/pociskow (np. Igni rzucone przez gracza lub wrogow)
			if ((W3SignEntity)entities[i] || (CProjectileTrajectory)entities[i]) continue;
			// Swiece/lampy/pochodnie w wnetrzach nosza CarriesOpenFire - to nie ognisko
			entStr = StrLower("" + entities[i]);
			if (StrContains(entStr, "igni") || StrContains(entStr, "spell") || StrContains(entStr, "magic")
				|| StrContains(entStr, "candle") || StrContains(entStr, "lantern")
				|| StrContains(entStr, "torch") || StrContains(entStr, "chandelier")
				|| StrContains(entStr, "sconce") || StrContains(entStr, "candelabr")
				|| StrContains(entStr, "lamp")) continue;
			dist = VecDistance(thePlayer.GetWorldPosition(), entities[i].GetWorldPosition());
			if (dist < 6.0) return true;
		}
		return false;
	}

	public function MCM_AR_IsInTavern() : bool
	{
		// 1. Vanilla fact 'player_in_inn' - nie pokrywa wszystkich tawern.
		if (FactsQuerySum('player_in_inn') > 0) return true;
		// 2. Fallback: wnetrze + karczmarz w poblizu (~zero false-positive).
		if (!thePlayer.IsInInterior()) return false;
		return MCM_AR_IsInnkeeperNearby();
	}

	// Skan encji 18m: tagi karczmarza lub sciezka warstwy/szablonu.
	// Wysoki cap: geste wnetrza (~100+ encji/10m) nie zwracaja po dystansie.
	private function MCM_AR_IsInnkeeperNearby() : bool
	{
		var entities : array<CGameplayEntity>;
		var ent      : CGameplayEntity;
		var entStr   : string;
		var i        : int;

		FindGameplayEntitiesInRange(entities, thePlayer, 18.0, 200);
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
				|| StrContains(entStr, "bartender") || StrContains(entStr, "tapster")
				|| StrContains(entStr, "inn\\") || StrContains(entStr, "inn/")
				|| StrContains(entStr, "inns\\") || StrContains(entStr, "inns/")
				|| StrContains(entStr, "inn_") || StrContains(entStr, "inn.")
				|| StrContains(entStr, "tavern")
				|| StrContains(entStr, "drinking_bench") || StrContains(entStr, "sit_drinking"))
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

	// Główny tick (wywoływany cyklicznie przez timer CR4Player za pomocą stanu)
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

		if (!parent.MCM_AR_IsSafeToInitiate(safeReason))
		{
			if (dbg) MCM_AR_Log("[AR tick] blokada bezpieczenstwa: " + safeReason);
			parent.UpdateIdleSuspend(false);
			// Wymuszona akcja z konsoli pada na tej samej bramce bezpieczenstwa -
			// czyscimy flage, zeby nie wymuszala odrzuconego ticku w kolko.
			if (parent.debugForceAction != '')
			{
				// Jesli blokada wynika TYLKO z otwartej konsoli (~ -> EMPTY_CONTEXT),
				// nie kasuj akcji! Gracz wlasnie wpisal komende i za sekunde zamknie konsole.
				if (theInput.GetContext() == 'EMPTY_CONTEXT' && thePlayer.GetCurrentStateName() == 'Exploration' && !thePlayer.IsInCombat())
				{
					parent.GotoState('Idle');
					return;
				}

				MCM_AR_Log("[AR] force '" + NameToString(parent.debugForceAction) + "' odrzucona: " + safeReason);
				parent.debugForceAction = '';
				parent.debugForceTarget = '';
			}
			parent.GotoState('Idle');
			return;
		}

		MCM_AR_GetActiveCompanions(companions);
		if (companions.Size() == 0)
		{
			if (dbg) MCM_AR_Log("[AR tick] no companions (tag 'GeraltsBFF' empty)");
			parent.GotoState('Idle');
			return;
		}

		// Early-exit: staged lock/cooldown czyni kontekst i petle zbednymi.
		// IsStagedBusy() wołane PIERWSZE - watchdog w getterze zdejmuje martwy
		// lock (celowy side-effect). debugForceAction omija ten skrot i idzie
		// pelna sciezka (potrzebuje ctx).
		if (parent.debugForceAction == '' &&
		    (parent.IsStagedBusy() || parent.GetStagedCooldownRemaining() > 0.0))
		{
			// Side-effects jak w pelnej sciezce: idle-suspend + affinity marszu.
			parent.UpdateIdleSuspend(true);
			parent.UpdatePassiveTravelAffinity(companions);

			// Reset histerezy notifiera "sweet spot" - bez ctx pytamy manager.
			if (parent.naughtySpotNotified && mod_scm_GetSCM() && mod_scm_GetSCM().NaughtyManager &&
			    mod_scm_GetSCM().NaughtyManager.naughtyPoints &&
			    !mod_scm_GetSCM().NaughtyManager.naughtyPoints.GetClosestPoint(40.0))
			{
				parent.naughtySpotNotified = false;
			}

			if (dbg)
			{
				// Statyczny marker - zmienne pola rozbilyby deduplikacje digestu.
				digest = "[AR tick] staged{busy=" + parent.IsStagedBusy() + "}";
				if (digest != parent.lastDebugDigest)
				{
					MCM_AR_Log(digest);
					parent.lastDebugDigest = digest;
				}
			}
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
				if (npc && npc.scmcc && npc.scmcc.data && (npc.scmcc.data.nam == parent.debugForceTarget || (parent.debugForceTarget == 'priscilla' && npc.scmcc.data.nam == 'pryscilla') || (parent.debugForceTarget == 'pryscilla' && npc.scmcc.data.nam == 'priscilla')))
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

		// Idle-suspend: postoj gracza ~50s -> followerzy w idle-anim;
		// wznowienie przy ruchu gracza albo unsafe.
		parent.UpdateIdleSuspend(true);

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

		// Anty-chaos: staged wyklucza sie wzajemnie (1 interakcja + ~90s cd);
		// ambient leci rownolegle. Markery ida do digestu (deduplikacja).
		if (parent.IsStagedBusy() || parent.GetStagedCooldownRemaining() > 0.0)
		{
			if (dbg)
			{
				// Statyczny marker - zmienny czas rozbilby deduplikacje digestu.
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

			// Staged cooldown takze W PETLI: fail poprzedniej akcji stempluje
			// lastStagedTime - kolejna towarzyszka nie strzeli w tym ticku.
			if (parent.IsStagedBusy() || parent.GetStagedCooldownRemaining() > 0.0)
			{
				if (dbg) digest += " | " + NameToString(npc.scmcc.data.nam) + "{staged-cd}";
				break;
			}

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

// Kanał ambient – barki RTT_OneLiner (w tym zazdrość Yen<->Triss) lecą
// równolegle do staged channel przez osobną maszynę stanów i timer.

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

		// Staged ma pierwszenstwo: barki nie leca na czas propozycji/sceny
		// (watchdog w getterze zdejmuje martwy lock - czytanie jest bezpieczne).
		if (core.IsStagedBusy())
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

		MCM_AR_GetActiveCompanions(companions);
		if (companions.Size() == 0)
		{
			parent.GotoState('Idle');
			return;
		}

		ctx = core.BuildContext(companions);
		core.ShuffleCompanions(companions);

		// Akcje okienkowe (isTimeCritical): wyprzedzaja barki i omijaja los
		// presetu - ich okno czasowe wygasa. Filtry jak w petli nizej.
		hasTimeCritical = false;
		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc) continue;
			if (core.IsNpcBusy(npc)) continue;
			if (!npc.HasTag('mod_scm_IsFollowing')) continue;
			if (theGame.IsDialogOrCutscenePlaying() || npc.IsSpeaking()) continue;
			if (core.registry.HasTimeCriticalEligible(npc, thePlayer, ctx))
			{
				hasTimeCritical = true;
				break;
			}
		}

		now = theGame.GetEngineTimeAsSeconds();

		// Globalny cooldown barków (~90s) bramkuje odtworzenie kwestii (omijany dla time-critical).
		canBark = (parent.GetBarkCooldownRemaining() <= 0.0) || hasTimeCritical;

		// Powitanie po absencji: NPC poza 'GeraltsBFF' >60s, powrot w <10m
		// -> greeting voiceset. Zjada ture barku; baseline nie strzela.
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

			// Stemplek "ostatnio widziana" TYLKO gdy powitanie mozliwe -
			// gate-fail nie konsumuje okna (gap przetrwa do eligible-ticku).
			if (!canBark || hasTimeCritical) continue;
			if (gap <= 60.0)
			{
				parent.greetSeenTime[idx] = now;
				continue;
			}
			if (!npc.HasTag('mod_scm_IsFollowing')) continue;
			if (core.IsNpcBusy(npc)) continue;
			if (theGame.IsDialogOrCutscenePlaying() || npc.IsSpeaking()) continue;

			dist = VecDistance(thePlayer.GetWorldPosition(), npc.GetWorldPosition());
			if (dist > 10.0) continue;

			// Cooldown powitania 300s per NPC
			g = parent.greetDoneNpc.FindFirst(nam);
			if (g != -1 && (now - parent.greetDoneTime[g]) < 300.0)
			{
				parent.greetSeenTime[idx] = now;
				continue;
			}

			parent.greetSeenTime[idx] = now;
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
			if (theGame.IsDialogOrCutscenePlaying() || npc.IsSpeaking()) continue;

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

//  Komendy Konsoli Deweloperskiej (Debug & Testing)

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
	MCM_AR_GetActiveCompanions(companions);
	LogChannel('MCM_AR', "[AR status] step9: loop, n=" + companions.Size());

	// 'GeraltsBFF' = kazdy NPC pod MCME (tez swiatowe spawny);
	// realnego followera rozroznia 'mod_scm_IsFollowing'.
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

exec function ar_unhide()
{
	var companions : array<CNewNPC>;
	var i          : int;
	var scm        : mod_scm;

	MCM_AR_GetActiveCompanions(companions);
	for (i = 0; i < companions.Size(); i += 1)
	{
		if (companions[i])
		{
			companions[i].SetHideInGame(false);
		}
	}
	scm = mod_scm_GetSCM();
	if (scm && scm.NaughtyManager)
	{
		scm.NaughtyManager.ShowAllExcept(NULL);
	}
    thePlayer.DisplayHudMessage("[AR] All companions unhidden (SetHideInGame false)!");
}

exec function ar_reset()
{
	var core       : MCM_AutonomousRomanceCore;
	var companions : array<CNewNPC>;
	var i          : int;

	core = MCM_AR_GetCore();
	if (core)
	{
		core.ResetAllCooldowns();
		MCM_AR_GetActiveCompanions(companions);
		for (i = 0; i < companions.Size(); i += 1)
		{
			if (companions[i])
			{
				companions[i].SetHideInGame(false);
			}
		}
		thePlayer.DisplayHudMessage("[AR] All cooldowns reset (-9999s) + companions unhidden!");
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

// Wymusza prog postoju - suspend bez czekania 50s (wynik: ar_diag/ar_logdump).
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

// Sonda downtime: stan klasyfikatora i watchera.
exec function ar_downtime()
{
	var core    : MCM_AutonomousRomanceCore;
	var kind    : name;
	var inDt    : bool;
	var bed     : W3WitcherBed;
	var bedUsed : string;
	var dLf     : Vector;
	var dLfY    : float;
	var dRf     : Vector;
	var dRfY    : float;
	var dPartner: string;

	core = MCM_AR_GetCore();
	if (!core || !thePlayer)
	{
		if (thePlayer) thePlayer.DisplayHudMessage("[AR] no core/player");
		return;
	}
	inDt = core.MCM_AR_IsPlayerInDowntime(kind);
	bed = (W3WitcherBed)theGame.GetEntityByTag('witcherBed');
	bedUsed = "no-entity";
	if (bed) bedUsed = "used=" + bed.GetWasUsed();
	thePlayer.DisplayHudMessage("--- [AR DOWNTIME] ---");
	thePlayer.DisplayHudMessage("state=" + NameToString(thePlayer.GetCurrentStateName()) +
		" | action=" + (int)thePlayer.GetPlayerAction() +
		" | ctx=" + NameToString(theInput.GetContext()));
	thePlayer.DisplayHudMessage("bed(" + bedUsed + ") | detected=" + inDt + " kind=" + NameToString(kind));
	thePlayer.DisplayHudMessage("watcher: active=" + core.dtActive + " count=" + core.dtCount +
		" cd=" + (int)(core.dtCooldownEnd - theGame.GetEngineTimeAsSeconds()) + "s | idleJobs=" + core.GetIdleSuspendCount());
	if (bed)
	{
		// Dump AP stron lozka (wlasna tabela) + wybrana strona/partner.
		if (core.DowntimeBedLookup(bed.GetWorldPosition(), dLf, dLfY, dRf, dRfY))
		{
			thePlayer.DisplayHudMessage("bedAP lf=" + (int)dLf.X + "," + (int)dLf.Y + "," + (int)dLf.Z +
				" yaw" + (int)dLfY + " free=" + core.DowntimeBedApFree(dLf) +
				" | rf=" + (int)dRf.X + "," + (int)dRf.Y + "," + (int)dRf.Z +
				" yaw" + (int)dRfY + " free=" + core.DowntimeBedApFree(dRf));
			dPartner = "none";
			if (core.dtBedPartner && core.dtBedPartner.scmcc && core.dtBedPartner.scmcc.data)
			{
				dPartner = NameToString(core.dtBedPartner.scmcc.data.nam);
			}
			thePlayer.DisplayHudMessage("bedSide=" + NameToString(core.DowntimeBedChooseSide(
				thePlayer.GetWorldPosition(), dLf, dRf,
				core.DowntimeBedApFree(dLf), core.DowntimeBedApFree(dRf))) +
				" | partner=" + dPartner);
		}
		else
		{
			thePlayer.DisplayHudMessage("bedAP: no table entry for this witcherBed");
		}
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
			thePlayer.DisplayHudMessage("[AR] RequireConsent: ON (consent-key prompt for Tier3+4)");
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
		MCM_AR_KickStagedTick(core);
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

// Dump diagnostyki do user.settings ([AR_Diag]) - kanal czytelny z
// dysku, gdy scriptslog.txt nie zapisuje po starcie.
exec function ar_diag()
{
	var wrapper : CInGameConfigWrapper;
	var core    : MCM_AutonomousRomanceCore;
	var dump    : string;
	var i : int;

	wrapper = theGame.GetInGameConfigWrapper();
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
		// Jeden flush na koncu - SetRawConfigValue tylko ustawia wartosci.
		theGame.SaveUserSettings();
	}
	// DEV (TW3SE): pelny ring do tw3se\out\ar_diag.txt; release stub = noop.
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

// Audycja linii na towarzyszce: ar_line(yennefer, 420362) — npcStr jako string
// (konsola W3 nie parsuje 'name').
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

// Sonda animacji: ar_probeanim(triss, woman_sit_stump_idle) — sondowac w idle
// (false = brak w animsecie LUB slot zajety; Salma moze nie miec woman_*).
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

// Macierzowa sonda animacji na towarzyszce lub graczu; ostatnia przyjeta
// zostaje na aktorze. Np.: ar_probeanim2(triss, determined_gesture_passionate_kiss_f)
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
		ok = mac.PlaySlotAnimationAsync(animName, 'GESTURE_BOTH_HANDS_SLOT', settings);
		report += "gestureboth=" + ok + " ";
		anyOk = anyOk || ok;
		ok = mac.PlaySlotAnimationAsync(animName, 'GESTURE_NO_HANDS_SLOT', settings);
		report += "gesturenone=" + ok + " ";
		anyOk = anyOk || ok;
		ok = mac.PlaySlotAnimationAsync(animName, 'MANUAL_DIALOG_SLOT', settings);
		report += "manualdlg=" + ok + " ";
		anyOk = anyOk || ok;
		ok = mac.PlaySlotAnimationAsync(animName, 'NPC_ANIM_STATIONARY_SLOT', settings);
		report += "npcstat=" + ok + " ";
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

// Sonda sync-instancji (manual GAMEPLAY_SLOT, poza kolejka akcji):
// tworzy prawdziwy idle-job i leci StartIdleSyncAnim - testuje nowy
// mechanizm poz downtime bez medytacji/snu.
//   ar_probesync shani low_sitting_ground_leaning_back_bored_idle
exec function ar_probesync(npcStr : string, animName : name)
{
	var npc : CNewNPC;
	var ok  : bool;

	if (!thePlayer || !thePlayer.mcm_ar_core)
	{
		thePlayer.DisplayHudMessage("[AR] core not init");
		return;
	}
	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc)
	{
		thePlayer.DisplayHudMessage("[AR] Companion not found: " + npcStr);
		return;
	}
	ok = thePlayer.mcm_ar_core.MCM_AR_ProbeSyncAnim(npc, animName);
	MCM_AR_Log("[AR] probesync " + NameToString(npc.scmcc.data.nam) +
	           " anim=" + NameToString(animName) + " syncAnim=" + ok, true);
	thePlayer.DisplayHudMessage("[AR] probesync " + npcStr + " -> syncAnim=" + ok);
}

exec function ar_probesyncstop()
{
	if (thePlayer && thePlayer.mcm_ar_core)
	{
		thePlayer.mcm_ar_core.MCM_AR_ProbeSyncStop();
	}
	thePlayer.DisplayHudMessage("[AR] probesync released");
}

// Sweep unstick: probuje zdjac zacieta flage IsInGameplayScene na
// companionach sekwencja release (cancel -> stop scenes -> break sync)
// i loguje flage przed/po - diagnozuje co faktycznie zdejmuje flage.
exec function ar_npcsweep()
{
	var all   : array<CNewNPC>;
	var npc   : CNewNPC;
	var i     : int;
	var broke : bool;

	MCM_AR_GetActiveCompanions(all);
	for (i = 0; i < all.Size(); i += 1)
	{
		npc = all[i];
		if (!npc) continue;
		MCM_AR_Log("[AR] sweep " + npc.GetDisplayName() +
			" before: talk=" + npc.wasInTalkInteraction +
			" scene=" + npc.IsInGameplayScene() +
			" speak=" + npc.IsSpeaking(), true);
		npc.ActionCancelAll();
		npc.RaiseForceEvent('ForceIdle');
		npc.StopAllScenes();
		broke = theGame.GetSyncAnimManager().BreakSyncIfPossible(npc);
		MCM_AR_Log("[AR] sweep " + npc.GetDisplayName() +
			" after: scene=" + npc.IsInGameplayScene() +
			" breakSync=" + broke, true);
	}
	thePlayer.DisplayHudMessage("[AR] npcsweep done - see log");
}

// Sonda injekcji animsetu na zywej encji: doklada CSkeletalAnimationSet
// do comp.animationSets i probuje tracki cutscen (cs704, sex_pre/do/after).
//   ar_probeinject triss "gameplay/.../cs704_sex_with_syanna.w2cutscene" "syanna:Root:cs704_sex_with_syanna"
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

// ar_debug = toggle; ar_debug(1) = wymus ON, ar_debug(-1) = wymus OFF
// (bare call nieodroznialny od ar_debug(0) - optional int domyslnie 0).
exec function ar_debug(optional mode : int)
{
	var on : bool;

	on = (FactsQuerySum('mcme_ar_debug') > 0);
	if (mode == 1)
	{
		on = true;
	}
	else if (mode == -1)
	{
		on = false;
	}
	else
	{
		on = !on;
	}

	if (on)
	{
		FactsRemove('mcme_ar_debug');
		FactsAdd('mcme_ar_debug', 1);
		thePlayer.DisplayHudMessage("[AR] Debug ON - tick digest on HUD. Disable: ar_debug (toggle) or ar_debug(-1). Analysis: ar_eval()");
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

	MCM_AR_GetActiveCompanions(companions);
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
			if (!MCM_AR_TargetMatches(act.targetNpc, nam)) continue;

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

		if (ent.HasTag('campfire') || ent.HasTag(theGame.params.TAG_OPEN_FIRE) || (W3Campfire)ent)
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

	MCM_AR_Log("encje 'campfire' (tag/klasa): " + campfires);
}

exec function ar_taverndebug()
{
	var entities : array<CGameplayEntity>;
	var entStr   : string;
	var i, hits  : int;
	var core     : MCM_AutonomousRomanceCore;

	if (!thePlayer) return;
	core = MCM_AR_GetCore();
	if (!core) return;

	MCM_AR_Log("=== TAVERNDEBUG === fact(player_in_inn)=" + FactsQuerySum('player_in_inn')
		+ " interior=" + thePlayer.IsInInterior() + " => isInTavern=" + core.MCM_AR_IsInTavern());

	FindGameplayEntitiesInRange(entities, thePlayer, 18.0, 200);
	hits = 0;
	for (i = 0; i < entities.Size(); i += 1)
	{
		if (!entities[i]) continue;
		entStr = StrLower("" + entities[i]);
		if (StrContains(entStr, "inn") || StrContains(entStr, "tavern")
			|| StrContains(entStr, "drink") || StrContains(entStr, "barma"))
		{
			MCM_AR_Log("[tavdbg] " + entities[i]);
			hits += 1;
			if (hits >= 15)
			{
				MCM_AR_Log("[tavdbg] capped at 15 hits");
				break;
			}
		}
	}
	MCM_AR_Log("[tavdbg] entities=" + entities.Size() + " hits=" + hits);
}

// Natychmiastowy test bezokienkowego pocałunku z dowolną towarzyszką
exec function ar_kiss(optional npcStr : string)
{
	var core       : MCM_AutonomousRomanceCore;
	var companions : array<CNewNPC>;
	var nearestNpc : CNewNPC;
	var minDist    : float;
	var dist       : float;
	var i          : int;
	var cmpStr     : string;
	var matched    : bool;
	var actionName : name;
	var targetName : name;

	core = MCM_AR_GetCore();
	if (!core) return;

	npcStr = StrLower(npcStr);

	// Jeden scan: nearestNpc = najblizszy follower (auto-pick dla pustego
	// argumentu; imie podane jawnie MUSI dopasowac aktywna towarzyszke -
	// fail-closed, bez podmiany celu na sasiadke).
	MCM_AR_GetActiveCompanions(companions);
	minDist = 999.0;
	for (i = 0; i < companions.Size(); i += 1)
	{
		if (!companions[i] || !companions[i].scmcc || !companions[i].scmcc.data) continue;
		if (!companions[i].HasTag('mod_scm_IsFollowing')) continue;
		dist = VecDistance(thePlayer.GetWorldPosition(), companions[i].GetWorldPosition());
		if (dist < minDist)
		{
			minDist = dist;
			nearestNpc = companions[i];
		}
	}

	if (npcStr == "")
	{
		if (nearestNpc)
		{
			npcStr = StrLower(NameToString(nearestNpc.scmcc.data.nam));
		}
		else
		{
			thePlayer.DisplayHudMessage("[AR kiss] Brak aktywnej towarzyszki w poblizu. Podaj imie: ar_kiss(\"keira\")");
			return;
		}
	}
	else
	{
		npcStr = MCM_AR_CanonCompanionName(npcStr);

		// Blokada by-design na ZADANYM imieniu - noble-rig nie ma animacji
		// kiss w ogole (brak akcji kiss w rejestrze). Odmowa przed dopasowaniem,
		// zeby pytanie o noble nie podmienialo celu na sasiadke.
		if (npcStr == "anna_henrietta")
		{
			thePlayer.DisplayHudMessage("[AR] anna_henrietta: no kiss tier - noble rig limit, by design");
			return;
		}
		if (npcStr == "sq701_vivienne")
		{
			thePlayer.DisplayHudMessage("[AR] vivienne: no kiss tier - noble rig limit, by design");
			return;
		}
		if (npcStr == "vampire_diva")
		{
			thePlayer.DisplayHudMessage("[AR] orianna: no kiss tier - noble rig limit, by design");
			return;
		}

		// Dopasowanie scisle
		matched = false;
		for (i = 0; i < companions.Size(); i += 1)
		{
			if (!companions[i] || !companions[i].scmcc || !companions[i].scmcc.data) continue;
			cmpStr = StrLower(NameToString(companions[i].scmcc.data.nam));
			if (cmpStr == npcStr || MCM_AR_CanonCompanionName(cmpStr) == npcStr
				|| (companions[i].scmcc.data.niceName != '' && StrLower(NameToString(companions[i].scmcc.data.niceName)) == npcStr)
				|| StrLower(MCM_AR_GetCompanionDisplayName(companions[i])) == npcStr)
			{
				nearestNpc = companions[i];
				matched = true;
				break;
			}
		}

		// Dopasowanie elastyczne substring jako fallback
		if (!matched && StrLen(npcStr) >= 3)
		{
			for (i = 0; i < companions.Size(); i += 1)
			{
				if (!companions[i] || !companions[i].scmcc || !companions[i].scmcc.data) continue;
				cmpStr = StrLower(NameToString(companions[i].scmcc.data.nam));
				if (StrContains(cmpStr, npcStr) || StrContains(npcStr, cmpStr)
					|| (companions[i].scmcc.data.niceName != '' && StrContains(StrLower(NameToString(companions[i].scmcc.data.niceName)), npcStr))
					|| StrContains(StrLower(MCM_AR_GetCompanionDisplayName(companions[i])), npcStr))
				{
					nearestNpc = companions[i];
					matched = true;
					break;
				}
			}
		}

		if (!nearestNpc)
		{
			thePlayer.DisplayHudMessage("[AR kiss] Nie znaleziono towarzyszki: " + npcStr);
			return;
		}
		// Fail-closed: imie podane jawnie, ktore nie dopasowalo zadnej aktywnej
		// towarzyszki, konczy komende bledem - NIE podmieniamy celu na
		// najblizsza sasiadke (cichy fallback mylilby raport diagnostyczny
		// i resetowal cooldowny pod niewlasciwa postac).
		if (!matched)
		{
			thePlayer.DisplayHudMessage("[AR kiss] Nie znaleziono aktywnej towarzyszki: '" + npcStr + "'");
			MCM_AR_Log("[AR kiss] requested '" + npcStr + "' has no active companion - fail-closed, no fallback");
			return;
		}
	}

	// Kanonikalizacja rozwiazanego nam (np. follower z nam 'anarietta').
	npcStr = MCM_AR_CanonCompanionName(npcStr);
	targetName = nearestNpc.scmcc.data.nam;

	// Noble-rig jako rozwiazany cel (auto-pick trafil na followerke
	// noble): brak animacji kiss - odmowa zamiast generic_kiss, ktory
	// odpadlby na guardzie IsWomanBaseCompanion.
	if (npcStr == "anna_henrietta")
	{
		thePlayer.DisplayHudMessage("[AR] anna_henrietta: no kiss tier - noble rig limit, by design");
		return;
	}
	if (npcStr == "sq701_vivienne")
	{
		thePlayer.DisplayHudMessage("[AR] vivienne: no kiss tier - noble rig limit, by design");
		return;
	}
	if (npcStr == "vampire_diva")
	{
		thePlayer.DisplayHudMessage("[AR] orianna: no kiss tier - noble rig limit, by design");
		return;
	}

	// Dedykowane akcje kiss wg kanonicznego nam; rozszerzony roster
	// woman_base bez dedykowanej akcji dostaje wildcard generic_kiss.
	if (npcStr == "yennefer")
	{
		core.debugForceAction = 'yen_night_invitation';
	}
	else if (npcStr == "keira_metz")
	{
		core.debugForceAction = 'keira_night_proposal';
	}
	else if (npcStr == "shani")
	{
		core.debugForceAction = 'shani_night_relax';
	}
	else if (npcStr == "becca")
	{
		core.debugForceAction = 'cerys_night_invitation';
	}
	else if (npcStr == "syanna")
	{
		core.debugForceAction = 'syanna_kiss';
	}
	else if (npcStr == "philippa_eilhart")
	{
		core.debugForceAction = 'philippa_kiss';
	}
	else if (npcStr == "ves")
	{
		core.debugForceAction = 'ves_kiss';
	}
	else if (npcStr == "mh303_succbus_v2")
	{
		core.debugForceAction = 'salma_kiss';
	}
	else if (npcStr == "priscilla")
	{
		core.debugForceAction = 'priscilla_kiss';
	}
	else if (npcStr == "edna_var_attre")
	{
		core.debugForceAction = 'edna_kiss';
	}
	else if (npcStr == "fringilla_vigo")
	{
		core.debugForceAction = 'fringilla_kiss';
	}
	else if (npcStr == "margarita")
	{
		core.debugForceAction = 'margarita_kiss';
	}
	else if (npcStr == "rosa_var_attre")
	{
		core.debugForceAction = 'rosa_kiss';
	}
	else if (npcStr == "prologue_village_herbalist")
	{
		core.debugForceAction = 'tomira_kiss';
	}
	else if (npcStr == "triss")
	{
		core.debugForceAction = 'triss_kiss_invite';
	}
	else if (npcStr == "cirilla")
	{
		if (thePlayer.MCM_AR_GetConfig().IsCiriAdultMode())
		{
			core.debugForceAction = 'ciri_kiss';
		}
		else
		{
			core.debugForceAction = 'ciri_hug';
		}
	}
	else
	{
		// Walidacja riga przed wymuszeniem wildcardu: auto-pick pustym
		// argumentem moze trafic na meskiego followera (GeraltsBFF, np.
		// Lambert/Regis) albo inna niekompatybilna towarzyszke - fail-closed
		// zamiast cichej smierci akcji na guardzie IsWomanBaseCompanion.
		if (!MCM_AR_IsWomanBaseCompanion(nearestNpc))
		{
			thePlayer.DisplayHudMessage("[AR kiss] " + NameToString(targetName) + ": niekompatybilny rig - kiss wymaga woman_base");
			MCM_AR_Log("[AR kiss] " + NameToString(targetName) + " rejected: not a woman_base companion");
			return;
		}
		core.debugForceAction = 'generic_kiss';
		MCM_AR_Log("[AR kiss] Triggering kiss action for " + NameToString(targetName));
	}
	core.debugForceTarget = targetName;

	actionName = core.debugForceAction;
	core.ResetAllCooldowns();
	MCM_AR_KickStagedTick(core);
	thePlayer.DisplayHudMessage("[AR] Bezposredni pocalunek: " + core.debugForceTarget);
	MCM_AR_Log("[AR] ar_kiss: wymuszono akcje " + NameToString(actionName) + " dla " + NameToString(targetName));
}

exec function ar_dance(optional npcStr : string)
{
	var core : MCM_AutonomousRomanceCore;
	core = MCM_AR_GetCore();
	if (core)
	{
		npcStr = StrLower(npcStr);
		if (npcStr == "yen" || npcStr == "yennefer")
		{
			core.debugForceAction = 'yen_dance_refuse';
			core.debugForceTarget = 'yennefer';
		}
		else if (npcStr == "keira" || npcStr == "keira_metz")
		{
			core.debugForceAction = 'keira_dance';
			core.debugForceTarget = 'keira_metz';
		}
		else if (npcStr == "triss")
		{
			core.debugForceAction = 'triss_dance';
			core.debugForceTarget = 'triss';
		}
		else if (npcStr == "shani")
		{
			core.debugForceAction = 'shani_dance';
			core.debugForceTarget = 'shani';
		}
		else if (npcStr == "tomira" || npcStr == "prologue_village_herbalist")
		{
			core.debugForceAction = 'tomira_dance';
			core.debugForceTarget = 'prologue_village_herbalist';
		}
		else if (npcStr == "cerys" || npcStr == "becca")
		{
			core.debugForceAction = 'cerys_dance';
			core.debugForceTarget = 'becca';
		}
		else if (npcStr == "priscilla" || npcStr == "pryscilla")
		{
			core.debugForceAction = 'priscilla_dance';
			core.debugForceTarget = 'priscilla';
		}
		else if (npcStr == "ves")
		{
			core.debugForceAction = 'ves_dance_refuse';
			core.debugForceTarget = 'ves';
		}
		else if (npcStr == "ciri" || npcStr == "cirilla")
		{
			core.debugForceAction = 'ciri_dance';
			core.debugForceTarget = 'cirilla';
		}
		else if (npcStr == "ciri_refuse")
		{
			core.debugForceAction = 'ciri_dance_refuse';
			core.debugForceTarget = 'cirilla';
		}
		else if (npcStr == "philippa" || npcStr == "filippa" || npcStr == "philippa_eilhart")
		{
			core.debugForceAction = 'philippa_dance_refuse';
			core.debugForceTarget = 'philippa_eilhart';
		}
		else
		{
			thePlayer.DisplayHudMessage("[AR] ar_dance: unknown npc");
			return;
		}
		core.ResetAllCooldowns();
		MCM_AR_KickStagedTick(core);
		thePlayer.DisplayHudMessage("[AR] Dance: " + core.debugForceTarget);
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
		MCM_AR_KickStagedTick(core);
		thePlayer.DisplayHudMessage("[AR] Direct hug: Ciri");
	}
}

// Kanonikalizacja aliasow i wariantow scmcc.data.nam na wspolny klucz
// dopasowania towarzyszki (stosowana po obu stronach porownania).
function MCM_AR_CanonCompanionName(s : string) : string
{
	if      (s == "yen")                                return "yennefer";
	else if (s == "keira")                              return "keira_metz";
	else if (s == "anarietta" || s == "henrietta")       return "anna_henrietta";
	else if (s == "stenger" || s == "celina" || s == "barons_wife") return "barons_wife_celina";
	else if (s == "corine" || s == "corinne" || s == "tilly")       return "dreamer_corine_tilly";
	else if (s == "ida" || s == "emean")                return "ida_emean_aep_sivney";
	else if (s == "irina" || s == "renarde")            return "irina_renarde";
	else if (s == "eveline" || s == "gallo")            return "q603_circus_artist_companion";
	else if (s == "birna")                              return "lady_bran";
	else if (s == "sasha" || s == "cantarella")         return "sq306_sacha";
	else if (s == "jutta")                              return "mq2038_shieldmaiden";
	else if (s == "vivienne")                           return "sq701_vivienne";
	else if (s == "cerys")                              return "becca";
	else if (s == "philippa" || s == "filippa")         return "philippa_eilhart";
	else if (s == "salma")                              return "mh303_succbus_v2";
	else if (s == "pryscilla")                          return "priscilla";
	else if (s == "edna")                               return "edna_var_attre";
	else if (s == "fringilla")                          return "fringilla_vigo";
	else if (s == "margaritta")                         return "margarita";
	else if (s == "oriana" || s == "orianna")           return "vampire_diva";
	else if (s == "rosa")                               return "rosa_var_attre";
	else if (s == "tomira")                             return "prologue_village_herbalist";
	else if (s == "ciri")                               return "cirilla";
	return s;
}

// Walidacja riga towarzyszki: true dla standardowego woman_base,
// false dla noble_woman_base / monster rig / towarzyszy meskich.
// Globalny helper (jedno zrodlo prawdy): metoda klasy akcji
// MCM_RomanceInteraction.IsWomanBaseCompanion deleguje tutaj, a exec
// ar_kiss uzywa go do walidacji celu przed wymuszeniem generic_kiss.
function MCM_AR_IsWomanBaseCompanion(npc : CNewNPC) : bool
{
	var nm : name;
	if (!npc || !npc.scmcc || !npc.scmcc.data) return false;
	if (!npc.IsWoman()) return false;
	if (!npc.GetMovingAgentComponent() || npc.GetMovingAgentComponent().GetName() != "woman_base") return false;
	nm = npc.scmcc.data.nam;
	if (nm == 'anarietta' || nm == 'anna_henrietta' || nm == 'anna' ||
	    nm == 'vivienne' || nm == 'sq701_vivienne' ||
	    nm == 'oriana' || nm == 'orianna' || nm == 'vampire_diva' || nm == 'anabelle')
	{
		return false;
	}
	return true;
}

exec function ar_intimate(optional npcStr : string)
{
	var core       : MCM_AutonomousRomanceCore;
	var companions : array<CNewNPC>;
	var nearestNpc : CNewNPC;
	var minDist    : float;
	var dist       : float;
	var i          : int;
	var cmpStr     : string;
	var matched    : bool;
	var actionName : name;
	var targetName : name;

	core = MCM_AR_GetCore();
	if (!core) return;

	npcStr = StrLower(npcStr);

	// Jeden scan: nearestNpc = najblizszy follower (auto-pick dla pustego
	// argumentu oraz safe-fallback gdy podane imie nie ma aktywnej towarzyszki).
	MCM_AR_GetActiveCompanions(companions);
	minDist = 999.0;
	for (i = 0; i < companions.Size(); i += 1)
	{
		if (!companions[i] || !companions[i].scmcc || !companions[i].scmcc.data) continue;
		if (!companions[i].HasTag('mod_scm_IsFollowing')) continue;
		dist = VecDistance(thePlayer.GetWorldPosition(), companions[i].GetWorldPosition());
		if (dist < minDist)
		{
			minDist = dist;
			nearestNpc = companions[i];
		}
	}

	if (npcStr == "")
	{
		if (nearestNpc)
		{
			npcStr = StrLower(NameToString(nearestNpc.scmcc.data.nam));
		}
		else
		{
			thePlayer.DisplayHudMessage("[AR intimate] Brak aktywnej towarzyszki w poblizu. Podaj imie: ar_intimate(\"keira\")");
			return;
		}
	}
	else
	{
		npcStr = MCM_AR_CanonCompanionName(npcStr);

		// Zamierzone blokady/gate na ZADANYM imieniu - przed safe-fallbackiem,
		// zeby pytanie o zablokowana towarzyszke nie podmienialo celu.
		if (npcStr == "cirilla" && !thePlayer.MCM_AR_GetConfig().IsCiriAdultMode())
		{
			thePlayer.DisplayHudMessage("[AR] cirilla: intimate tier disabled in Lore-Friendly mode (enable Adult Mode in MCM)");
			MCM_AR_Log("[AR] ar_intimate: cirilla intimate tier is disabled in Lore-Friendly mode");
			return;
		}

		// Dopasowanie scisle
		matched = false;
		for (i = 0; i < companions.Size(); i += 1)
		{
			if (!companions[i] || !companions[i].scmcc || !companions[i].scmcc.data) continue;
			cmpStr = StrLower(NameToString(companions[i].scmcc.data.nam));
			if (cmpStr == npcStr || MCM_AR_CanonCompanionName(cmpStr) == npcStr
				|| (companions[i].scmcc.data.niceName != '' && StrLower(NameToString(companions[i].scmcc.data.niceName)) == npcStr)
				|| StrLower(MCM_AR_GetCompanionDisplayName(companions[i])) == npcStr)
			{
				nearestNpc = companions[i];
				matched = true;
				break;
			}
		}

		// Dopasowanie elastyczne substring jako fallback
		if (!matched && StrLen(npcStr) >= 3)
		{
			for (i = 0; i < companions.Size(); i += 1)
			{
				if (!companions[i] || !companions[i].scmcc || !companions[i].scmcc.data) continue;
				cmpStr = StrLower(NameToString(companions[i].scmcc.data.nam));
				if (StrContains(cmpStr, npcStr) || StrContains(npcStr, cmpStr)
					|| (companions[i].scmcc.data.niceName != '' && StrContains(StrLower(NameToString(companions[i].scmcc.data.niceName)), npcStr))
					|| StrContains(StrLower(MCM_AR_GetCompanionDisplayName(companions[i])), npcStr))
				{
					nearestNpc = companions[i];
					matched = true;
					break;
				}
			}
		}

		if (!nearestNpc)
		{
			thePlayer.DisplayHudMessage("[AR intimate] Nie znaleziono towarzyszki: " + npcStr);
			return;
		}
		if (!matched)
		{
			thePlayer.DisplayHudMessage("[AR intimate] '" + npcStr + "' bez aktywnej towarzyszki - fallback: " + NameToString(nearestNpc.scmcc.data.nam));
			MCM_AR_Log("[AR intimate] requested '" + npcStr + "' has no active companion - falling back to " + NameToString(nearestNpc.scmcc.data.nam));
			npcStr = StrLower(NameToString(nearestNpc.scmcc.data.nam));
		}
	}

	// Kanonikalizacja rozwiazanego nam (np. follower z nam 'anarietta').
	npcStr = MCM_AR_CanonCompanionName(npcStr);
	targetName = nearestNpc.scmcc.data.nam;

	// Dedykowane invite i gate'y wg klucza - noble-rig (anarietta/vivienne/
	// orianna) jest wylaczony z wildcard generic (IsWomanBaseCompanion),
	// a cirilla ma dedykowana akcje z wlasnym gate Adult Mode.
	if (npcStr == "anna_henrietta")
	{
		core.debugForceAction = 'anarietta_intimate_invite';
	}
	else if (npcStr == "sq701_vivienne")
	{
		core.debugForceAction = 'vivienne_intimate_invite';
	}
	else if (npcStr == "vampire_diva")
	{
		core.debugForceAction = 'orianna_intimate_invite';
	}
	else if (npcStr == "cirilla")
	{
		if (thePlayer.MCM_AR_GetConfig().IsCiriAdultMode())
		{
			core.debugForceAction = 'ciri_intimate_invite';
		}
		else
		{
			thePlayer.DisplayHudMessage("[AR] cirilla: intimate tier disabled in Lore-Friendly mode (enable Adult Mode in MCM)");
			MCM_AR_Log("[AR] ar_intimate: cirilla intimate tier is disabled in Lore-Friendly mode");
			return;
		}
	}
	else if (npcStr == "syanna")
	{
		core.debugForceAction = 'syanna_intimate_invite';
	}
	else
	{
		core.debugForceAction = 'generic_intimate_invite';
		MCM_AR_Log("[AR intimate] Triggering intimate action for " + NameToString(targetName));
	}
	core.debugForceTarget = targetName;

	actionName = core.debugForceAction;
	core.ResetAllCooldowns();
	MCM_AR_KickStagedTick(core);
	thePlayer.DisplayHudMessage("[AR] Wymuszenie intymnosci: " + NameToString(targetName));
	MCM_AR_Log("[AR] ar_intimate: wymuszono akcje " + NameToString(actionName) + " dla " + NameToString(targetName));
}


