/*****************************************************************************/
/* MCME Autonomous Romance x Unicorn — optional bridge (modMCME_AR_Unicorn)  */
/*                                                                           */
/* Wraps MCM_RomanceInteraction.PlayIntimateScene with a Unicorn backend.    */
/* Every failure path falls through to wrappedMethod() = the native          */
/* .w2scene path, so the bridge is a strict superset of today's behavior.    */
/*                                                                           */
/* Requires: modMCME_AutonomousRomance (base) + modUnicornCore (optional).   */
/* Without this package the base mod behaves exactly as before; without      */
/* modUnicornCore this package fails to compile by design (fail-fast).       */
/*                                                                           */
/* Busy-gate contract (cross-mod, no Unicorn symbols in base mod):           */
/*   'mcme_ar_uc_active'    global fact — any Unicorn scene live (+3s grace) */
/*   'mcme_ar_uc_on_<nam>'  per-actor fact — actor in UC scene (+5s grace)   */
/* Both facts carry expires so a crash cannot lock the gates forever.        */
/*****************************************************************************/

// ===== Konfiguracja MCM (grupa MCM_AR_Unicorn) =====

function MCM_AR_UcGetFloat(varName : name, defaultVal : float) : float
{
	var wrapper : CInGameConfigWrapper;
	var val     : string;

	wrapper = theGame.GetInGameConfigWrapper();
	if (!wrapper) return defaultVal;
	val = wrapper.GetVarValue('MCM_AR_Unicorn', varName);
	if (StrLen(val) == 0) return defaultVal;
	return StringToFloat(val);
}

// 0=off, 1=prefer-unicorn+fallback, 2=unicorn-only, 3=mix-random
function MCM_AR_UcMode() : int
{
	return RoundMath(MCM_AR_UcGetFloat('MCM_AR_UcMode', 1.0));
}

function MCM_AR_UcAllowRough() : bool
{
	var wrapper : CInGameConfigWrapper;
	var val     : string;

	wrapper = theGame.GetInGameConfigWrapper();
	if (!wrapper) return true;
	val = wrapper.GetVarValue('MCM_AR_Unicorn', 'MCM_AR_UcAllowRough');
	if (StrLen(val) == 0) return true;
	return (val == "1" || StrLower(val) == "true");
}

// ===== Fakty busy-gate =====

// FactsSet = Remove+Add; validFor=0 oznaczaloby "bez wygasania", wiec
// sufit expires ustawiamy zawsze jawnie (awaria nie zablokuje gate'ow).
function MCM_AR_UcSetActive()
{
	FactsSet("mcme_ar_uc_active", 1, 600);
}

function MCM_AR_UcClearActive(optional graceSec : int)
{
	if (graceSec > 0)
	{
		FactsSet("mcme_ar_uc_active", 1, graceSec);
	}
	else
	{
		FactsRemove("mcme_ar_uc_active");
	}
}

// Wspolna logika konca sceny (listener OnSceneEnd + fail-start w dispatchu):
// globalny fakt skracamy do graceSec TYLKO gdy zaden inny watek UC nie zyje -
// rownolegla scena nie-mostkowa inaczej utracilaby gate na 3s przed koncem.
function MCM_AR_UcEndActiveGrace(graceSec : int, excludeThread : CUnicornThread)
{
	var u       : CUnicorn;
	var threads : array<CUnicornThread>;
	var i       : int;

	u = UnicornGet();
	if (u)
	{
		threads = u.GetThreads();
		for (i = 0; i < threads.Size(); i += 1)
		{
			if (threads[i] && threads[i] != excludeThread && threads[i].IsLive())
			{
				MCM_AR_UcSetActive();
				return;
			}
		}
	}
	MCM_AR_UcClearActive(graceSec);
}

// expiresSec=0 -> FactsSet dalby fakt bez wygasania: awaryjny sufit 300s.
function MCM_AR_UcMarkActor(npc : CNewNPC, expiresSec : int)
{
	var nm : name;

	if (!npc || !npc.scmcc || !npc.scmcc.data) return;
	if (expiresSec <= 0) expiresSec = 300;
	nm = npc.scmcc.data.nam;
	FactsSet("mcme_ar_uc_on_" + NameToString(nm), 1, expiresSec);
}

function MCM_AR_UcIsMarked(npc : CNewNPC) : bool
{
	if (!npc || !npc.scmcc || !npc.scmcc.data) return false;
	return FactsQuerySum("mcme_ar_uc_on_" + NameToString(npc.scmcc.data.nam)) > 0;
}

function MCM_AR_UcClearActor(npc : CNewNPC)
{
	if (!npc || !npc.scmcc || !npc.scmcc.data) return;
	FactsRemove("mcme_ar_uc_on_" + NameToString(npc.scmcc.data.nam));
}

function MCM_AR_UcMarkThreadActors(t : CUnicornThread, expiresSec : int)
{
	var actors : array<CActor>;
	var npc    : CNewNPC;
	var i      : int;

	if (!t) return;
	actors = t.GetActors();
	for (i = 0; i < actors.Size(); i += 1)
	{
		npc = (CNewNPC)actors[i];
		if (npc)
		{
			MCM_AR_UcMarkActor(npc, expiresSec);
		}
	}
}

// ===== Init (lazy + eager przy kazdym player-ready) =====

@addField(CR4Player)
var mcm_ar_uc_listener : CMCMEARUnicornListener;

@addField(CR4Player)
var mcm_ar_uc_ciriChecked : bool;

@addField(CR4Player)
var mcm_ar_uc_fxDone : bool;

@addField(CR4Player)
var mcm_ar_uc_packsDone : bool;

// Anti-repeat: rownolegle FIFO pary (npc, scene). Mutacja tylko przez
// @addMethod - jednolity wzorzec 'this'.
@addField(CR4Player)
var mcm_ar_uc_lastNpc : array<name>;

@addField(CR4Player)
var mcm_ar_uc_lastScene : array<name>;

@addField(CR4Player)
var mcm_ar_uc_prefDone : array<name>;

// @addMethod: zapis pol @addField legalny tylko przez 'this' (thePlayer jest const).
@addMethod(CR4Player)
function MCM_AR_UcEnsureInit() : bool
{
	var u      : CUnicorn;
	var comps  : array<CNewNPC>;
	var i      : int;
	var forbid : bool;

	u = UnicornGet();
	if (!u || !u.IsReady()) return false;

	if (!mcm_ar_uc_listener)
	{
		// Pusty hook = listener slyszy WSZYSTKIE sceny, takze reczne uc_start.
		mcm_ar_uc_listener = new CMCMEARUnicornListener in this;
		u.AddListener(mcm_ar_uc_listener);
		MCM_AR_Log("[AR-UC] listener registered (no hook = all scenes)");
	}

	// Przelaczniki efektow (raz na sesje): npc_reactions i stats to
	// globalny szum poza naszymi scenami; dreams i monologue zostaja.
	// Tryb 0 = mostek wylaczony: effects/packs/ForbidActor to side-effecty
	// bridge'a i nie ruszamy recznych scen UC. Listener zostaje - busy-fakty
	// musza dzialac takze dla uc_start spoza dispatchu.
	if (MCM_AR_UcMode() <= 0) return true;
	if (!mcm_ar_uc_fxDone)
	{
		u.SetEffectEnabled('npc_reactions', false);
		u.SetEffectEnabled('stats', false);
		mcm_ar_uc_fxDone = true;
		MCM_AR_Log("[AR-UC] effects off: npc_reactions, stats (dreams/monologue on)");
	}

	// Rejestracja wlasnego packa (plan 005): lazy — U_NewScene wklada prosto
	// do U.scenes, bez wrapa na RegisterPacks (patrz MCM_AR_UnicornPacks.ws).
	if (!mcm_ar_uc_packsDone)
	{
		mcm_ar_uc_packsDone = true;
		MCM_AR_UcRegisterOurPack(u);
	}

	// Ciri: twardy zakaz w samym frameworku (druga linia za bramka nazwy
	// w dispatchu). Skan co wywolanie az do znalezienia (ciriChecked =
	// 'seen', tylko log-once); ForbidActor przy kazdym zobaczeniu i
	// respektuje IsCiriAdultMode - tryb moze sie zmienic w locie.
	MCM_AR_GetActiveCompanions(comps);
	for (i = 0; i < comps.Size(); i += 1)
	{
		if (comps[i] && comps[i].scmcc && comps[i].scmcc.data &&
		    (comps[i].scmcc.data.nam == 'cirilla' || comps[i].scmcc.data.nam == 'ciri'))
		{
			forbid = !thePlayer.MCM_AR_GetConfig().IsCiriAdultMode();
			u.ForbidActor(comps[i], forbid);
			if (!mcm_ar_uc_ciriChecked)
			{
				mcm_ar_uc_ciriChecked = true;
				MCM_AR_Log("[AR-UC] ForbidActor: " + NameToString(comps[i].scmcc.data.nam) +
				           " forbid=" + forbid);
			}
		}
	}
	return true;
}

// ===== Anti-repeat + preferencje per-NPC (plan 003) =====

// Filtr ostatnich 3 scen per-NPC; zwraca przefiltrowana kopie puli.
@addMethod(CR4Player)
function MCM_AR_UcFilterScenes(nm : name, scenes : array<name>) : array<name>
{
	var filtered : array<name>;
	var excluded : array<name>;
	var i, j     : int;

	for (i = mcm_ar_uc_lastNpc.Size() - 1; i >= 0 && excluded.Size() < 3; i -= 1)
	{
		if (mcm_ar_uc_lastNpc[i] == nm)
		{
			excluded.PushBack(mcm_ar_uc_lastScene[i]);
		}
	}
	for (i = 0; i < scenes.Size(); i += 1)
	{
		for (j = 0; j < excluded.Size(); j += 1)
		{
			if (scenes[i] == excluded[j]) break;
		}
		if (j >= excluded.Size())
		{
			filtered.PushBack(scenes[i]);
		}
	}
	return filtered;
}

@addMethod(CR4Player)
function MCM_AR_UcStampScene(nm : name, scene : name)
{
	mcm_ar_uc_lastNpc.PushBack(nm);
	mcm_ar_uc_lastScene.PushBack(scene);
	// FIFO cap: 12 par starcza na last-3 przy ~4 aktywnych NPC.
	while (mcm_ar_uc_lastNpc.Size() > 12)
	{
		mcm_ar_uc_lastNpc.Erase(0);
		mcm_ar_uc_lastScene.Erase(0);
	}
}

@addMethod(CR4Player)
function MCM_AR_UcClearStamps(nm : name)
{
	var i : int;

	for (i = mcm_ar_uc_lastNpc.Size() - 1; i >= 0; i -= 1)
	{
		if (mcm_ar_uc_lastNpc[i] == nm)
		{
			mcm_ar_uc_lastNpc.Erase(i);
			mcm_ar_uc_lastScene.Erase(i);
		}
	}
}

@addMethod(CR4Player)
function MCM_AR_UcPrefDone(nm : name) : bool
{
	var i : int;
	for (i = 0; i < mcm_ar_uc_prefDone.Size(); i += 1)
	{
		if (mcm_ar_uc_prefDone[i] == nm) return true;
	}
	return false;
}

@addMethod(CR4Player)
function MCM_AR_UcMarkPref(nm : name)
{
	mcm_ar_uc_prefDone.PushBack(nm);
}

// Eager init przy starcie core (wrap wlasnej klasy bazowej = zero kontencji
// z wrapami InitRemasterSettings/OnSpawned innych modow). Init() jest
// guard'owane isInit w bazie i odpala raz na sesje; jak Unicorn nie jest
// jeszcze ready, lazy retry zostaje w dispatchu.
@wrapMethod(MCM_AutonomousRomanceCore)
function Init()
{
	wrappedMethod();
	if (thePlayer)
	{
		thePlayer.MCM_AR_UcEnsureInit();
	}
}

// ===== Listener: wlasnik cyklu zycia faktow (dla wszystkich scen UC) =====

class CMCMEARUnicornListener extends CUnicornListener
{
	event OnSceneStart(thread : CUnicornThread, hasPlayer : bool)
	{
		MCM_AR_UcSetActive();
		MCM_AR_UcMarkThreadActors(thread, 300);
		MCM_AR_Log("[AR-UC] scene start: " + NameToString(thread.GetScene()) +
		           " hook=" + NameToString(thread.GetHook()) + " player=" + hasPlayer);
	}

	event OnStageStart(thread : CUnicornThread, hasPlayer : bool)
	{
		// Odswiezanie expires przy dlugich scenach: globalny I per-actor
		// (mark 300s moze wygasnac w scenie dluzszej niz 5 min).
		MCM_AR_UcSetActive();
		MCM_AR_UcMarkThreadActors(thread, 300);
	}

	event OnSceneEnd(thread : CUnicornThread, hasPlayer : bool)
	{
		// 5s grace per-actor dla posera; globalny fakt skroc do 3s tylko
		// gdy zaden inny watek UC nie zyje (sceny rownolegle).
		MCM_AR_UcMarkThreadActors(thread, 5);
		MCM_AR_UcEndActiveGrace(3, thread);
		MCM_AR_Log("[AR-UC] scene end: " + NameToString(thread.GetScene()));
	}
}

// ===== Eligibility + mapy per-NPC (plan 003) =====

function MCM_AR_UcEligibleRig(npc : CNewNPC) : bool
{
	var n : string;

	if (!npc || !npc.scmcc || !npc.scmcc.data) return false;
	if (!npc.IsWoman()) return false;
	if (!npc.GetMovingAgentComponent()) return false;
	n = npc.GetMovingAgentComponent().GetName();
	// noble_woman_base: Vivienne zweryfikowana live (undress + face keys).
	return (n == "woman_base" || n == "noble_woman_base");
}

// Mapa charakterow -> tagi scen (plan 015: pelna matryca per-NPC).
// Gramatyka UC: 'A' wymagany, '-A' wyklucz, '~A,~B' przynajmniej jeden.
// Wiersz = ~includes (akty/mood) + '-' osobiste veto dopasowane do lore.
// Klucze = scmcc.data.nam (StrLower); aliasy w jednym if. Nieznany nam ->
// DEFAULT z pelnym zestawem veto (pula >=12 nawet przy rough=0).
// ~Anal w wierszach domme (anna/oriana/syanna/salma) jest inert przy
// AllowRough=0 - globalny suffix TagsFinal dokleja -Anal i wygrywa;
// przy rough=1 tag przepuszcza anal-capable scenes (za projekt).
function MCM_AR_UcTagsForNpc(nm : name) : string
{
	var n : string;
	n = StrLower(NameToString(nm));

	if (n == "anarietta" || n == "anna_henrietta" || n == "anna")
		return "~Vaginal,~Anal,~Dominant,~Femdom,~Titfuck,~BoobJob,-Armbinder,-DeviousDevice,-Object,-XCross,-Bound,-Cuffs";
	if (n == "becca" || n == "cerys")
		return "~Vaginal,~Dominant,~Aggressive,~Titfuck,~BoobJob,-Armbinder,-DeviousDevice,-Object,-Yoke,-XCross";
	if (n == "cirilla" || n == "ciri")
		return "~Vaginal,~Kissing,~foreplay,~Loving,~FootJob,~ThighJob,-Rough,-Bound,-Armbinder,-DeviousDevice,-Object,-Yoke,-XCross,-Anal,-Fetish,-Discipline,-Aggressive,-Dominant,-Femdom";
	if (n == "edna" || n == "edna_var_attre")
		return "~Vaginal,~Oral,~Dominant,~Femdom,~Aggressive,~Titfuck,~BoobJob,-Armbinder,-DeviousDevice,-Object,-XCross,-Bound,-Cuffs";
	if (n == "fringilla" || n == "fringilla_vigo")
		return "~Vaginal,~Oral,~Dominant,~Loving,~Titfuck,~BoobJob,-Bound,-Armbinder,-DeviousDevice,-Object,-XCross";
	if (n == "keira" || n == "keira_metz")
		return "~Vaginal,~Oral,~Dominant,~Titfuck,~BoobJob,-Bound,-Armbinder,-DeviousDevice,-Object,-XCross,-Rough";
	if (n == "margarita" || n == "margaritta")
		return "~Vaginal,~Oral,~HandJob,~Kissing,~Loving,~FootJob,~ThighJob,-Rough,-Bound,-Armbinder,-DeviousDevice,-Object,-Yoke,-XCross,-Anal,-Fetish,-Discipline,-Dominant,-Femdom";
	if (n == "mh303_succbus_v2" || n == "salma")
		return "~Vaginal,~Oral,~Anal,~Dominant,~Femdom,~Titfuck,~BoobJob,-Armbinder,-DeviousDevice,-Object,-XCross";
	if (n == "philippa" || n == "filippa" || n == "philippa_eilhart")
		return "~Vaginal,~Dominant,~Femdom,~Aggressive,~Titfuck,~BoobJob,-Armbinder,-DeviousDevice,-Object,-Yoke,-XCross";
	if (n == "priscilla" || n == "pryscilla")
		return "~Vaginal,~Kissing,~foreplay,~Loving,~FootJob,~ThighJob,-Rough,-Bound,-Armbinder,-DeviousDevice,-Object,-Yoke,-XCross,-Anal,-Fetish,-Discipline,-Dominant,-Femdom";
	if (n == "prologue_village_herbalist" || n == "tomira")
		return "~Vaginal,~Oral,~HandJob,~Kissing,~Loving,~FootJob,~ThighJob,-Rough,-Bound,-Armbinder,-DeviousDevice,-Object,-Yoke,-XCross,-Anal,-Fetish,-Discipline,-Dominant,-Femdom";
	if (n == "rosa" || n == "rosa_var_attre")
		return "~Vaginal,~Oral,~HandJob,~Dirty,~Loving,-Rough,-Bound,-Armbinder,-DeviousDevice,-Object,-Yoke,-XCross,-Fetish";
	if (n == "shani")
		return "~Vaginal,~Oral,~HandJob,~Kissing,~Loving,~FootJob,~ThighJob,-Rough,-Bound,-Armbinder,-DeviousDevice,-Object,-Yoke,-XCross,-Anal,-Fetish,-Discipline,-Dominant,-Femdom";
	if (n == "sq701_vivienne" || n == "vivienne")
		return "~Vaginal,~Oral,~Kissing,~Loving,~FootJob,~ThighJob,-Rough,-Bound,-Armbinder,-DeviousDevice,-Object,-Yoke,-XCross,-Anal,-Fetish,-Discipline,-Dominant,-Femdom";
	if (n == "syanna")
		return "~Vaginal,~Anal,~Dominant,~Aggressive,~Titfuck,~BoobJob,-Armbinder,-DeviousDevice,-Object,-XCross,-Bound,-Cuffs";
	if (n == "triss")
		return "~Vaginal,~Oral,~HandJob,~Kissing,~Loving,~FootJob,~ThighJob,-Rough,-Bound,-Armbinder,-DeviousDevice,-Object,-Yoke,-XCross,-Anal,-Fetish,-Discipline,-Dominant,-Femdom";
	if (n == "ves")
		return "~Vaginal,~Oral,~Dominant,~Femdom,~Titfuck,~BoobJob,-Armbinder,-DeviousDevice,-Object,-XCross";
	if (n == "vampire_diva" || n == "orianna" || n == "oriana")
		return "~Vaginal,~Anal,~Dominant,~Femdom,~Aggressive,~Titfuck,~BoobJob,-Armbinder,-DeviousDevice,-Object,-XCross,-Bound,-Cuffs";
	if (n == "yennefer" || n == "yen")
		return "~Vaginal,~Oral,~Dominant,~Femdom,~Aggressive,~Titfuck,~BoobJob,-Bound,-Armbinder,-DeviousDevice,-Object,-XCross";

	// DEFAULT: tamara, iris, corinne, sasha, jutta, yoana, eveline, lussi...
	return "~Vaginal,~Loving,-Rough,-Bound,-Armbinder,-DeviousDevice,-Object,-Yoke,-XCross,-DD,-Anal,-Dominant,-Femdom,-Fetish,-Discipline";
}

// Sukcesywnie doklejane wykluczenia: consent zawsze, rough gdy AllowRough=0.
// 'Sex' = wymagany tag globalny (plan 015): odcina kiss-only sceny
// (skiss1/spankstan); foreplay sceny tag Sex maja, wiec przepuszcza.
function MCM_AR_UcTagsFinal(nm : name) : string
{
	var tags : string;
	tags = "Sex," + MCM_AR_UcTagsForNpc(nm) + ",-Forced,-Humiliation";
	if (!MCM_AR_UcAllowRough())
	{
		tags += ",-Aggressive,-Bound,-Yoke,-XCross,-Rough,-Anal,-Armbinder,-DeviousDevice,-Object,-DD,-DomSub,-Discipline,-Fetish,-Cuffs,-Spanking";
	}
	return tags;
}

// Kontekst meblowy: furn=2 (NaughtyPoint) odcina sceny stojace/klekajace/
// kucajace i kotwiczone przy scianie (-Wall; SweetSpot to nie sciana;
// ~Bed odrzucone - OR-merge wplywaloby na kazdy wiersz). UWAGA: engine
// furniture=2 jest no-op na sciezce
// ScenesFor+StartSceneEx (preferencja mebli dziala tylko w start_scene) -
// ten suffix jest jedynym filtrem postawy. furn=1 (teren) odcina sceny
// meblowe; -Wall,-InvisFurn,-Furniture dodane bo engine odrzuca je w
// StartSceneEx(furn=1), a ScenesFor by ich nie policzyl (pool poison).
function MCM_AR_UcContextSuffix(furn : int) : string
{
	if (furn == 2) return ",-Standing,-Kneeling,-Squatting,-Wall";
	return ",-Bed,-Chair,-Table,-Wall,-InvisFurn,-Furniture,-Yoke,-XCross";
}

// Tag dominujacy do SetPreference (mnoznik przyjemnosci, NIE selekcja scen).
function MCM_AR_UcPrefTagFor(nm : name) : name
{
	var n : string;
	n = StrLower(NameToString(nm));

	if (n == "anarietta" || n == "anna_henrietta" || n == "anna") return 'Dominant';
	if (n == "cerys" || n == "becca") return 'Aggressive';
	if (n == "cirilla" || n == "ciri") return 'Loving';
	if (n == "edna" || n == "edna_var_attre") return 'Dominant';
	if (n == "fringilla" || n == "fringilla_vigo") return 'Loving';
	if (n == "keira" || n == "keira_metz") return 'Dominant';
	if (n == "margarita" || n == "margaritta") return 'Loving';
	if (n == "mh303_succbus_v2" || n == "salma") return 'Dominant';
	if (n == "philippa" || n == "filippa" || n == "philippa_eilhart") return 'Dominant';
	if (n == "priscilla" || n == "pryscilla") return 'Loving';
	if (n == "prologue_village_herbalist" || n == "tomira") return 'Loving';
	if (n == "q603_circus_artist_companion" || n == "eveline_gallo") return 'Loving';
	if (n == "rosa" || n == "rosa_var_attre") return 'Loving';
	if (n == "shani") return 'Loving';
	if (n == "sq701_vivienne" || n == "vivienne") return 'Loving';
	if (n == "syanna") return 'Dominant';
	if (n == "triss") return 'Loving';
	if (n == "ves") return 'Dominant';
	if (n == "vampire_diva" || n == "orianna" || n == "oriana") return 'Dominant';
	if (n == "yennefer" || n == "yen") return 'Dominant';
	return '';
}

// nam -> nude appearance (BODYPACK_MANIFEST v1.0.0). Klucze nam to
// najlepsze zgady na podstawie logow/encji - rozszerzac przy live-test.
// '' = brak pewnego wpisu (UC uzyje strip piece-by-piece).
function MCM_AR_UcNudeAppFor(nm : name) : name
{
	var n : string;
	n = StrLower(NameToString(nm));

	if (n == "anabelle") return 'anabelle_naked';
	if (n == "anarietta" || n == "anna_henrietta" || n == "anna") return 'anna_henrietta_naked';
	if (n == "astrid" || n == "q205_astrid") return '__q205_astrid_naked';
	if (n == "bea" || n == "q310_favor_girl") return '__q310_bea_naked';
	if (n == "birna" || n == "lady_bran") return 'lady_bran_naked';
	if (n == "cerys" || n == "becca") return 'becca_naked';
	if (n == "corinne" || n == "dreamer_corine_tilly") return 'dreamer_naked';
	if (n == "eveline" || n == "eveline_gallo" || n == "q603_circus_artist_companion") return 'eveline_gallo_naked';
	if (n == "fringilla" || n == "fringilla_vigo") return 'fringilla_naked';
	if (n == "ida" || n == "ida_emean_aep_sivney") return '__ida_emean_aep_sivney_naked';
	if (n == "ingrid" || n == "q308_ingrid_vegelbud") return '__q308_ingrid_naked';
	if (n == "irina" || n == "irina_renarde") return 'irina_naked';
	if (n == "iris") return 'iris_naked';
	if (n == "isilira" || n == "q210_avallach_lover") return '__q210_avallach_lover_naked';
	if (n == "jutta" || n == "mq2038_shieldmaiden") return '__mq2038_shieldmaiden_naked';
	if (n == "lady_of_the_lake" || n == "mq7006_lady_of_the_lake") return 'sq701_forest_nymph_naked';
	if (n == "louisa" || n == "luiza_la_valette") return 'luiza_lavalette_naked';
	if (n == "lussi" || n == "q309_raisa") return '__q309_raisa_naked';
	if (n == "marabella") return '__q304_marabella_naked';
	if (n == "margarita") return 'margaritta_naked';
	if (n == "master_blacksmith" || n == "yoana") return '__sq108_blacksmith_naked';
	if (n == "molly") return '__q304_molly_naked';
	if (n == "mq7004_witch" || n == "lynx_witch") return 'lynx_rock_witch_naked';
	if (n == "philippa" || n == "filippa" || n == "philippa_eilhart") return 'filippa_naked';
	if (n == "ravella" || n == "bob_ravella") return 'bob_herbalist_01_naked';
	if (n == "rosa" || n == "rosa_var_attre") return 'rosa_naked';
	if (n == "sasha" || n == "sq306_sacha") return '__sq306_sacha_naked';
	if (n == "tamara") return 'tamara_naked';
	if (n == "tomira" || n == "prologue_village_herbalist") return '__q002_Herbalist_naked';
	if (n == "vernossiel" || n == "sq305_scoiatael_vernossiel") return '__sq305_scoiatael_vernossiel_naked';
	if (n == "ves") return 'ves_naked';
	if (n == "vespula") return 'vespula_naked';
	if (n == "vivienne" || n == "sq701_vivienne") return 'vivienne_de_tabris_naked';
	return '';
}

// Jednorazowo per sesja per-NPC: preferencja przyjemnosci + nude appearance
// (klucz z zywych danych aktora - brak zgadywania template).
function MCM_AR_UcApplySceneMods(u : CUnicorn, npc : CNewNPC, nm : name)
{
	var prefTag : name;
	var nudeApp : name;

	if (thePlayer.MCM_AR_UcPrefDone(nm)) return;

	prefTag = MCM_AR_UcPrefTagFor(nm);
	if (prefTag != '')
	{
		u.SetPreference(npc, NameToString(prefTag), 0.8);
		MCM_AR_Log("[AR-UC] SetPreference(" + NameToString(nm) + ", " +
		           NameToString(prefTag) + ", 0.8)");
	}
	// Mapa nude UC zyje cala sesje w Lua - rejestracja jednorazowa wystarczy.
	nudeApp = MCM_AR_UcNudeAppFor(nm);
	if (nudeApp != '')
	{
		u.SetNudeAppearance(StrLower(npc.GetReadableName()), npc.GetAppearance(), nudeApp);
		MCM_AR_Log("[AR-UC] SetNudeAppearance(" + NameToString(nm) + " -> " +
		           NameToString(nudeApp) + ")");
	}
	thePlayer.MCM_AR_UcMarkPref(nm);
}

// ===== Latent wait na koniec sceny =====

latent function MCM_AR_UcWait(t : CUnicornThread, npc : CNewNPC) : bool
{
	var elapsed : float;
	var sawLive : bool;

	elapsed = 0.0;
	sawLive = false;
	Sleep(0.5);
	while (elapsed < 300.0)
	{
		if (!t || !t.IsLive())
		{
			if (sawLive) break;
			// Fail-start: scena nie wstala po 8s - wychodzimy jak WaitForSceneEnd.
			if (elapsed >= 8.0) break;
		}
		else
		{
			sawLive = true;
		}
		Sleep(0.5);
		elapsed += 0.5;
	}
	if (t && t.IsLive())
	{
		MCM_AR_Log("[AR-UC] wait timeout 300s - t.Stop()");
		t.Stop();
		Sleep(2.0);
		// Stop() moze nie odpalic OnSceneEnd - skroc marker do 5s samemu.
		MCM_AR_UcMarkActor(npc, 5);
	}
	// Watchdog: IsInGameplayScene potrafi wisiec po scenie (tryb-2 z reconu,
	// reload-only). Nie naprawiamy - tylko glosny log diagnostyczny.
	Sleep(1.5);
	if (npc && npc.IsInGameplayScene())
	{
		if (npc.scmcc && npc.scmcc.data)
		{
			MCM_AR_Log("[AR-UC] WATCHDOG: " + NameToString(npc.scmcc.data.nam) +
			           " IsInGameplayScene po koncu sceny UC");
		}
		else
		{
			MCM_AR_Log("[AR-UC] WATCHDOG: npc IsInGameplayScene po koncu sceny UC");
		}
	}
	return sawLive;
}

// ===== Dispatch: wrap PlayIntimateScene z totalnym fallbackiem =====

// latent dziedziczone z oryginalu; wrappedMethod wolno wywolac DOKLADNIE RAZ
// w ciele wrapa (drugi call-site = "could not find wrappedMethod"), wiec
// wszystkie bramki schodza sie w flaga useUc i jest jeden punkt fallbacku.
@wrapMethod(MCM_RomanceInteraction)
function PlayIntimateScene(npc : CNewNPC) : bool
{
	var u        : CUnicorn;
	var t        : CUnicornThread;
	var scm      : mod_scm;
	var worker   : MCM_Worker;
	var point    : mod_scm_NaughtyPoint;
	var actors   : array<CActor>;
	var scenes   : array<name>;
	var nm       : name;
	var tags     : string;
	var mode     : int;
	var furn     : int;
	var poolSize : int;
	var picked   : name;
	var pickedArr: array<name>;
	var ok       : bool;
	var useUc    : bool;
	var valNpc   : EUnicornValidation;

	// Listener musi zyc PRZED jakakolwiek scena UC (tez reczny uc_start):
	// rejestracja przy pierwszym przejsciu dispatchu, niezaleznie od bramek
	// i Mode - inaczej scena nie-mostkowa zostawialaby MCME bez gate'a.
	if (thePlayer)
	{
		thePlayer.MCM_AR_UcEnsureInit();
	}

	mode = MCM_AR_UcMode();
	useUc = mode > 0;
	if (useUc && (!thePlayer || !npc || !npc.scmcc || !npc.scmcc.data))
	{
		useUc = false;
	}

	if (useUc)
	{
		nm = npc.scmcc.data.nam;
		// Ciri: ta sama bramka co natywna - UC tylko przy Adult Mode ON
		// (OFF = ForbidActor w EnsureInit + ta bramka = podwojna blokada).
		if ((nm == 'cirilla' || nm == 'ciri') &&
		    !thePlayer.MCM_AR_GetConfig().IsCiriAdultMode())
		{
			useUc = false;
		}
		// Mode 3 mix-random: polowa prob idzie prosto na natywna sciezke.
		else if (mode == 3 && RandRange(2) == 0)
		{
			useUc = false;
		}
		else if (!MCM_AR_UcEligibleRig(npc))
		{
			MCM_AR_Log("[AR-UC] " + NameToString(nm) + ": rig nie kwalifikuje sie - fallback");
			useUc = false;
		}
	}

	if (useUc)
	{
		u = UnicornGet();
		if (!u || !u.IsReady() || u.GetSceneCount() <= 0)
		{
			MCM_AR_Log("[AR-UC] Unicorn not ready/scenes=0 - fallback");
			useUc = false;
		}
	}

	if (useUc)
	{
		valNpc = u.ValidateActor(npc);
		if (valNpc != UV_Valid)
		{
			MCM_AR_Log("[AR-UC] ValidateActor(" + NameToString(nm) + ")=" +
			           (int)valNpc + " - fallback");
			useUc = false;
		}
		else if (u.ValidateActor(thePlayer) != UV_Valid)
		{
			MCM_AR_Log("[AR-UC] ValidateActor(player) fail - fallback");
			useUc = false;
		}
	}

	if (useUc)
	{
		// Kontekst meblowy PRZED tagami: furn steruje suffixem puli.
		scm = MCM_GetMCM();
		furn = 1;
		point = NULL;
		if (scm && scm.NaughtyManager && scm.NaughtyManager.naughtyPoints &&
		    IsOnNaughtyPoint())
		{
			furn = 2;
			point = scm.NaughtyManager.naughtyPoints.GetClosestPoint(20.0);
		}
		tags = MCM_AR_UcTagsFinal(nm) + MCM_AR_UcContextSuffix(furn);
		actors.PushBack(npc);
		actors.PushBack(thePlayer);
		scenes = u.ScenesFor(actors, tags);
		if (scenes.Size() <= 0)
		{
			MCM_AR_Log("[AR-UC] ScenesFor(\"" + tags + "\") puste dla " +
			           NameToString(nm) + " - fallback");
			useUc = false;
		}
		else
		{
			// Anti-repeat: last-3 per NPC; gdy filtr wyczerpie pule,
			// reset stempli i pelna pula (lepsza powtorka niz fallback).
			poolSize = scenes.Size();
			scenes = thePlayer.MCM_AR_UcFilterScenes(nm, scenes);
			if (scenes.Size() <= 0)
			{
				thePlayer.MCM_AR_UcClearStamps(nm);
				scenes = u.ScenesFor(actors, tags);
				MCM_AR_Log("[AR-UC] anti-repeat wyczerpal pule dla " +
				           NameToString(nm) + " - reset stempli");
			}
			if (scenes.Size() <= 0)
			{
				// Pula nadal pusta po resecie (pack/stan UC) - bez scenes[0].
				MCM_AR_Log("[AR-UC] pool pusta po resecie dla " + NameToString(nm) + " - fallback");
				useUc = false;
			}
			else
			{
				picked = scenes[RandRange(scenes.Size())];
				pickedArr.PushBack(picked);
			}
		}
	}

	// Mode 2 = unicorn-only: bramka nie przeszla -> brak sceny w ogole,
	// NIE tylko brak fallbacku po StartScene-NULL (semantyka etykiety).
	if (!useUc && mode == 2)
	{
		MCM_AR_Log("[AR-UC] mode=2 (unicorn-only): gate fail - return false");
		return false;
	}

	if (useUc)
	{
		// Job posera trzymajacy NPC w pozie = mode-1 freeze z reconu.
		if (thePlayer.mcm_ar_core)
		{
			thePlayer.mcm_ar_core.RemoveIdleJobFor(npc);
		}

		// Parity z natywna sciezka: worker stop + pop idle-state +
		// ghost-collision + bron schowana na czas sceny. Native ustawia
		// tez scmcc.wasInDialogue - pomijamy swiadomie: sciezka resetu
		// flagi niezweryfikowana, a jej zaciecie kosztuje wiecej niz
		// pominiety suppression (nasz busy-fakt i tak blokuje MCME).
		if (scm && scm.JobManager)
		{
			worker = scm.JobManager.getWorker(npc);
			if (worker)
			{
				worker.forceStop();
			}
		}
		if (npc.GetCurrentStateName() == 'SCMPlayIdleAnim')
		{
			npc.PopState(true);
		}
		npc.EnableCharacterCollisions(false);
		npc.scmcc.StopFollowing(true);
		HideActorWeapons(thePlayer);
		HideActorWeapons(npc);

		// Preferencja (once/session) + nude appearance z klucza zywych
		// danych aktora; potem deterministyczny pick przez StartSceneEx.
		MCM_AR_UcApplySceneMods(u, npc, nm);
		t = u.StartSceneEx(actors, pickedArr, 'MCME_AR', NULL, furn);
		if (t)
		{
			// Okno StartSceneEx -> OnSceneStart: fakt ustawiamy i tu.
			MCM_AR_UcSetActive();
			MCM_AR_UcMarkActor(npc, 300);

			t.SetConsent(true);
			t.AddContext('mcme_ar');
			t.SetAuto(true);
			if (point)
			{
				t.Relocate(point.pos, point.rot);
			}
			thePlayer.MCM_AR_UcStampScene(nm, picked);
			MCM_AR_Log("[AR-UC] StartSceneEx: " + NameToString(t.GetScene()) +
			           " dla " + NameToString(nm) + " pick=" + NameToString(picked) +
			           " tags=\"" + tags + "\" furn=" + furn +
			           " pool=" + scenes.Size() + "/" + poolSize);

			ok = MCM_AR_UcWait(t, npc);

			// Follow przywraca EndInteraction caller-side (snapshot
			// npcWasFollowing) - bez unconditional StartFollowing.
			UnhideActorWeapons(thePlayer);
			UnhideActorWeapons(npc);
			if (ok)
			{
				u.ModAffection(npc, thePlayer, 5.0);
			}
			else
			{
				// Fail-start: scena nigdy nie wstala - jesli OnSceneEnd
				// nie odpali dla never-live watku, fakty wisialyby do
				// expiry (600s blokady MCME). Idempotentne z listenerem;
				// respektuje inne zywe watki UC.
				MCM_AR_UcEndActiveGrace(3, t);
				MCM_AR_UcMarkActor(npc, 5);
			}
			MCM_AR_Log("[AR-UC] scene end ok=" + ok + " dla " + NameToString(nm));
			return ok;
		}

		// StartScene NULL: odtworz lokalny stan, potem wspolny fallback.
		// Follow = caller EndInteraction (npcWasFollowing snapshot).
		MCM_AR_Log("[AR-UC] StartSceneEx NULL dla " + NameToString(nm) + " - fallback");
		UnhideActorWeapons(thePlayer);
		UnhideActorWeapons(npc);
		if (mode == 2)
		{
			return false;
		}
	}

	// Jedyny call-site wrappedMethod (latent: assign-then-return).
	ok = wrappedMethod(npc);
	return ok;
}

// ===== Komendy diagnostyczne =====

exec function ar_uc_status()
{
	var u       : CUnicorn;
	var threads : array<CUnicornThread>;
	var msg     : string;

	u = UnicornGet();
	if (!u)
	{
		msg = "[AR-UC] UnicornGet() NULL - brak modUnicornCore";
		thePlayer.DisplayHudMessage(msg);
		MCM_AR_Log(msg);
		return;
	}
	thePlayer.MCM_AR_UcEnsureInit();
	threads = u.GetThreads();
	msg = "[AR-UC] bridge ON | mode=" + MCM_AR_UcMode() +
	      " ready=" + u.IsReady() + " ver=" + u.GetVersion() +
	      " scenes=" + u.GetSceneCount() + " threads=" + threads.Size() +
	      " busyFact=" + FactsQuerySum("mcme_ar_uc_active");
	thePlayer.DisplayHudMessage(msg);
	MCM_AR_Log(msg);
}

exec function ar_uc_mode(optional m : int)
{
	var wrapper : CInGameConfigWrapper;
	var msg     : string;

	wrapper = theGame.GetInGameConfigWrapper();
	if (!wrapper)
	{
		thePlayer.DisplayHudMessage("[AR-UC] brak config wrappera");
		return;
	}
	m = Clamp(m, 0, 3);
	wrapper.SetVarValue('MCM_AR_Unicorn', 'MCM_AR_UcMode', "" + m);
	msg = "[AR-UC] mode=" + m + " (0=off 1=prefer 2=only 3=mix)";
	thePlayer.DisplayHudMessage(msg);
	MCM_AR_Log(msg);
}

exec function ar_uc_eval()
{
	var u      : CUnicorn;
	var comps  : array<CNewNPC>;
	var actors : array<CActor>;
	var scenes : array<name>;
	var scenesIn : array<name>;
	var i      : int;
	var nm     : name;
	var msg    : string;

	u = UnicornGet();
	if (!u || !u.IsReady())
	{
		thePlayer.DisplayHudMessage("[AR-UC] Unicorn not ready");
		return;
	}
	MCM_AR_GetActiveCompanions(comps);
	MCM_AR_Log("[AR-UC] eval: " + comps.Size() + " companion(s)");
	for (i = 0; i < comps.Size(); i += 1)
	{
		if (!comps[i] || !comps[i].scmcc || !comps[i].scmcc.data) continue;
		nm = comps[i].scmcc.data.nam;
		actors.Clear();
		actors.PushBack(comps[i]);
		actors.PushBack(thePlayer);
		scenes = u.ScenesFor(actors, MCM_AR_UcTagsFinal(nm) + MCM_AR_UcContextSuffix(1));
		scenesIn = u.ScenesFor(actors, MCM_AR_UcTagsFinal(nm) + MCM_AR_UcContextSuffix(2));
		msg = "[AR-UC] eval " + NameToString(nm) +
		      ": rig=" + MCM_AR_UcEligibleRig(comps[i]) +
		      " valid=" + (int)u.ValidateActor(comps[i]) +
		      " scenesFor=" + scenes.Size() +
		      " scenesForIn=" + scenesIn.Size() +
		      " pref=" + NameToString(MCM_AR_UcPrefTagFor(nm)) +
		      " nude=" + NameToString(MCM_AR_UcNudeAppFor(nm)) +
		      " ucMarked=" + MCM_AR_UcIsMarked(comps[i]);
		MCM_AR_Log(msg);
		thePlayer.DisplayHudMessage(msg);
	}
}

exec function ar_uc_stop()
{
	var u       : CUnicorn;
	var threads : array<CUnicornThread>;
	var actors  : array<CActor>;
	var npc     : CNewNPC;
	var i, j    : int;

	u = UnicornGet();
	if (!u) return;
	threads = u.GetThreads();
	for (i = 0; i < threads.Size(); i += 1)
	{
		if (threads[i])
		{
			// Stop() moze nie odpalic OnSceneEnd - wyczysc per-actor
			// busy-fakty, inaczej wisialyby do 300s expiry.
			actors = threads[i].GetActors();
			threads[i].Stop();
			for (j = 0; j < actors.Size(); j += 1)
			{
				npc = (CNewNPC)actors[j];
				if (npc) MCM_AR_UcClearActor(npc);
			}
		}
	}
	// Na wypadek never-live/zacietych watkow bez OnSceneEnd - inaczej
	// mcme_ar_uc_active blokuje MCME do uplywu expiry (600 s).
	MCM_AR_UcEndActiveGrace(3, NULL);
	MCM_AR_Log("[AR-UC] ar_uc_stop: stopped " + threads.Size() + " thread(s)");
	thePlayer.DisplayHudMessage("[AR-UC] stopped " + threads.Size() + " UC thread(s)");
}
