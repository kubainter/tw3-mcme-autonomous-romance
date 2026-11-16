// MCM_RomanceTw3seDev.ws — warstwa DEV na TW3SE.
// JEDYNY plik z importami TW3SE_* (wiazane w kompilacji -> release podmienia
// na MCM_RomanceTw3seDev.stub.ws o identycznych sygnaturach).
// Dev: tw3se.config -> natives = on. ReloadScripts zabija latenty w locie
// -> po reloadzie ar_devreset.

import function TW3SE_GetVersion() : int;
import function TW3SE_Log(text : string);
import function TW3SE_WriteNamed(fileName : string, text : string) : bool;
import function TW3SE_AppendNamed(fileName : string, text : string) : bool;
import function TW3SE_ReadNamed(fileName : string) : string;
import function TW3SE_FileSize(fileName : string) : int;
import function TW3SE_DeleteNamed(fileName : string) : bool;
import function TW3SE_FileExists(fileName : string) : bool;
import function TW3SE_GetConfig(key : string) : string;
import function TW3SE_GetConfigKey(setting : string) : int;
import function TW3SE_SetVar(key : string, value : string) : bool;
import function TW3SE_GetVar(key : string) : string;
import function TW3SE_HasVar(key : string) : bool;
import function TW3SE_DeleteVar(key : string) : bool;
import function TW3SE_KeyPressed(vk : int) : bool;
import function TW3SE_KeyJustPressed(vk : int) : bool;
import function TW3SE_Emit(text : string);
import function TW3SE_ReloadScripts();
import function TW3SE_Lua(code : string) : string;

// --- detekcja warstwy (stub zwraca 0/false) -------------------------------

function MCM_AR_DevActive() : bool
{
	return TW3SE_GetVersion() != 0;
}

function MCM_AR_DevVersion() : int
{
	return TW3SE_GetVersion();
}

// --- logowanie ---------------------------------------------------------
// LEAF: NIGDY nie wolac tu MCM_AR_Log ani GetCore (rekursja).
// Tee [AR]: append do ar_log.txt + pipe 'events'.
function MCM_AR_DevLog(msg : string)
{
	var line : string;
	line = "" + RoundMath(theGame.GetEngineTimeAsSeconds()) + "s " + msg;
	TW3SE_AppendNamed("ar_log.txt", line + "\n");
	TW3SE_Emit(line);
}

// Emit bez zapisu do pliku - dla zdarzen strukturalnych ("consent|accept").
function MCM_AR_DevEmit(msg : string)
{
	TW3SE_Emit(msg);
}

// Linia w tw3se.log obok komunikatow natywnych.
function MCM_AR_DevLogNative(msg : string)
{
	TW3SE_Log(msg);
}

// --- pliki w tw3se\out\ -----------------------------------------------------

function MCM_AR_DevWriteFile(f : string, text : string) : bool
{
	return TW3SE_WriteNamed(f, text);
}

function MCM_AR_DevAppendFile(f : string, text : string) : bool
{
	return TW3SE_AppendNamed(f, text);
}

function MCM_AR_DevReadFile(f : string) : string
{
	return TW3SE_ReadNamed(f);
}

function MCM_AR_DevClearFile(f : string) : bool
{
	return TW3SE_DeleteNamed(f);
}

function MCM_AR_DevFileSize(f : string) : int
{
	return TW3SE_FileSize(f);
}

// --- klawiatura (prawdziwy stan VK, dev-only) --------------------------------

function MCM_AR_DevKeyDown(vk : int) : bool
{
	return TW3SE_KeyPressed(vk);
}

// KeyJustPressed jest per-frame i gubi pressy przy poll; do tapow licz zbocza DevKeyDown.
function MCM_AR_DevKeyEdge(vk : int) : bool
{
	return TW3SE_KeyJustPressed(vk);
}

// Kod klawisza z tw3se.config (rebindable), np. ar_consent_key = 0x43.
function MCM_AR_DevConfigKey(setting : string) : int
{
	return TW3SE_GetConfigKey(setting);
}

// Dowolny klucz tekstowy z tw3se.config.
function MCM_AR_DevConfig(key : string) : string
{
	return TW3SE_GetConfig(key);
}

// --- vars.txt: stan DEV poza save'em (nie zanieczyszcza savow) ---------------

function MCM_AR_DevSetVar(k : string, v : string) : bool
{
	return TW3SE_SetVar(k, v);
}

function MCM_AR_DevGetVar(k : string) : string
{
	return TW3SE_GetVar(k);
}

function MCM_AR_DevHasVar(k : string) : bool
{
	return TW3SE_HasVar(k);
}

function MCM_AR_DevDelVar(k : string) : bool
{
	return TW3SE_DeleteVar(k);
}

// --- Lua bridge: mcme_bridge.lua (Clone()/templateParams nie istnieja w WS) --
function MCM_AR_DevLua(code : string) : string
{
	return TW3SE_Lua(code);
}

// --- hot reload (OSTROZNIE: zabija latent-loope -> ar_devreset po powrocie) --

function MCM_AR_DevReloadScripts()
{
	TW3SE_ReloadScripts();
}

// --- exec diagnostyczne ------------------------------------------------------

exec function ar_devinfo()
{
	var v  : int;
	var ok : bool;
	var msg : string;

	v = MCM_AR_DevVersion();
	if (v == 0)
	{
		thePlayer.DisplayHudMessage("[AR-dev] TW3SE inactive (stub/release)");
		return;
	}
	ok = MCM_AR_DevAppendFile("ar_selftest.txt", "L1\nL2\n");
	// v = (major<<16)|(minor<<8)|patch — WS nie ma operatorow bitowych.
	msg = "[AR-dev] TW3SE v" + (v / 65536) + "." + ((v / 256) % 256) + "." + (v % 256) +
	      " | write=" + ok +
	      " | size=" + MCM_AR_DevFileSize("ar_selftest.txt") +
	      " | read='" + MCM_AR_DevReadFile("ar_selftest.txt") + "'" +
	      " | keyC=" + MCM_AR_DevKeyDown(0x43);
	thePlayer.DisplayHudMessage(msg);
	MCM_AR_DevEmit(msg);
}

exec function ar_reload()
{
	if (!MCM_AR_DevActive())
	{
		thePlayer.DisplayHudMessage("[AR-dev] TW3SE inactive - reload unavailable");
		return;
	}
	MCM_AR_Log("[AR] ReloadScripts - po powrocie uruchom ar_devreset!");
	TW3SE_Emit("[AR] reload requested");
	MCM_AR_DevReloadScripts();
}

// E2E suite (dev) — exec ar_test_e2e. Wynik: ar_e2e.txt + pipe 'events';
// linie [E2E:PASS|FAIL|SKIP], koniec [E2E:SUMMARY]+[E2E:DONE].

class MCM_AR_E2E
{
	public var passed  : int;
	public var failed  : int;
	public var skipped : int;

	private function Out(line : string)
	{
		MCM_AR_DevAppendFile("ar_e2e.txt", line + "\n");
		MCM_AR_DevEmit(line);
	}

	public function Check(testName : string, cond : bool, optional detail : string)
	{
		if (cond)
		{
			passed += 1;
			Out("[E2E:PASS] " + testName);
		}
		else
		{
			failed += 1;
			Out("[E2E:FAIL] " + testName + ": " + detail);
		}
	}

	public function Skip(testName : string, reason : string)
	{
		skipped += 1;
		Out("[E2E:SKIP] " + testName + ": " + reason);
	}

	public function Finish()
	{
		Out("[E2E:SUMMARY] pass=" + passed + " fail=" + failed + " skip=" + skipped);
		Out("[E2E:DONE]");
	}
}

function MCM_AR_E2E_Core(t : MCM_AR_E2E)
{
	var core : MCM_AutonomousRomanceCore;
	var ok   : bool;

	ok = false;
	if (thePlayer) ok = true;
	t.Check("player_valid", ok, "thePlayer == NULL (zaladuj save)");

	core = MCM_AR_GetCore();
	ok = false;
	if (core) ok = true;
	t.Check("core_valid", ok, "MCM_AR_GetCore() == NULL");
	if (core)
	{
		ok = false;
		if (core.registry) ok = true;
		t.Check("registry_valid", ok, "core.registry == NULL");
	}

	ok = false;
	if (MCM_AR_GetConfig()) ok = true;
	t.Check("config_wrapper_valid", ok, "MCM_AR_GetConfig() == NULL");

	ok = false;
	if (MCM_AR_GetAffinity()) ok = true;
	t.Check("affinity_resolver_valid", ok, "MCM_AR_GetAffinity() == NULL");

	t.Check("mod_enabled", MCM_AR_GetConfig().IsEnabled(), "MCM_AR_Enabled == false");
}

function MCM_AR_E2E_Registry(t : MCM_AR_E2E)
{
	var core        : MCM_AutonomousRomanceCore;
	var reg         : MCM_RomanceActionRegistry;
	var act, other  : MCM_RomanceInteraction;
	var i, j, n     : int;
	var nullCount   : int;
	var badIdCount  : int;
	var dupCount    : int;
	var firstDup    : string;
	var hasSyanna   : bool;

	core = MCM_AR_GetCore();
	if (!core || !core.registry)
	{
		t.Skip("registry_suite", "brak core/registry");
		return;
	}
	reg = core.registry;
	n = reg.GetActionCount();

	// Floor: rejestr nie moze skurczyc sie po cichu.
	t.Check("registry_size_ge_106", n >= 106, "GetActionCount()=" + n + " (oczekiwano >= 106)");

	nullCount = 0;
	badIdCount = 0;
	dupCount = 0;
	firstDup = "";
	hasSyanna = false;
	for (i = 0; i < n; i += 1)
	{
		act = reg.GetAction(i);
		if (!act)
		{
			nullCount += 1;
			continue;
		}
		if (!IsNameValid(act.id))
		{
			badIdCount += 1;
			continue;
		}
		if (act.id == 'syanna_intimate_invite')
		{
			hasSyanna = true;
		}
		for (j = i + 1; j < n; j += 1)
		{
			other = reg.GetAction(j);
			if (other && other.id == act.id)
			{
				dupCount += 1;
				if (firstDup == "") firstDup = NameToString(act.id);
			}
		}
	}
	t.Check("registry_no_null_actions", nullCount == 0, "null akcji: " + nullCount);
	t.Check("registry_ids_valid", badIdCount == 0, "akcji z pustym id: " + badIdCount);
	t.Check("registry_ids_unique", dupCount == 0, "duplikaty id: " + dupCount + " (pierwszy: " + firstDup + ")");
	t.Check("registry_has_syanna_t4", hasSyanna, "brak syanna_intimate_invite w rejestrze");
}

function MCM_AR_E2E_AffinityAndConfig(t : MCM_AR_E2E)
{
	var wrapper     : CInGameConfigWrapper;
	var aff         : MCM_RomanceAffinityResolver;
	var cfg         : MCM_AR_ConfigWrapper;
	var origForce   : string;
	var origConsent : string;
	var dummy       : name;
	var factName    : string;
	var base, earned, expected, got : int;

	wrapper = theGame.GetInGameConfigWrapper();
	cfg = MCM_AR_GetConfig();
	aff = MCM_AR_GetAffinity();
	if (!wrapper || !cfg || !aff)
	{
		t.Skip("affinity_config_suite", "brak wrapper/config/affinity");
		return;
	}

	origForce   = wrapper.GetVarValue('MCM_AR', 'MCM_AR_ForceRomance');
	origConsent = wrapper.GetVarValue('MCM_AR', 'MCM_AR_RequireConsent');

	// --- formula zazylosci przy wylaczonym Sandboxie ---
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_ForceRomance', "0");
	t.Check("config_force_off", !cfg.IsForceRomanceOn(), "ForceRomance nie wylaczyl sie");

	dummy = 'ar_e2e_dummy';
	factName = "mcme_ar_ar_e2e_dummy_affinity";
	FactsRemove(factName);

	aff.AddAffinityPoints(dummy, 7);
	earned = aff.GetEarnedAffinity(dummy);
	t.Check("affinity_earned_add", earned == 7, "earned=" + earned + " (oczekiwano 7)");

	base = aff.GetBaseStoryAffinity(dummy);
	expected = RoundMath((float)(base) + ((float)(earned) * cfg.GetAffinityMultiplier()));
	got = aff.GetAffinity(dummy);
	t.Check("affinity_formula", got == expected, "GetAffinity=" + got + " expected=" + expected + " (base=" + base + " earned=" + earned + " mult=" + cfg.GetAffinityMultiplier() + ")");
	t.Check("affinity_multiplier_positive", cfg.GetAffinityMultiplier() > 0.0, "mnoznik <= 0");

	aff.AddAffinityPoints(dummy, 5);
	t.Check("affinity_earned_accumulates", aff.GetEarnedAffinity(dummy) == 12, "earned=" + aff.GetEarnedAffinity(dummy) + " (oczekiwano 12)");
	FactsRemove(factName);
	t.Check("affinity_dummy_cleanup", aff.GetEarnedAffinity(dummy) == 0, "fakt dummy nie zniknal");

	// --- Sandbox: ForceRomance => 200 ---
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_ForceRomance', "1");
	t.Check("config_force_on", cfg.IsForceRomanceOn(), "ForceRomance nie wlaczyl sie");
	t.Check("affinity_force_200", aff.GetAffinity(dummy) == 200, "GetAffinity w Sandboxie=" + aff.GetAffinity(dummy));

	// --- zgoda: przelacznik RequireConsent ---
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_RequireConsent', "1");
	t.Check("config_consent_on", cfg.RequiresPlayerConsent(), "RequireConsent nie wlaczyl sie");
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_RequireConsent', "0");
	t.Check("config_consent_off", !cfg.RequiresPlayerConsent(), "RequireConsent nie wylaczyl sie");

	// --- przywrocenie ---
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_ForceRomance', origForce);
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_RequireConsent', origConsent);
	t.Check("config_restored",
		wrapper.GetVarValue('MCM_AR', 'MCM_AR_ForceRomance') == origForce &&
		wrapper.GetVarValue('MCM_AR', 'MCM_AR_RequireConsent') == origConsent,
		"nie przywrocono ustawien MCM");
}

function MCM_AR_E2E_Facts(t : MCM_AR_E2E)
{
	FactsRemove('mcme_ar_e2e_probe');
	FactsAdd('mcme_ar_e2e_probe', 1);
	t.Check("facts_add", FactsQuerySum('mcme_ar_e2e_probe') == 1, "FactsQuerySum != 1");
	FactsRemove('mcme_ar_e2e_probe');
	t.Check("facts_remove", FactsQuerySum('mcme_ar_e2e_probe') == 0, "fakt nie zostal usuniety");
}

function MCM_AR_E2E_DevIO(t : MCM_AR_E2E)
{
	var content : string;

	MCM_AR_DevClearFile("ar_e2e_probe.txt");
	t.Check("devio_write", MCM_AR_DevWriteFile("ar_e2e_probe.txt", "e2e"), "DevWriteFile zwrocil false");
	content = MCM_AR_DevReadFile("ar_e2e_probe.txt");
	t.Check("devio_read", content == "e2e", "odczyt='" + content + "'");
	MCM_AR_DevClearFile("ar_e2e_probe.txt");
}

// Dry-run bramek na realnej druzynie: ten sam filtr co ar_eval.
function MCM_AR_E2E_Gating(t : MCM_AR_E2E)
{
	var core       : MCM_AutonomousRomanceCore;
	var reg        : MCM_RomanceActionRegistry;
	var ctx        : MCM_RomanceContext;
	var companions : array<CNewNPC>;
	var npc        : CNewNPC;
	var act        : MCM_RomanceInteraction;
	var i, j       : int;
	var followers  : int;
	var eligible   : int;
	var blocked    : int;
	var noReason   : int;
	var firstBad   : string;
	var nam        : name;

	core = MCM_AR_GetCore();
	if (!core || !core.registry)
	{
		t.Skip("gating_dry_run", "brak core/registry");
		return;
	}
	reg = core.registry;

	theGame.GetNPCsByTag('GeraltsBFF', companions);
	followers = 0;
	for (i = 0; i < companions.Size(); i += 1)
	{
		if (companions[i] && companions[i].scmcc && companions[i].HasTag('mod_scm_IsFollowing'))
		{
			followers += 1;
		}
	}
	if (followers == 0)
	{
		t.Skip("gating_dry_run", "w party nie ma towarzyszy (zrespawnuj kogos przez menu MCME)");
		return;
	}

	ctx = core.BuildContext(companions);
	eligible = 0;
	blocked = 0;
	noReason = 0;
	firstBad = "";
	for (i = 0; i < companions.Size(); i += 1)
	{
		npc = companions[i];
		if (!npc || !npc.scmcc || !npc.HasTag('mod_scm_IsFollowing')) continue;
		nam = npc.scmcc.data.nam;
		for (j = 0; j < reg.GetActionCount(); j += 1)
		{
			act = reg.GetAction(j);
			if (!act) continue;
			if (IsNameValid(act.targetNpc) && act.targetNpc != nam) continue;
			if (act.CanExecute(npc, thePlayer, ctx))
			{
				eligible += 1;
			}
			else
			{
				blocked += 1;
				if (act.GetBlockReason(npc, thePlayer, ctx) == "")
				{
					noReason += 1;
					if (firstBad == "") firstBad = NameToString(act.id) + "@" + NameToString(nam);
				}
			}
		}
	}
	t.Check("gating_completed", eligible + blocked > 0, "zadna akcja nie zostala oceniona");
	t.Check("gating_block_reasons", noReason == 0, "akcji zablokowanych bez powodu: " + noReason + " (pierwsza: " + firstBad + ")");
}

exec function ar_test_e2e()
{
	var t : MCM_AR_E2E;

	if (!MCM_AR_DevActive())
	{
		thePlayer.DisplayHudMessage("[AR-dev] TW3SE inactive - E2E unavailable");
		return;
	}
	if (!thePlayer)
	{
		return;
	}

	MCM_AR_DevClearFile("ar_e2e.txt");
	t = new MCM_AR_E2E in thePlayer;

	MCM_AR_E2E_Core(t);
	MCM_AR_E2E_Registry(t);
	MCM_AR_E2E_AffinityAndConfig(t);
	MCM_AR_E2E_Facts(t);
	MCM_AR_E2E_DevIO(t);
	MCM_AR_E2E_Gating(t);

	t.Finish();
	thePlayer.DisplayHudMessage("[AR-e2e] pass=" + t.passed + " fail=" + t.failed + " skip=" + t.skipped);
}


// Tour scen dla obserwatora (ar_tour_scenes)

// Pin w polu: GC zabija nieprzypisany latent-runner w pierwszym Sleep.
@addField(CR4Player)
public var mcm_ar_tour : MCM_AR_TourRunner;

statemachine class MCM_AR_TourRunner
{
	default autoState = 'Idle';
	public var targetNpc : CNewNPC;
	public var action    : MCM_RomanceInteraction;
}

state Idle in MCM_AR_TourRunner
{
}

state Running in MCM_AR_TourRunner
{
	private function LogTour(msg : string)
	{
		MCM_AR_Log("[TOUR] " + msg);
		MCM_AR_DevEmit("[TOUR] " + msg);
		thePlayer.DisplayHudMessage("[TOUR] " + msg);
	}

	event OnEnterState(prevStateName : name)
	{
		RunTourSequence();
	}

	entry function RunTourSequence()
	{
		var npc : CNewNPC;
		var nam : name;
		var ok : bool;

		npc = parent.targetNpc;
		if (!npc || !npc.scmcc || !npc.scmcc.data)
		{
			LogTour("ABORT: NPC invalid or missing scmcc");
			StopTour();
			return;
		}

		nam = npc.scmcc.data.nam;
		parent.action = new MCM_RomanceInteraction in thePlayer;

		LogTour("=== START TOUR dla " + NameToString(nam) + " ===");

		// Staging jak SoftApproach: rekord idle-joba musi umrzec, inaczej re-pose walczy o slot.
		if (npc.scmcc && npc.scmcc.IsFollowing())
		{
			npc.scmcc.StopFollowing(true);
		}
		if (npc.GetCurrentStateName() == 'SCMPlayIdleAnim')
		{
			npc.PopState(true);
		}
		if (MCM_AR_GetCore())
		{
			MCM_AR_GetCore().RemoveIdleJobFor(npc);
		}
		npc.ActionCancelAll();
		npc.ActionRotateToAsync(thePlayer.GetWorldPosition());

		// 1. Toast / animacja picia wina
		LogTour("1/4: Odtwarzanie animacji picia (PlayDrinkingAnimation)...");
		parent.action.PlayDrinkingAnimation(npc);
		Sleep(2.5);

		// 2. Bark powitalny / po rozłące
		LogTour("2/4: Odgrywanie kwestii głosowej towarzyszki...");
		npc.PlayVoiceset(100, 'greeting_geralt');
		Sleep(3.0);

		// 3. Bezpośredni Pocałunek (lub Uścisk dla Ciri)
		if (nam == 'ciri' || nam == 'cirilla')
		{
			LogTour("3/4: Odtwarzanie bezokienkowego uścisku Ciri (PlayHugScene)...");
			ok = parent.action.PlayHugScene(npc);
		}
		else
		{
			LogTour("3/4: Odtwarzanie bezokienkowego pocałunku (PlayKissScene)...");
			ok = parent.action.PlayKissScene(npc);
		}
		LogTour("3/4: Pocałunek/Uścisk zakończony (ok=" + ok + "). Afterglow bark...");
		Sleep(3.0);

		// 4. Scena intymna NaughtyPoint (jeśli w pobliżu sweet spota).
		// Ciri: pomijamy — więź rodzinna, T4 nie istnieje dla niej (lore).
		if (nam == 'ciri' || nam == 'cirilla')
		{
			LogTour("4/4: POMINIĘTO dla Ciri (więź rodzinna — brak T4).");
		}
		else
		{
			LogTour("4/4: Sprawdzanie punktu intymnego (NaughtyPoint <=20m)...");
			ok = parent.action.PlayIntimateScene(npc);
			if (ok)
			{
				LogTour("4/4: Scena intymna zakończona pomyślnie!");
			}
			else
			{
				LogTour("4/4: Scena intymna pominięta/niedostępna (brak NaughtyPoint w pobliżu lub brak sceny).");
			}
		}

		Sleep(1.0);
		LogTour("=== TOUR ZAKOŃCZONY POMYŚLNIE ===");
		StopTour();
	}

	private function StopTour()
	{
		var pl : CR4Player;

		if (parent.action && parent.targetNpc)
		{
			parent.action.CleanHandProps(parent.targetNpc);
		}
		parent.action = NULL;
		if (thePlayer)
		{
			thePlayer.UnblockAction(EIAB_Movement, 'MCM_AR_interaction');
			thePlayer.DisableLookAt();
			// thePlayer jest const dla zapisu pol - przez lokalna.
			pl = GetWitcherPlayer();
			if (pl)
			{
				pl.mcm_ar_tour = NULL;
			}
		}
		if (parent.targetNpc)
		{
			parent.targetNpc.ActionCancelAll();
			if (parent.targetNpc.scmcc && parent.targetNpc.scmcc.IsFollowing())
			{
				parent.targetNpc.scmcc.StartFollowing(true);
			}
		}
	}
}

exec function ar_tour_scenes(optional npcStr : string)
{
	var companions : array<CNewNPC>;
	var target     : CNewNPC;
	var runner     : MCM_AR_TourRunner;
	var pl         : CR4Player;
	var i          : int;

	if (!MCM_AR_DevActive())
	{
		thePlayer.DisplayHudMessage("[AR-dev] TW3SE inactive - tour unavailable");
		return;
	}

	if (thePlayer.mcm_ar_tour && thePlayer.mcm_ar_tour.GetCurrentStateName() == 'Running')
	{
		thePlayer.DisplayHudMessage("[TOUR] Tour already in progress.");
		return;
	}

	if (npcStr != "")
	{
		target = MCM_AR_FindCompanion(npcStr);
	}

	if (!target)
	{
		theGame.GetNPCsByTag('GeraltsBFF', companions);
		for (i = 0; i < companions.Size(); i += 1)
		{
			if (companions[i] && companions[i].scmcc && companions[i].HasTag('mod_scm_IsFollowing'))
			{
				target = companions[i];
				break;
			}
		}
	}

	if (!target)
	{
		thePlayer.DisplayHudMessage("[TOUR] Nie znaleziono aktywnej towarzyszki w druzynie!");
		return;
	}

	runner = new MCM_AR_TourRunner in thePlayer;
	runner.targetNpc = target;
	pl = GetWitcherPlayer();
	if (pl)
	{
		pl.mcm_ar_tour = runner;
	}
	runner.GotoState('Running');
}
