/*****************************************************************************/
/* MCME Autonomous Romance - Interaction Framework                           */
/* Struktura kontekstu, klasy bazowe akcji, rejestr i procedury wykonawcze  */
/*****************************************************************************/

// Typ wyzwalacza interakcji (4 tiery z planu)

enum ERomanceTriggerType
{
	RTT_OneLiner,   // Tier 1: autonomiczny komentarz głosowy
	RTT_Gesture,    // Tier 2: podejście + gest / pocałunek w świecie
	RTT_Prompt,     // Tier 3: zaproszenie przez HUD prompt [C]
	RTT_Scene,      // Tier 4: pełna scena CStoryScene (tylko w strefach relaksu)
}

// Kontekst otoczenia przekazywany do każdej akcji

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
	// Kontekstowe T1: pogoda silnikowa (WT_*), jazda konna, łódź, wnętrze
	public var weatherName     : name;
	public var playerMounted   : bool;
	public var playerOnBoat    : bool;
	public var isInInterior    : bool;
}

// Klasa bazowa pojedynczej interakcji romantycznej

class MCM_RomanceInteraction
{
	// [E2E] publiczne wrappery dla suity testowej (bez zmiany logiki)
	public function E2E_AutonomousScenePath(npc : CNewNPC, isHug : bool) : string
	{
		return AutonomousScenePath(npc, isHug);
	}

	public function E2E_NaughtyScenePath(npcName : name) : string
	{
		return NaughtyScenePath(npcName);
	}

	public function E2E_ResolveIntimateScenePath(npc : CNewNPC) : string
	{
		return ResolveIntimateScenePath(npc);
	}

	public function E2E_IsOnNaughtyPoint() : bool
	{
		return IsOnNaughtyPoint();
	}

	public latent function E2E_ShowConsentPrompt(promptText : string, timeoutSec : float, optional npc : CNewNPC) : bool
	{
		var ok : bool;
		ok = ShowConsentPrompt(promptText, timeoutSec, npc);
		return ok;
	}
	public var id              : name;
	public var targetNpc       : name;   // '' = dowolny towarzysz romansowy
	public var minAffinity     : int;
	public var cooldownSeconds : float;
	public var triggerType     : ERomanceTriggerType;
	public var weight          : int;    // priorytet losowania (wyższy = częściej)
	public var isTimeCritical  : bool;   // okno czasowe: prio w kanale ambient, omija los presetu
	default isTimeCritical = false;

	// Treść barku – data-driven (klasa akcji ustawia default, retune bez kodu)
	public var lineId          : int;    // voiced line id (0 = tylko tekst HUD)
	public var lineText        : string; // fallback EN, gdy brak lokalizacji dla lineId
	public var lineKey         : string; // klucz w3strings (ar_line_*) - lokalizowany fallback
	public var barkMimic       : name;   // semantyczna mimika ('flirt'/'concern'/'')
	public var barkVoiceset    : name;   // voiceset NPC zamiast lineId (np. 'greeting_geralt')
	default lineId = 0;

	// Akcje oparte o sceny ar_*: brak wpisu w AutonomousScenePath dla NPC
	// = nigdy eligible (blocked: no_scene), zamiast promptu i cichego faila.
	public var usesAutonomousKiss : bool;
	public var usesAutonomousHug  : bool;
	default usesAutonomousKiss = false;
	default usesAutonomousHug  = false;

	// Czas ostatniego wykonania (czas silnika, tylko RAM – nie zaśmieca save)
	private var lastExecTime   : float;
	default lastExecTime = -9999.0;

	// Niezalezne cooldowny i backoffy per-NPC dla akcji z pustym targetNpc (wildcard)
	private var compCooldownNpcs  : array<name>;
	private var compCooldownTimes : array<float>;
	private var compRejectNpcs    : array<name>;
	private var compRejectTimes   : array<float>;
	private var compRejectCounts  : array<int>;

	// Backoff po odmowie/zignorowaniu propozycji (5 -> 15 -> 30 min)
	private var rejectedUntil  : float;
	private var rejectCount    : int;
	default rejectedUntil = -1.0;
	default rejectCount = 0;

	// Scratch na wyniki latent (latent nie moze byc w 'if'/'var' - W3Script).
	protected var approachOk : bool;

	// Stan podążania przed rozpoczęciem interakcji.
	protected var npcWasFollowing : bool;
	default npcWasFollowing = false;

	public function ResetCooldown()
	{
		lastExecTime = -9999.0;
		rejectedUntil = -1.0;
		rejectCount = 0;
		compCooldownNpcs.Clear();
		compCooldownTimes.Clear();
		compRejectNpcs.Clear();
		compRejectTimes.Clear();
		compRejectCounts.Clear();
	}

	// Pomocniczy index search dla tablic name (WitcherScript nie posiada array.Find)
	private function FindCompNameIndex(compName : name, arr : array<name>) : int
	{
		var i : int;
		for (i = 0; i < arr.Size(); i += 1)
		{
			if (arr[i] == compName) return i;
		}
		return -1;
	}

	// Sprawdzenie cooldownu i reject backoffu dla konkretnego NPC
	public function IsCompanionOnCooldown(compName : name, cooldownSec : float) : bool
	{
		var nowT : float;
		var idx  : int;

		nowT = theGame.GetEngineTimeAsSeconds();
		idx = FindCompNameIndex(compName, compCooldownNpcs);
		if (idx >= 0)
		{
			if ((nowT - compCooldownTimes[idx]) < cooldownSec)
			{
				return true;
			}
		}
		idx = FindCompNameIndex(compName, compRejectNpcs);
		if (idx >= 0)
		{
			if (compRejectTimes[idx] > 0.0 && nowT < compRejectTimes[idx])
			{
				return true;
			}
		}
		return false;
	}

	public function RecordCompanionExecution(compName : name)
	{
		var nowT : float;
		var idx  : int;

		nowT = theGame.GetEngineTimeAsSeconds();
		idx = FindCompNameIndex(compName, compCooldownNpcs);
		if (idx >= 0)
		{
			compCooldownTimes[idx] = nowT;
		}
		else
		{
			compCooldownNpcs.PushBack(compName);
			compCooldownTimes.PushBack(nowT);
		}
		idx = FindCompNameIndex(compName, compRejectNpcs);
		if (idx >= 0)
		{
			compRejectTimes[idx] = -1.0;
			compRejectCounts[idx] = 0;
		}
	}

	public function RecordCompanionRejection(compName : name)
	{
		var nowT   : float;
		var idx    : int;
		var delay  : float;
		var rCount : int;

		nowT = theGame.GetEngineTimeAsSeconds();
		idx = FindCompNameIndex(compName, compRejectNpcs);
		if (idx < 0)
		{
			compRejectNpcs.PushBack(compName);
			compRejectTimes.PushBack(-1.0);
			compRejectCounts.PushBack(0);
			idx = compRejectNpcs.Size() - 1;
		}
		rCount = compRejectCounts[idx] + 1;
		compRejectCounts[idx] = rCount;
		if (rCount <= 1)       delay = 300.0;
		else if (rCount == 2)  delay = 900.0;
		else                   delay = 1800.0;
		compRejectTimes[idx] = nowT + delay;
		MCM_AR_Log("[AR] Companion Reject: " + id + " comp=" + NameToString(compName) + " backoff " + delay + "s (x" + rCount + ")");
	}

	// Walidacja riga: true dla standardowego woman_base, false dla noble_woman_base / monster rig
	public function IsWomanBaseCompanion(npc : CNewNPC) : bool
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

	public function HasNaughtyScene(npc : CNewNPC) : bool
	{
		var nm : name;
		if (!npc || !npc.scmcc || !npc.scmcc.data) return false;
		nm = npc.scmcc.data.nam;
		if (npc.scmcc.specialData && StrLen(npc.scmcc.specialData.naughtyScene) > 0) return true;
		if (NaughtyScenePath(nm) != "") return true;
		if (IsWomanBaseCompanion(npc) && MCM_AR_SceneExists("dlc\mod_mcme_autonomous_romance\dialogue\ar_shani_intimate_outdoor.w2scene"))
		{
			return true;
		}
		return false;
	}

	// Odmowa/ignorowanie promptu: narastający cooldown na tę akcję
	public function MarkRejected(optional compName : name)
	{
		var backoff : float;
		rejectCount += 1;
		if (rejectCount <= 1)       backoff = 300.0;
		else if (rejectCount == 2)  backoff = 900.0;
		else                        backoff = 1800.0;
		rejectedUntil = theGame.GetEngineTimeAsSeconds() + backoff;
		if (compName != '')
		{
			RecordCompanionRejection(compName);
		}
		else if (targetNpc != '')
		{
			RecordCompanionRejection(targetNpc);
		}
		MCM_AR_Log("[AR] Reject: " + id + " backoff " + backoff + "s (x" + rejectCount + ")");
	}

	// Próba wykonania akcji (ustawia cooldown inicjatywy).
	public function MarkAttempted()
	{
		lastExecTime = theGame.GetEngineTimeAsSeconds();
	}

	// Sukces: cooldown + reset backoffu odmowy (wołane przez registry).
	public function MarkExecuted(optional compName : name)
	{
		lastExecTime = theGame.GetEngineTimeAsSeconds();
		rejectedUntil = -1.0;
		rejectCount = 0;
		if (compName != '')
		{
			RecordCompanionExecution(compName);
		}
		else if (targetNpc != '')
		{
			RecordCompanionExecution(targetNpc);
		}
	}

	public function CanExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		return GetBlockReason(npc, player, ctx) == "";
	}

	// Powód blokady ("" = eligible) – używany też przez ar_eval diagnostykę
	public function GetBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		var now        : float;
		var autoReason : string;
		var compName   : name;
		var idx        : int;

		now = theGame.GetEngineTimeAsSeconds();

		// 1. Sprawdzenie per-towarzysz dla akcji uniwersalnych (wildcard)
		if (targetNpc == '' && npc && npc.scmcc && npc.scmcc.data)
		{
			compName = npc.scmcc.data.nam;
			idx = FindCompNameIndex(compName, compRejectNpcs);
			if (idx >= 0 && compRejectTimes[idx] > 0.0 && now < compRejectTimes[idx])
			{
				return "rejected_backoff";
			}
			idx = FindCompNameIndex(compName, compCooldownNpcs);
			if (idx >= 0 && (now - compCooldownTimes[idx]) < cooldownSeconds)
			{
				return "cooldown";
			}
		}

		// 2. Globalny cooldown i backoff akcji (lub akcji dedykowanej z targetNpc)
		if (rejectedUntil > 0.0 && now < rejectedUntil) return "rejected_backoff";
		if ((now - lastExecTime) < cooldownSeconds) return "cooldown";

		// ForceRomance omija prog affinity
		if (minAffinity > 0 && !MCM_AR_GetConfig().IsForceRomanceOn())
		{
			if (!MCM_AR_GetAffinity().MeetsMinAffinity(npc.scmcc.data.nam, minAffinity))
				return "affinity";
		}

		// Zazdrosc: Tier2+ wymagaja braku rywalek
		if (ctx.hasRivals && MCM_AR_GetConfig().IsJealousyModeOn())
		{
			if (triggerType == RTT_Gesture || triggerType == RTT_Prompt || triggerType == RTT_Scene)
				return "jealousy";
		}

		if (VecDistance(player.GetWorldPosition(), npc.GetWorldPosition()) > 15.0)
			return "distance";

		if (usesAutonomousKiss)
		{
			autoReason = AutonomousSceneBlockReason(npc, false);
			if (autoReason != "") return autoReason;
		}
		if (usesAutonomousHug)
		{
			autoReason = AutonomousSceneBlockReason(npc, true);
			if (autoReason != "") return autoReason;
		}

		// Warunki podklas (noc/ogien/HP/kontekst)
		return GetExtraBlockReason(npc, player, ctx);
	}

	// Powody blokad podklas ("" = eligible). Podklasy nadpisuja TYLKO to -
	// jedno zrodlo prawdy gatingu, ar_eval wypisuje realny powod.
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
		var txt      : string;
		var core     : MCM_AutonomousRomanceCore;

		if (!npc) return;
		if (IsNameValid(barkMimic))
		{
			PlayMimic(npc, barkMimic);
		}
		// Napis HUD: w3strings (ar_line_*) w jezyku gry, fallback EN.
		txt = AR_T(lineKey, lineText);
		core = MCM_AR_GetCore();
		// Voiceset ma pierwszenstwo (zawsze glos tego NPC). NPC z cache
		// voiceset-miss pomija probe - ten sam efekt, zero spamu w logu.
		if (IsNameValid(barkVoiceset) && (!core || !core.MCM_AR_IsVoicesetMissing(npc.scmcc.data.nam)))
		{
			vsPlayed = npc.PlayVoiceset(100, barkVoiceset);
			if (vsPlayed)
			{
				// sam napis HUD z pola tekstu (bez podwójnego PlayLine)
				if (StrLen(txt) > 0)
				{
					PlayOneLiner(npc, 0, txt);
				}
			}
			else
			{
				// Cicha degradacja (ARCHITECTURE §15.1): brak voicesetu
				// -> fallback na lineId + HUD; log tylko przy 1. missie.
				MCM_AR_Log("[AR] voiceset missing '" + NameToString(barkVoiceset) + "' on " + NameToString(npc.scmcc.data.nam) + " - fallback lineId (cached)");
				if (core) core.MCM_AR_MarkVoicesetMissing(npc.scmcc.data.nam);
				if (lineId > 0 || StrLen(txt) > 0)
				{
					PlayOneLiner(npc, lineId, txt);
				}
			}
		}
		else if (lineId > 0 || StrLen(txt) > 0)
		{
			PlayOneLiner(npc, lineId, txt);
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

		// lineID<=0 = sam napis HUD
		if (lineID > 0)
		{
			npc.PlayLine(lineID, true);
		}

		if (lineID > 0)
		{
			localizedLine = GetLocStringById(lineID);
		}
		if (localizedLine == "")
		{
			localizedLine = lineText;
		}

		speakerName = MCM_AR_GetCompanionDisplayName(npc);
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

	// Mimiki: 'flirt'/'concern' to nazwy semantyczne mapowane na realne
	// animy z w2anims (surowe nazwy padaly po cichu = martwa twarz).
	protected function PlayMimic(npc : CNewNPC, mimicName : name)
	{
		var anim   : name;
		var played : bool;

		if (!npc || !npc.scmcc) return;

		switch (mimicName)
		{
			case 'flirt':
			case 'smile':   anim = 'happy_anim_face'; break;
			case 'concern': anim = 'sad_anim_face';   break;
			default:        anim = mimicName;         break;
		}

		played = npc.PlayMimicAnimationAsync(anim);
		if (!played)
		{
			MCM_AR_Log("[AR] PlayMimic FAIL: no anim '" + NameToString(anim) + "' for " + NameToString(npc.scmcc.data.nam));
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

	// Propy animacji (kielich/kufel): sprzatanie snapshot-delta - usuwamy
	// WYLACZNIE itemy spoza snapshotu (nigdy bron/zbroje/questowe).
	// Usuwanie jak vanilla DestroyNotWantedItems (bez DropItemFromSlot).
	protected var propSnapshot      : array<SItemUniqueId>;
	protected var propSnapshotNpc   : CNewNPC;
	protected var propSnapshotValid : bool;

	protected function IsInPropSnapshot(itemId : SItemUniqueId) : bool
	{
		var i : int;
		for (i = 0; i < propSnapshot.Size(); i += 1)
		{
			if (propSnapshot[i] == itemId) return true;
		}
		return false;
	}

	// true = to nie wyposazenie bojowe/pancerz/quest, mozna go usunac jako prop
	protected function IsRemovableProp(inv : CInventoryComponent, itemId : SItemUniqueId) : bool
	{
		if (!inv || !inv.IsIdValid(itemId)) return false;
		if (inv.IsItemWeapon(itemId) || inv.IsItemSecondaryWeapon(itemId) || inv.IsItemFists(itemId)) return false;
		if (inv.IsItemAnyArmor(itemId) || inv.IsItemQuest(itemId)) return false;
		return true;
	}

	// Propy z 4 slotow rak. Sloty propow ('r_hand','l_hand') bez guardu
	// IsItemQuest (kielichy questowe tez wylatuja); sloty broni - pelne guardy.
	protected function RemoveHandSlotProps(inv : CInventoryComponent)
	{
		var slots  : array<name>;
		var itemId : SItemUniqueId;
		var i      : int;

		if (!inv) return;
		slots.PushBack('r_hand');
		slots.PushBack('l_hand');
		slots.PushBack('r_weapon');
		slots.PushBack('l_weapon');
		for (i = 0; i < slots.Size(); i += 1)
		{
			itemId = inv.GetItemFromSlot(slots[i]);
			if (!inv.IsIdValid(itemId)) continue;
			if (IsInPropSnapshot(itemId)) continue;

			if (slots[i] == 'r_hand' || slots[i] == 'l_hand')
			{
				if (!inv.IsItemWeapon(itemId) && !inv.IsItemSecondaryWeapon(itemId) && !inv.IsItemFists(itemId) && !inv.IsItemAnyArmor(itemId))
				{
					inv.UnmountItem(itemId, true);
					inv.RemoveItem(itemId, -1);
				}
			}
			else
			{
				if (IsRemovableProp(inv, itemId))
				{
					inv.UnmountItem(itemId, true);
					inv.RemoveItem(itemId, -1);
				}
			}
		}
	}

	// Wolac PRZED animacja picia. Zapisuje co NPC juz trzyma/ma zamontowane.
	protected function SnapshotHeldItems(npc : CNewNPC)
	{
		var inv      : CInventoryComponent;
		var allItems : array<SItemUniqueId>;
		var i        : int;

		propSnapshot.Clear();
		propSnapshotValid = false;
		propSnapshotNpc   = NULL;
		if (!npc) return;
		inv = npc.GetInventory();
		if (!inv) return;

		inv.GetAllItems(allItems);
		for (i = 0; i < allItems.Size(); i += 1)
		{
			if (inv.IsItemHeld(allItems[i]) || inv.IsItemMounted(allItems[i]))
			{
				propSnapshot.PushBack(allItems[i]);
			}
		}
		propSnapshotNpc   = npc;
		propSnapshotValid = true;
	}

	// Sprzata propy po animacji (wspolny punkt: koniec sekwencji, abort walka,
	// EndSoft, EndInteraction). cancelAnim=true: najpierw zatrzymaj slot-anim,
	// zeby prop sie nie przyczepil ponownie.
	public function CleanHandProps(npc : CNewNPC, optional cancelAnim : bool)
	{
		var inv      : CInventoryComponent;
		var allItems : array<SItemUniqueId>;
		var i        : int;

		if (!npc || !propSnapshotValid || propSnapshotNpc != npc) return;

		if (cancelAnim) npc.ActionCancelAll();

		inv = npc.GetInventory();
		if (inv)
		{
			RemoveHandSlotProps(inv);

			// Delta: held/mounted, a nieobecne w snapshocie
			inv.GetAllItems(allItems);
			for (i = 0; i < allItems.Size(); i += 1)
			{
				if ((inv.IsItemHeld(allItems[i]) || inv.IsItemMounted(allItems[i]))
				    && !IsInPropSnapshot(allItems[i]) && IsRemovableProp(inv, allItems[i]))
				{
					inv.UnmountItem(allItems[i], true);
					inv.RemoveItem(allItems[i], -1);
				}
			}
		}

		propSnapshot.Clear();
		propSnapshotValid = false;
		propSnapshotNpc   = NULL;
	}

	// Kontrola miedzy krokami sekwencji picia. false = przerwij (despawn/walka).
	protected function DrinkStepOk(npc : CNewNPC) : bool
	{
		if (!npc)
		{
			propSnapshot.Clear();
			propSnapshotValid = false;
			propSnapshotNpc   = NULL;
			return false;
		}
		if (thePlayer.IsInCombat() || npc.IsInCombat())
		{
			CleanHandProps(npc, true);
			return false;
		}
		return true;
	}

	// Jedna sekwencja: start (unosi kielich) -> loop x2 (pije) -> stop (odstawia).
	// Zwraca: 0 = animacja niedostepna, 1 = zagrana w calosci, 2 = przerwana.
	protected latent function RunDrinkSequence(npc : CNewNPC, startAnim : name, loopAnim : name, stopAnim : name) : int
	{
		if (!MCM_AR_ProbeAnim(npc, startAnim)) return 0;

		Sleep(1.5);
		if (!DrinkStepOk(npc)) return 2;
		MCM_AR_ProbeAnim(npc, loopAnim);
		Sleep(2.5);
		if (!DrinkStepOk(npc)) return 2;
		MCM_AR_ProbeAnim(npc, loopAnim);
		Sleep(2.0);
		if (!DrinkStepOk(npc)) return 2;
		MCM_AR_ProbeAnim(npc, stopAnim);
		Sleep(1.5);
		// DrinkStepOk uniewaznia snapshot i sprzata przy przerwaniu/walce
		if (!DrinkStepOk(npc)) return 2;
		CleanHandProps(npc);
		return 1;
	}

	// Wrapper sekwencji picia: zdejmuje ewentualny idle-job (postac
	// wstaje z siadu) i blokuje tworzenie nowego na czas animacji -
	// ProbeAnim grywa na tych samych slotach co sync-instancja idle.
	public latent function PlayDrinkingAnimation(npc : CNewNPC) : bool
	{
		var r    : bool;
		var core : MCM_AutonomousRomanceCore;

		if (!npc) return false;
		core = MCM_AR_GetCore();
		if (core)
		{
			core.RemoveIdleJobFor(npc);
			core.MarkAmbientBusy(npc);
		}
		r = PlayDrinkingAnimationInner(npc);
		if (core) core.ClearAmbientBusy(npc);
		return r;
	}

	// Bezpieczne odtworzenie animacji picia (toast/degustacja wina/kufla)
	protected latent function PlayDrinkingAnimationInner(npc : CNewNPC) : bool
	{
		var r             : int;
		var followStopped : bool;

		if (!npc) return false;
		SnapshotHeldItems(npc);

		followStopped = false;
		if (npc.scmcc && npc.HasTag('mod_scm_IsFollowing'))
		{
			npc.scmcc.StopFollowing(true);
			followStopped = true;
		}

		// Kobiety: degustacja wina
		r = RunDrinkSequence(npc, 'woman_noble_wine_tasting_start', 'woman_noble_wine_tasting_loop_01', 'woman_noble_wine_tasting_stop');
		if (r == 1)
		{
			if (followStopped && npc.scmcc) npc.scmcc.StartFollowing();
			return true;
		}
		if (r == 2)
		{
			if (followStopped && npc.scmcc) npc.scmcc.StartFollowing();
			return false;
		}

		// Mezczyzni: degustacja lub praca w karczmie
		r = RunDrinkSequence(npc, 'man_noble_stand_tasting_wine_start', 'man_noble_stand_tasting_wine_1', 'man_noble_stand_tasting_wine_stop');
		if (r == 1)
		{
			if (followStopped && npc.scmcc) npc.scmcc.StartFollowing();
			return true;
		}
		if (r == 2)
		{
			if (followStopped && npc.scmcc) npc.scmcc.StartFollowing();
			return false;
		}

		r = RunDrinkSequence(npc, 'man_work_drinking_start', 'man_work_drinking_loop_01', 'man_work_drinking_stop');
		if (r == 1)
		{
			if (followStopped && npc.scmcc) npc.scmcc.StartFollowing();
			return true;
		}
		if (r == 2)
		{
			if (followStopped && npc.scmcc) npc.scmcc.StartFollowing();
			return false;
		}

		CleanHandProps(npc);
		if (followStopped && npc.scmcc) npc.scmcc.StartFollowing();
		return false;
	}

	// Krok tanca: npc zywy + brak walki. Przerwanie -> kod 2 (NPC wraca do idle).
	protected function DanceStepOk(npc : CNewNPC) : bool
	{
		if (!npc) return false;
		if (thePlayer.IsInCombat() || npc.IsInCombat()) return false;
		return true;
	}

	// Mapa nam -> ID zestawu animacji tanca; "" = NPC nie tanczy
	// (refuse/noble-rig/poza whitelist). Silnik nie ma StringToName, wiec zwracamy
	// ID zestawu, a literaly animacji rozwija RunDanceSequence.
	// Audyt: archive\diffbase\v21\DANCE_AUDIT.md.
	public function GetDanceAnimsForNpc(nam : name) : string
	{
		switch (nam)
		{
			case 'triss':
			case 'keira':
			case 'keira_metz':
			case 'shani':
			case 'priscilla':
			case 'pryscilla':
			case 'becca':
			case 'cerys':
			case 'tomira':
			case 'prologue_village_herbalist':
				return "woman_dance";

			case 'cirilla':
			case 'ciri':
				if (thePlayer.MCM_AR_GetConfig().IsCiriAdultMode())
				{
					return "woman_dance";
				}
				return "";
			default:
				return "";
		}
	}

	// Wrapper sekwencji tanca: jak PlayDrinkingAnimation - zdejmuje idle-job
	// i blokuje nowy na czas animacji (wspolne sloty z sync-instancja).
	protected latent function RunDanceSequence(npc : CNewNPC, animSet : string) : int
	{
		var r    : int;
		var core : MCM_AutonomousRomanceCore;

		if (!npc) return 0;
		core = MCM_AR_GetCore();
		if (core)
		{
			core.RemoveIdleJobFor(npc);
			core.MarkAmbientBusy(npc);
		}
		r = RunDanceSequenceInner(npc, animSet);
		if (core) core.ClearAmbientBusy(npc);
		return r;
	}

	// Sekwencja tanca wzorowana na RunDrinkSequence, ale bez propsow.
	// Zwraca: 0 = brak zestawu/animacji na rigu, 1 = zagrana w calosci, 2 = przerwana.
	protected latent function RunDanceSequenceInner(npc : CNewNPC, animSet : string) : int
	{
		var followStopped : bool;

		followStopped = false;
		if (npc && npc.scmcc && npc.HasTag('mod_scm_IsFollowing'))
		{
			npc.scmcc.StopFollowing(true);
			followStopped = true;
		}

		if (animSet == "woman_dance")
		{
			if (!MCM_AR_ProbeAnim(npc, 'woman_work_stand_dancing_start'))
			{
				if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
				return 0;
			}
			Sleep(2.0);
			if (!DanceStepOk(npc))
			{
				if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
				return 2;
			}
			MCM_AR_ProbeAnim(npc, 'woman_work_prostitute_dance_01');
			Sleep(6.0);
			if (!DanceStepOk(npc))
			{
				if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
				return 2;
			}
			MCM_AR_ProbeAnim(npc, 'woman_work_prostitute_dance_02');
			Sleep(6.0);
			if (!DanceStepOk(npc))
			{
				if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
				return 2;
			}
			MCM_AR_ProbeAnim(npc, 'woman_work_prostitute_dance_03');
			Sleep(6.0);
			if (!DanceStepOk(npc))
			{
				if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
				return 2;
			}
			MCM_AR_ProbeAnim(npc, 'woman_work_stand_dancing_stop');
			Sleep(2.0);
			if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
			return 1;
		}
		if (animSet == "woman_cheering")
		{
			if (!MCM_AR_ProbeAnim(npc, 'woman_cheering_arena_loop_1'))
			{
				if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
				return 0;
			}
			Sleep(4.0);
			if (!DanceStepOk(npc))
			{
				if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
				return 2;
			}
			MCM_AR_ProbeAnim(npc, 'woman_cheering_arena_loop_2');
			Sleep(4.0);
			if (!DanceStepOk(npc))
			{
				if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
				return 2;
			}
			MCM_AR_ProbeAnim(npc, 'woman_cheering_arena_loop_3');
			Sleep(4.0);
			if (!DanceStepOk(npc))
			{
				if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
				return 2;
			}
			MCM_AR_ProbeAnim(npc, 'woman_cheering_arena_loop_4');
			Sleep(4.0);
			if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
			return 1;
		}
		if (followStopped && npc && npc.scmcc) npc.scmcc.StartFollowing();
		return 0;
	}

	// Heal akcji opiekunczych: % max HP Geralta skalowany Affinity
	// (bazowy ulamek * 0.6x..1.4x). Vanilla GainStat jak mikstury.
	protected function HealPlayer(npc : CNewNPC, player : CR4Player, frac : float)
	{
		var amount        : int;
		var aff           : int;
		var effectiveFrac : float;
		var resolver      : MCM_RomanceAffinityResolver;

		if (!player) return;

		resolver = MCM_AR_GetAffinity();
		if (resolver && npc && npc.scmcc && npc.scmcc.data)
		{
			aff = resolver.GetAffinity(npc.scmcc.data.nam);
		}
		else
		{
			aff = 20; // bezpieczny fallback
		}

		if (aff < 0) aff = 0;
		if (aff > 100) aff = 100;

		effectiveFrac = frac * (0.6 + 0.8 * ((float)aff / 100.0));
		amount = RoundMath(player.GetStatMax(BCS_Vitality) * effectiveFrac);
		if (amount < 1) amount = 1;

		player.GainStat(BCS_Vitality, amount);
		player.DisplayHudMessage(AR_Fmt(AR_T("ar_msg_healed", "{1} healed you (+{2} HP)"), MCM_AR_GetCompanionDisplayName(npc), "" + amount));
		MCM_AR_Log("[AR] " + id + ": heal +" + amount + " HP (aff=" + aff + ", effFrac=" + effectiveFrac + ")");
	}

	// Staging interakcji twarzą w twarz:
	// Faza 1 (miękkie podejście): NPC kieruje się asynchronicznie ku graczowi.
	protected latent function SoftApproach(npc : CNewNPC, player : CR4Player, targetDist : float)
	{
		var arCore : MCM_AutonomousRomanceCore;

		if (!npc || !player) return;

		arCore = MCM_AR_GetCore();
		if (arCore)
		{
			arCore.RemoveIdleJobFor(npc);
		}

		// Zapamietaj follow przed ruszeniem - scena moze pozniej zdjac flage
		// (toggle_follow), a EndInteraction musi wiedziec czy wracac do podazania.
		npcWasFollowing = npc.scmcc && npc.scmcc.IsFollowing();

		// Zawieszona (idle-suspend) towarzyska ZOSTAJE na liscie idle; wake-loop
		// ja omija, a wpis sprzata sie sam przy nastepnym wake.

		// Zatrzymanie ruchu towarzyszki przed rozpoczęciem obrotu.
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

	// Czekaj az NPC dojdzie (async goni ruchomego gracza). false = przerwij
	// (gracz >25m, walka, timeout); po false wolaj EndSoft().
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

		// Gdyby HardStage wywolano bez SoftApproach: flaga follow musi byc swieza.
		npcWasFollowing = npc.scmcc && npc.scmcc.IsFollowing();

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

		player.BlockAction(EIAB_Movement, 'MCM_AR_interaction');
		player.EnableDynamicLookAt(npc, 120.0);
		toNpc = npc.GetWorldPosition() - player.GetWorldPosition();
		rot = EulerAngles(0.0, VecHeading(toNpc), 0.0);
		player.TeleportWithRotation(player.GetWorldPosition(), rot);

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
		CleanHandProps(npc);
		npc.DisableLookAt();
		npc.EnableCharacterCollisions(true);
		npc.wasInTalkInteraction = false;
		// Wznowienie podążania bez modyfikacji listy drużyny.
		if (npc.scmcc && npc.scmcc.IsFollowing())
		{
			npc.scmcc.StartFollowing(true);
		}
		// Rekord idle-suspendu umiera z interakcja (martwy wpis blokuje nowe joby).
		if (MCM_AR_GetCore()) MCM_AR_GetCore().RemoveIdleJobFor(npc);
	}

	// Zwolnienie po pelnym stagingu/scenie: odblokuj gracza, wylacz look-at,
	// wznow follow AI i mimiki NPC (mechanizm MCME). Wolaj na KAZDEJ sciezce
	// po HardStage - takze przy bledzie sceny.
	protected latent function EndInteraction(npc : CNewNPC, player : CR4Player)
	{
		var scm : mod_scm;
		var t   : float;

		if (player)
		{
			player.UnblockAction(EIAB_Movement, 'MCM_AR_interaction');
			player.DisableLookAt();
		}
		if (npc)
		{
			// Oczekiwanie na zwolnienie aktora przez scenę dialogową.
			t = 0.0;
			while (npc.IsInGameplayScene() && t < 6.0)
			{
				Sleep(0.25);
				t += 0.25;
			}
			if (npc.IsInGameplayScene())
			{
				MCM_AR_Log("[AR] EndInteraction: IsInGameplayScene >6s - restore follow mimo to (NPC moze utknac)");
			}

			npc.ActionCancelAll();
			CleanHandProps(npc);

			// NPC utknieta w SCMPlayIdleAnim (job MCME): pop - stan nadpisuje lokomocje.
			if (npc.GetCurrentStateName() == 'SCMPlayIdleAnim')
			{
				npc.PopState(true);
			}

			npc.DisableLookAt();
			npc.EnableCharacterCollisions(true);
			npc.wasInTalkInteraction = false;

			// Po scenach .w2scene reaktywuj mimiki (mechanizm MCME); flage
			// ustaw PRZED wznowieniem follow - StartFollowing musi ja widziec.
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

				// Wznowienie podążania według stanu sprzed rozpoczęcia sceny.
				if (npcWasFollowing)
				{
					if (npc.scmcc.IsFollowing())
					{
						// follow zachowany (zwykla suspensja) - lekki restart AI
						npc.scmcc.StartFollowing(true);
					}
					else
					{
						// scena zdjela follow - pelny restore
						// (tag + czlonkostwo w MODSCM_COMPANIONS + AI)
						npc.scmcc.StartFollowing();
						MCM_AR_Log("[AR] EndInteraction: scena zdjela follow - pelny StartFollowing()");
					}
				}
			}
		}
		// Rekord idle-suspendu umiera z interakcja (martwy wpis blokuje nowe joby).
		if (MCM_AR_GetCore()) MCM_AR_GetCore().RemoveIdleJobFor(npc);
	}

	// Wyświetla prompt HUD i oczekuje na potwierdzenie gracza (przytrzymanie [C] ~1s).
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
		var vkC          : int;
		var devVK        : bool;
		var prevAction   : bool;
		var vkTaps       : int;
		var tStart       : float;
		var pl           : CR4Player;
		var evHeld       : bool;
		var actHeld      : bool;
		var prevEvHeld   : bool;
		var consentTag   : string;
		var consentKeys  : array<EInputKey>;
		var holdStartT   : float;
		var lastProbe    : float;

		if (timeoutSec < 20.0) timeoutSec = 20.0;
		step = 0.05;
		heldFor = 0.0;
		lastShow = 0.0;
		lastTapAt = -99.0;
		holdStartT = -99.0;
		tapsSeen = 0;
		vkTaps = 0;
		pressedFresh = false;
		lastProbe = 0.0;
		tStart = theGame.GetEngineTimeAsSeconds();
		elapsed = 0.0;

		// W trybie dev odczytuje stan VK bezpośrednio przez TW3SE.
		devVK = MCM_AR_DevActive();
		vkC = MCM_AR_DevConfigKey('ar_consent_key');
		if (vkC == 0) vkC = 0x43;
		prevAction = IsPressed(theInput.GetAction('MCM_AR_Consent'), true)
		          || IsPressed(theInput.GetAction('SwordSheathe'), true);
		pl = GetWitcherPlayer();
		if (pl)
		{
			pl.mcm_ar_consentHeldC = false;
			pl.mcm_ar_consentHeldS = false;
			pl.mcm_ar_consentPressAt = -1.0;
		}
		if (devVK)
		{
			prevDown = MCM_AR_DevKeyDown(vkC);
			MCM_AR_DevLog("consent: devVK on, vk=" + vkC +
			              " ctx=" + theInput.GetContext());
		}
		else
		{
			prevDown = false;
		}
		theInput.GetCurrentKeysForActionStr("MCM_AR_Consent", consentKeys);
		if (consentKeys.Size() > 0 && consentKeys[0] != IK_None)
		{
			consentTag = "MCM_AR_Consent";
		}
		else
		{
			consentTag = "SwordSheathe";
		}
		fullPrompt = ReplaceTagsToIcons(StrReplaceAll(
			promptText + "  " + AR_T("ar_prompt_consent_hint", "(hold [C] ~1s or tap twice)"),
			"[C]",
			"<<" + consentTag + ">>"));

		FactsRemove('mcme_ar_consent_given');
		FactsAdd('mcme_ar_consent_given', 0);
		FactsRemove('mcme_ar_awaiting_consent');
		FactsAdd('mcme_ar_awaiting_consent', 1);

		thePlayer.DisplayHudMessage(fullPrompt);
		MCM_AR_Log("[AR] Consent prompt shown, waiting max " + (int)timeoutSec + "s for hold/2x tap (consent key)");

		while (elapsed < timeoutSec)
		{
			Sleep(step);
			elapsed = theGame.GetEngineTimeAsSeconds() - tStart;

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
				MCM_AR_Log("[AR] Consent refused: player walked away");
				return false;
			}

			actHeld = IsPressed(theInput.GetAction('MCM_AR_Consent'), true)
			       || IsPressed(theInput.GetAction('SwordSheathe'), true);
			evHeld = (thePlayer.mcm_ar_consentHeldC || thePlayer.mcm_ar_consentHeldS)
			      && thePlayer.mcm_ar_consentPressAt >= tStart;
			if (devVK)
			{
				nowDown = MCM_AR_DevKeyDown(vkC) || evHeld;
				if (actHeld != prevAction)
				{
					MCM_AR_DevLog("consent cien: action=" + actHeld +
					              " vk=" + MCM_AR_DevKeyDown(vkC) +
					              " ev=" + evHeld + " @" + elapsed + "s");
				}
				if (elapsed - lastProbe >= 1.0)
				{
					lastProbe = elapsed;
					MCM_AR_DevLog("consent probe: ctx=" + theInput.GetContext() +
					              " vk=" + MCM_AR_DevKeyDown(vkC) +
					              " cAct=" + theInput.GetActionValue('MCM_AR_Consent') +
					              " ssAct=" + theInput.GetActionValue('SwordSheathe') +
					              " ev=" + FactsQuerySum('mcme_ar_consent_given') +
					              " hld=" + evHeld);
				}
			}
			else
			{
				nowDown = evHeld;
				// cien: dywergencja event-vs-action.value trafia do loga
				if (evHeld != prevEvHeld && evHeld != actHeld)
				{
					MCM_AR_Log("[AR] consent dywergencja: evHeld=" + evHeld +
					           " actHeld=" + actHeld + " @" + elapsed + "s");
				}
				prevEvHeld = evHeld;
			}
			prevAction = actHeld;
			if (nowDown && !prevDown)
			{
				pressedFresh = true;
				holdStartT = elapsed;
				if (devVK) vkTaps += 1;
			}
			if (nowDown && pressedFresh)
			{
				heldFor = elapsed - holdStartT;
				if (heldFor >= 1.0)
				{
					FactsRemove('mcme_ar_awaiting_consent');
					FactsRemove('mcme_ar_consent_given');
					MCM_AR_Log("[AR] Consent accepted (hold " + heldFor + "s) after " + elapsed + "s");
					return true;
				}
			}
			else if (!nowDown)
			{
				heldFor = 0.0;
				pressedFresh = false;
			}
			prevDown = nowDown;

			nowTaps = FactsQuerySum('mcme_ar_consent_given');
			if (devVK && vkTaps > nowTaps)
			{
				nowTaps = vkTaps;
			}
			if (nowTaps > tapsSeen)
			{
				if (nowTaps - tapsSeen >= 2 || elapsed - lastTapAt <= 0.7)
				{
					FactsRemove('mcme_ar_awaiting_consent');
					FactsRemove('mcme_ar_consent_given');
					MCM_AR_Log("[AR] Consent accepted (2x tap, presses=" + nowTaps + ") after " + elapsed + "s");
					return true;
				}
				lastTapAt = elapsed;
				tapsSeen = nowTaps;
			}
		}

		tapsSeen = FactsQuerySum('mcme_ar_consent_given');
		FactsRemove('mcme_ar_awaiting_consent');
		FactsRemove('mcme_ar_consent_given');
		MCM_AR_Log("[AR] Consent timeout (" + (int)timeoutSec + "s) - refused, presses=" +
		           nowTaps + " evpresses=" + tapsSeen + " vktaps=" + vkTaps);
		return false;
	}

	// Zwalnia kolejke DialogueManager przed scena (zawsze true): czeka max
	// min(maxWaitSec, 3s) na naturalny koniec kwestii, potem wymusza
	// MCM_DM_Idle; kwestia >2s bez postepu zwalniana od razu.
	protected latent function WaitForDialogueFree(maxWaitSec : float) : bool
	{
		var t        : float;
		var limitSec : float;
		var mcm      : mod_scm;

		limitSec = MinF(maxWaitSec, 3.0);
		t = 0.0;
		while (true)
		{
			mcm = MCM_GetMCM();
			if (!mcm || !mcm.DialogueManager || !mcm.DialogueManager.IsBusy())
			{
				return true;
			}
			if (t >= limitSec || theGame.GetEngineTimeAsSeconds() - mcm.DialogueManager.lastProgress > 2.0)
			{
				MCM_AR_Log("[AR] WaitForDialogueFree: zwolnienie DialogueManager dla sceny (t=" + (int)t + "s)");
				mcm.DialogueManager.GotoState('MCM_DM_Idle');
				return true;
			}
			Sleep(0.5);
			t += 0.5;
		}
		return true;
	}

	// Wspolna faza propozycji staged: prompt [C] dopiero PO dotarciu NPC
	// (prompt na starcie = "ghost refuse" na progu walk-away i nieudany
	// pathing liczony jako odmowa). alwaysRequire: Tier4 wymusza prompt.
	protected latent function ApproachAndConsent(npc : CNewNPC, player : CR4Player,
		targetDist : float, promptText : string, optional alwaysRequire : bool) : bool
	{
		var ok : bool;

		ok = WaitForApproach(npc, player, targetDist, 8.0);
		if (!ok)
		{
			// NPC nie doszla (pathing/timeout/gracz >25m) – to NIE odmowa.
			EndSoft(npc);
			MCM_AR_Log("[AR] " + id + ": approach failed/timeout (not a rejection)");
			return false;
		}
		if (alwaysRequire || MCM_AR_GetConfig().RequiresPlayerConsent())
		{
			ok = ShowConsentPrompt(promptText, 10.0, npc);
			if (!ok)
			{
				EndSoft(npc);
				// Wildcard (targetNpc == '') potrzebuje nazwy NPC, inaczej
				// RecordCompanionRejection nie zapisze backoffu per-towarzysz.
				if (npc && npc.scmcc && npc.scmcc.data)
				{
					MarkRejected(npc.scmcc.data.nam);
				}
				else
				{
					MarkRejected();
				}
				MCM_AR_Log("[AR] Player declined/ignored: " + id);
				return false;
			}
		}
		return true;
	}

	// Scena .w2scene przez API MCME + wait na koniec. Timeout na wypadek
	// braku startu (wtedy krotki staging).
	protected latent function PlayScene(npc : CNewNPC, scenePath : string) : bool
	{
		var t      : float;
		var quietT : float;
		var scm    : mod_scm;
		var ent    : MultiCompanionModEntity;
		var dialogueFree : bool;
		var sawScene     : bool;
		var pPos         : Vector;

		// Gate: scena nie startuje przy swiezej kolejce czatu MCME
		// (25s > prog helpera 20s, inaczej martwa kolejka bez bypassu).
		dialogueFree = WaitForDialogueFree(25.0);
		if (!dialogueFree)
		{
			MCM_AR_Log("[AR] PlayScene ABORT: DialogueManager busy >25s: " + scenePath);
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

		// Sceny ar_* binduja kompana po tagu encji (dontSearchByVoicetag).
		// Tag potrzebny tylko na moment rozwiązania aktora przy starcie sceny.
		if (npc) npc.AddTag('mcme_companion');
		// Sonda A / Cutscenes: stworz lub przenies dynamiczny punkt akcji pod stopy gracza,
		// aby cutscenka (ar_kiss_point) nie teleportowala na koniec swiata (np. do Vegelbudow)
		if (scm && scm.APManager)
		{
			pPos = thePlayer.GetWorldPosition();
			scm.APManager.CreateActionPoint('ar_kiss_point', pPos.X, pPos.Y, pPos.Z, 0, thePlayer.GetHeading(), 0);
		}
		ent.mod_scm_delayedDialogue(scenePath, 0.05);
		MCM_AR_Log("[AR] PlayScene: " + scenePath);

		// Czekaj az cicho; sawScene=false gdy delayedDialogue odrzucil sciezke.
		// IsInGameplayScene NIE moze blokowac wyjscia - flaga zostaje dlugo
		// po scenie (idle-pose + dziwactwo MCME) i dawala 45s martwej ciszy.
		Sleep(0.6);
		t = 0.0;
		quietT = 0.0;
		sawScene = false;
		while (t < 45.0)
		{
			if (theGame.IsDialogOrCutscenePlaying() || (npc && npc.IsInGameplayScene()))
			{
				sawScene = true;
			}
			if (theGame.IsDialogOrCutscenePlaying() || (npc && npc.IsSpeaking()))
			{
				quietT = 0.0;
			}
			else
			{
				quietT += 0.5;
			}
			if (t >= 4.0 && quietT >= 3.0 && !(npc && npc.IsInGameplayScene()))
			{
				break;
			}
			if (t >= 15.0 && quietT >= 6.0)
			{
				break;
			}
			Sleep(0.5);
			t += 0.5;
		}
		if (npc) npc.RemoveTag('mcme_companion');
		return sawScene;
	}

	// Wspolny wait: czeka az scena/dialog przestanie grac. Grace 4s na start
	// + timeout na fail-start.
	protected latent function WaitForSceneEnd(npc : CNewNPC, optional timeoutSec : float, optional rehideWeapons : bool) : bool
	{
		var t              : float;
		var quietT         : float;
		var sawScene       : bool;
		var playerReleased : bool;
		var rehideT        : float;

		if (timeoutSec <= 0.0) timeoutSec = 60.0;

		sawScene = false;
		playerReleased = false;
		rehideT = -1.0;
		quietT = 0.0;

		Sleep(0.2);
		t = 0.0;
		while (t <= timeoutSec)
		{
			// Cutscenki sex_* remountuja itemy w trakcie - periodyczny re-hide.
			if (rehideWeapons && t - rehideT >= 1.0)
			{
				HideActorWeapons(thePlayer);
				if (npc) HideActorWeapons(npc);
				rehideT = t;
			}

			if (theGame.IsDialogOrCutscenePlaying())
			{
				sawScene = true;
				quietT = 0.0;
			}
			else if (!sawScene && t >= 8.0)
			{
				// Fast-fail: scena nie wystartowala w ciagu 8s - abortujemy martwe oczekiwanie
				MCM_AR_Log("[AR] WaitForSceneEnd FAIL-START: scena nie wystartowala po 8s - przerywanie");
				break;
			}
			else if (sawScene)
			{
				// Scena grala, ale silnik zglosil brak DialogOrCutscenePlaying
				// (koniec w2scene lub natychmiastowy skip SPACJA).
				if (npc && npc.IsSpeaking())
				{
					quietT = 0.0;
				}
				else
				{
					quietT += 0.15;
				}

				// Debounce 0.4s bez dialogu/cutscenki = scena definitywnie zakonczona.
				// IsInGameplayScene celowo NIE blokuje wyjscia (flaga potrafi wisiec bez konca).
				if (quietT >= 0.4)
				{
					if (!playerReleased)
					{
						thePlayer.UnblockAction(EIAB_Movement, 'MCM_AR_interaction');
						thePlayer.DisableLookAt();
					}
					return true;
				}
			}

			Sleep(0.15);
			t += 0.15;
		}

		// Timeout / abort - pelny teardown sceny i odblokowanie sterowania
		if (thePlayer)
		{
			thePlayer.StopAllScenes();
		}
		if (theGame.GetSyncAnimManager())
		{
			theGame.GetSyncAnimManager().BreakSyncIfPossible(npc);
		}
		if (npc)
		{
			npc.StopAllScenes();
			npc.ActionCancelAll();
		}
		if (!playerReleased)
		{
			thePlayer.UnblockAction(EIAB_Movement, 'MCM_AR_interaction');
			thePlayer.DisableLookAt();
		}
		return sawScene;
	}

	// Sceny autonomiczne kiss/hug: per-NPC .w2scene z wycietym PChoice we
	// wlasnym bundle (sciezki ar_*) - zero kola dialogowego, zero kolizji
	// z oryginalami MCME. Brak wpisu = akcja zwraca false.
	protected function AutonomousScenePath(npc : CNewNPC, isHug : bool) : string
	{
		var nam : name;

		if (!npc || !npc.scmcc || !npc.scmcc.data) return "";
		nam = npc.scmcc.data.nam;

		if (isHug)
		{
			switch (nam)
			{
				case 'cirilla':
				case 'ciri':
					return "dlc\mod_mcme_autonomous_romance\dialogue\ar_cirilla_hug.w2scene";
			}
			return "";
		}

		switch (nam)
		{
			case 'yennefer':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_yennefer_kiss.w2scene";
			case 'triss':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_triss_kiss.w2scene";
			case 'keira_metz':
			case 'keira':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_keira_kiss.w2scene";
			case 'shani':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_shani_kiss.w2scene";
			case 'cerys':
			case 'becca':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_cerys_kiss.w2scene";
			case 'syanna':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_syanna_kiss.w2scene";
			// Ciri kiss tylko w trybie Adult (opcia MCM_AR_CiriMode);
			// domyślny Lore-Friendly zwraca "" -> akcja odfiltrowana (no_scene).
			case 'cirilla':
			case 'ciri':
				if (thePlayer.MCM_AR_GetConfig().IsCiriAdultMode())
				{
					return "dlc\mod_mcme_autonomous_romance\dialogue\ar_cirilla_kiss.w2scene";
				}
				return "";
			case 'rosa_var_attre':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_rosa_kiss.w2scene";
			case 'prologue_village_herbalist':
			case 'tomira':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_tomira_kiss.w2scene";
			// noble_woman_base rig (anna/vivienne/orianna): brak animacji kiss
			// dla tego szkieletu -> "" (no_scene), inaczej T-pose w scenie.
			case 'philippa_eilhart':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_philippa_kiss.w2scene";
			case 'ves':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_ves_kiss.w2scene";
			case 'mh303_succbus_v2':
			case 'salma':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_salma_kiss.w2scene";
			case 'pryscilla':
			case 'priscilla':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_priscilla_kiss.w2scene";
			case 'edna_var_attre':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_edna_kiss.w2scene";
			case 'fringilla_vigo':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_fringilla_kiss.w2scene";
			case 'margarita':
			case 'margaritta':
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_margarita_kiss.w2scene";
		}
		return "";
	}

	// TODO#27b: Kinowe warianty pocałunku per-NPC (w2scene z dynamiczną reżyserią kamer).
	// Zwraca dedykowany zasób kinowy dla postaci (np. Shani q604, Triss sq301).
	protected function AutonomousCinematicKissPath(npc : CNewNPC) : string
	{
		var nam : name;

		if (!npc || !npc.scmcc || !npc.scmcc.data) return "";
		nam = npc.scmcc.data.nam;

		switch (nam)
		{
			case 'shani':
			case 'triss':
			case 'yennefer':
			case 'keira':
			case 'keira_metz':
				// Sonda A (cutscene wrapper z retargetingiem na mcme_companion):
				// Odpalamy wrapper cs_sq301 w celu weryfikacji in-game kompatybilnosci szkieletu/rigow
				if (MCM_AR_SceneExists("dlc\mod_mcme_autonomous_romance\dialogue\ar_cs_kiss_probe.w2scene"))
				{
					return "dlc\mod_mcme_autonomous_romance\dialogue\ar_cs_kiss_probe.w2scene";
				}
				if (nam == 'shani')
				{
					return "dlc\mod_mcme_autonomous_romance\dialogue\ar_shani_kiss_cinematic.w2scene";
				}
				return "";
			default:
				return "";
		}
		return "";
	}

	public latent function PlayKissScene(npc : CNewNPC) : bool
	{
		var basePath      : string;
		var cinematicPath : string;
		var chosenPath    : string;
		var hasBase       : bool;
		var hasCinematic  : bool;
		var ok            : bool;
		var nam           : name;

		basePath      = AutonomousScenePath(npc, false);
		cinematicPath = AutonomousCinematicKissPath(npc);

		if (StrLen(basePath) == 0 && StrLen(cinematicPath) == 0)
		{
			if (npc && npc.scmcc && npc.scmcc.data)
			{
				MCM_AR_Log("[AR] KissScene: no autonomous scene for " + NameToString(npc.scmcc.data.nam));
			}
			return false;
		}

		hasBase      = (StrLen(basePath) > 0 && MCM_AR_SceneExists(basePath));
		hasCinematic = (StrLen(cinematicPath) > 0 && MCM_AR_SceneExists(cinematicPath));

		if (npc && npc.scmcc && npc.scmcc.data)
		{
			nam = npc.scmcc.data.nam;
		}

		// Wybór wariantu sceny (TODO#27b):
		// Gdy dostępny jest zarówno wariant kinowy, jak i standardowy: rotacja 50/50.
		if (hasCinematic && hasBase)
		{
			if (RandRange(100) < 50)
			{
				chosenPath = cinematicPath;
				MCM_AR_Log("[AR] KissScene: selected cinematic variant '" + chosenPath + "' for " + NameToString(nam));
			}
			else
			{
				chosenPath = basePath;
				MCM_AR_Log("[AR] KissScene: selected standard variant '" + chosenPath + "' for " + NameToString(nam));
			}
		}
		else if (hasCinematic)
		{
			chosenPath = cinematicPath;
			MCM_AR_Log("[AR] KissScene: playing cinematic variant '" + chosenPath + "' for " + NameToString(nam));
		}
		else if (hasBase)
		{
			chosenPath = basePath;
		}
		else
		{
			MCM_AR_Log("[AR] KissScene: scene resources missing for " + NameToString(nam) + " (base='" + basePath + "', cinematic='" + cinematicPath + "') - niekompletny bundle/metadata.store");
			return false;
		}

		ok = PlayScene(npc, chosenPath);
		if (ok)
		{
			PlayPostKissReaction(npc);
		}
		return ok;
	}

	public latent function PlayHugScene(npc : CNewNPC) : bool
	{
		var path : string;
		var ok   : bool;

		path = AutonomousScenePath(npc, true);
		if (StrLen(path) == 0)
		{
			if (npc && npc.scmcc && npc.scmcc.data)
			{
				MCM_AR_Log("[AR] HugScene: no autonomous scene for " + NameToString(npc.scmcc.data.nam));
			}
			return false;
		}
		if (!MCM_AR_SceneExists(path))
		{
			MCM_AR_Log("[AR] HugScene: scene resource missing '" + path + "' (niekompletny bundle/metadata.store)");
			return false;
		}
		ok = PlayScene(npc, path);
		if (ok)
		{
			PlayPostHugReaction(npc);
		}
		return ok;
	}

	protected function PlayPostKissReaction(npc : CNewNPC)
	{
		var nam  : name;
		var text : string;

		if (!npc || !npc.scmcc || !npc.scmcc.data) return;
		nam = npc.scmcc.data.nam;

		switch (nam)
		{
			case 'yennefer':
				text = AR_T("ar_afterglow_yen", "Now that's a welcome distraction. Let's keep moving, Geralt.");
				break;
			case 'triss':
				text = AR_T("ar_afterglow_triss", "I've missed that... Stay close, all right?");
				break;
			case 'keira_metz':
			case 'keira':
				text = AR_T("ar_afterglow_keira", "Mmm... You certainly haven't lost your touch, witcher.");
				break;
			case 'shani':
				text = AR_T("ar_afterglow_shani", "That made this journey so much better, Geralt.");
				break;
			case 'anna_henrietta':
				text = AR_T("ar_afterglow_anarietta", "A delightful moment. Now, let us attend to our duties.");
				break;
			case 'sq701_vivienne':
			case 'vivienne':
				text = AR_T("ar_afterglow_vivienne", "Thank you, Geralt. You bring warmth to my heart.");
				break;
			case 'becca':
			case 'cerys':
				text = AR_T("ar_afterglow_cerys", "Hah! Not bad, witcher, not bad at all.");
				break;
			case 'rosa_var_attre':
				text = AR_T("ar_afterglow_rosa", "Not bad. Though my fencing form is still sharper than yours.");
				break;
			case 'prologue_village_herbalist':
			case 'tomira':
				text = AR_T("ar_afterglow_tomira", "Sweeter than any herb in my garden. Take care on the road.");
				break;
			case 'syanna':
				text = AR_T("ar_afterglow_syanna", "Didn't think you had it in you, witcher. Nice surprise.");
				break;
			case 'philippa_eilhart':
			case 'filippa':
				text = AR_T("ar_afterglow_philippa", "Satisfactory, Geralt. Let's not make a habit of lingering.");
				break;
			case 'ves':
				text = AR_T("ar_afterglow_ves", "Not soft, are you? Good. Back to the road.");
				break;
			case 'mh303_succbus_v2':
			case 'salma':
				text = AR_T("ar_afterglow_salma", "Mmm... Delicious. You always know how to please.");
				break;
			case 'pryscilla':
			case 'priscilla':
				text = AR_T("ar_afterglow_priscilla", "Like a verse from a forgotten ballad. Thank you, Geralt.");
				break;
			case 'edna_var_attre':
				text = AR_T("ar_afterglow_edna", "Bold, witcher. Much bolder than my sister thinks.");
				break;
			case 'fringilla_vigo':
			case 'fringilla':
				text = AR_T("ar_afterglow_fringilla", "A rare moment of tenderness. I will remember it.");
				break;
			case 'margarita':
			case 'margaritta':
				text = AR_T("ar_afterglow_margarita", "Warmth is precious in times like these. Thank you.");
				break;
			case 'vampire_diva':
			case 'oriana':
			case 'orianna':
				text = AR_T("ar_afterglow_orianna", "Exquisite... A taste I could easily grow fond of.");
				break;
			default:
				text = AR_T("ar_line_afterglow", "That was... nice. Don't be a stranger.");
				break;
		}

		PlayOneLiner(npc, 0, text);
	}

	protected function PlayPostHugReaction(npc : CNewNPC)
	{
		var text : string;
		if (!npc) return;
		text = AR_T("ar_afterglow_ciri", "It's good to be together again, Geralt.");
		PlayOneLiner(npc, 0, text);
	}

	// Scena intymna w punkcie intymnym (NaughtyPoint).
	protected function HasIntimateScene(npc : CNewNPC) : bool
	{
		return StrLen(ResolveIntimateScenePath(npc)) > 0;
	}

	// Cache path->exists: GetExtraBlockReason odpala sie na kazdym eval-ticku,
	// a LoadResource na brakujacym DLC-bundle stalby w miejscu za kazdym razem.
	protected var sceneExistsKeys : array<string>;
	protected var sceneExistsVals : array<bool>;

	protected function MCM_AR_SceneExists(path : string) : bool
	{
		var i     : int;
		var scene : CStoryScene;

		for (i = 0; i < sceneExistsKeys.Size(); i += 1)
		{
			if (sceneExistsKeys[i] == path)
			{
				return sceneExistsVals[i];
			}
		}
		sceneExistsKeys.PushBack(path);
		scene = (CStoryScene)LoadResource(path, true);
		if (!scene)
		{
			sceneExistsVals.PushBack(false);
			return false;
		}
		sceneExistsVals.PushBack(true);
		return true;
	}

	// Rozdzielczosc sciezki sceny intymnej identyczna z PlayIntimateScene:
	// specialData.naughtyScene gdy ustawiona, inaczej NaughtyScenePath(nam).
	protected function ResolveIntimateScenePath(npc : CNewNPC) : string
	{
		var nm : name;

		if (!npc || !npc.scmcc || !npc.scmcc.data) return "";
		nm = npc.scmcc.data.nam;

		// Wariant A (TODO#12): Dedykowana plenerowa scena intymna w plenerze/przy ognisku,
		// lub jako glowny uniwersalny fallback dla towarzyszek bez stalego punktu MCME
		if (IsWomanBaseCompanion(npc) && !IsOnNaughtyPoint())
		{
			if (MCM_AR_SceneExists("dlc\mod_mcme_autonomous_romance\dialogue\ar_shani_intimate_outdoor.w2scene"))
			{
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_shani_intimate_outdoor.w2scene";
			}
		}

		if (StrStartsWith(NaughtyScenePath(nm), "dlc\mod_mcme_autonomous_romance") && MCM_AR_SceneExists(NaughtyScenePath(nm)))
		{
			return NaughtyScenePath(nm);
		}
		if (npc.scmcc.specialData && StrLen(npc.scmcc.specialData.naughtyScene) > 0)
		{
			if (MCM_AR_SceneExists(npc.scmcc.specialData.naughtyScene))
			{
				return npc.scmcc.specialData.naughtyScene;
			}
		}
		if (NaughtyScenePath(nm) != "")
		{
			return NaughtyScenePath(nm);
		}

		// Fallback na scene uniwersalna z wlasnego bundle dla kazdej kompatybilnej towarzyszki woman_base
		if (IsWomanBaseCompanion(npc))
		{
			if (MCM_AR_SceneExists("dlc\mod_mcme_autonomous_romance\dialogue\ar_shani_intimate_outdoor.w2scene"))
			{
				return "dlc\mod_mcme_autonomous_romance\dialogue\ar_shani_intimate_outdoor.w2scene";
			}
		}
		return "";
	}

	// Powod blokady scen autonomicznych (kiss/hug): "" = ok,
	// "no_scene" = brak mapowania dla NPC, "no_dlc_scene" = sciezka jest
	// ale zasob niezaladowany (niekompletny bundle ar_*/metadata.store).
	protected function AutonomousSceneBlockReason(npc : CNewNPC, isHug : bool) : string
	{
		var path          : string;
		var cinematicPath : string;

		path = AutonomousScenePath(npc, isHug);
		if (!isHug)
		{
			cinematicPath = AutonomousCinematicKissPath(npc);
		}

		if (path == "" && cinematicPath == "") return "no_scene";

		// Jeśli chociaż jeden zmapowany wariant poprawnie ładuje się z zasobów (bundle/metadata.store) -> scena odblokowana
		if (path != "" && MCM_AR_SceneExists(path)) return "";
		if (cinematicPath != "" && MCM_AR_SceneExists(cinematicPath)) return "";

		return "no_dlc_scene";
	}

	// Powod blokady T4 dla ar_eval: "" = scena ok, "no_scene" = brak sciezki,
	// "no_dlc_scene" = sciezka znana ale plik nie istnieje (DLC/submod off).
	protected function IntimateSceneBlockReason(npc : CNewNPC) : string
	{
		var path : string;

		path = ResolveIntimateScenePath(npc);
		if (path == "") return "no_scene";
		if (!MCM_AR_SceneExists(path)) return "no_dlc_scene";
		return "";
	}

	// Eligibility na 16m (PreDialogue <=16m < PreNaughtyWith 20m) - inaczej
	// consent dla sceny padajacej na allownaughty=0. Notifier: ctx 30m.
	protected function IsOnNaughtyPoint() : bool
	{
		var pt : mod_scm_NaughtyPoint;

		if (mod_scm_GetSCM() && mod_scm_GetSCM().NaughtyManager && mod_scm_GetSCM().NaughtyManager.naughtyPoints)
		{
			pt = mod_scm_GetSCM().NaughtyManager.naughtyPoints.GetClosestPoint(16.0);
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
			// CIRI: T4 tylko w trybie Adult (MCM_AR_CiriMode); domyslny
			// Lore-Friendly -> "" (wiez rodzinna, brak sceny intymnej).
			case 'cirilla':
			case 'ciri':
				if (thePlayer.MCM_AR_GetConfig().IsCiriAdultMode())
				{
					return "dlc\mod_spawn_companions\naughty\ciri\anywhere.w2scene";
				}
				return "";
			case 'anna_henrietta': return "dlc\mod_mcme_autonomous_romance\naughty\anarietta\anywhere.w2scene";
			// 'vivienne' = forma ludzka (vivienne_bird = przekleta forma ptasia)
			case 'sq701_vivienne':
			case 'vivienne':       return "dlc\mod_mcme_autonomous_romance\naughty\vivienne\anywhere.w2scene";
			case 'becca':
			case 'cerys':          return "dlc\mod_mcme_autonomous_romance\naughty\cerys\anywhere.w2scene";
			case 'syanna':         return "dlc\mod_spawn_companions\naughty\syanna\anywhere.w2scene";
			// noble rig -> brak kiss scene; top tier to naughty cutscene (rig-safe)
			case 'vampire_diva':
			case 'oriana':
			case 'orianna':        return "dlc\mod_mcme_autonomous_romance\naughty\oriana\anywhere.w2scene";
			// Fallbacki dla NPC, gdy pack nie ustawi specialData.naughtyScene
			case 'philippa_eilhart':
			case 'philippa':        return "dlc\mod_mcme_autonomous_romance\naughty\philippa\anywhere.w2scene";
			case 'ves':             return "dlc\mod_mcme_autonomous_romance\naughty\ves\anywhere.w2scene";
			case 'mh303_succbus_v2':
			case 'salma':           return "dlc\mod_mcme_autonomous_romance\naughty\salma\anywhere.w2scene";
			// runtime nam z roostera MCME to 'pryscilla' (upstream typo) - alias jak w AutonomousScenePath
			case 'pryscilla':
			case 'priscilla':       return "dlc\mod_mcme_autonomous_romance\naughty\priscilla\anywhere.w2scene";
			case 'edna_var_attre':
			case 'edna':            return "dlc\mod_mcme_autonomous_romance\naughty\edna\anywhere.w2scene";
			case 'fringilla_vigo':
			case 'fringilla':       return "dlc\mod_mcme_autonomous_romance\naughty\fringilla\anywhere.w2scene";
			// upstream pisownia katalogu to 'margaritta' (podwojne t)
			case 'margarita':       return "dlc\mod_mcme_autonomous_romance\naughty\margaritta\anywhere.w2scene";
			case 'shani':           return "dlc\mod_spawn_companions\naughty\shani\anywhere.w2scene";
		}
		return "";
	}

	// Filtr: bron / amunicja / pochwa. Pochwy modowanych itemow nie maja
	// tagu 'Scabbard' (tag dotyczy startowych), wiec kluczowe sa tez
	// kategorie steel_scabbards/silver_scabbards.
	protected function IsWeaponOrScabbardItem(inv : CInventoryComponent, item : SItemUniqueId) : bool
	{
		var cat : name;

		if (inv.IsItemWeapon(item) || inv.IsItemBolt(item) ||
		    inv.ItemHasTag(item, 'Scabbard'))
		{
			return true;
		}
		cat = inv.GetItemCategory(item);
		return cat == 'steel_scabbards' || cat == 'silver_scabbards';
	}

	// Diagnostyka: zamontowane itemy aktora z flagami (W/B/S) i info
	// o encji - pokazuje co realnie renderuje sie w scenie.
	protected function DumpMountedItems(actor : CActor, who : string)
	{
		var inv    : CInventoryComponent;
		var items  : array<SItemUniqueId>;
		var i      : int;
		var flags  : string;

		if (!actor) return;
		inv = (CInventoryComponent)actor.GetComponentByClassName('CInventoryComponent');
		if (!inv) return;
		inv.GetAllItems(items);
		for (i = 0; i < items.Size(); i += 1)
		{
			if (!inv.IsItemMounted(items[i])) continue;
			flags = "";
			if (inv.IsItemWeapon(items[i])) flags += "W";
			if (inv.IsItemBolt(items[i])) flags += "B";
			if (!inv.IsItemWeapon(items[i]) && !inv.IsItemBolt(items[i]) &&
			    IsWeaponOrScabbardItem(inv, items[i])) flags += "S";
			if (inv.GetItemEntityUnsafe(items[i])) flags += "+ent";
			MCM_AR_Log("[AR]   mounted<" + who + ">: " + NameToString(inv.GetItemName(items[i])) +
			           " cat=" + NameToString(inv.GetItemCategory(items[i])) +
			           " flags=" + flags);
		}
	}

	// Chowa encje zamontowanych broni/pochw aktora na czas sceny intymnej.
	// NIE unmountujemy - cutscenki sex_* remountuja itemy eventami w trakcie
	// odtwarzania; SetHideInGame na encji itemu przetrwa remount.
	protected function HideActorWeapons(actor : CActor) : int
	{
		var inv    : CInventoryComponent;
		var items  : array<SItemUniqueId>;
		var ent    : CItemEntity;
		var i, hid : int;

		if (!actor) return 0;
		inv = (CInventoryComponent)actor.GetComponentByClassName('CInventoryComponent');
		if (!inv) return 0;
		inv.GetAllItems(items);
		hid = 0;
		for (i = 0; i < items.Size(); i += 1)
		{
			if (!inv.IsItemMounted(items[i]))
			{
				continue;
			}
			if (!IsWeaponOrScabbardItem(inv, items[i]))
			{
				continue;
			}
			ent = inv.GetItemEntityUnsafe(items[i]);
			if (ent)
			{
				ent.SetHideInGame(true);
				hid += 1;
			}
		}
		return hid;
	}

	// Odchowuje bronie ukryte przez HideActorWeapons; rescan po ekwipunku
	// (scena mogla odtworzyc encje itemow remountem w trakcie).
	protected function UnhideActorWeapons(actor : CActor) : int
	{
		var inv    : CInventoryComponent;
		var items  : array<SItemUniqueId>;
		var ent    : CItemEntity;
		var i, cnt : int;

		if (!actor) return 0;
		inv = (CInventoryComponent)actor.GetComponentByClassName('CInventoryComponent');
		if (!inv) return 0;
		inv.GetAllItems(items);
		cnt = 0;
		for (i = 0; i < items.Size(); i += 1)
		{
			if (!inv.IsItemMounted(items[i]))
			{
				continue;
			}
			if (!IsWeaponOrScabbardItem(inv, items[i]))
			{
				continue;
			}
			ent = inv.GetItemEntityUnsafe(items[i]);
			if (ent)
			{
				ent.SetHideInGame(false);
				cnt += 1;
			}
		}
		return cnt;
	}

	public latent function PlayIntimateScene(npc : CNewNPC) : bool
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
		var hidP, hidN : int;
		var pPos : Vector;
		var isAutonomousScene : bool;
		var savedGeraltItems   : array<SItemUniqueId>;
		var equipSlots         : array<EEquipmentSlots>;
		var eqI                : int;
		var eqItem             : SItemUniqueId;
		var savedNpcAppearance : name;
		var appToRestore       : name;
		var appStr             : string;
		var allComps           : array<CNewNPC>;
		var compI              : int;
		var template           : CEntityTemplate;
		var appNames           : array<name>;
		var foundNakedApp      : name;
		var foundUnderwearApp  : name;
		var aStr               : string;
		var appI               : int;

		if (!thePlayer || !npc || !npc.scmcc || !npc.scmcc.data) return false;
		nm = npc.scmcc.data.nam;

		// Gate: scena nie startuje w trakcie swiezej kolejki czatu MCME
		dialogueFree = WaitForDialogueFree(25.0);
		if (!dialogueFree)
		{
			MCM_AR_Log("[AR] IntimateScene ABORT: DialogueManager busy >25s for " + NameToString(nm));
			return false;
		}

		scm = mod_scm_GetSCM();
		mcm = MCM_GetMCM();
		if (!scm || !mcm || !scm.NaughtyManager || !scm.NaughtyManager.naughtyPoints)
		{
			MCM_AR_Log("[AR] IntimateScene FAIL: SCM/MCM/NaughtyManager NULL for " + NameToString(nm));
			return false;
		}

		path = ResolveIntimateScenePath(npc);
		if (path == "")
		{
			MCM_AR_Log("[AR] IntimateScene FAIL: ResolveIntimateScenePath empty for " + NameToString(nm));
			return false;
		}

		isAutonomousScene = StrStartsWith(path, "dlc\mod_mcme_autonomous_romance") && StrFindFirst(path, "naughty") < 0;
		MCM_AR_Log("[AR] IntimateScene: target=" + NameToString(nm) + " path=" + path + " isAutonomous=" + isAutonomousScene);
		if (isAutonomousScene)
		{
			// Dynamiczny Action Point pod stopami gracza dla scen plenerowych
			if (scm && scm.APManager)
			{
				pPos = thePlayer.GetWorldPosition();
				scm.APManager.CreateActionPoint('ar_intimate_point', pPos.X, pPos.Y, pPos.Z, 0, thePlayer.GetHeading(), 0);
			}
			else
			{
				MCM_AR_Log("[AR] IntimateScene WARN: APManager NULL - ar_intimate_point not spawned!");
			}

			scene = (CStoryScene)LoadResource(path, true);
			if (!scene)
			{
				MCM_AR_Log("[AR] IntimateScene FAIL: LoadResource NULL: " + path);
				return false;
			}
			FactsSet('mod_scm_allownaughty', 1);
		}
		else
		{
			// Standardowy rezim MCME: wymaga stalego NaughtyPoint (<=20m)
			point = scm.NaughtyManager.naughtyPoints.GetClosestPoint(20.0);
			if (!point)
			{
				MCM_AR_Log("[AR] IntimateScene FAIL: no NaughtyPoint <=20m for " + NameToString(nm));
				return false;
			}

			if (npc.scmcc.specialData && path == npc.scmcc.specialData.naughtyScene)
			{
				scene = (CStoryScene)LoadResource(npc.scmcc.specialData.naughtyScene, true);
				if (!scene)
				{
					MCM_AR_Log("[AR] IntimateScene FAIL: LoadResource NULL: " + npc.scmcc.specialData.naughtyScene);
					return false;
				}

				scm.NaughtyManager.PreDialogue(npc);
				if (FactsQuerySum('mod_scm_allownaughty') <= 0)
				{
					MCM_AR_Log("[AR] IntimateScene FAIL: allownaughty=0 for " + NameToString(nm) +
					           " (point >16m or unmet reqs)");
					return false;
				}
				MCM_AR_Log("[AR] IntimateScene: allownaughty=1, scena=" + npc.scmcc.specialData.naughtyScene);
			}
			else
			{
				scene = (CStoryScene)LoadResource(path, true);
				if (!scene)
				{
					MCM_AR_Log("[AR] IntimateScene FAIL: LoadResource NULL: " + path);
					return false;
				}
				FactsSet('mod_scm_allownaughty', 1);
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
		hidP = HideActorWeapons(thePlayer);
		hidN = 0;
		if (npc) hidN = HideActorWeapons(npc);
		MCM_AR_Log("[AR] IntimateScene: hid " + hidP + " player + " + hidN + " npc weapon entit(ies)");
		DumpMountedItems(thePlayer, "player");
		DumpMountedItems(npc, "npc");

		// Zapis aktywnego stroju towarzyszki oraz rynsztunku Geralta
		if (npc)
		{
			savedNpcAppearance = npc.GetAppearance();
			appStr = StrLower(NameToString(savedNpcAppearance));
			if (StrContains(appStr, "naked") || StrContains(appStr, "panties") || StrContains(appStr, "underwear") || StrContains(appStr, "lingerie"))
			{
				savedNpcAppearance = '';
			}
			if (!IsNameValid(savedNpcAppearance) && npc.scmcc && npc.scmcc.data && IsNameValid(npc.scmcc.data.appearance))
			{
				savedNpcAppearance = npc.scmcc.data.appearance;
			}
			if (!IsNameValid(savedNpcAppearance))
			{
				savedNpcAppearance = MCM_GetDefaultAppearance(nm);
			}
			MCM_AR_Log("[AR] IntimateScene: initial appearance for " + NameToString(nm) + " = " + NameToString(savedNpcAppearance));
		}

		equipSlots.Clear();
		equipSlots.PushBack(EES_Armor);
		equipSlots.PushBack(EES_Boots);
		equipSlots.PushBack(EES_Pants);
		equipSlots.PushBack(EES_Gloves);
		equipSlots.PushBack(EES_SilverSword);
		equipSlots.PushBack(EES_SteelSword);
		equipSlots.PushBack(EES_RangedWeapon);
		equipSlots.PushBack(EES_Mask);

		savedGeraltItems.Clear();
		for (eqI = 0; eqI < equipSlots.Size(); eqI += 1)
		{
			eqItem = GetInvalidUniqueId();
			if (GetWitcherPlayer() && GetWitcherPlayer().GetItemEquippedOnSlot(equipSlots[eqI], eqItem) && thePlayer.inv.IsIdValid(eqItem))
			{
				savedGeraltItems.PushBack(eqItem);
			}
		}

		if (scm && scm.NaughtyManager)
		{
			scm.NaughtyManager.PreNaughty();
		}
		if (npc && npc.scmcc)
		{
			if (npc.scmcc.specialData && IsNameValid(npc.scmcc.specialData.nakedAppearance))
			{
				npc.scmcc.applyNakedAppearance();
			}
			else
			{
				// Postacie drugoplanowe: dynamiczny skan szablonu .w2ent (naked / underwear)
				template = MCM_GetEntityTemplate(nm, npc.scmcc.data.depotPathPrefix);
				if (template)
				{
					appNames.Clear();
					GetAppearanceNames(template, appNames);
					for (appI = 0; appI < appNames.Size(); appI += 1)
					{
						aStr = StrLower(NameToString(appNames[appI]));
						if (foundNakedApp == '' && (StrContains(aStr, "naked") || StrContains(aStr, "nude")))
						{
							foundNakedApp = appNames[appI];
						}
						else if (foundUnderwearApp == '' && (StrContains(aStr, "underwear") || StrContains(aStr, "lingerie") || StrContains(aStr, "panties")))
						{
							foundUnderwearApp = appNames[appI];
						}
					}
				}

				if (foundNakedApp != '')
				{
					npc.ApplyAppearance(foundNakedApp);
					MCM_AR_Log("[AR] IntimateScene: template naked appearance '" + NameToString(foundNakedApp) + "' for " + NameToString(nm));
				}
				else if (foundUnderwearApp != '')
				{
					npc.ApplyAppearance(foundUnderwearApp);
					MCM_AR_Log("[AR] IntimateScene: template underwear appearance '" + NameToString(foundUnderwearApp) + "' for " + NameToString(nm));
				}
				else if (npc.scmcc.specialData && IsNameValid(npc.scmcc.specialData.underwearAppearance))
				{
					npc.ApplyAppearance(npc.scmcc.specialData.underwearAppearance);
				}
				else
				{
					MCM_AR_Log("[AR] IntimateScene: no naked/underwear appearance for " + NameToString(nm) + " - keeping current outfit");
				}
			}
		}

		if (isAutonomousScene)
		{
			scm.NaughtyManager.HideAllExcept(npc);
			npc.AddTag('mcme_companion');
			theGame.GetStorySceneSystem().PlayScene(scene, "Input");
			MCM_AR_Log("[AR] IntimateScene (autonomous AR): " + path + " for " + NameToString(nm));
		}
		else if (npc.scmcc.specialData && StrLen(npc.scmcc.specialData.naughtyScene) > 0 && path == npc.scmcc.specialData.naughtyScene)
		{
			if (!mod_scm_GetNPC(nm, ST_Special, false))
			{
				MCM_AR_Log("[AR] IntimateScene WARN: GetNPC(ST_Special) NULL for " +
				           NameToString(nm) + " - PreNaughtyWith likely a no-op");
			}
			scm.NaughtyManager.PreNaughtyWith(nm);
			MCM_AR_Log("[AR] IntimateScene (PreNaughtyWith) for " + NameToString(nm));
		}
		else
		{
			point.AddActionPoint();
			scm.NaughtyManager.HideAllExcept(npc);
			theGame.GetStorySceneSystem().PlayScene(scene, "Input");
			MCM_AR_Log("[AR] IntimateScene (manual): " + path + " for " + NameToString(nm));
		}

		ok = WaitForSceneEnd(npc, 90.0, true);
		if (isAutonomousScene && npc)
		{
			npc.RemoveTag('mcme_companion');
		}
		FactsSet('mod_scm_allownaughty', 0);
		MCM_AR_Log("[AR] IntimateScene end: ok=" + ok + " for " + NameToString(nm));
		// IsInGameplayScene true po timeout = scena wiszaca, NPC stoi do reloadu.
		if (!ok && npc && npc.IsInGameplayScene())
		{
			MCM_AR_Log("[AR] IntimateScene WARN: " + NameToString(nm) +
			           " nadal IsInGameplayScene po timeout - scena wiszaca");
		}
		// Przywrocenie ubioru towarzyszki sprzed sceny (ApplyAppearance z resetem komponentow)
		if (npc)
		{
			if (npc.scmcc && npc.scmcc.data && IsNameValid(npc.scmcc.data.appearance))
			{
				appToRestore = npc.scmcc.data.appearance;
			}
			else if (IsNameValid(savedNpcAppearance))
			{
				appToRestore = savedNpcAppearance;
			}
			else
			{
				appToRestore = MCM_GetDefaultAppearance(nm);
			}

			appStr = StrLower(NameToString(appToRestore));
			if (StrContains(appStr, "naked") || StrContains(appStr, "panties") || StrContains(appStr, "underwear") || StrContains(appStr, "lingerie"))
			{
				appToRestore = MCM_GetDefaultAppearance(nm);
			}

			if (IsNameValid(appToRestore))
			{
				npc.ApplyAppearance(appToRestore);
				MCM_AR_Log("[AR] IntimateScene: restored appearance for " + NameToString(nm) + " to " + NameToString(appToRestore));
			}
		}

		// Przywrocenie widocznosci wszystkim towarzyszom ukrytym przed scena
		MCM_AR_GetActiveCompanions(allComps);
		for (compI = 0; compI < allComps.Size(); compI += 1)
		{
			if (allComps[compI])
			{
				allComps[compI].SetHideInGame(false);
			}
		}
		if (scm && scm.NaughtyManager)
		{
			scm.NaughtyManager.ShowAllExcept(NULL);
		}
		// Niezalezny re-equip rynsztunku Geralta (odporny na skip sceny SPACJA i czyszczenie buforow MCME)
		for (eqI = 0; eqI < savedGeraltItems.Size(); eqI += 1)
		{
			thePlayer.EquipItem(savedGeraltItems[eqI]);
		}

		// PostNaughty (EquipItem) moze odtworzyc encje itemow - unhide po nim.
		if (scm && scm.NaughtyManager)
		{
			scm.NaughtyManager.PostNaughty();
		}
		hidP = UnhideActorWeapons(thePlayer);
		hidN = 0;
		if (npc) hidN = UnhideActorWeapons(npc);
		MCM_AR_Log("[AR] IntimateScene: unhid " + hidP + " player + " + hidN + " npc weapon entit(ies)");

		// Aktualizacja czasu widoczności towarzyszek po ukryciu podczas sceny intymnej.
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

// Klasa bazowa: Gift Request (autonomiczna prosba o prezent)

class MCM_AR_GiftRequest_Base extends MCM_RomanceInteraction
{
	default triggerType     = RTT_Prompt;
	default minAffinity     = 20;
	default cooldownSeconds = 3600.0; // 1h - prezenty sa rzadkim bonusem
	default weight          = 2;
	default barkMimic       = 'flirt';

	public var thanksLineId   : int;
	public var thanksLineText : string;
	public var thanksLineKey  : string; // klucz w3strings (ar_thanks_*)
	public var thanksVoiceset : name;
	default thanksLineId   = 0;
	default thanksLineText = "";
	default thanksVoiceset = 'greeting_geralt';

	// Wirtualna lista trunków w kolejności preferencji danej towarzyszki
	public function GetCandidateGifts(out gifts : array<name>)
	{
		gifts.Clear();
		gifts.PushBack('Est Est');
		gifts.PushBack('Erveluce');
		gifts.PushBack('Beauclair White');
		gifts.PushBack('Mettina Rose');
		gifts.PushBack('Alcohest');
		gifts.PushBack('Dwarven spirit');
	}

	public function FindBestAvailableGift() : name
	{
		var gifts : array<name>;
		var i     : int;

		GetCandidateGifts(gifts);
		for (i = 0; i < gifts.Size(); i += 1)
		{
			if (thePlayer.inv.GetItemQuantityByName(gifts[i]) > 0)
			{
				return gifts[i];
			}
		}
		return '';
	}

	// Nazwa itemu na HUD: silnik lokalizuje (GetItemLocalizedNameByName),
	// fallback na surowe id.
	public function GetGiftDisplayName(item : name) : string
	{
		var key : string;
		key = thePlayer.inv.GetItemLocalizedNameByName(item);
		return AR_T(key, NameToString(item));
	}

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		var gift : name;
		var core : MCM_AutonomousRomanceCore;

		gift = FindBestAvailableGift();
		if (!IsNameValid(gift))
		{
			return "no_gift";
		}
		// Prosba o prezent tylko w scenerii relaksu: tawerna, Corvo Bianco,
		// ognisko albo postoj z zawieszonymi NPC (idle-suspend > 0).
		core = MCM_AR_GetCore();
		if (!(ctx.isInTavern || ctx.isInCorvo || ctx.isNearCampfire || (core && core.GetIdleSuspendCount() > 0)))
		{
			return "not_relaxed";
		}
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var chosenGift   : name;
		var giftName     : string;
		var compName     : string;
		var promptMsg    : string;
		var removed      : bool;
		var ok           : bool;

		chosenGift = FindBestAvailableGift();
		if (!IsNameValid(chosenGift))
		{
			return false;
		}

		compName = MCM_AR_GetCompanionDisplayName(npc);
		giftName = GetGiftDisplayName(chosenGift);

		// FAZA 1 – propozycja: podejście + bark z prośbą, brak locka gracza
		SoftApproach(npc, player, 2.4);
		PlayBark(npc);

		promptMsg = AR_Fmt(AR_T("ar_prompt_gift", "[C] Give {1} to {2}"), giftName, compName);

		ok = ApproachAndConsent(npc, player, 2.4, promptMsg);
		if (!ok)
		{
			MCM_AR_Log("[AR] Gift request failed/declined (" + giftName + ") from " + compName);
			return false;
		}

		// FAZA 2 – akceptacja: defensywne sprawdzenie czy gracz nadal ma ten przedmiot
		if (player.inv.GetItemQuantityByName(chosenGift) <= 0)
		{
			EndSoft(npc);
			player.DisplayHudMessage("[AR] " + AR_T("ar_msg_item_gone", "The drink is no longer in your inventory."));
			return false;
		}

		removed = player.inv.RemoveItemByName(chosenGift, 1);
		if (!removed)
		{
			player.DisplayHudMessage("[AR] " + AR_Fmt(AR_T("ar_msg_remove_fail", "Couldn't remove {1} from your inventory."), giftName));
			MCM_AR_Log("[AR] Gift: REMOVE FAIL " + NameToString(chosenGift) + " qty=" + player.inv.GetItemQuantityByName(chosenGift));
			EndSoft(npc);
			return false;
		}

		if (npc && npc.scmcc && npc.scmcc.data)
		{
			MCM_AR_GetAffinity().AddAffinityPoints(npc.scmcc.data.nam, 3);
		}
		else
		{
			MCM_AR_GetAffinity().AddAffinityPoints(targetNpc, 3);
		}

		npc.EnableDynamicLookAt(player, 10.0);
		PlayMimic(npc, 'flirt');
		PlayDrinkingAnimation(npc);

		if (thanksLineId > 0 || StrLen(thanksLineText) > 0)
		{
			PlayOneLiner(npc, thanksLineId, AR_T(thanksLineKey, thanksLineText));
		}
		else if (IsNameValid(thanksVoiceset))
		{
			npc.PlayVoiceset(100, thanksVoiceset);
		}

		player.DisplayHudMessage("[AR] " + AR_Fmt(AR_T("ar_msg_gift_given", "Gave {1} to {2} (+3 affinity)"), giftName, compName));
		MCM_AR_Log("[AR] Gift: " + NameToString(chosenGift) + " -> " + compName + " (removed=" + removed + ")");

		if (player.IsInCombat())
		{
			EndSoft(npc);
			return true;
		}

		Sleep(1.5);
		EndSoft(npc);
		return true;
	}
}

//  DANCE - wspolna baza akcji *_dance (F1): bark + sekwencja animacji.
//  Gate: tawerna LUB (ognisko i noc). Zestaw animacji z GetDanceAnimsForNpc.

class MCM_AR_Dance_Base extends MCM_RomanceInteraction
{
	default triggerType     = RTT_OneLiner;
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default weight          = 16;
	default barkMimic       = 'flirt';

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!(ctx.isInTavern || (ctx.isNearCampfire && ctx.isNight))) return "no_dance_scene";
		if (GetDanceAnimsForNpc(targetNpc) == "") return "no_dance_anim";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var r : int;

		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		r = RunDanceSequence(npc, GetDanceAnimsForNpc(targetNpc));
		return r == 1;
	}
}

//  DANCE REFUSE - bark odmowy dla NPC poza whitelist tanca (yen/philippa/ciri-Lore).

class MCM_AR_DanceRefuse_Base extends MCM_RomanceInteraction
{
	default triggerType     = RTT_OneLiner;
	default minAffinity     = 30;
	default cooldownSeconds = 600.0;
	default weight          = 8;
	default barkMimic       = 'concern';

	public function GetExtraBlockReason(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : string
	{
		if (!(ctx.isInTavern || (ctx.isNearCampfire && ctx.isNight))) return "no_dance_scene";
		if (GetDanceAnimsForNpc(targetNpc) != "") return "dance_available";
		return "";
	}

	public latent function Execute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		npc.EnableDynamicLookAt(player, 6.0);
		PlayBark(npc);
		return true;
	}
}

function MCM_AR_TargetMatches(target : name, npcName : name) : bool
{
	if (!IsNameValid(target) || target == npcName) return true;
	return (target == 'priscilla' && npcName == 'pryscilla') || (target == 'pryscilla' && npcName == 'priscilla');
}

// Centralny rejestr akcji (Action Registry Pattern)


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
			MCM_AR_Log("[AR] Registered action: " + action.id);
		}
	}

	public latent function TryExecuteSpecificAction(actionId : name, npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var i       : int;
		var action  : MCM_RomanceInteraction;
		var res     : bool;
		var npcName : name;
		var core    : MCM_AutonomousRomanceCore;

		if (!npc || !npc.scmcc || !npc.scmcc.data) return false;
		npcName = npc.scmcc.data.nam;

		for (i = 0; i < actions.Size(); i += 1)
		{
			action = actions[i];
			if (!action) continue;
			if (action.id == actionId)
			{
				if (action.GetBlockReason(npc, player, ctx) != "")
				{
					MCM_AR_Log("[AR] TryExecuteSpecificAction BLOCKED: " + action.id + " reason=" + action.GetBlockReason(npc, player, ctx));
					thePlayer.DisplayHudMessage("[AR] Akcja niemozliwa: " + action.GetBlockReason(npc, player, ctx));
					return false;
				}
				core = MCM_AR_GetCore();
				if (core && !core.BeginStagedInteraction(npc)) return false;

				action.MarkAttempted();
				res = action.Execute(npc, player, ctx);
				if (core) core.EndStagedInteraction();

				if (res)
				{
					action.MarkExecuted(npcName);
					affinity.AddAffinityPoints(npcName, 1);
					if (action.triggerType == RTT_Scene || action.triggerType == RTT_Prompt)
					{
						if (core)
						{
							core.lastSceneOkNpc  = npcName;
							core.lastSceneOkTime = theGame.GetEngineTimeAsSeconds();
						}
					}
				}
				return res;
			}
		}
		return false;
	}

	// Główna pętla selekcji i wykonania
	public latent function TryExecute(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext, optional out eligibleCount : int, optional ambientOnly : bool) : bool
	{
		var eligible    : array<MCM_RomanceInteraction>;
		var action      : MCM_RomanceInteraction;
		var totalWeight : int;
		var roll        : int;
		var i           : int;
		var npcName     : name;
		var result      : bool;
		var core        : MCM_AutonomousRomanceCore;

		eligibleCount = 0;
		if (!npc || !npc.scmcc || !npc.scmcc.data) return false;
		// Fail-fast (staged): NPC zajeta silnikowo (kwestia/scena/rozmowa/walka)
		// - nie przerywamy jej ActionCancelAll; nastepny tick sprobuje ponownie.
		if (!ambientOnly && (npc.IsSpeaking() || theGame.IsDialogOrCutscenePlaying() || npc.wasInTalkInteraction || npc.IsInCombat()))
		{
			return false;
		}
		if (!MCM_AR_GetConfig().IsEnabled()) return false;

		npcName = npc.scmcc.data.nam;

		// Zbierz kwalifikujące się akcje dla tego NPC
		for (i = 0; i < actions.Size(); i += 1)
		{
			action = actions[i];
			if (!action) continue;

			// Filtr: akcja musi pasować do NPC lub być ogólna
			if (!MCM_AR_TargetMatches(action.targetNpc, npcName)) continue;

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
				MCM_AR_Log("[AR] " + (ambientOnly ? "ambient" : "staged") + " -> " + eligible[i].id + " (" + NameToString(npcName) + ")");
				result = eligible[i].Execute(npc, player, ctx);
				if (!ambientOnly)
				{
					MCM_AR_GetCore().EndStagedInteraction();
				}
				if (result)
				{
					// npcName wymagane: akcje wildcard (targetNpc == '') inaczej
					// nie zapisza cooldownu per-towarzysz (RecordCompanionExecution).
					eligible[i].MarkExecuted(npcName);
					affinity.AddAffinityPoints(npcName, 1);
					// Stempelek dla afterglow/konfrontacji zazdrości (T3/T4)
					if (eligible[i].triggerType == RTT_Scene || eligible[i].triggerType == RTT_Prompt)
					{
						core = MCM_AR_GetCore();
						core.lastSceneOkNpc  = npcName;
						core.lastSceneOkTime = theGame.GetEngineTimeAsSeconds();
					}
				}
				return result;
			}
		}

		return false;
	}

	// Akcje okienkowe (isTimeCritical) - jak TryExecute, ale bez wazonego
	// losu: eligible o najwyzszym weight (remis: pierwsza).
	public latent function TryExecuteTimeCritical(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var action  : MCM_RomanceInteraction;
		var best    : MCM_RomanceInteraction;
		var i       : int;
		var npcName : name;
		var result  : bool;

		if (!npc || !npc.scmcc || !npc.scmcc.data) return false;
		if (!MCM_AR_GetConfig().IsEnabled()) return false;

		npcName = npc.scmcc.data.nam;

		for (i = 0; i < actions.Size(); i += 1)
		{
			action = actions[i];
			if (!action) continue;
			if (!action.isTimeCritical) continue;
			if (action.triggerType != RTT_OneLiner) continue;
			if (!MCM_AR_TargetMatches(action.targetNpc, npcName)) continue;
			if (!action.CanExecute(npc, player, ctx)) continue;

			if (!best || action.weight > best.weight)
			{
				best = action;
			}
		}

		if (!best) return false;

		best.MarkAttempted();
		MCM_AR_Log("[AR] ambient(prio) -> " + best.id + " (" + NameToString(npcName) + ")");
		result = best.Execute(npc, player, ctx);
		if (result)
		{
			best.MarkExecuted(npcName);
			affinity.AddAffinityPoints(npcName, 1);
		}
		return result;
	}

	// Lekki check bez Execute – ProcessAmbient uzywa go do ominięcia losu
	// presetu gadatliwosci, gdy w oknie czeka akcja isTimeCritical.
	public function HasTimeCriticalEligible(npc : CNewNPC, player : CR4Player, ctx : MCM_RomanceContext) : bool
	{
		var action  : MCM_RomanceInteraction;
		var i       : int;
		var npcName : name;

		if (!MCM_AR_GetConfig().IsEnabled()) return false;

		npcName = npc.scmcc.data.nam;

		for (i = 0; i < actions.Size(); i += 1)
		{
			action = actions[i];
			if (!action) continue;
			if (!action.isTimeCritical) continue;
			if (action.triggerType != RTT_OneLiner) continue;
			if (!MCM_AR_TargetMatches(action.targetNpc, npcName)) continue;
			if (action.CanExecute(npc, player, ctx)) return true;
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

	// Szuka akcji danego NPC po sufiksie id (np. "gift_request"). Kluczem jest
	// scmcc.data.nam, wiec dziala dla wszystkich postaci bez recznej mapy nazw.
	public function FindActionForNpc(nam : name, idSuffix : string) : MCM_RomanceInteraction
	{
		var i : int;
		for (i = 0; i < actions.Size(); i += 1)
		{
			if (actions[i] && IsNameValid(actions[i].targetNpc) && MCM_AR_TargetMatches(actions[i].targetNpc, nam) && StrContains(NameToString(actions[i].id), idSuffix))
			{
				return actions[i];
			}
		}
		return NULL;
	}

	public function GetActionCount() : int
	{
		return actions.Size();
	}
}

// Specjalna akcja: HUD Prompt Input Listener
// (zarejestruj odpowiedź gracza na prompt [C])

// Stan trzymania klawisza zgody [C] na graczu (czas naciśnięcia i flaga aktywnego trzymania).
@addField(CR4Player)
public var mcm_ar_consentPressAt : float;

@addField(CR4Player)
public var mcm_ar_consentHeldC : bool;

@addField(CR4Player)
public var mcm_ar_consentHeldS : bool;

@addMethod(CR4Player)
event OnMCM_AR_ConsentKey(action : SInputAction)
{
	var now : float;

	// Diagnostyka eventowa (dev): kazde wywolanie listenera - pokazuje
	// czy eventy w ogole dochodza do CR4Player i co niosa.
	if (MCM_AR_DevActive())
	{
		MCM_AR_DevLog("consent ev: " + NameToString(action.aName) +
		              " v=" + action.value + " lv=" + action.lastFrameValue +
		              " awaiting=" + FactsQuerySum('mcme_ar_awaiting_consent'));
	}

	if (IsPressed(action))
	{
		if (FactsQuerySum('mcme_ar_awaiting_consent') > 0)
		{
			now = theGame.GetEngineTimeAsSeconds();
			if (now - mcm_ar_consentPressAt > 0.12)
			{
				FactsAdd('mcme_ar_consent_given', 1);
			}
			mcm_ar_consentPressAt = now;
			if (action.aName == 'MCM_AR_Consent')
			{
				mcm_ar_consentHeldC = true;
			}
			else
			{
				mcm_ar_consentHeldS = true;
			}
			if (MCM_AR_DevActive())
			{
				MCM_AR_DevLog("consent ev: pressed " + NameToString(action.aName) +
				              " total=" + (FactsQuerySum('mcme_ar_consent_given')));
			}
		}
	}
	else if (IsReleased(action))
	{
		if (action.aName == 'MCM_AR_Consent')
		{
			mcm_ar_consentHeldC = false;
		}
		else
		{
			mcm_ar_consentHeldS = false;
		}
	}
}

// @wrapMethod(CNewNPC) OnInteraction usuniety celowo: shadowing wrappera
// modMCME_RemasteredNPCHooks calkowicie blokowal klawisz [E] (dialog).


// Pary rywalizujące ze sobą o Geralta (kanoniczny trójkąt)
function MCM_AR_AreRivals(a : name, b : name) : bool
{
	return (a == 'yennefer' && b == 'triss') || (a == 'triss' && b == 'yennefer');
}

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
		case 'becca':
		case 'cerys':            return "Cerys";
		case 'jutta':            return "Jutta";
		case 'philippa_eilhart':
		case 'philippa':
		case 'filippa':          return "Philippa";
		case 'mh303_succbus_v2':
		case 'salma':            return "Salma";
		case 'ves':              return "Ves";
		case 'corinne':          return "Corinne";
		case 'frida':            return "Frida";
		case 'rosa_var_attre':
		case 'rosa':             return "Rosa var Attre";
		case 'prologue_village_herbalist':
		case 'tomira':
			return "Tomira";
		case 'edna_var_attre':
		case 'edna':             return "Edna var Attre";
		case 'margarita':
		case 'margaritta':       return "Margarita";
		case 'fringilla_vigo':
		case 'fringilla':        return "Fringilla";
		case 'pryscilla':
		case 'priscilla':        return "Priscilla";
		case 'vampire_diva':
		case 'oriana':
		case 'orianna':          return "Orianna";
		case 'cantarella':       return "Cantarella";
		case 'tamara':           return "Tamara";
		case 'dreamer_corine_tilly':        return "Corinne Tilly";
		case 'ida_emean_aep_sivney':        return "Ida Emean";
		case 'irina_renarde':               return "Irina Renarde";
		case 'q603_circus_artist_companion': return "Eveline Gallo";
		case 'barons_wife_celina':          return "Anna Stenger";
		case 'lady_bran':                   return "Birna Bran";
		case 'sq306_sacha':                 return "Sasha";
		case 'mq2038_shieldmaiden':         return "Jutta";
		case 'iris':                        return "Iris";
		case 'vernossiel':                  return "Vernossiel";
		default:
			// npc.GetName() na spawn'owanych NPC zwraca "" - fallback na niceName MCME.
			if (npc && npc.scmcc && npc.scmcc.data && IsNameValid(npc.scmcc.data.niceName))
				return NameToString(npc.scmcc.data.niceName);
			return AR_T("ar_msg_companion", "Companion");
	}
}

// Sonda sprawdzająca dostępność animacji w slotach animacji danego NPC.
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

