// modMCME_AR_Unicorn — punkt rejestracji przyszłych packów scen MCME
// (plan 005). Manifest = dane: jeden case w builderze na scene.
//
// Dewiacja od literalnego "@wrapMethod(CUnicorn) RegisterPacks" z planu:
// Billyy juz wrapuje RegisterPacks (55 scen), a kompilator Remastered nie
// laczy @wrapMethod na tej samej metodzie miedzy niezmergowanymi modami
// (AGENTS.md §3.1) — drugi wrap shadowuje nasz ALBO Billyy'ego (cała pula).
// U_NewScene wklada definicje wprost do zywej tabeli U.scenes (core.lua:259),
// wiec rejestracja lazy przy inicie mostu daje ten sam efekt — bez wrapa.

// Liczba scen w manifescie — zwiekszac wraz z dodawaniem case'ow.
function MCM_AR_UcPackSceneCount() : int
{
	return 0;
}

// Builder scen — jeden case na scene (switch pojawi sie z pierwsza scena;
// pusty switch = blad kompilacji). Szablon (Billyy order: AddRole(1) kobieta
// pierwsza, AddRole(0) Geralt):
//	var s : CUnicornSceneDef;
//	switch (idx)
//	{
//		case 0:
//			s = u.NewScene('mcme_probe', "Vaginal,~Loving,-Forced,-Humiliation");
//			s.SetName("MCME: probe");
//			s.AddRole(1);
//			s.AddRole(0);
//			s.AddAnimSet("dlc\dlcMCME_AR_Unicorn\data\animations\w3stage\woman.w2anims");
//			s.AddAnimSet("dlc\dlcMCME_AR_Unicorn\data\animations\w3stage\man.w2anims");
//			s.AddStage('s1', 15.0, 'anim_a', 'anim_b');
//			s.SetLoop('s1', 8.0);
//			s.SetPenisAim('s1', 0.0);
//			break;
//		default:
//			break;
//	}
function MCM_AR_UcBuildPackScene(u : CUnicorn, idx : int)
{
}

// Wywolywane z MCM_AR_UcEnsureInit pod flaga packsDone — idempotentne.
function MCM_AR_UcRegisterOurPack(u : CUnicorn)
{
	var i : int;
	var n : int;

	if (!u)
	{
		return;
	}
	n = MCM_AR_UcPackSceneCount();
	for (i = 0; i < n; i += 1)
	{
		MCM_AR_UcBuildPackScene(u, i);
	}
	MCM_AR_Log("[AR-UC] custom packs: " + n + " scene(s) registered (scaffold)");
}
