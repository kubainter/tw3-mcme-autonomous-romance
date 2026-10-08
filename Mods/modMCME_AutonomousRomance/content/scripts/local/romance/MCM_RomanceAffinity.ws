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
				if (FactsQuerySum('prologue_yen_pleased') > 0)  score += 10;
				if (FactsQuerySum('q201_undress_geralt_sex') > 0) score += 15;
				if (FactsQuerySum('q401_yen_geralt_fight') > 0) score -= 20;
				break;

			// ----- Triss -----
			case 'triss':
				if (FactsQuerySum('q309_triss_stayed') > 0)         score += 50;
				if (FactsQuerySum('q309_triss_lover') > 0)          score += 30;
				if (FactsQuerySum('sq301_complimented') > 0)        score += 10;
				if (FactsQuerySum('sq301_necklace_on') > 0)         score += 10;
				if (FactsQuerySum('import_geralt_rescued_triss') > 0) score += 10;
				break;

			// ----- Keira -----
			case 'keira_metz':
				if (FactsQuerySum('sq108_keira_romance') > 0) score += 50;
				if (FactsQuerySum('sq108_keira_to_km') > 0)   score += 20;
				break;

			// ----- Shani -----
			case 'shani':
				if (FactsQuerySum('q603_shani_romance') > 0)  score += 50;
				if (FactsQuerySum('q603_shani_kiss') > 0)     score += 20;
				break;

			// ----- Anna Henrietta -----
			case 'anna_henrietta':
				if (FactsQuerySum('q704_anna_survived') > 0)           score += 30;
				if (FactsQuerySum('q705_syanna_and_anna_survived') > 0) score += 20;
				if (FactsQuerySum('q701_wine_festival_finished') > 0)   score += 15;
				break;

			// ----- Vivienne -----
			case 'sq701_vivienne':
				if (FactsQuerySum('sq701_ritual_success') > 0)         score += 40;
				if (FactsQuerySum('sq701_feather_curse_lifted') > 0)   score += 30;
				break;

			// ----- Cerys -----
			case 'becca':
				if (FactsQuerySum('sq202_cerys_queen') > 0)            score += 50;
				if (FactsQuerySum('q206_berserker_solved') > 0)        score += 20;
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
		FactsAdd("mcme_ar_" + NameToString(npcName) + "_affinity", amount);
		LogChannel('MCM_AR', "[AR] Affinity +" + amount + " dla " + npcName + " (łącznie: " + GetEarnedAffinity(npcName) + ")");
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
