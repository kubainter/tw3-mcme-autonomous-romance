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
	RTT_Prompt,     // Tier 3: zaproszenie przez HUD prompt [C]
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
	// Czy w zasiegu 30m jest "sweet spot" MCME (NaughtyPoint) –
	// zaproszenia intymne padają zanim staniemy na punkcie (scena: <=20m)
	public var isNearNaughtySpot : bool;
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

	// Treść barku – data-driven (klasa akcji ustawia default, retune bez kodu)
	public var lineId          : int;    // voiced line id (0 = tylko tekst HUD)
	public var lineText        : string; // fallback, gdy brak lokalizacji dla lineId
	public var barkMimic       : name;   // semantyczna mimika ('flirt'/'concern'/'')
	public var barkVoiceset    : name;   // voiceset NPC zamiast lineId (np. 'greeting_geralt')
	default lineId = 0;

	// Czas ostatniego wykonania (czas silnika, tylko RAM – nie zaśmieca save)
	private var lastExecTime   : float;
	default lastExecTime = -9999.0;

	// Backoff po odmowie/zignorowaniu propozycji (5 -> 15 -> 30 min)
	private var rejectedUntil  : float;
	private var rejectCount    : int;
	default rejectedUntil = -1.0;
	default rejectCount = 0;

	// Zmienna robocza na wyniki latent (W3Script: wywolanie latent nie moze
	// byc w warunku 'if' ani w deklaracji 'var' w srodku funkcji – Execute
	// gestow nie maja bloku var, wiec trzymamy scratch na klasie)
	protected var approachOk : bool;

	public function ResetCooldown()
	{
		lastExecTime = -9999.0;
		rejectedUntil = -1.0;
		rejectCount = 0;
	}

	// Odmowa/ignorowanie promptu: narastający cooldown na tę akcję
	public function MarkRejected()
	{
		var backoff : float;
		rejectCount += 1;
		if (rejectCount <= 1)       backoff = 300.0;
		else if (rejectCount == 2)  backoff = 900.0;
		else                        backoff = 1800.0;
		rejectedUntil = theGame.GetEngineTimeAsSeconds() + backoff;
		MCM_AR_Log("[AR] Odmowa: " + id + " backoff " + backoff + "s (x" + rejectCount + ")");
	}

	// Próba wykonania: startuje cooldown akcji (chroni przed spamem
	// retry przy fail-start), ale NIE rusza backoffu odmowy.
	public function MarkAttempted()
	{
		lastExecTime = theGame.GetEngineTimeAsSeconds();
	}

	// Sukces: cooldown + reset backoffu odmowy (wołane przez registry).
	public function MarkExecuted()
	{
		lastExecTime = theGame.GetEngineTimeAsSeconds();
		rejectedUntil = -1.0;
		rejectCount = 0;
	}

	// Sprawdź, czy interakcja może zostać uruchomiona
	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		return GetBlockReason(npc, player, ctx) == "";
	}

	// Powód blokady ("" = eligible) – używany też przez ar_eval diagnostykę
	public function GetBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		var now : float;

		now = theGame.GetEngineTimeAsSeconds();

		// Cooldown własny akcji
		if ((now - lastExecTime) < cooldownSeconds) return "cooldown";

		// Backoff po odmowie propozycji
		if (rejectedUntil > 0.0 && now < rejectedUntil) return "rejected_backoff";

		// Sprawdź zażyłość (pomijane w trybie Sandbox / ForceRomance)
		if (minAffinity > 0 && !MCM_AR_GetConfig().IsForceRomanceOn())
		{
			if (!MCM_AR_GetAffinity().MeetsMinAffinity(npc.scmcc.data.nam, minAffinity))
				return "affinity";
		}

		// Tryb zazdrości: akcje Tier2+ wymagają braku rywalek
		if (ctx.hasRivals && MCM_AR_GetConfig().IsJealousyModeOn())
		{
			if (triggerType == RTT_Gesture || triggerType == RTT_Prompt || triggerType == RTT_Scene)
				return "jealousy";
		}

		// Sprawdź odległość NPC od gracza
		if (VecDistance(player.GetWorldPosition(), npc.GetWorldPosition()) > 15.0)
			return "distance";

		// Warunki dodatkowe podklas (kontekst: noc/ogień/HP/zazdrość/...)
		return GetExtraBlockReason(npc, player, ctx);
	}

	// Powody blokad z warunkow wlasnych podklas ("" = brak). Subklasy
	// nadpisuja TYLKO to zamiast CanExecute – jedno zrodlo prawdy gatingu,
	// a ar_eval potrafi wypisac realny powod zamiast pustego "nazwa:".
	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		return "";
	}

	// Placeholder – nadpisywany w podklasach
	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		return false;
	}

	// Bark wg pól akcji: mimika + głos (lineId LUB voiceset) + napis HUD
	protected function PlayBark(npc : CNewNPC)
	{
		var vsPlayed : bool;

		if (!npc) return;
		if (IsNameValid(barkMimic))
		{
			PlayMimic(npc, barkMimic);
		}
		// Voiceset ma pierwszeństwo dla audio (zawsze głos tego NPC)
		if (IsNameValid(barkVoiceset))
		{
			vsPlayed = npc.PlayVoiceset(100, barkVoiceset);
			if (vsPlayed)
			{
				// sam napis HUD z pola tekstu (bez podwójnego PlayLine)
				if (StrLen(lineText) > 0)
				{
					PlayOneLiner(npc, 0, lineText);
				}
			}
			else
			{
				// Cicha degradacja (ARCHITECTURE §15.1): voicesetu brak
				// w danych audio tego NPC -> fallback na lineId + HUD
				MCM_AR_Log("[AR] voiceset missing '" + NameToString(barkVoiceset) + "' on " + NameToString(npc.scmcc.data.nam) + " - fallback lineId");
				if (lineId > 0 || StrLen(lineText) > 0)
				{
					PlayOneLiner(npc, lineId, lineText);
				}
			}
		}
		else if (lineId > 0 || StrLen(lineText) > 0)
		{
			PlayOneLiner(npc, lineId, lineText);
		}
	}

	// Skrót: jeden liner przez DialogueManager MCME i bezpośrednio na aktorze
	protected function PlayOneLiner(npc : CNewNPC, lineID : int, lineText : string)
	{
		var el            : mod_scm_NPCChatElement;
		var dm            : MCM_DialogueManager;
		var mcm           : mod_scm;
		var localizedLine : string;
		var speakerName   : string;

		if (!npc) return;

		// Odtwórz kwestię głosową na aktorze (lineID<=0 = tylko napis HUD)
		if (lineID > 0)
		{
			npc.PlayLine(lineID, true);
		}

		// Pobierz oficjalny tekst z bazy gry w bieżącym języku gracza (np. PL)
		if (lineID > 0)
		{
			localizedLine = GetLocStringById(lineID);
		}
		if (localizedLine == "")
		{
			localizedLine = lineText;
		}

		speakerName = MCM_AR_GetCompanionDisplayName(npc);

		// Wyświetl kwestię na ekranie HUD z poprawnym imieniem mówcy i w języku gry
		thePlayer.DisplayHudMessage(speakerName + ": \"" + localizedLine + "\"");

		mcm = MCM_GetMCM();
		if (!mcm) return;
		dm = mcm.DialogueManager;
		if (!dm) return;

		el = new mod_scm_NPCChatElement in npc;
		el.entSpecialID   = npc.scmcc.data.nam;
		el.talkingID      = lineID;
		el.talkingString  = localizedLine;
		el.time           = 4.0 + 0.07 * StrLen(localizedLine);

		dm.AddChat(el);
	}

	// Skrót: przesuń NPC do gracza (ActionMoveToNode) – zachowaj naturalny dystans konwersacyjny
	protected latent function ApproachPlayer(npc : CNewNPC, player : CR4Player, targetDist : float)
	{
		var dist : float;

		if (!npc || !player) return;

		dist = targetDist;
		if (dist < 2.5)
		{
			dist = 2.8;
		}

		if (VecDistance(player.GetWorldPosition(), npc.GetWorldPosition()) <= dist)
			return;

		npc.ActionMoveToNode(player, MT_Walk, 1.0, dist);
	}

	// Bezpieczne odtworzenie mimiki twarzy.
	// 'flirt'/'concern' to nasze nazwy semantyczne – mapujemy je na realne
	// animacje mimiki z w2anims (surowe nazwy padaly po cichu = martwa twarz).
	protected function PlayMimic(npc : CNewNPC, mimicName : name)
	{
		var anim   : name;
		var played : bool;

		if (!npc || !npc.scmcc) return;

		switch (mimicName)
		{
			case 'flirt':   anim = 'happy_anim_face'; break;
			case 'concern': anim = 'sad_anim_face';   break;
			default:        anim = mimicName;         break;
		}

		played = npc.PlayMimicAnimationAsync(anim);
		if (!played)
		{
			MCM_AR_Log("[AR] PlayMimic FAIL: brak animacji '" + NameToString(anim) + "' dla " + NameToString(npc.scmcc.data.nam));
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

	// -------------------------------------------------------------------
	// Staging inicjatywy "twarzą w twarz".
	// Naprawia "kwestia rzucona w plecy w biegu":
	//  - wstrzymuje follow AI towarzyszki (suspensja wewnętrzna: tag i
	//    członkostwo w drużynie zostają, wznowienie w EndInteraction),
	//  - zatrzymuje ją, obraca twarzą do Geralta, włącza head-tracking
	//    i flagę rozmowy (jak vanilla greeting / MCME talk),
	//  - wyłącza jej kolizje (jak MCME przy dialogu) i podprowadza na
	//    dystans rozmowy – wcześniej follow trzymał ją ~3.5m za plecami,
	//  - zatrzymuje Geralta i obraca go ku niej – kamera pościgowa
	//    ustawia się wtedy na towarzyszkę.
	// OBOWIĄZKOWO: na każdej ścieżce wyjścia wołać EndInteraction()!
	// -------------------------------------------------------------------
	// FAZA 1 – miękkie podejście: NPC suspendsuje follow i kieruje się ku
	// graczowi asynchronicznie (goni ruchomego gracza). ZERO locka gracza —
	// propozycja może być zignorowana bez przerywania gry.
	protected latent function SoftApproach(npc : CNewNPC, player : CR4Player, targetDist : float)
	{
		if (!npc || !player) return;

		// Bez tego follow AI (BTAP_Emergency) goniło za graczem i gwałciło
		// nasze ActionMoveToNode / ActionRotateTo – towarzyszka "uciekała".
		if (npc.scmcc && npc.scmcc.IsFollowing())
		{
			npc.scmcc.StopFollowing(true);
		}
		if (npc.GetCurrentStateName() == 'SCMPlayIdleAnim')
		{
			npc.PopState(true);
		}
		npc.ActionCancelAll();

		// Vanilla greeting / MCME talk: head-tracking + flaga dla BT
		npc.EnableDynamicLookAt(player, 120.0);
		npc.wasInTalkInteraction = true;
		npc.AddTimer('ResetTalkInteractionFlag', 1.0, true, , , true);
		npc.EnableCharacterCollisions(false);
		npc.ActionRotateToAsync(player.GetWorldPosition());
		// Async – podąża za graczem nawet gdy ten idzie dalej
		npc.ActionMoveToNodeAsync(player, MT_Walk, 1.0, targetDist);
	}

	// Czekaj aż NPC dojdzie na dystans (soft-approach async goni ruchomego
	// gracza). Zwraca false, gdy trzeba przerwać: gracz uciekł >25m,
	// walka, timeout. Po false wołaj EndSoft().
	protected latent function WaitForApproach(npc : CNewNPC, player : CR4Player, targetDist : float, timeoutSec : float) : bool
	{
		var t : float;
		t = 0.0;
		while (t <= timeoutSec)
		{
			if (!npc || !player) return false;
			if (player.IsInCombat()) return false;
			if (VecDistance(player.GetWorldPosition(), npc.GetWorldPosition()) <= targetDist + 0.5)
			{
				return true;
			}
			// Gracz odszedł za daleko – NPC nie goni w nieskończoność
			if (VecDistance(player.GetWorldPosition(), npc.GetWorldPosition()) > 25.0)
			{
				return false;
			}
			Sleep(0.25);
			t += 0.25;
		}
		return false;
	}

	// FAZA 2 – dopiero po akceptacji [C]: krótki lock gracza (gap do startu
	// sceny, ~1-2s), obrót obojga twarzami w twarz, domknięcie dystansu.
	protected latent function HardStage(npc : CNewNPC, player : CR4Player, targetDist : float)
	{
		var toNpc : Vector;
		var rot   : EulerAngles;

		if (!npc || !player) return;

		if (npc.scmcc && npc.scmcc.IsFollowing())
		{
			npc.scmcc.StopFollowing(true);
		}
		if (npc.GetCurrentStateName() == 'SCMPlayIdleAnim')
		{
			npc.PopState(true);
		}
		npc.ActionCancelAll();
		npc.EnableDynamicLookAt(player, 120.0);
		npc.wasInTalkInteraction = true;
		npc.AddTimer('ResetTalkInteractionFlag', 1.0, true, , , true);
		npc.EnableCharacterCollisions(false);

		// Geralt: stop ruchu + obrót twarzą do towarzyszki
		player.BlockAction(EIAB_Movement, 'MCM_AR_interaction');
		player.EnableDynamicLookAt(npc, 120.0);
		toNpc = npc.GetWorldPosition() - player.GetWorldPosition();
		rot = EulerAngles(0.0, VecHeading(toNpc), 0.0);
		player.TeleportWithRotation(player.GetWorldPosition(), rot);

		// NPC: obrót, podejście na dystans rozmowy, finalny obrót
		npc.ActionRotateToAsync(player.GetWorldPosition());
		ApproachPlayer(npc, player, targetDist);
		npc.ActionRotateToAsync(player.GetWorldPosition());
		npc.EnableCharacterCollisions(false);
	}

	// Legacy wrapper – pełny staging od razu (używany do czasu migracji akcji)
	protected latent function BeginInteraction(npc : CNewNPC, player : CR4Player, targetDist : float)
	{
		SoftApproach(npc, player, targetDist);
		HardStage(npc, player, targetDist);
	}

	// Zwolnienie po samej propozycji/miękkim podejściu (odmowa, timeout,
	// gracz odszedł): NPC wraca do follow, gracz nigdy nie był lockowany.
	protected function EndSoft(npc : CNewNPC)
	{
		if (!npc) return;
		npc.ActionCancelAll();
		npc.DisableLookAt();
		npc.EnableCharacterCollisions(true);
		npc.wasInTalkInteraction = false;
		// UWAGA: StopFollowing/StartFollowing MUSZĄ dostawać 'true'
		// (dontModifyPlayersList) – wtedy MCME suspensduje follow bez
		// zerowania isFollowing/tagu i IsFollowing() tu nadal zwraca true.
		// Ze StopFollowing() bez parametru towarzyszka straciłaby
		// członkostwo w drużynie i nigdy nie wznowiłaby follow.
		if (npc.scmcc && npc.scmcc.IsFollowing())
		{
			npc.scmcc.StartFollowing(true);
		}
	}

	// -------------------------------------------------------------------
	// Zwolnienie po pełnym stagingu/scenie: odblokuj gracza, wyłącz look-at,
	// wznów follow AI i zreinicjuj mimiki NPC (mechanizm MCME).
	// Wołaj na KAŻDEJ ścieżce po HardStage – także przy błędzie sceny.
	// -------------------------------------------------------------------
	protected function EndInteraction(npc : CNewNPC, player : CR4Player)
	{
		var scm : mod_scm;

		if (player)
		{
			player.UnblockAction(EIAB_Movement, 'MCM_AR_interaction');
			player.DisableLookAt();
		}
		if (npc)
		{
			npc.DisableLookAt();
			npc.EnableCharacterCollisions(true);
			npc.wasInTalkInteraction = false;

			// Po scenach .w2scene mimiki trzeba reaktywować – ten sam
			// mechanizm, którego MCME używa przy własnych dialogach.
			// Ustaw flagę PRZED wznowieniem follow, żeby zmiana stanu
			// w trakcie StartFollowing już ja widziala.
			if (npc.scmcc)
			{
				npc.scmcc.wasInDialogue = true;
				scm = mod_scm_GetSCM();
				if (scm)
				{
					scm.RefreshMimicsNextStateChange();
				}
				else
				{
					MCM_AR_Log("[AR] EndInteraction: SCM NULL - mimiki bez reinit (cleanup kontynuowany)");
				}

				// Wznów podążanie, jeśli wciąż jest towarzyszką.
				// IsFollowing() po StopFollowing(true) nadal zwraca true
				// (suspensja nie zeruje flagi) – dlatego ten guard działa.
				if (npc.scmcc.IsFollowing())
				{
					npc.scmcc.StartFollowing(true);
				}
			}
		}
	}

	// Skrót: pokaż prompt HUD i poczekaj na odpowiedź gracza (Tier 3)
	// Consent = PRZYTRZYMANIE [C] ~1s. Zwykle tapniecie chowa miecz i nic
	// nie robi - filtruje przypadkowe akceptacje ([C]=SwordSheathe jest
	// wciskane non-stop w eksploracji; wczesniej kazde tapniecie/FactsSet
	// z listenera zaliczalo consent). Prompt odswiezany co ~2s bo
	// DisplayHudMessage znika za szybko, zeby zdazyc zareagowac.
	protected latent function ShowConsentPrompt(promptText : string, timeoutSec : float, optional npc : CNewNPC) : bool
	{
		var elapsed      : float;
		var step         : float;
		var heldFor      : float;
		var lastShow     : float;
		var lastTapAt    : float;
		var prevDown     : bool;
		var nowDown      : bool;
		var pressedFresh : bool;
		var tapsSeen     : int;
		var nowTaps      : int;
		var fullPrompt   : string;

		// step 0.05: dokladniejszy hold. Tapniecia liczy eventowo listener
		// OnMCM_AR_ConsentKey (FactsAdd) - przetrwa klikniecia <50ms,
		// ktore polling moglby zgubic (CR botex m2).
		step = 0.05;
		elapsed = 0.0;
		heldFor = 0.0;
		lastShow = 0.0;
		lastTapAt = -99.0;
		tapsSeen = 0;
		pressedFresh = false;
		// Inicjalizacja stanem faktycznym: klawisz wcisniety juz PRZED
		// promptem nie moze wygenerowac sztucznego pierwszego zbocza.
		prevDown = (theInput.GetActionValue('SwordSheathe') > 0.1);
		fullPrompt = promptText + "  (przytrzymaj [C] ~1s lub tapnij 2x)";

		FactsRemove('mcme_ar_consent_given');
		FactsAdd('mcme_ar_consent_given', 0);
		FactsRemove('mcme_ar_awaiting_consent');
		FactsAdd('mcme_ar_awaiting_consent', 1);

		thePlayer.DisplayHudMessage(fullPrompt);
		MCM_AR_Log("[AR] Consent prompt pokazany, czekam max " + (int)timeoutSec + "s na hold/2x tap [C]");

		while (elapsed < timeoutSec)
		{
			Sleep(step);
			elapsed += step;

			if (elapsed - lastShow >= 2.0)
			{
				thePlayer.DisplayHudMessage(fullPrompt);
				lastShow = elapsed;
			}

			// Gracz odszedl podczas propozycji = odmowa – NPC nie goni
			// w nieskonczonosc za uciekajacym Geraltem.
			if (npc && VecDistance(thePlayer.GetWorldPosition(), npc.GetWorldPosition()) > 12.0)
			{
				FactsRemove('mcme_ar_awaiting_consent');
				FactsRemove('mcme_ar_consent_given');
				MCM_AR_Log("[AR] Consent odmowa: gracz odszedl");
				return false;
			}

			// Sciezka A - HOLD: liczymy dopiero po SWIEZYM nacisnieciu
			// w oknie promptu (pressedFresh). Klawisz trzymany juz przed
			// promptem nie konsentuje bez nowej intencji (CR botex M3).
			nowDown = (theInput.GetActionValue('SwordSheathe') > 0.1);
			if (nowDown && !prevDown)
			{
				pressedFresh = true;
			}
			if (nowDown && pressedFresh)
			{
				heldFor += step;
				if (heldFor >= 1.0)
				{
					FactsRemove('mcme_ar_awaiting_consent');
					FactsRemove('mcme_ar_consent_given');
					MCM_AR_Log("[AR] Consent zaakceptowany (hold " + heldFor + "s) po " + elapsed + "s");
					return true;
				}
			}
			else if (!nowDown)
			{
				heldFor = 0.0;
			}
			prevDown = nowDown;

			// Sciezka B - DOUBLE-TAP: licznik pressow z listenera.
			// Drugi press w <0.7s = accept; delta>=2 miedzy pollami =
			// masher - tez liczymy jako decyzje.
			nowTaps = FactsQuerySum('mcme_ar_consent_given');
			if (nowTaps > tapsSeen)
			{
				if (nowTaps - tapsSeen >= 2 || elapsed - lastTapAt <= 0.7)
				{
					FactsRemove('mcme_ar_awaiting_consent');
					FactsRemove('mcme_ar_consent_given');
					MCM_AR_Log("[AR] Consent zaakceptowany (2x tap, presses=" + nowTaps + ") po " + elapsed + "s");
					return true;
				}
				lastTapAt = elapsed;
				tapsSeen = nowTaps;
			}
		}

		FactsRemove('mcme_ar_awaiting_consent');
		FactsRemove('mcme_ar_consent_given');
		MCM_AR_Log("[AR] Consent timeout (" + (int)timeoutSec + "s) - odmowa");
		return false;
	}

	// Czeka az kolejka czatu DialogueManager MCME bedzie wolna.
	// IsBusy = stan MCM_DM_Talking (onelinery/banter) - scena nie
	// powinna startowac w trakcie swiezego czatu. Stale: brak postepu
	// kolejki >20s = martwy stan (watchdog MCME zdejmie go przy
	// nastepnym AddChat) - przepuszczamy, inaczej martwa kolejka
	// blokowalaby sceny na stale. Zwraca false po maxWaitSec.
	protected latent function WaitForDialogueFree(maxWaitSec : float) : bool
	{
		var t   : float;
		var mcm : mod_scm;

		t = 0.0;
		while (t <= maxWaitSec)
		{
			mcm = MCM_GetMCM();
			if (!mcm || !mcm.DialogueManager || !mcm.DialogueManager.IsBusy())
			{
				return true;
			}
			if (theGame.GetEngineTimeAsSeconds() - mcm.DialogueManager.lastProgress > 20.0)
			{
				return true;
			}
			Sleep(0.5);
			t += 0.5;
		}
		return false;
	}

	// Skrót: odpal scenę .w2scene przez istniejące API MCME i poczekaj
	// na jej koniec – scena blokująca ustawia flagę dialogu, scena
	// gameplay trzyma aktora w IsInGameplayScene. Timeout na wypadek,
	// gdyby scena w ogóle nie wystartowała (wtedy krótki staging).
	protected latent function PlayScene(npc : CNewNPC, scenePath : string) : bool
	{
		var t   : float;
		var scm : mod_scm;
		var ent : MultiCompanionModEntity;
		var dialogueFree : bool;
		var sawScene     : bool;

		// Gate: scena nie startuje w trakcie swiezej kolejki czatu MCME.
		// 10s wystarcza na onelinery (~4-8s); dluzsze czekanie trzyma
		// lock staged bez potrzeby (CR botex m3).
		dialogueFree = WaitForDialogueFree(10.0);
		if (!dialogueFree)
		{
			MCM_AR_Log("[AR] PlayScene ABORT: DialogueManager zajety >10s: " + scenePath);
			return false;
		}

		// Fakty i naughty-check jak przy wejściu w dialog MCME
		scm = mod_scm_GetSCM();
		if (npc && npc.scmcc && scm && scm.NaughtyManager)
		{
			if (npc.scmcc.IsFollowing())
			{
				FactsRemove('mod_scm_fact_following');
				FactsAdd('mod_scm_fact_following', 1, -1);
			}
			else
			{
				FactsRemove('mod_scm_fact_following');
				FactsAdd('mod_scm_fact_following', 0, -1);
			}
			scm.NaughtyManager.PreDialogue(npc);
		}
		else if (!scm || !scm.NaughtyManager)
		{
			MCM_AR_Log("[AR] PlayScene: SCM/NaughtyManager NULL - pomijam fakty/PreDialogue");
		}

		ent = mod_scm_GetSCMEntity();
		if (!ent)
		{
			MCM_AR_Log("[AR] PlayScene FAIL: SCMEntity NULL: " + scenePath);
			return false;
		}
		ent.mod_scm_delayedDialogue(scenePath, 0.05);
		MCM_AR_Log("[AR] PlayScene: " + scenePath);

		// Czas na timer delayedDialogue + start sceny, potem czekaj aż cicho.
		// sawScene = scena faktycznie wystartowala - delayedDialogue moze
		// po cichu odrzucic sciezke, wtedy zwracamy false (CR botex M2).
		Sleep(0.6);
		t = 0.0;
		sawScene = false;
		while (t < 45.0)
		{
			if (theGame.IsDialogOrCutscenePlaying() || (npc && npc.IsInGameplayScene()))
			{
				sawScene = true;
			}
			if (t >= 4.0 &&
			    !theGame.IsDialogOrCutscenePlaying() &&
			    !(npc && npc.IsInGameplayScene()) &&
			    !(npc && npc.IsSpeaking()))
			{
				break;
			}
			Sleep(0.5);
			t += 0.5;
		}
		return sawScene;
	}

	// -------------------------------------------------------------------
	// Wspólny wait: latent, czeka aż scena/dialog przestanie grać.
	// Scena blokująca ustawia flagę dialogu, gameplay-scena trzyma aktora
	// w IsInGameplayScene. Grace 4s na start + timeout na fail-start.
	// -------------------------------------------------------------------
	protected latent function WaitForSceneEnd(npc : CNewNPC, optional timeoutSec : float) : bool
	{
		var t              : float;
		var sawScene       : bool;
		var playerReleased : bool;
		var core           : MCM_AutonomousRomanceCore;
		var hud            : CR4ScriptedHud;
		var dm             : CR4HudModuleDialog;
		var idxToPick      : int;

		if (timeoutSec <= 0.0) timeoutSec = 60.0;

		sawScene = false;
		playerReleased = false;
		core = thePlayer.mcm_ar_core;
		dm = NULL;

		Sleep(0.6);
		t = 0.0;
		while (t <= timeoutSec)
		{
			// Auto-pick opcji w scenach FollowWithKiss: wrap OnDialogChoicesSet
			// ustawil pendingPickIdx – tutaj wykonujemy select+accept z malym
			// opoznieniem (jak gracz). Poza uzbrojona scena arAutoPick=false.
			if (core && core.arAutoPick && core.arPendingPickIdx >= 0 &&
			    theGame.GetEngineTimeAsSeconds() - core.arPendingPickAt >= 0.35)
			{
				if (!dm)
				{
					hud = (CR4ScriptedHud)theGame.GetHud();
					if (hud)
					{
						dm = (CR4HudModuleDialog)hud.GetHudModule("DialogModule");
					}
				}
				if (dm)
				{
					// Bufor lokalny: Sleep ponizej jest latent yield – stan
					// core'a moze sie zmienic (disarm z innego watku), wtedy
					// OnDialogOptionAccepted dostalby idx=-1.
					idxToPick = core.arPendingPickIdx;
					core.arPendingPickIdx = -1;
					dm.OnDialogOptionSelected(idxToPick);
					Sleep(0.3);
					dm.OnDialogOptionAccepted(idxToPick);
					MCM_AR_Log("[AR] autoPick: zaakceptowano opcje " + idxToPick);
				}
				else
				{
					core.arPendingPickIdx = -1;
				}
			}
			if (theGame.IsDialogOrCutscenePlaying() || (npc && npc.IsInGameplayScene()))
			{
				sawScene = true;
			}
			// Scena skonczona z perspektywy gracza – oddaj sterowanie od razu.
			// NPC moze jeszcze wychodzic z gameplay-sceny (IsInGameplayScene
			// zostaje kilka sekund po koncu) – to nie powod trzymania locka
			// ruchu na graczu (raportowane "zamrozenie" po scenach).
			if (!playerReleased && sawScene && !theGame.IsDialogOrCutscenePlaying())
			{
				thePlayer.UnblockAction(EIAB_Movement, 'MCM_AR_interaction');
				thePlayer.DisableLookAt();
				playerReleased = true;
			}
			if (t >= 4.0 &&
			    !theGame.IsDialogOrCutscenePlaying() &&
			    !(npc && npc.IsInGameplayScene()) &&
			    !(npc && npc.IsSpeaking()))
			{
				if (!playerReleased)
				{
					thePlayer.UnblockAction(EIAB_Movement, 'MCM_AR_interaction');
					thePlayer.DisableLookAt();
				}
				return sawScene;
			}
			Sleep(0.5);
			t += 0.5;
		}
		// Timeout – bezpiecznik: nigdy nie zostawiaj locka gracza na zawsze.
		if (!playerReleased)
		{
			thePlayer.UnblockAction(EIAB_Movement, 'MCM_AR_interaction');
			thePlayer.DisableLookAt();
		}
		return false;
	}

	// -------------------------------------------------------------------
	// Prawdziwa scena-dialog – dokładna replika ścieżki [E] na towarzyszce
	// (SCMCC.OnPlayerInteract): zabija job-workera (bez tego scena nie może
	// przejąć aktora i umiera po cichu), fakty following, mimiki przed
	// sceną, PreDialogue (fakt allownaughty), LoadResource z logiem NULL,
	// synchroniczny PlayScene. Zwraca false gdy scena nie wystartowała.
	// -------------------------------------------------------------------
	protected latent function PlayDialogueScene(npc : CNewNPC, scenePath : string, optional autoPick : bool) : bool
	{
		var worker : MCM_Worker;
		var scene  : CStoryScene;
		var ok     : bool;
		var scm    : mod_scm;
		var mcm    : mod_scm;
		var core   : MCM_AutonomousRomanceCore;
		var dialogueFree : bool;

		if (!npc || !npc.scmcc) return false;

		// Gate: scena nie startuje w trakcie swiezej kolejki czatu MCME
		dialogueFree = WaitForDialogueFree(10.0);
		if (!dialogueFree)
		{
			MCM_AR_Log("[AR] PlayDialogueScene ABORT: DialogueManager zajety >10s: " + scenePath);
			return false;
		}

		// LoadResource PRZED jakimikolwiek mutacjami stanu/faktow –
		// przy braku sceny wychodzimy czysto.
		scene = (CStoryScene)LoadResource(scenePath, true);
		if (!scene)
		{
			MCM_AR_Log("[AR] PlayDialogueScene FAIL: LoadResource NULL: " + scenePath);
			return false;
		}

		scm = mod_scm_GetSCM();
		mcm = MCM_GetMCM();
		if (!scm || !mcm)
		{
			MCM_AR_Log("[AR] PlayDialogueScene FAIL: SCM/MCM NULL dla " + NameToString(npc.scmcc.data.nam));
			return false;
		}

		if (mcm.JobManager)
		{
			worker = mcm.JobManager.getWorker(npc);
		}
		if (worker)
		{
			worker.forceStop();
		}
		if (npc.GetCurrentStateName() == 'SCMPlayIdleAnim')
		{
			npc.PopState(true);
		}
		npc.EnableCharacterCollisions(false);

		if (npc.scmcc.IsFollowing())
		{
			FactsRemove('mod_scm_fact_following');
			FactsAdd('mod_scm_fact_following', 1, -1);
		}
		else
		{
			FactsRemove('mod_scm_fact_following');
			FactsAdd('mod_scm_fact_following', 0, -1);
		}

		// Jak MCME przed dialogiem: oznacz "była w dialogu" i zreinicjuj mimiki
		npc.scmcc.wasInDialogue = true;
		scm.RefreshMimicsNextStateChange();
		if (scm.NaughtyManager)
		{
			scm.NaughtyManager.PreDialogue(npc);
		}

		// Uzbroj auto-pick tylko dla naszych scen FollowWithKiss – opcja
		// "kiss" z menu hub zostanie wybrana automatycznie (faza 0), a gdy
		// scena wroci do menu, "exit" (faza 1). Nigdy globalnie.
		core = thePlayer.mcm_ar_core;
		if (autoPick && core)
		{
			core.arAutoPick = true;
			core.arPickPhase = 0;
			core.arPendingPickIdx = -1;
			MCM_AR_Log("[AR] autoPick ARMED dla " + NameToString(npc.scmcc.data.nam));
		}
		else if (!autoPick)
		{
			MCM_AR_Log("[AR] autoPick NIE uzbrojony: autoPick=false");
		}
		else
		{
			MCM_AR_Log("[AR] autoPick NIE uzbrojony: core NULL");
		}

		theGame.GetStorySceneSystem().PlayScene(scene, "Input");
		MCM_AR_Log("[AR] PlayDialogueScene: " + scenePath + " dla " + npc.scmcc.data.nam);

		ok = WaitForSceneEnd(npc, 60.0);

		if (core)
		{
			core.arAutoPick = false;
			core.arPickPhase = 0;
			core.arPendingPickIdx = -1;
		}
		return ok;
	}

	// -------------------------------------------------------------------
	// Scena intymna przy "sweet spot" (NaughtyPoint MCME).
	// Zarejestrowane NPC (yen/triss/ciri/keira/shani/syanna): pełny pipeline
	// PreNaughtyWith (action point + delayedDialogue + HideAllExcept).
	// Niezarejestrowane (anarietta/vivienne): własny pipeline z konwencją
	// naughty\<dir>\anywhere.w2scene. Zwraca false gdy brak punktu/sceny.
	// -------------------------------------------------------------------
	protected function HasIntimateScene(npc : CNewNPC) : bool
	{
		if (!npc || !npc.scmcc || !npc.scmcc.specialData) return false;
		if (StrLen(npc.scmcc.specialData.naughtyScene) > 0) return true;
		return StrLen(NaughtyScenePath(npc.scmcc.data.nam)) > 0;
	}

	// Ścisły zasięg dla scen intymnych: sama scena wymaga punktu <=20m
	// (PreNaughtyWith/AddActionPoint działają tylko wtedy). Szerszy notifier
	// (30m) jest na ctx.isNearNaughtySpot – to jest gate kwalifikacji.
	protected function IsOnNaughtyPoint() : bool
	{
		var pt : mod_scm_NaughtyPoint;

		if (mod_scm_GetSCM() && mod_scm_GetSCM().NaughtyManager && mod_scm_GetSCM().NaughtyManager.naughtyPoints)
		{
			pt = mod_scm_GetSCM().NaughtyManager.naughtyPoints.GetClosestPoint(20.0);
			if (pt) return true;
		}
		return false;
	}

	// Pelne sciezki scen intymnych dla NPC bez rejestracji w specialData
	// (kompletne literaly – precheck weryfikuje je wobec indeksu bundle)
	protected function NaughtyScenePath(npcName : name) : string
	{
		switch (npcName)
		{
			case 'anna_henrietta': return "dlc\mod_spawn_companions\naughty\anarietta\anywhere.w2scene";
			// 'vivienne' = forma ludzka (vivienne_bird = przekleta forma ptasia)
			case 'sq701_vivienne': return "dlc\mod_spawn_companions\naughty\vivienne\anywhere.w2scene";
			case 'becca':          return "dlc\mod_spawn_companions\naughty\cerys\anywhere.w2scene";
		}
		return "";
	}

	protected latent function PlayIntimateScene(npc : CNewNPC) : bool
	{
		var worker : MCM_Worker;
		var point  : mod_scm_NaughtyPoint;
		var nm     : name;
		var path   : string;
		var scene  : CStoryScene;
		var ok     : bool;
		var scm    : mod_scm;
		var mcm    : mod_scm;
		var amb    : MCM_AmbientRomanceChannel;
		var gi     : int;
		var nowT   : float;
		var greetT : array<float>;
		var dialogueFree : bool;

		if (!npc || !npc.scmcc) return false;
		nm = npc.scmcc.data.nam;

		// Gate: scena nie startuje w trakcie swiezej kolejki czatu MCME
		dialogueFree = WaitForDialogueFree(10.0);
		if (!dialogueFree)
		{
			MCM_AR_Log("[AR] IntimateScene ABORT: DialogueManager zajety >10s dla " + NameToString(nm));
			return false;
		}

		scm = mod_scm_GetSCM();
		mcm = MCM_GetMCM();
		if (!scm || !mcm || !scm.NaughtyManager || !scm.NaughtyManager.naughtyPoints)
		{
			MCM_AR_Log("[AR] IntimateScene FAIL: SCM/MCM/NaughtyManager NULL dla " + NameToString(nm));
			return false;
		}

		// Scena wymaga action pointu w zasiegu – sprawdzamy sami (20m jak MCME)
		point = scm.NaughtyManager.naughtyPoints.GetClosestPoint(20.0);
		if (!point)
		{
			MCM_AR_Log("[AR] IntimateScene FAIL: brak NaughtyPoint <=20m dla " + NameToString(nm));
			return false;
		}

		// Sciezka manualna: LoadResource PRZED mutacjami stanu –
		// przy braku sceny wychodzimy czysto.
		if (!(npc.scmcc.specialData && StrLen(npc.scmcc.specialData.naughtyScene) > 0))
		{
			path = NaughtyScenePath(nm);
			scene = (CStoryScene)LoadResource(path, true);
			if (!scene)
			{
				MCM_AR_Log("[AR] IntimateScene FAIL: LoadResource NULL: " + path);
				return false;
			}
		}

		if (mcm.JobManager)
		{
			worker = mcm.JobManager.getWorker(npc);
		}
		if (worker)
		{
			worker.forceStop();
		}
		if (npc.GetCurrentStateName() == 'SCMPlayIdleAnim')
		{
			npc.PopState(true);
		}
		npc.EnableCharacterCollisions(false);
		npc.scmcc.wasInDialogue = true;
		scm.RefreshMimicsNextStateChange();

		if (npc.scmcc.specialData && StrLen(npc.scmcc.specialData.naughtyScene) > 0)
		{
			// PreNaughtyWith wewnatrz robi mod_scm_GetNPC(nam, ST_Special, false)
			// – jak zwroci NULL, MCME cicho nic nie odpala. Diag pre-check.
			if (!mod_scm_GetNPC(nm, ST_Special, false))
			{
				MCM_AR_Log("[AR] IntimateScene WARN: GetNPC(ST_Special) NULL dla " +
				           NameToString(nm) + " – PreNaughtyWith prawdopodobnie nic nie zrobi");
			}
			// Zarejestrowana: pelny pipeline MCME (AddActionPoint + scene + hide)
			scm.NaughtyManager.PreNaughtyWith(nm);
			MCM_AR_Log("[AR] IntimateScene (PreNaughtyWith) dla " + NameToString(nm));
		}
		else
		{
			point.AddActionPoint();
			scm.NaughtyManager.HideAllExcept(npc);
			theGame.GetStorySceneSystem().PlayScene(scene, "Input");
			MCM_AR_Log("[AR] IntimateScene (manual): " + path + " dla " + NameToString(nm));
		}

		ok = WaitForSceneEnd(npc, 90.0);
		MCM_AR_Log("[AR] IntimateScene end: ok=" + ok + " dla " + NameToString(nm));
		// Bezpiecznik: PostNaughty = superset ShowAllExcept (re-equip ekwipunku,
		// reset appearance, odsloniecie reszty) – idempotentne, gdy scena sama
		// juz zawolala mod_scm_Naughty(true); ratuje gdy scena umarla w polowie.
		// Re-guard: WaitForSceneEnd jest latent (do 90s) – scm moglo zniknac
		if (scm && scm.NaughtyManager)
		{
			scm.NaughtyManager.PostNaughty();
		}

		// Scena intymna chowa pozostale towarzyszki (HideAllExcept) – wypadaja
		// z tagu 'GeraltsBFF' i po odslonieciu wygladaja jak "powrot po
		// absencji" (falszywe powitania). Przestempluj bookkeeping na "teraz".
		// Uwaga: greetSeenTime[i]=x przez obiekt nie dziala (array = kopia) –
		// kopiujemy cala tablice, modyfikujemy, przypisujemy z powrotem.
		amb = thePlayer.mcm_ar_ambient;
		if (amb)
		{
			nowT = theGame.GetEngineTimeAsSeconds();
			greetT = amb.greetSeenTime;
			for (gi = 0; gi < greetT.Size(); gi += 1)
			{
				greetT[gi] = nowT;
			}
			amb.greetSeenTime = greetT;
		}
		return ok;
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
			MCM_AR_Log("[AR] Zarejestrowano akcję: " + action.id);
		}
	}

	// -----------------------------------------------------------------------
	// Główna pętla selekcji i wykonania
	// -----------------------------------------------------------------------
	public latent function TryExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext, optional out eligibleCount : int, optional ambientOnly : bool) : bool
	{
		var eligible    : array<MCM_RomanceInteraction>;
		var action      : MCM_RomanceInteraction;
		var totalWeight : int;
		var roll        : int;
		var i           : int;
		var npcName     : name;
		var result      : bool;

		eligibleCount = 0;
		if (!MCM_AR_GetConfig().IsEnabled()) return false;

		npcName = npc.scmcc.data.nam;

		// Zbierz kwalifikujące się akcje dla tego NPC
		for (i = 0; i < actions.Size(); i += 1)
		{
			action = actions[i];
			if (!action) continue;

			// Filtr: akcja musi pasować do NPC lub być ogólna
			if (IsNameValid(action.targetNpc) && action.targetNpc != npcName) continue;

			// Filtr kanału: ambient = tylko RTT_OneLiner, staged = reszta
			if (ambientOnly)
			{
				if (action.triggerType != RTT_OneLiner) continue;
			}
			else
			{
				if (action.triggerType == RTT_OneLiner) continue;
			}

			if (action.CanExecute(npc, player, ctx))
			{
				eligible.PushBack(action);
				totalWeight += action.weight;
			}
		}
		eligibleCount = eligible.Size();

		if (eligible.Size() == 0) return false;
		// Akcje zewnetrznych paczek moga miec weight=0 – nie losuj z zera.
		if (totalWeight <= 0) return false;

		// Ważone losowanie akcji
		roll = RandRange(totalWeight, 0);
		for (i = 0; i < eligible.Size(); i += 1)
		{
			roll -= eligible[i].weight;
			if (roll < 0)
			{
				// Staged channel: globalny lock na czas Execute (propozycja+scena).
				// Odmowa -> false, ale busy i tak zwalniamy i liczymy post-cd.
				if (!ambientOnly && !MCM_AR_GetCore().BeginStagedInteraction(npc))
				{
					return false;
				}
				eligible[i].MarkAttempted();
				result = eligible[i].Execute(npc, player, ctx);
				if (!ambientOnly)
				{
					MCM_AR_GetCore().EndStagedInteraction();
				}
				if (result)
				{
					eligible[i].MarkExecuted();
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

	// Dostęp do listy akcji na potrzeby diagnostyki (ar_eval)
	public function GetAction(index : int) : MCM_RomanceInteraction
	{
		if (index >= 0 && index < actions.Size())
		{
			return actions[index];
		}
		return NULL;
	}

	public function GetActionCount() : int
	{
		return actions.Size();
	}
}

// ---------------------------------------------------------------------------
// Specjalna akcja: HUD Prompt Input Listener
// (zarejestruj odpowiedź gracza na prompt [C])
// ---------------------------------------------------------------------------

@addMethod(CR4Player)
event OnMCM_AR_ConsentKey(action : SInputAction)
{
	if (IsPressed(action))
	{
		if (FactsQuerySum('mcme_ar_awaiting_consent') > 0)
		{
			// Eventowy licznik pressow - ShowConsentPrompt liczy delte
			// i okno 0.7s; przetrwa klikniecia <50ms bez pollingu
			FactsAdd('mcme_ar_consent_given', 1);
		}
	}
}

// Consent prompt handler jest obslugiwany przez event OnMCM_AR_ConsentKey zarejestrowany na CR4Player.
// USUNIETO @wrapMethod(CNewNPC) OnInteraction - powodowal shadowing wrappera z modMCME_RemasteredNPCHooks.ws
// i calkowicie blokowal klawisz [E] (rozmowe z towarzyszkami)!


// Przyjazna nazwa wyświetlana na ekranie HUD dla towarzyszek
function MCM_AR_GetCompanionDisplayName(npc : CNewNPC) : string
{
	var nam : name;
	if (npc && npc.scmcc && npc.scmcc.data)
	{
		nam = npc.scmcc.data.nam;
	}
	else if (npc)
	{
		nam = npc.GetVoicetag();
	}

	switch (nam)
	{
		case 'cirilla':
		case 'ciri':             return "Ciri";
		case 'yennefer':         return "Yennefer";
		case 'triss':            return "Triss";
		case 'keira_metz':
		case 'keira':            return "Keira";
		case 'shani':            return "Shani";
		case 'anna_henrietta':   return "Anna Henrietta";
		case 'sq701_vivienne':
		case 'vivienne':         return "Vivienne";
		case 'syanna':           return "Syanna";
		case 'becca':            return "Cerys";
		case 'jutta':            return "Jutta";
		case 'filippa':          return "Filippa";
		case 'corinne':          return "Corinne";
		case 'frida':            return "Frida";
		case 'rosa_var_attre':   return "Rosa var Attre";
		case 'edna_var_attre':   return "Edna var Attre";
		case 'margarita':        return "Margarita";
		case 'fringilla':        return "Fringilla";
		case 'cantarella':       return "Cantarella";
		case 'tamara':           return "Tamara";
		default:
			if (npc)
				return npc.GetName();
			return "Towarzyszka";
	}
}

// ---------------------------------------------------------------------------
// Sonda dostępności animacji w animsecie danego NPC (§15.1 – cicha degradacja).
// Replikuje scmcc.PlayAnimSimple (SpawnCompanionsSCMCC l.403), ale trzyma
// zwrot PlaySlotAnimationAsync: false = animacji brak w w2anims tego NPC
// LUB slot zajęty – sondować w stanie idle, ewentualnie drugim podejściem.
// Zwraca true, gdy którykolwiek slot przyjął animację.
// ---------------------------------------------------------------------------
function MCM_AR_ProbeAnim(npc : CNewNPC, animName : name) : bool
{
	var animComp : CMovingPhysicalAgentComponent;
	var settings : SAnimatedComponentSlotAnimationSettings;
	var played   : bool;

	if (!npc || !IsNameValid(animName))
		return false;

	animComp = (CMovingPhysicalAgentComponent)npc.GetComponentByClassName('CMovingPhysicalAgentComponent');
	if (!animComp)
		return false;

	settings.blendIn  = 0.2;
	settings.blendOut = 0.2;

	played = animComp.PlaySlotAnimationAsync(animName, 'NPC_ANIM_SLOT', settings);
	if (!played)
	{
		played = animComp.PlaySlotAnimationAsync(animName, 'GAMEPLAY_SLOT', settings);
	}
	return played;
}

// ---------------------------------------------------------------------------
// Wrap: engine zglasza nowe menu wyborow dialogowych (OnDialogChoicesSet
// strzela przy kazdym pokazaniu – tez powrocie do hubu po kiss). Gdy nasza
// scena FollowWithKiss ma uzbrojony auto-pick (arAutoPick na core), core
// wybiera opcje; WaitForSceneEnd dokonuje select+accept. Poza naszymi
// scenami arAutoPick=false – zwykly dialog przechodzi nietkniety.
// ---------------------------------------------------------------------------
@wrapMethod(CR4HudModuleDialog)
function OnDialogChoicesSet(choices : array<SSceneChoice>, alternativeUI : bool)
{
	wrappedMethod(choices, alternativeUI);

	if (thePlayer && thePlayer.mcm_ar_core)
	{
		if (choices.Size() > 0)
		{
			thePlayer.mcm_ar_core.MCM_AR_OnDialogChoices(choices);
		}
		else
		{
			MCM_AR_Log("[AR] OnDialogChoicesSet: puste choices (flush)");
		}
	}
	else
	{
		MCM_AR_Log("[AR] OnDialogChoicesSet: thePlayer/core NULL, n=" + choices.Size());
	}
}

// Drugi wrap na nizszej warstwie: SendDialogChoicesToUI dostaje wybor
// takze przez OnMissingContentDialogClosed i ewentualne sciezki omijajace
// OnDialogChoicesSet. Podwojny strzal na ten sam zestaw jest bezpieczny –
// handler ma guard arPendingPickIdx>=0.
@wrapMethod(CR4HudModuleDialog)
function SendDialogChoicesToUI(choices : array<SSceneChoice>, allowContentMissingDialog : bool)
{
	wrappedMethod(choices, allowContentMissingDialog);

	if (thePlayer && thePlayer.mcm_ar_core)
	{
		if (choices.Size() > 0)
		{
			thePlayer.mcm_ar_core.MCM_AR_OnDialogChoices(choices);
		}
	}
}

