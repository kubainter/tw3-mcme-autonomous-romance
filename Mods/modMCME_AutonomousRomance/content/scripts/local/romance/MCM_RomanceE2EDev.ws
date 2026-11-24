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

	public function Dump(line : string)
	{
		Out(line);
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

function MCM_AR_E2E_TriggerName(tt : ERomanceTriggerType) : string
{
	if (tt == RTT_OneLiner) return "OneLiner";
	if (tt == RTT_Gesture) return "Gesture";
	if (tt == RTT_Prompt) return "Prompt";
	if (tt == RTT_Scene) return "Scene";
	return "unknown";
}

function MCM_AR_E2E_DumpRegistry(t : MCM_AR_E2E)
{
	var core : MCM_AutonomousRomanceCore;
	var reg  : MCM_RomanceActionRegistry;
	var act  : MCM_RomanceInteraction;
	var i, n : int;

	core = MCM_AR_GetCore();
	if (!core || !core.registry)
	{
		t.Skip("registry_dump", "brak core/registry");
		return;
	}
	reg = core.registry;
	n = reg.GetActionCount();
	for (i = 0; i < n; i += 1)
	{
		act = reg.GetAction(i);
		if (!act) continue;
		t.Dump("[E2E:REG] " + NameToString(act.id) + "|" + NameToString(act.targetNpc) + "|" + MCM_AR_E2E_TriggerName(act.triggerType) + "|" + act.minAffinity + "|" + (int)act.cooldownSeconds + "|" + act.weight + "|" + act.isTimeCritical);
	}
	t.Check("registry_dump", n > 0, "rejestr pusty");
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

	MCM_AR_GetActiveCompanions(companions);
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

// Kanal downtime: klasyfikator czysty-IDLE vs medytacja/sen.
function MCM_AR_E2E_Downtime(t : MCM_AR_E2E)
{
	var core       : MCM_AutonomousRomanceCore;
	var kind       : name;
	var inDt       : bool;
	var safeReason : string;
	var pureExpl   : bool;
	var lfT        : Vector;
	var rfT        : Vector;
	var ringT      : Vector;
	var sideT      : name;

	core = MCM_AR_GetCore();
	if (!core)
	{
		t.Skip("downtime_*", "brak core");
		return;
	}

	inDt = core.MCM_AR_IsPlayerInDowntime(kind);
	t.Dump("[E2E:INFO] downtime now=" + inDt + " kind=" + NameToString(kind) +
	       " state=" + NameToString(thePlayer.GetCurrentStateName()) +
	       " action=" + (int)thePlayer.GetPlayerAction() +
	       " ctx=" + NameToString(theInput.GetContext()));

	pureExpl = thePlayer.GetCurrentStateName() == 'Exploration' &&
	           thePlayer.GetPlayerAction() != PEA_GoToSleep &&
	           thePlayer.GetPlayerAction() != PEA_Meditation;

	if (pureExpl)
	{
		// Czysta eksploracja: klasyfikator MUSI zwrocic false, a bramka
		// nie moze raportowac downtime jako powodu blokady.
		t.Check("downtime_false_in_exploration", !inDt, "kind=" + NameToString(kind));
		core.MCM_AR_IsSafeToInitiate(safeReason);
		t.Check("downtime_not_gate_reason", safeReason != "downtime (meditation/sleep)", "reason=" + safeReason);
	}
	else
	{
		// Test odpalony w medytacji/lozku: klasyfikator MUSI to wykryc.
		t.Check("downtime_detected_when_expected", inDt,
		        "stan/action w downtime, klasyfikator zwrocil false");
	}

	// Pure-logic: wybor strony lozka + geometria pierscienia (bez encji).
	// lf/rf = nasze wlasne stale AP łozka Corvo master (parter).
	lfT = Vector(-400.561, -799.693, 35.235);
	rfT = Vector(-399.806, -800.192, 35.235);
	// Geralt po stronie rf -> wolny partner powinien isc na lf.
	sideT = core.DowntimeBedChooseSide(Vector(-399.8, -800.2, 35.2), lfT, rfT, true, true);
	t.Check("downtime_bed_side_far_lf", sideT == 'lf', "side=" + NameToString(sideT));
	sideT = core.DowntimeBedChooseSide(Vector(-400.6, -799.7, 35.2), lfT, rfT, true, true);
	t.Check("downtime_bed_side_far_rf", sideT == 'rf', "side=" + NameToString(sideT));
	sideT = core.DowntimeBedChooseSide(Vector(-399.8, -800.2, 35.2), lfT, rfT, false, true);
	t.Check("downtime_bed_side_occ_lf", sideT == 'rf', "side=" + NameToString(sideT));
	sideT = core.DowntimeBedChooseSide(Vector(0, 0, 0), lfT, rfT, false, false);
	t.Check("downtime_bed_side_none", sideT == '', "side=" + NameToString(sideT));

	// Ring spot: odleglosc wynosi dokladnie radius, nawet przy degeneracji.
	ringT = core.DowntimeRingSpot(Vector(0, 0, 0), Vector(5, 0, 0), 1.4);
	t.Check("downtime_ring_radius", AbsF(VecDistance2D(ringT, Vector(0, 0, 0)) - 1.4) < 0.05,
	        "len=" + FloatToString(VecDistance2D(ringT, Vector(0, 0, 0))));
	ringT = core.DowntimeRingSpot(Vector(0, 0, 0), Vector(0.1, 0.1, 0), 1.9);
	t.Check("downtime_ring_degenerate", AbsF(VecDistance2D(ringT, Vector(0, 0, 0)) - 1.9) < 0.05,
	        "len=" + FloatToString(VecDistance2D(ringT, Vector(0, 0, 0))));
}

function MCM_AR_E2E_DumpGateMap(t : MCM_AR_E2E)
{
	var core       : MCM_AutonomousRomanceCore;
	var reg        : MCM_RomanceActionRegistry;
	var ctx        : MCM_RomanceContext;
	var companions : array<CNewNPC>;
	var npc        : CNewNPC;
	var act        : MCM_RomanceInteraction;
	var i, j, rows : int;
	var nam        : name;
	var reason     : string;

	core = MCM_AR_GetCore();
	if (!core || !core.registry)
	{
		t.Skip("gatemap_dump", "brak core/registry");
		return;
	}
	reg = core.registry;

	MCM_AR_GetActiveCompanions(companions);
	ctx = core.BuildContext(companions);
	rows = 0;
	for (i = 0; i < companions.Size(); i += 1)
	{
		npc = companions[i];
		if (!npc || !npc.scmcc || !npc.HasTag('mod_scm_IsFollowing')) continue;
		nam = npc.scmcc.data.nam;
		for (j = 0; j < reg.GetActionCount(); j += 1)
		{
			act = reg.GetAction(j);
			if (!act) continue;
			if (IsNameValid(act.targetNpc) && act.targetNpc != nam && !(act.targetNpc == 'pryscilla' && nam == 'priscilla') && !(act.targetNpc == 'priscilla' && nam == 'pryscilla')) continue;
			reason = act.GetBlockReason(npc, thePlayer, ctx);
			if (reason == "") t.Dump("[E2E:GATE] " + NameToString(nam) + "|" + NameToString(act.id) + "|ELIGIBLE");
			else t.Dump("[E2E:GATE] " + NameToString(nam) + "|" + NameToString(act.id) + "|BLOCKED|" + reason);
			rows += 1;
		}
	}
	t.Check("gatemap_followers", rows > 0, "brak followerow z tagiem mod_scm_IsFollowing (zaladuj save z Triss+Yen w follow)");
}
@addField(CR4Player)
public var mcm_ar_e2e : MCM_AR_E2ERunner;

statemachine class MCM_AR_E2ERunner
{
	default autoState = 'Idle';
	public var t : MCM_AR_E2E;
}

state Idle in MCM_AR_E2ERunner
{
}

state Running in MCM_AR_E2ERunner
{
	event OnEnterState(prevStateName : name)
	{
		RunSuites();
	}

	entry function RunSuites()
	{
		var pl : CR4Player;

		MCM_AR_E2E_GateOrder(parent.t);
		MCM_AR_E2E_AffinityEdge(parent.t);
		MCM_AR_E2E_IdleJob(parent.t);
		MCM_AR_E2E_GiftFlow(parent.t);
		MCM_AR_E2E_ScenePaths(parent.t);
		MCM_AR_E2E_ConfigGuards(parent.t);
		MCM_AR_E2E_DanceWhitelist(parent.t);
		MCM_AR_E2E_RegistryFlow(parent.t);
		MCM_AR_E2E_ConsentTimeout(parent.t);

		parent.t.Finish();
		thePlayer.DisplayHudMessage("[AR-e2e] pass=" + parent.t.passed + " fail=" + parent.t.failed + " skip=" + parent.t.skipped);
		pl = GetWitcherPlayer();
		if (pl)
		{
			pl.mcm_ar_e2e = NULL;
		}
	}
}

function MCM_AR_E2E_FirstFollower(companions : array<CNewNPC>) : CNewNPC
{
	var i : int;

	for (i = 0; i < companions.Size(); i += 1)
	{
		if (companions[i] && companions[i].scmcc && companions[i].HasTag('mod_scm_IsFollowing')) return companions[i];
	}
	return NULL;
}

function MCM_AR_E2E_GateOrder(t : MCM_AR_E2E)
{
	var core       : MCM_AutonomousRomanceCore;
	var a          : MCM_RomanceInteraction;
	var ctx        : MCM_RomanceContext;
	var companions : array<CNewNPC>;
	var npc        : CNewNPC;
	var r          : string;

	core = MCM_AR_GetCore();
	if (!core)
	{
		t.Skip("gate_order", "brak core");
		return;
	}
	MCM_AR_GetActiveCompanions(companions);
	npc = MCM_AR_E2E_FirstFollower(companions);
	ctx = core.BuildContext(companions);
	a = new MCM_RomanceInteraction in thePlayer;
	a.cooldownSeconds = 300.0;

	a.ResetCooldown();
	a.MarkAttempted();
	r = a.GetBlockReason(npc, thePlayer, ctx);
	t.Check("gate_order_cooldown", r == "cooldown", "reason=" + r + " (oczekiwano cooldown)");

	a.ResetCooldown();
	a.MarkRejected();
	a.MarkRejected();
	a.MarkRejected();
	r = a.GetBlockReason(npc, thePlayer, ctx);
	t.Check("gate_order_backoff_x3", r == "rejected_backoff", "reason=" + r + " (oczekiwano rejected_backoff)");

	a.ResetCooldown();
	if (!npc)
	{
		t.Skip("gate_order_after_reset", "brak followera - bramki dystansu nie da sie ocenic");
		return;
	}
	r = a.GetBlockReason(npc, thePlayer, ctx);
	t.Check("gate_order_after_reset", r != "cooldown" && r != "rejected_backoff", "reason=" + r);
}

function MCM_AR_E2E_AffinityEdge(t : MCM_AR_E2E)
{
	var wrapper    : CInGameConfigWrapper;
	var cfg        : MCM_AR_ConfigWrapper;
	var aff        : MCM_RomanceAffinityResolver;
	var core       : MCM_AutonomousRomanceCore;
	var a          : MCM_RomanceInteraction;
	var ctx        : MCM_RomanceContext;
	var companions : array<CNewNPC>;
	var npc        : CNewNPC;
	var nam        : name;
	var cur        : int;
	var r          : string;
	var origForce  : string;

	wrapper = theGame.GetInGameConfigWrapper();
	cfg = MCM_AR_GetConfig();
	aff = MCM_AR_GetAffinity();
	core = MCM_AR_GetCore();
	if (!wrapper || !cfg || !aff || !core)
	{
		t.Skip("affinity_edge", "brak wrapper/config/affinity/core");
		return;
	}
	MCM_AR_GetActiveCompanions(companions);
	npc = MCM_AR_E2E_FirstFollower(companions);
	if (!npc)
	{
		t.Skip("affinity_edge", "brak followera");
		return;
	}
	nam = npc.scmcc.data.nam;
	ctx = core.BuildContext(companions);

	origForce = wrapper.GetVarValue('MCM_AR', 'MCM_AR_ForceRomance');
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_ForceRomance', "0");
	cur = aff.GetAffinity(nam);
	t.Check("affinity_edge_meets_current", aff.MeetsMinAffinity(nam, cur), "MeetsMinAffinity(cur=" + cur + ")=false");
	t.Check("affinity_edge_fails_above", !aff.MeetsMinAffinity(nam, cur + 1), "MeetsMinAffinity(cur+1)=true");

	a = new MCM_RomanceInteraction in thePlayer;
	a.minAffinity = cur + 1;
	a.ResetCooldown();
	r = a.GetBlockReason(npc, thePlayer, ctx);
	t.Check("affinity_edge_gate_blocks", r == "affinity", "reason=" + r + " (oczekiwano affinity)");

	wrapper.SetVarValue('MCM_AR', 'MCM_AR_ForceRomance', "1");
	r = a.GetBlockReason(npc, thePlayer, ctx);
	t.Check("affinity_edge_sandbox_bypass", r != "affinity", "reason=" + r + " (Sandbox powinien omijac prog)");

	wrapper.SetVarValue('MCM_AR', 'MCM_AR_ForceRomance', origForce);
	t.Check("affinity_edge_force_restored", wrapper.GetVarValue('MCM_AR', 'MCM_AR_ForceRomance') == origForce, "nie przywrocono ForceRomance");
}

latent function MCM_AR_E2E_IdleJob(t : MCM_AR_E2E)
{
	var core : MCM_AutonomousRomanceCore;
	var n    : int;
	var k    : int;

	core = MCM_AR_GetCore();
	if (!core)
	{
		t.Skip("idle_job", "brak core");
		return;
	}
	core.ForceIdleSuspendNow();
	n = 0;
	for (k = 0; k < 45 && n == 0; k += 1)
	{
		Sleep(1.0);
		n = core.GetIdleSuspendCount();
	}
	if (n == 0)
	{
		t.Skip("idle_job", "brak kandydatow do idle-suspend (brak followera?)");
		return;
	}
	t.Check("idle_job_created", n > 0, "GetIdleSuspendCount=" + n);
	t.Check("idle_anim_state_valid", core.IdleAnimStateValid(), "animPhase/animStart/animEnd niespojne");
	core.ForceResetRuntimeState();
	t.Check("idle_job_reset", core.GetIdleSuspendCount() == 0, "po resecie count=" + core.GetIdleSuspendCount());
}

function MCM_AR_E2E_GiftFlow(t : MCM_AR_E2E)
{
	var a      : MCM_AR_GiftRequest_Base;
	var inv    : CInventoryComponent;
	var g      : name;
	var before : int;
	var after  : int;

	inv = thePlayer.inv;
	before = inv.GetItemQuantityByName('Alcohest');
	inv.AddAnItem('Alcohest', 1);
	a = new MCM_AR_Keira_GiftRequest in thePlayer;
	g = a.FindBestAvailableGift();
	t.Check("gift_found_after_add", IsNameValid(g), "FindBestAvailableGift == ''");
	t.Check("gift_qty_positive", IsNameValid(g) && inv.GetItemQuantityByName(g) > 0, "qty kandydata <= 0");
	inv.RemoveItemByName('Alcohest', 1);
	after = inv.GetItemQuantityByName('Alcohest');
	t.Check("gift_restore_qty", after == before, "before=" + before + " after=" + after);
}

function MCM_AR_E2E_ScenePaths(t : MCM_AR_E2E)
{
	var a          : MCM_RomanceInteraction;
	var companions : array<CNewNPC>;
	var npc        : CNewNPC;
	var nam        : name;
	var p          : string;
	var i, n       : int;

	MCM_AR_GetActiveCompanions(companions);
	a = new MCM_RomanceInteraction in thePlayer;
	n = 0;
	for (i = 0; i < companions.Size(); i += 1)
	{
		npc = companions[i];
		if (!npc || !npc.scmcc || !npc.HasTag('mod_scm_IsFollowing')) continue;
		n += 1;
		nam = npc.scmcc.data.nam;
		p = a.E2E_AutonomousScenePath(npc, false);
		if (nam == 'anna_henrietta' || nam == 'sq701_vivienne' || nam == 'vampire_diva')
		{
			t.Check("scene_noble_empty_" + NameToString(nam), p == "", "path=" + p + " (noble rig: brak kiss)");
		}
		else if (nam == 'cirilla' || nam == 'ciri')
		{
			if (MCM_AR_GetConfig().IsCiriAdultMode()) t.Check("scene_ciri_adult", p != "", "adult: path pusta");
			else t.Check("scene_ciri_lore", p == "", "lore: path=" + p);
		}
		else
		{
			if (p == "" && a.E2E_ResolveIntimateScenePath(npc) == "dlc\mod_mcme_autonomous_romance\dialogue\ar_shani_intimate_outdoor.w2scene") t.Check("scene_generic_woman_base_" + NameToString(nam), true, "");
			else t.Check("scene_kiss_" + NameToString(nam), p != "", "path pusta (brak sceny ar_*)");
		}

		if (nam == 'shani' || nam == 'triss' || nam == 'yennefer' || nam == 'keira' || nam == 'keira_metz')
		{
			if (!a.E2E_IsOnNaughtyPoint())
			{
				t.Check("scene_outdoor_intimate_" + NameToString(nam), a.E2E_ResolveIntimateScenePath(npc) == "dlc\mod_mcme_autonomous_romance\dialogue\ar_shani_intimate_outdoor.w2scene", "outdoor intimate path mismatch");
			}
		}
		else if (nam != 'cirilla' && nam != 'ciri')
		{
			t.Check("scene_resolve_bundle_" + NameToString(nam), StrStartsWith(a.E2E_ResolveIntimateScenePath(npc), "dlc\mod_mcme_autonomous_romance\naughty") || (a.E2E_ResolveIntimateScenePath(npc) == "dlc\mod_mcme_autonomous_romance\dialogue\ar_shani_intimate_outdoor.w2scene"), "resolve path mismatch (neither naughty bundle nor universal outdoor)");
		}
	}

	t.Check("scene_margarita_typo", StrContains(a.E2E_NaughtyScenePath('margarita'), "margaritta"), "NaughtyScenePath(margarita) bez 'margaritta'");
	t.Check("scene_naughty_bundle_anarietta", StrStartsWith(a.E2E_NaughtyScenePath('anna_henrietta'), "dlc\mod_mcme_autonomous_romance\naughty"), "anarietta bundle path");
	t.Check("scene_naughty_bundle_vivienne", StrStartsWith(a.E2E_NaughtyScenePath('vivienne'), "dlc\mod_mcme_autonomous_romance\naughty"), "vivienne bundle path");
	t.Check("scene_naughty_bundle_cerys", StrStartsWith(a.E2E_NaughtyScenePath('cerys'), "dlc\mod_mcme_autonomous_romance\naughty"), "cerys bundle path");
	t.Check("scene_naughty_bundle_ves", StrStartsWith(a.E2E_NaughtyScenePath('ves'), "dlc\mod_mcme_autonomous_romance\naughty"), "ves bundle path");
	t.Check("scene_naughty_bundle_salma", StrStartsWith(a.E2E_NaughtyScenePath('salma'), "dlc\mod_mcme_autonomous_romance\naughty"), "salma bundle path");
	t.Check("scene_naughty_bundle_priscilla", StrStartsWith(a.E2E_NaughtyScenePath('priscilla'), "dlc\mod_mcme_autonomous_romance\naughty"), "priscilla bundle path");
	t.Check("scene_naughty_bundle_edna", StrStartsWith(a.E2E_NaughtyScenePath('edna'), "dlc\mod_mcme_autonomous_romance\naughty"), "edna bundle path");
	t.Check("scene_naughty_bundle_fringilla", StrStartsWith(a.E2E_NaughtyScenePath('fringilla'), "dlc\mod_mcme_autonomous_romance\naughty"), "fringilla bundle path");
	t.Check("scene_naughty_bundle_philippa", StrStartsWith(a.E2E_NaughtyScenePath('philippa'), "dlc\mod_mcme_autonomous_romance\naughty"), "philippa bundle path");
	t.Check("scene_naughty_bundle_oriana", StrStartsWith(a.E2E_NaughtyScenePath('oriana'), "dlc\mod_mcme_autonomous_romance\naughty"), "oriana bundle path");

	if (n == 0)
	{
		t.Skip("scene_paths", "brak followerow");
		return;
	}
}

function MCM_AR_E2E_ConfigGuards(t : MCM_AR_E2E)
{
	var cfg       : MCM_AR_ConfigWrapper;
	var wrapper   : CInGameConfigWrapper;
	var origCiri  : string;
	var origTick  : string;
	var bp        : int;

	cfg = MCM_AR_GetConfig();
	wrapper = theGame.GetInGameConfigWrapper();
	if (!cfg || !wrapper)
	{
		t.Skip("config_guards", "brak config/wrapper");
		return;
	}

	bp = cfg.GetBarkPreset();
	t.Check("config_bark_preset_range", bp >= 1 && bp <= 3, "BarkPreset=" + bp);

	origCiri = wrapper.GetVarValue('MCM_AR', 'MCM_AR_CiriMode');
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_CiriMode', "1");
	t.Check("config_ciri_on", cfg.IsCiriAdultMode(), "CiriMode nie wlaczyl sie");
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_CiriMode', "0");
	t.Check("config_ciri_off", !cfg.IsCiriAdultMode(), "CiriMode nie wylaczyl sie");
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_CiriMode', origCiri);

	origTick = wrapper.GetVarValue('MCM_AR', 'MCM_AR_TickInterval');
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_TickInterval', "5");
	t.Check("config_tick_clamp_min", cfg.GetTickIntervalSeconds() >= 20.0, "tick=" + cfg.GetTickIntervalSeconds() + " (oczekiwano >=20)");
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_TickInterval', "500");
	t.Check("config_tick_clamp_max", cfg.GetTickIntervalSeconds() <= 160.0, "tick=" + cfg.GetTickIntervalSeconds() + " (oczekiwano <=160)");
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_TickInterval', origTick);

	t.Check("config_guards_restored", wrapper.GetVarValue('MCM_AR', 'MCM_AR_CiriMode') == origCiri && wrapper.GetVarValue('MCM_AR', 'MCM_AR_TickInterval') == origTick, "nie przywrocono ustawien MCM");
}

// Suita DanceWhitelist (F1): mapa animacji + istnienie akcji *_dance/*_dance_refuse
// w rejestrze. GetDanceAnimsForNpc jest synchroniczne - suita nie musi byc latentna.
function MCM_AR_E2E_DanceWhitelist(t : MCM_AR_E2E)
{
	var inter   : MCM_AR_Dance_Base;
	var reg     : MCM_RomanceActionRegistry;
	var wrapper : CInGameConfigWrapper;
	var core    : MCM_AutonomousRomanceCore;
	var orig    : string;
	var ok      : bool;

	inter   = new MCM_AR_Dance_Base in t;
	core    = MCM_AR_GetCore();
	wrapper = theGame.GetInGameConfigWrapper();
	if (!inter || !core || !core.registry || !wrapper)
	{
		t.Skip("dance_whitelist", "brak inter/core/registry/wrapper");
		return;
	}
	reg = core.registry;

	// Whitelist -> niepusty zestaw animacji.
	t.Check("dance_anim_triss",     inter.GetDanceAnimsForNpc('triss') != "", "triss -> ''");
	t.Check("dance_anim_keira",     inter.GetDanceAnimsForNpc('keira_metz') != "", "keira_metz -> ''");
	t.Check("dance_anim_shani",     inter.GetDanceAnimsForNpc('shani') != "", "shani -> ''");
	t.Check("dance_anim_priscilla", inter.GetDanceAnimsForNpc('priscilla') != "", "priscilla -> ''");
	t.Check("dance_anim_cerys",     inter.GetDanceAnimsForNpc('becca') != "", "becca -> ''");
	t.Check("dance_anim_tomira",    inter.GetDanceAnimsForNpc('prologue_village_herbalist') != "", "tomira -> ''");
	t.Check("dance_anim_ves_empty",  inter.GetDanceAnimsForNpc('ves') == "", "ves has dance anim (should refuse)");

	// Refuse / noble-rig / edna -> pusty zestaw (nigdy nie tancza).
	t.Check("dance_anim_yen_empty",      inter.GetDanceAnimsForNpc('yennefer') == "", "yennefer niepusty");
	t.Check("dance_anim_philippa_empty", inter.GetDanceAnimsForNpc('philippa_eilhart') == "", "philippa niepusty");
	t.Check("dance_anim_noble_empty",    inter.GetDanceAnimsForNpc('anna_henrietta') == "", "noble niepusty");
	t.Check("dance_anim_edna_empty",     inter.GetDanceAnimsForNpc('edna_var_attre') == "", "edna niepusty");

	// Ciri: Adult -> zestaw dance, Lore -> "".
	orig = wrapper.GetVarValue('MCM_AR', 'MCM_AR_CiriMode');
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_CiriMode', "1");
	t.Check("dance_anim_ciri_adult", inter.GetDanceAnimsForNpc('cirilla') != "", "ciri Adult -> ''");
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_CiriMode', "0");
	t.Check("dance_anim_ciri_lore", inter.GetDanceAnimsForNpc('cirilla') == "", "ciri Lore niepusty");
	wrapper.SetVarValue('MCM_AR', 'MCM_AR_CiriMode', orig);

	// Rejestr: akcje *_dance i *_dance_refuse istnieja (uchwyt -> bool przez if).
	ok = false;
	if (reg.FindActionForNpc('triss', "dance")) ok = true;
	t.Check("dance_reg_triss", ok, "brak triss_dance");
	ok = false;
	if (reg.FindActionForNpc('cirilla', "dance")) ok = true;
	t.Check("dance_reg_ciri", ok, "brak ciri_dance");
	ok = false;
	if (reg.FindActionForNpc('yennefer', "dance_refuse")) ok = true;
	t.Check("dance_refuse_yen", ok, "brak yen_dance_refuse");
	ok = false;
	if (reg.FindActionForNpc('philippa_eilhart', "dance_refuse")) ok = true;
	t.Check("dance_refuse_philippa", ok, "brak philippa_dance_refuse");
	ok = false;
	if (reg.FindActionForNpc('cirilla', "dance_refuse")) ok = true;
	t.Check("dance_refuse_ciri", ok, "brak ciri_dance_refuse");
}

latent function MCM_AR_E2E_RegistryFlow(t : MCM_AR_E2E)
{
	var core       : MCM_AutonomousRomanceCore;
	var reg        : MCM_RomanceActionRegistry;
	var ctx        : MCM_RomanceContext;
	var companions : array<CNewNPC>;
	var npc        : CNewNPC;
	var act        : MCM_RomanceInteraction;
	var a          : MCM_RomanceInteraction;
	var nam        : name;
	var j          : int;
	var ok         : bool;
	var followBefore : bool;
	var r          : string;

	core = MCM_AR_GetCore();
	if (!core || !core.registry)
	{
		t.Skip("registry_flow", "brak core/registry");
		return;
	}
	reg = core.registry;
	MCM_AR_GetActiveCompanions(companions);
	npc = MCM_AR_E2E_FirstFollower(companions);
	if (!npc)
	{
		t.Skip("registry_flow", "brak followera");
		return;
	}
	nam = npc.scmcc.data.nam;
	ctx = core.BuildContext(companions);

	act = NULL;
	for (j = 0; j < reg.GetActionCount(); j += 1)
	{
		a = reg.GetAction(j);
		if (!a) continue;
		if (a.triggerType != RTT_OneLiner) continue;
		if (IsNameValid(a.targetNpc) && a.targetNpc != nam) continue;
		if (a.GetBlockReason(npc, thePlayer, ctx) == "")
		{
			act = a;
			break;
		}
	}
	if (!act)
	{
		t.Skip("registry_flow", "brak eligible T1 dla followera");
		return;
	}

	followBefore = npc.scmcc.IsFollowing();
	ok = reg.TryExecuteSpecificAction(act.id, npc, thePlayer, ctx);
	t.Check("registry_flow_staged_free", !core.IsStagedBusy(), "IsStagedBusy=true po egzekucji");
	t.Check("registry_flow_no_consent_latch", !core.HasConsentLatch(), "fakt/latch zgody zawisl");
	t.Check("registry_flow_follow_restored", npc.scmcc.IsFollowing() == followBefore, "follow przed=" + followBefore);
	if (ok)
	{
		r = act.GetBlockReason(npc, thePlayer, ctx);
		t.Check("registry_flow_cooldown_stamp", r == "cooldown", "reason=" + r + " (oczekiwano cooldown po MarkExecuted)");
	}
	else
	{
		t.Skip("registry_flow_cooldown_stamp", "TryExecuteSpecificAction zwrocilo false");
	}
	act.ResetCooldown();
}

latent function MCM_AR_E2E_ConsentTimeout(t : MCM_AR_E2E)
{
	var core       : MCM_AutonomousRomanceCore;
	var companions : array<CNewNPC>;
	var npc        : CNewNPC;
	var a          : MCM_RomanceInteraction;
	var ok         : bool;
	var followBefore : bool;
	var pl         : CR4Player;

	core = MCM_AR_GetCore();
	if (!core)
	{
		t.Skip("consent_timeout", "brak core");
		return;
	}
	MCM_AR_GetActiveCompanions(companions);
	npc = MCM_AR_E2E_FirstFollower(companions);
	if (!npc)
	{
		t.Skip("consent_timeout", "brak followera");
		return;
	}
	pl = GetWitcherPlayer();
	if (pl)
	{
		pl.mcm_ar_consentHeldC = false;
		pl.mcm_ar_consentHeldS = false;
	}
	FactsRemove('mcme_ar_awaiting_consent');
	if (core.HasConsentLatch())
	{
		t.Skip("consent_timeout", "zgoda juz wisi przed testem");
		return;
	}

	a = new MCM_RomanceInteraction in thePlayer;
	followBefore = npc.scmcc.IsFollowing();
	ok = a.E2E_ShowConsentPrompt("[E2E] consent timeout", 2.0, npc);
	t.Check("consent_timeout_returns_false", !ok, "ShowConsentPrompt=true bez wejscia gracza");
	t.Check("consent_latch_cleared", !core.HasConsentLatch(), "fakt/latch zgody zostal po timeoucie");
	t.Check("consent_staged_free", !core.IsStagedBusy(), "IsStagedBusy=true po timeoucie");
	t.Check("consent_follow_restored", npc.scmcc.IsFollowing() == followBefore, "follow przed=" + followBefore);
}
// Diagnostyka encji-mebli w poblizu gracza (do strojenia kotwicy Unicorn
// `where`): wypisuje encje w promieniu z nazwa, dystansem i tagami
// meblowymi. Dev-only (MCM_RomanceE2EDev.ws jest stripowany z release).
exec function ar_bedscan(optional radius : float)
{
	var ents  : array<CGameplayEntity>;
	var ent   : CGameplayEntity;
	var pos   : Vector;
	var s     : string;
	var i     : int;

	if (radius <= 0) radius = 5.0;
	pos = thePlayer.GetWorldPosition();
	FindGameplayEntitiesInSphere(ents, pos, radius, 80);
	MCM_AR_Log("[BEDSCAN] pos=" + VecToString(pos) + " ents=" + ents.Size());
	for (i = 0; i < ents.Size(); i += 1)
	{
		ent = ents[i];
		if (!ent || ent == (CGameplayEntity)thePlayer) continue;
		s = "" + ent;
		MCM_AR_Log("[BEDSCAN] #" + i + " d=" +
		           (int)(VecDistance(pos, ent.GetWorldPosition()) * 100) + "cm " +
		           s + " tags{bed=" + ent.HasTag('bed') +
		           " furn=" + ent.HasTag('furniture') +
		           " sleep=" + ent.HasTag('sleep') +
		           " interact=" + ent.HasTag('interaction') +
		           " sex=" + ent.HasTag('sex') + "}");
	}
}
exec function ar_e2e_rebuild_registry()
{
	var core : MCM_AutonomousRomanceCore;

	core = MCM_AR_GetCore();
	if (!core)
	{
		thePlayer.DisplayHudMessage("[AR-dev] brak core");
		return;
	}
	core.registry = new MCM_RomanceActionRegistry in core;
	core.registry.Init();
	thePlayer.DisplayHudMessage("[AR-dev] registry przebudowany: " + core.registry.GetActionCount() + " akcji");
}
exec function ar_test_e2e()
{
	var t : MCM_AR_E2E;
	var runner : MCM_AR_E2ERunner;
	var pl : CR4Player;

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
	MCM_AR_E2E_DumpRegistry(t);
	MCM_AR_E2E_DumpGateMap(t);
	MCM_AR_E2E_Registry(t);
	MCM_AR_E2E_AffinityAndConfig(t);
	MCM_AR_E2E_Facts(t);
	MCM_AR_E2E_DevIO(t);
	MCM_AR_E2E_Gating(t);
	MCM_AR_E2E_Downtime(t);

	runner = new MCM_AR_E2ERunner in thePlayer;
	runner.t = t;
	pl = GetWitcherPlayer();
	if (pl)
	{
		pl.mcm_ar_e2e = runner;
	}
	runner.GotoState('Running');
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
		MCM_AR_GetActiveCompanions(companions);
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
