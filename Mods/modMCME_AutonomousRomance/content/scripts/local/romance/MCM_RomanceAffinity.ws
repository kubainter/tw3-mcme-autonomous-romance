/*****************************************************************************/
/* MCME Autonomous Romance - Affinity Engine                                 */
/* Stateless obliczanie zażyłości (Facts + Config + RAM)                     */
/* Namespace: mcme_ar_  (w 100% unikalny, brak kolizji z grą i modami)       */
/*****************************************************************************/

// ---------------------------------------------------------------------------
// Wrapper konfiguracji MCM (user.settings)
// ---------------------------------------------------------------------------

class MCM_AR_ConfigWrapper
{
	// Domyślne wartości (używane gdy MCM nie zwróci wartości)
	private var defaultCooldown       : float; default defaultCooldown       = 720.0;  // 12 min
	private var defaultTickInterval   : float; default defaultTickInterval   = 30.0;
	private var defaultAffinityMult   : float; default defaultAffinityMult   = 1.0;
	private var defaultJealousyMode   : bool;  default defaultJealousyMode   = true;
	private var defaultForceRomance   : bool;  default defaultForceRomance   = false;
	private var defaultEnabled        : bool;  default defaultEnabled        = true;
	private var defaultRequireConsent : bool;  default defaultRequireConsent = true;

	// -----------------------------------------------------------------------
	// Odczyt z CInGameConfigWrapper (MCM menu)
	// -----------------------------------------------------------------------
	private function GetFloat(group : name, var_ : name, defaultVal : float) : float
	{
		var wrapper : CInGameConfigWrapper;
		var val     : string;
		wrapper = theGame.GetInGameConfigWrapper();
		if (!wrapper) return defaultVal;
		val = wrapper.GetVarValue(group, var_);
		if (StrLen(val) == 0) return defaultVal;
		return StringToFloat(val);
	}

	private function GetBool(group : name, var_ : name, defaultVal : bool) : bool
	{
		var wrapper : CInGameConfigWrapper;
		var val     : string;
		wrapper = theGame.GetInGameConfigWrapper();
		if (!wrapper) return defaultVal;
		val = wrapper.GetVarValue(group, var_);
		if (StrLen(val) == 0) return defaultVal;
		return (val == "1" || val == "true");
	}

	// -----------------------------------------------------------------------
	// Publiczne API
	// -----------------------------------------------------------------------
	public function IsEnabled() : bool
	{
		return GetBool('MCM_AR', 'MCM_AR_Enabled', defaultEnabled);
	}

	// Cooldown pomiędzy inicjatywami (sekundy)
	public function GetInitiativeCooldown() : float
	{
		return GetFloat('MCM_AR', 'MCM_AR_CooldownSlider', defaultCooldown);
	}

	// Interwał timera decyzyjnego MCM_AR_AutonomousTick (sekundy).
	// Suwak MCM 20-160s (krok 10s); wartość aplikowana przy starcie timera
	// w MCM_AR_InitCore - zmiana w menu wymaga reloadu skryptów/sesji.
	public function GetTickIntervalSeconds() : float
	{
		var val : float;
		val = GetFloat('MCM_AR', 'MCM_AR_TickInterval', defaultTickInterval);
		if (val < 20.0)  return 20.0;
		if (val > 160.0) return 160.0;
		return val;
	}

	// Mnożnik budowania zażyłości (suwak 5..50 odpowiada 0.5x .. 5.0x)
	public function GetAffinityMultiplier() : float
	{
		var val : float;
		val = GetFloat('MCM_AR', 'MCM_AR_AffinityMult', 10.0);
		if (val <= 0.0) return 1.0;
		return val / 10.0;
	}

	// Tryb zazdrości (true = Yen i Triss nie mogą być razem intymne)
	public function IsJealousyModeOn() : bool
	{
		return GetBool('MCM_AR', 'MCM_AR_JealousyMode', defaultJealousyMode);
	}

	// Sandbox: wymuś odblokowanie romansów niezależnie od wyborów fabularnych
	public function IsForceRomanceOn() : bool
	{
		return GetBool('MCM_AR', 'MCM_AR_ForceRomance', defaultForceRomance);
	}

	// Wymóg zgody gracza przez prompt HUD przed sceną (Tier 3/4)
	public function RequiresPlayerConsent() : bool
	{
		return GetBool('MCM_AR', 'MCM_AR_RequireConsent', defaultRequireConsent);
	}

	// Wyświetlanie komunikatów diagnostycznych w HUD
	public function IsDebugHudOn() : bool
	{
		return GetBool('MCM_AR', 'MCM_AR_DebugHud', true);
	}

	// Preset gadatliwosci barkow: 1=Quiet, 2=Default, 3=Chatty (suwak 1-3)
	public function GetBarkPreset() : int
	{
		var val : float;
		val = GetFloat('MCM_AR', 'MCM_AR_BarkPreset', 2.0);
		if (val <= 1.0) return 1;
		if (val >= 3.0) return 3;
		return 2;
	}

	public function EnsureMCMDefaults()
	{
		var wrapper : CInGameConfigWrapper;
		wrapper = theGame.GetInGameConfigWrapper();
		if (!wrapper) return;
		if (StrLen(wrapper.GetVarValue('MCM_AR', 'MCM_AR_BarkPreset')) == 0)
		{
			wrapper.SetVarValue('MCM_AR', 'MCM_AR_BarkPreset', 2);
		}
	}
}

// ---------------------------------------------------------------------------
// Globalny singleton konfiguracji
// ---------------------------------------------------------------------------

// Deklaracja pola na CR4Player
@addField(CR4Player)
public var mcm_ar_config : MCM_AR_ConfigWrapper;

@addMethod(CR4Player)
function MCM_AR_GetConfig() : MCM_AR_ConfigWrapper
{
	if (!mcm_ar_config)
	{
		mcm_ar_config = new MCM_AR_ConfigWrapper in this;
		mcm_ar_config.EnsureMCMDefaults();
	}
	return mcm_ar_config;
}

function MCM_AR_GetConfig() : MCM_AR_ConfigWrapper
{
	return thePlayer.MCM_AR_GetConfig();
}

function MCM_AR_Log(msg : string, optional forceHUD : bool)
{
	var core : MCM_AutonomousRomanceCore;

	LogChannel('MCM_AR', msg);

	// Ring buffer diagnostyki w core (odczyt bezposredni, BEZ rekursywnego wywolywania GetCore!)
	// Gdy core jeszcze nie istnieje - bootlog na polu gracza (dump: ar_bootlog).
	if (thePlayer)
	{
		core = thePlayer.mcm_ar_core;
		if (core)
		{
			core.PushDebugLine(msg);
		}
		else
		{
			thePlayer.mcm_ar_bootlog.PushBack(msg);
			if (thePlayer.mcm_ar_bootlog.Size() > 30)
			{
				thePlayer.mcm_ar_bootlog.Erase(0);
			}
		}
	}

	// DEV (TW3SE): tee calego strumienia do tw3se\out\ar_log.txt + pipe
	// events. MCM_AR_DevLog to leaf bez rekursji; w release stub = noop.
	MCM_AR_DevLog(msg);

	if (forceHUD || (thePlayer && MCM_AR_GetConfig().IsDebugHudOn()))
	{
		if (thePlayer)
		{
			thePlayer.DisplayHudMessage(msg);
		}
	}
}

// Tryb diagnostyczny ticków - przełączany przez exec ar_debug (fakt, znika z sesją)
function MCM_AR_IsDebugOn() : bool
{
	return FactsQuerySum('mcme_ar_debug') > 0;
}

// ---------------------------------------------------------------------------
// Lokalizacja w3strings (teksty widoczne dla gracza na HUD)
// ---------------------------------------------------------------------------

// AR_T(key, fallback): tekst w jezyku gry z en/pl.w3strings; gdy klucza
// brak (brak paczki jezykowej, starsza wersja pliku) -> hardcoded fallback.
// Klucze: ar_line_* / ar_thanks_* (barki), ar_prompt_* (zgoda [C]),
// ar_msg_* (komunikaty HUD). Przestrzen id: 211880xxxx.
function AR_T(key : string, optional fallback : string) : string
{
	var txt : string;
	if (StrLen(key) <= 0) return fallback;
	txt = GetLocStringByKeyExt(key);
	// Brak wpisu: silnik zwraca "" lub sam klucz zaleznie od wersji.
	if (StrLen(txt) <= 0 || txt == key) return fallback;
	return txt;
}

// Podmiana pojedynczego tokena "{N}" (brak StrReplace w WitcherScript NG).
function AR_ReplToken(text : string, token : string, value : string) : string
{
	var idx : int;
	idx = StrFindFirst(text, token);
	if (idx < 0) return text;
	return StrMid(text, 0, idx) + value + StrMid(text, idx + StrLen(token));
}

// AR_Fmt(text, a, b, c): podmienia {1},{2},{3} w zlokalizowanym tekscie
// (np. "[C] Give {1} to {2}" -> "[C] Give Est Est to Yennefer").
function AR_Fmt(text : string, arg1 : string, optional arg2 : string, optional arg3 : string) : string
{
	text = AR_ReplToken(text, "{1}", arg1);
	if (StrLen(arg2) > 0 || StrFindFirst(text, "{2}") >= 0)
		text = AR_ReplToken(text, "{2}", arg2);
	if (StrLen(arg3) > 0 || StrFindFirst(text, "{3}") >= 0)
		text = AR_ReplToken(text, "{3}", arg3);
	return text;
}



// Uwaga: inicjalizacja mcm_ar_config odbywa się w MCM_RomanceCore.ws @wrapMethod(CR4Player) OnSpawned
// Nie duplikujemy wrapa tutaj – jeden wrapper na metodę zapewnia czysty chain adnotacji.


// ---------------------------------------------------------------------------
// Silnik obliczania zażyłości (Affinity Resolver)
// ---------------------------------------------------------------------------

class MCM_RomanceAffinityResolver
{
	// -----------------------------------------------------------------------
	// Główna metoda: zwraca sumę wszystkich filarów * mnożnik konfiguracji
	// -----------------------------------------------------------------------
	public function GetAffinity(npcName : name) : int
	{
		var config : MCM_AR_ConfigWrapper;
		var base   : int;
		var earned : int;
		var total  : float;

		config = MCM_AR_GetConfig();

		// Tryb "always in love" – zwróć maksimum
		if (config.IsForceRomanceOn()) return 200;

		// Filar 1: deterministyczne fakty fabularne
		base = GetBaseStoryAffinity(npcName);

		// Filar 2: trwały postęp sesji (FactsQuerySum)
		earned = GetEarnedAffinity(npcName);

		// Filar 3 (offset): tylko jeśli mnożnik != 1.0 – wpływa na skalę earned
		total = (float)(base) + ((float)(earned) * config.GetAffinityMultiplier());

		return RoundMath(total);
	}

	// -----------------------------------------------------------------------
	// Filar 1 – deterministyczna projekcja z oryginalnych wyborów fabularnych
	// -----------------------------------------------------------------------
	public function GetBaseStoryAffinity(npcName : name) : int
	{
		var score : int;

		switch(npcName)
		{
			// ----- Yennefer -----
			case 'yennefer':
				if (FactsQuerySum('sq202_yen_girlfriend') > 0)  score += 50;
				if (FactsQuerySum('q208_yen_lover') > 0)        score += 30;
				if (FactsQuerySum('q002_talked_to_yennefer') > 0) score += 10;
				if (FactsQuerySum('q201_undress_geralt_sex') > 0) score += 15;
				if (FactsQuerySum('q309_triss_lover') > 0)      score -= 20;
				break;

			// ----- Triss -----
			case 'triss':
				if (FactsQuerySum('q309_triss_stayed') > 0)         score += 50;
				if (FactsQuerySum('q309_triss_lover') > 0)          score += 30;
				if (FactsQuerySum('sq301_complimented') > 0)        score += 10;
				if (FactsQuerySum('sq301_kissed_triss') > 0)        score += 10;
				if (FactsQuerySum('import_geralt_rescued_triss') > 0) score += 10;
				break;

			// ----- Keira -----
			case 'keira_metz':
				if (FactsQuerySum('sq101_keira_had_sex') > 0) score += 50;
				if (FactsQuerySum('q109_keira_to_km') > 0)    score += 20;
				break;

			// ----- Shani -----
			case 'shani':
				if (FactsQuerySum('q602_shani_romance_completed') > 0) score += 50;
				if (FactsQuerySum('q602_had_sex_with_shani') > 0)      score += 20;
				break;

			// ----- Anna Henrietta -----
			case 'anna_henrietta':
				if (FactsQuerySum('q705_henrietta_alive') > 0)   score += 30;
				if (FactsQuerySum('q705_syanna_correct') > 0)    score += 20;
				if (FactsQuerySum('q701_wine_festival') > 0)     score += 15;
				break;

			// ----- Vivienne -----
			case 'sq701_vivienne':
				if (FactsQuerySum('sq701_guillaume_pond_epilogue') > 0) score += 40;
				if (FactsQuerySum('sq701_guillaume_egg_epilogue') > 0)  score += 30;
				break;

			// ----- Cerys -----
			case 'becca':
				if (FactsQuerySum('q206_cerys_queen') > 0)    score += 50;
				if (FactsQuerySum('q206_csi_completed') > 0)  score += 20;
				break;

			// ----- Ciri -----
			case 'cirilla':
				score += 50;
				if (FactsQuerySum('q403_ciri_met') > 0) score += 20;
				break;

			// ----- Syanna -----
			case 'syanna':
				if (FactsQuerySum('q705_syanna_correct') > 0) score += 40;
				if (FactsQuerySum('q704_syanna_sex') > 0 || FactsQuerySum('q704_sex_with_syanna') > 0) score += 30;
				break;

			// ----- Filippa -----
			case 'philippa_eilhart':
			case 'filippa':
				if (FactsQuerySum('sq302_philippa') > 0)      score += 30;
				break;

			// ----- Salma -----
			case 'mh303_succbus_v2':
			case 'salma':
				if (FactsQuerySum('mh303_succubus_spared') > 0) score += 30;
				break;

			// ----- Ves -----
			case 'ves':
				if (FactsQuerySum('sq312_fact_ves_alive') > 0) score += 40;
				break;

			// ----- Priscilla -----
			case 'pryscilla':
			case 'priscilla':
				if (FactsQuerySum('q305_dandelion_rescued') > 0) score += 30;
				break;

			// ----- Edna var Attre -----
			case 'edna_var_attre':
				if (FactsQuerySum('sq302_completed') > 0) score += 20;
				break;

			// ----- Fringilla Vigo -----
			case 'fringilla_vigo':
			case 'fringilla':
				if (FactsQuerySum('q501_lodge_gathered') > 0) score += 30;
				break;

			// ----- Margarita -----
			case 'margarita':
			case 'margaritta':
				if (FactsQuerySum('q310_margarita_rescued') > 0) score += 30;
				break;

			// ----- Orianna -----
			case 'vampire_diva':
			case 'oriana':
			case 'orianna':
				if (FactsQuerySum('q701_wine_festival') > 0) score += 25;
				break;

			case 'rosa_var_attre':
				if (FactsQuerySum('sq302_completed') > 0)     score += 25;
				if (FactsQuerySum('sq302_rosa_defeated') > 0) score += 15;
				break;

			case 'prologue_village_herbalist':
				if (FactsQuerySum('q103_tomira_saved_lena') > 0) score += 20;
				break;
		}

		return score;
	}

	// -----------------------------------------------------------------------
	// Filar 2 – trwały postęp: bezpieczny odczyt przez FactsQuerySum
	// Prefiks "mcme_ar_" gwarantuje unikalność w całym ekosystemie modów
	// -----------------------------------------------------------------------
	public function GetEarnedAffinity(npcName : name) : int
	{
		return FactsQuerySum("mcme_ar_" + NameToString(npcName) + "_affinity");
	}

	// Dodaj punkty zażyłości (wywoływane po wykonaniu akcji)
	public function AddAffinityPoints(npcName : name, amount : int)
	{
		var factName : string;
		var current  : int;

		factName = "mcme_ar_" + NameToString(npcName) + "_affinity";
		current = FactsQuerySum(factName);

		// Zapobiega save-bloat: FactsAdd tworzy permanentnie nowy wpis w bazie faktów
		// dla każdego dodania, co bardzo szybko zwiększa rozmiar save'a.
		// FactsRemove z FactsAdd podmienia stary wpis.
		FactsRemove(factName);
		FactsAdd(factName, current + amount);
		LogChannel('MCM_AR', "[AR] Affinity +" + amount + " for " + npcName + " (total: " + (current + amount) + ")");
	}

	// -----------------------------------------------------------------------
	// Pomocnik: wymagany próg zażyłości dla danego Tier
	// -----------------------------------------------------------------------
	public function MeetsMinAffinity(npcName : name, minAffinity : int) : bool
	{
		return GetAffinity(npcName) >= minAffinity;
	}
}

// ---------------------------------------------------------------------------
// Globalny singleton resolvera (lazy-initialized w Core)
// ---------------------------------------------------------------------------

function MCM_AR_GetAffinity() : MCM_RomanceAffinityResolver
{
	var core : MCM_AutonomousRomanceCore;
	core = MCM_AR_GetCore();
	if (core && core.registry)
	{
		return core.registry.affinity;
	}
	return NULL;
}
