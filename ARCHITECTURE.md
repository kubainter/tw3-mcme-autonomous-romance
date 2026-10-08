# MCME Autonomous Romance — ARCHITEKTURA I FLOW

> Dokument referencyjny moda: jak działa (1:1 z kodu), z jakich API gry/MCME korzysta,
> jakie są twarde ograniczenia platformy i co da się rozszerzyć.
> Cytaty `plik:l.linia` wskazują źródło prawdy — przy zmianach kodu aktualizować.

**Legenda wykonalności (roadmapa):**
- ✅ **Realne** — mechanika/API potwierdzone w kodzie gry lub MCME.
- ⚠️ **Warunkowe** — realne, ale wymaga dodatkowej weryfikacji w runtime lub jest kruche.
- ❌ **Nierealne** — brak mechaniki w grze / brak narzędzi.

---

## 1. Architektura w pigułce

```
┌──────────────────────────────────────────────────────────────────┐
│  GRA (Witcher 3 NG 4.04+)                                        │
│   └─ CR4Player.OnSpawned → InitRemasterSettings()  [wrap]        │
│        └─ MCM_AR_OnPlayerReady()                                 │
│             ├─ MCM_AR_InitCore()                                 │
│             │    ├─ MCM_AutonomousRomanceCore   (statemachine)   │
│             │    │    └─ MCM_RomanceActionRegistry → 35 akcji    │
│             │    ├─ MCM_AmbientRomanceChannel   (statemachine)   │
│             │    ├─ timer MCM_AR_AutonomousTick  co 4s  (STAGED) │
│             │    └─ timer MCM_AR_AmbientTick     co 10s (AMBIENT)│
│             ├─ MCM_AR_ConfigWrapper (user.settings / MCM menu)   │
│             └─ input listener: 'SwordSheathe' → consent [C]      │
└──────────────────────────────────────────────────────────────────┘
│ MCM_RomanceCore.ws        — pętla, gating, kontekst, locki, auto-pick, execy
│ MCM_RomanceAffinity.ws    — config wrapper + resolver zażyłości + MCM_AR_Log
│ MCM_RomanceInteraction.ws — klasa bazowa akcji, staging, consent, sceny, rejestr
│ MCM_RomanceActions_Main.ws— 23 akcje: Yen(7) Triss(7) Keira(5) Shani(4)
│ MCM_RomanceActions_DLC.ws — 12 akcji: Anarietta(4) Vivienne(4) Cerys(4)
│ MCM_RomanceQoL.ws         — enum ubioru w menu MCME + execy (dress/gift)
│ bin/.../modMCME_AutonomousRomance.xml — konfiguracja MCM (7 opcji, 5 presetów)
│
│ Zależność twarda: modMCME_Remastered 5.00+ (companioni, sceny, NaughtyManager,
│ DialogueManager, JobManager, scmcc, specialData).
│ Integracja wyłącznie przez @wrapMethod/@addMethod/@addField — zero merge'ów.
```

### 1.1 Inwentarz plików (100% pokrycia `_ModDev\MCME_AutonomousRomance`)

| Ścieżka | Rola | Stan |
|---|---|---|
| `repo\Mods\modMCME_AutonomousRomance\content\scripts\local\romance\*.ws` ×6 | cały kod moda (Core/Affinity/Interaction/Actions_Main/Actions_DLC/QoL) | ✅ live — wdrożone przez junction 1:1 |
| `repo\Mods\...\romance\*.ws.bak` ×5 | snapshoty sprzed ostatnich edycji | ✅ ignorowane przez kompilator, `.gitignore` i `package_release.ps1` (l.34 filtruje) |
| `repo\Mods\...\content\*.w3strings` ×17 + `en/pl.w3strings.csv` | tablice napisów (CSV = źródło, .w3strings = build); wszystkie locale poza `pl` = kopie `en` | ✅ używane przez `GetLocStringById`/HUD; ⚠️ 15 locale = fallback na EN (brak tłumaczeń); CSV odfiltrowane z zipa |
| `repo\Mods\modMCME_AutonomousRomance\README.md` | README w folderze moda (trafia do zipa) | ✅ zsynchronizowany z `repo\README.md` (07.10) |
| `repo\bin\config\r4game\user_config_matrix\pc\modMCME_AutonomousRomance.xml` | definicja menu MCM | ✅ live (deploy kopiuje do `bin\config\...` gry) |
| `repo\README.md` | dokument publiczny | ✅ aktualny (poprawiony `[C]`, tiery, suwak) |
| `repo\ARCHITECTURE.md` | **ten dokument** | ✅ |
| `repo\TODO.md` | roadmapa zadań + gift design C1/C2 | ✅ aktywna |
| `repo\GEMINI.md` | wytyczne dev (test_compile, reguły WS-NG, init przez InitRemasterSettings) | ✅ obowiązujące |
| `repo\LICENSE`, `repo\.gitignore` | meta | ✅ |
| `repo\scripts\test_compile.ps1` + `repo\scripts\precheck_syntax.ps1` | weryfikacja kompilacji | ✅ zsynchronizowane z kanonicznymi (07.10); uwaga: `repo\scripts\` **nigdy nie było w commitach** (git log — staged list PR nie zawiera `scripts/`), repo-copy to był snapshot sprzed Fazy 0 |
| `scripts\test_compile.ps1` (8607 B) + `scripts\precheck_syntax.ps1` | test kompilacji przez `witcher3.exe -headless` + szybki pre-check składni | ✅ kanoniczne — Faza 0 woła `precheck_syntax.ps1` przed grą (`-SkipPrecheck` pomija) |
| `scripts\deploy_junctions.ps1` | junction repo→`Mods\` + kopia XML do `bin\config` | ✅ (po fixie nazwy XML) |
| `scripts\package_release.ps1` | zip release (`Mods\`+`bin\`) | ✅ działa; ⚠️ nie filtruje `.bak`/`.csv` |
| `scripts\run_game_debug.bat` | odpalenie gry z debug konsolą | ✅ dev |
| `scripts\known_scenes.txt` | lista scen `.w2scene` MCME | ✅ referencja |
| `dumps\scene_and_dialog_ids.md` | baza ścieżek scen, faktów, namespace `mcme_ar_*` | ✅ referencja |
| `nexus\description.bbcode` + `nexus\changelog.md` | opis/changelog Nexus | ✅ aktualne (`[C]` poprawione) |
| `releases\MCME_AutonomousRomance_v1.0.0.zip` (1380 B) | — | ❌ **stub**: same puste katalogi, zero plików |
| `.diffbase\*.ws` ×5 + `E1_interaction.diff.txt` | kopie bazowe do diffów | ✅ narzędzie dev |
| `compile_out.txt` | ostatni log kompilacji (06.10 02:36: precheck 6 plików 0 błędów → **kompilacja 100% OK**) | ✅ artefakt testu |
| **`Mods\modMCME_AutonomousRomance` (w katalogu gry)** | junction → `repo\Mods\modMCME_AutonomousRomance` | ✅ wdrożone 1:1 (identyczne rozmiary plików) |

**Nieistniejące:** `ar_probe_local.ws` / `ar_probe_mcme.ws` — wpisane w IDE jako
otwarte dokumenty, ale **fizycznie nie istnieją** na dysku (0 trafień `ar_probe*`,
zero referencji poza tym dokumentem). Rolę sond z §15.1 przejęły wdrożone w W0:
`MCM_AR_ProbeAnim` (Interaction.ws) + exec `ar_probeanim` (Core) + fallback
w `PlayBark` — osobne pliki-sondy nie są już potrzebne.

---

## 2. FLOW: Boot / init

```
[spawn gracza]
 CR4Player.InitRemasterSettings()          ← wrap (MCM_RomanceCore.ws ~l.84)
   └─ wrappedMethod()  (vanilla init)
   └─ MCM_AR_OnPlayerReady()               (~l.33)
        ├─ MCM_AR_InitCore()               (~l.92)
        │    ├─ new MCM_AutonomousRomanceCore → Init()
        │    │    └─ registry.Init()
        │    │         └─ InitDefaultActions()   ← LAŃCUCH wrapów:
        │    │              wrap Main (Actions_Main.ws l.11) → +23 akcje
        │    │              wrap DLC  (Actions_DLC.ws l.12)  → +12 akcji
        │    ├─ new MCM_AmbientRomanceChannel → Init()
        │    ├─ AddTimer('MCM_AR_AutonomousTick', 4.0, loop)
        │    └─ AddTimer('MCM_AR_AmbientTick',   10.0, loop)
        ├─ new MCM_AR_ConfigWrapper (lazy; Filar 3 konfiguracji)
        ├─ theInput.RegisterListener(this,'OnMCM_AR_ConsentKey','SwordSheathe')
        └─ core.ResetAllCooldowns()
```

**Dlaczego `InitRemasterSettings`, a nie `CPlayerInput.Initialize`:** Next-Gen nie łączy
wielu `@wrapMethod` różnych modów na tej samej metodzie (cienie priorytetów — np. BIA
Priority 19 zjadłby nasz wrap). `InitRemasterSettings` jest wywoływane na końcu bazowego
`OnSpawned` i nic go nie wrapuje → zawsze odpala (GEMINI.md §2.8).

---

## 3. FLOW: Kanał STAGED — co 4 s (Tiery 2–4)

```
MCM_AR_AutonomousTick (Core l.110)
  → core w stanie Idle? → GotoState('ProcessingTick') → ProcessTick() (l.737)
  1. UpdateCombatStatus()                         (stempel końca walki)
  2. GATE MCM_AR_IsSafeToInitiate (l.386) — BLOKUJE gdy:
       player state ≠ 'Exploration' | input ctx ≠ 'Exploration'
       | IsInCombat | IsDialogOrCutscenePlaying
       | MCM DialogueManager.IsBusy | IsSwimming | IsOnBoat
  3. theGame.GetNPCsByTag('GeraltsBFF') → pusto? → Idle
  4. ctx = BuildContext(companions) (l.449):
       godzina/noc(22–4)/świt(6–9) | HP gracza | obszar (Corvo=11)
       | campfire<6m (tag 'campfire') | tawerna (fakt 'player_in_inn')
       | NaughtySpot<30m | romansowe NPC + rivalCount
  5. Naughty-spot notifier: HUD raz przy wejściu w 30m; reset >40m
  6. ShuffleCompanions (fisher-yates — fairness)
  7. GATE anty-chaos: IsStagedBusy() LUB post-staged cooldown 90s → Idle
       (watchdog: lock >300s uznany za martwy → wymuszone zwolnienie)
  8. PĘTLA po companionach:
       wymagany tag 'mod_scm_IsFollowing'
       → re-check staged busy/cooldown w pętli
       → per-NPC cooldown (suwak MCM, dom. 720s)
       → registry.TryExecute(npc, player, ctx) (Interaction l.960)
            ├─ filtr targetNpc + kanał (staged = wszystko poza RTT_OneLiner)
            ├─ CanExecute → GetBlockReason()=="" (l.116):
            │    cooldown akcji → rejected_backoff → minAffinity (pomijane
            │    w ForceRomance) → jealousy (T2+ przy rywalkach)
            │    → dystans ≤15m → GetExtraBlockReason podklasy
            ├─ ważone losowanie (weight) po eligible
            └─ BeginStagedInteraction(npc) → Execute → EndStagedInteraction
                 sukces → MarkExecuted + FactsAdd('mcme_ar_<npc>_affinity',+1)
       → pierwszy sukces = break (max 1 inicjatywa na tick)
  9. debug digest (ar_debug) — deduplikacja na lastDebugDigest
```

## 4. FLOW: Kanał AMBIENT — co 10 s (Tier 1 barki)

```
MCM_AR_AmbientTick (Core l.121) → ProcessAmbient() (l.935)
  1. Ta sama bramka IsSafeToInitiate + lista 'GeraltsBFF' + BuildContext
  2. BOOKKEEPING powitań CO TICK (stemple muszą biec nawet przy cooldown):
       NPC zniknął z tagu >60s i wrócił <10m
       → EnableDynamicLookAt + PlayVoiceset(100,'greeting_geralt')
       → zjada turę barku; cooldown powitania 300s/NPC
  3. Bark cooldown globalny 90s → wolny? pętla NPC:
       nie-busy staged | following | !IsInGameplayScene | !IsSpeaking
       → TryExecute(ambientOnly=true) → tylko RTT_OneLiner → PlayBark → break
```

Dlaczego dwa kanały: latent `Execute` staged (podejście+scena) nigdy nie blokuje
harmonogramu barków — osobne maszyny stanów i timery.

## 5. FLOW: Cykl życia akcji per Tier

```
T1 OneLiner (ambient):
  EnableDynamicLookAt(player,6s) → PlayBark:
    mimika 'flirt'→'happy_anim_face' / 'concern'→'sad_anim_face' (PlayMimic, l.256)
    voiceset? PlayVoiceset(100,barkVoiceset) : PlayLine(lineId)
    + HUD "Imię: \"tekst\"" (GetLocStringById / lineText fallback)
    + DialogueManager.AddChat (subtitles MCME)

T2 Gesture (staged):
  SoftApproach (l.302): StopFollowing(true)=suspensja | PopState SCMPlayIdleAnim
    | ActionCancelAll | look-at 120s | wasInTalkInteraction | kolizje OFF
    | rotate + ActionMoveToNodeAsync (goni ruchomego gracza)
  WaitForApproach (l.331): abort gdy walka / gracz >25m / timeout ~8s
  → bark / PlayAnimSimple → EndSoft (l.400): przywróć follow, kolizje, look-at

T3 Prompt (staged):
  SoftApproach + bark
  → RequiresPlayerConsent? ShowConsentPrompt(tekst, 10s, npc)
                            : WaitForApproach (brak promptu)
  → ODMOWA (timeout / gracz odjdzie >12m / brak [C]):
       EndSoft + MarkRejected → backoff 300s → 900s → 1800s
  → AKCEPT ([C]):
       HardStage (l.356): BlockAction(EIAB_Movement) gracza ~1-2s
         + obrót obojga twarzami + domknięcie dystansu
       → PlayDialogueScene → WaitForSceneEnd(60s) → EndInteraction (l.423):
         unlock gracza | look-at off | kolizje on | wasInDialogue +
         RefreshMimicsNextStateChange | wznowienie follow

T4 Scene (staged): jak T3, ale consent ZAWSZE wymagany (niezależnie od configu)
  gate: IsOnNaughtyPoint() ≤20m && HasIntimateScene(npc)
  → PlayIntimateScene (l.803):
       zarejestrowana (specialData.naughtyScene): scm.NaughtyManager.PreNaughtyWith
       niezarejestrowana (anarietta/vivienne/cerys-fallback): point.AddActionPoint
         + HideAllExcept(npc) + PlayScene(manual path naughty\<npc>\anywhere.w2scene)
       → WaitForSceneEnd(90s) → PostNaughty() (idempotentny cleanup)
       → re-stamp greetSeenTime (NPC schowani HideAllExcept ≠ „powrót po absencji")
```

## 6. FLOW: Consent `[C]` = `SwordSheathe`

- Historia: `[E]`/`Interaction`/`Talk` odpalało równolegle dialog MCME (podwójny efekt).
  `MCM_K_C` był zbindowany w sekcji `[SCMMenuBase]` input.settings → dispatchował TYLKO
  w menu MCME, nigdy w eksploracji → wszystkie prompty timeoutowały. (TODO.md l.29,32)
- Obecnie: listener `OnMCM_AR_ConsentKey` na akcję `'SwordSheathe'` ([C]) — vanilla
  binding w `[Exploration]`+`[Combat]`, zero konfiguracji użytkownika.
- `ShowConsentPrompt` (Interaction l.467): fakty `mcme_ar_awaiting_consent`/
  `mcme_ar_consent_given` + polling `GetActionValue('SwordSheathe')>0.1` ORAZ
  `GetLastActivationTime>0 && <elapsed` (czas OD aktywacji, nie timestamp).
- Skutek uboczny: schowanie miecza przy akceptacji (kosmetyczne, udokumentowane).

**Opcja: dedykowany klawisz consentu (niezmapowana akcja).**
W `input.settings` istnieją akcje vanilla domyślnie **niezbindowane** (`IK_None`
w `[Exploration]`): `SpecialAttackLight`, `SpecialAttackHeavy`,
`AttackWithAlternateHeavy`, `SpecialAttackWithAlternateLight`,
`SpecialAttackWithAlternateHeavy` oraz `SprintToggle` (zbindowany tylko na padzie).
Recepta na własny klawisz:

```
[Exploration] (+[Combat]) w input.settings użytkownika:
IK_<klawisz>=(Action=SpecialAttackLight)
→ listener zamienić z 'SwordSheathe' na 'SpecialAttackLight'
→ w oknie promptu BlockAction(EIAB_SpecialAttackLight|EIAB_SpecialAttackHeavy)
  żeby klawisz nie wywoływał specjalnego ataku
```

⚠️ Ograniczenia tej opcji:
- `input.settings` to plik użytkownika — mod nie może go dostarczyć; wymagana
  ręczna edycja lub skrypt instalacyjny (friction).
- ⚠️ Do zweryfikowania w runtime: czy `RegisterListener`/`GetActionValue`
  otrzymują akcję, gdy jej `EIAB_*` jest zablokowany przez `BlockAction`
  (zablokowanie efektu ≠ wyciszenie eventu — zakładamy dispatch, potwierdzić).
- Efekt uboczny `SwordSheathe` (sheathe/draw) **nie da się stłumić** —
  `EIAB` nie ma `SheathSword` (najbliższy `EIAB_DrawWeapon`).
- Alternatywa bez edycji plików o minimalnym skutku ubocznym:
  `WalkToggle` [LCtrl] — przełącza tryb chodu (pozostaje po prompcie, odwracalne
  drugim naciśnięciem). Akcje kontekstowe interakcji (`SitDown`, `Knock`, …)
  siedzą na `[E]` — nasłuch na nich = powrót problemu [E].

## 7. FLOW: Sceny MCME + auto-pick

```
PlayDialogueScene(npc, path, autoPick)  (Interaction l.671)
  LoadResource(path) → NULL? return false (czyste wyjście PRZED mutacjami)
  worker.forceStop() | PopState SCMPlayIdleAnim | kolizje off
  fakt mod_scm_fact_following | wasInDialogue | RefreshMimicsNextStateChange
  NaughtyManager.PreDialogue(npc)          (fakt allownaughty)
  autoPick → core.arAutoPick=true, arPickPhase=0
  theGame.GetStorySceneSystem().PlayScene(scene,"Input")
  WaitForSceneEnd(npc, 60s)
    ├─ wrapy: CR4HudModuleDialog.OnDialogChoicesSet + SendDialogChoicesToUI
    │    → core.MCM_AR_OnDialogChoices (Core l.203):
    │       faza 0: wybór STRUKTURALNY — idx=1 gdy ≥3 opcje i ostatnia ma
    │               DialogAction_EXIT (locale-free); fallback: keywords
    │               (kiss/poca/caluj/love/kocham/'aime/ amo/quiero…)
    │       faza 1: po kiss wybierz EXIT (scena wraca do hub-menu)
    │    → pending idx → WaitForSceneEnd: +0.35s OnDialogOptionSelected,
    │      +0.3s OnDialogOptionAccepted (wzorcem tw3-automatic-dialog-picker)
    └─ release locka gracza gdy scena kończy się dla gracza (IsInGameplayScene
       może zostać dłużej u NPC — to nie powód trzymania locka)
```

Bezpieczniki auto-pick: disarm w `EndStagedInteraction`/`ResetAllCooldowns`/watchdog.

**Mapa NaughtyPointów** (SpawnCompanionsSpecial.ws l.744–764, 16 punktów):
Triss House, Rosemary & Thyme (3), Kingfisher (2), Var Attre Villa, Passiflora,
Crow's Perch (2), Shani Clinic Oxenfurt, Kaer Trolde pokój Yen, Kaer Morhen (2),
Corvo Bianco (sypialnia + gościnny), Pałac Beauclair, Posiadłość Orianny.
Zaproszenie pada w zasięgu 30 m (ctx.isNearNaughtySpot), scena wymaga ≤20 m.

## 8. Macierz anty-chaos

| Mechanizm | Wartość | Źródło |
|---|---|---|
| Tick staged | 4 s | `AddTimer` InitCore (Core l.105) |
| Tick ambient | 10 s | Core l.106 |
| Lock staged (1 naraz) | `interactionBusy` | Core l.150, Begin/End l.587/627 |
| Watchdog locka | >300 s → wymuszone zwolnienie | Core l.600 |
| Cooldown post-staged | 90 s | `lastStagedTime` Core l.651 |
| Cooldown per-NPC | suwak MCM 60–1200 s (dom. 720) | `GetInitiativeCooldown` |
| Cooldown per-akcja | `cooldownSeconds` (300–3600 s) | pole akcji |
| Backoff po odmowie | 300 → 900 → 1800 s | `MarkRejected` Interaction l.83 |
| Bark globalny | 90 s | `GetBarkCooldownRemaining` Core l.908 |
| Powitanie po absencji | gap>60 s, dist<10 m, cd 300 s/NPC | ProcessAmbient l.990-1037 |
| Prompt consent | 10 s okno; odjście >12 m = odmowa | ShowConsentPrompt l.467 |
| Podejście | timeout 8 s; abort >25 m / walka | WaitForApproach l.331 |
| WaitForSceneEnd | 60 s (dialog) / 90 s (intymna) | Interaction l.574, l.887 |
| Notifier naughty | 30 m in / 40 m out (histereza) | ProcessTick l.780-795 |
| Limit na tick | 1 staged, 1 bark, 1 powitanie | pętle |

## 9. Rejestr akcji (35)

Wspólne gatingi (bazowa `GetBlockReason`): cooldown akcji → backoff odmowy →
`minAffinity` (pomijane w ForceRomance) → jealousy dla T2+ przy `hasRivals` →
dystans ≤15 m → `GetExtraBlockReason` podklasy.

| NPC (nam) | Akcja | Tier | minAff | cd s | waga | Extra-gate / scena |
|---|---|---|---|---|---|---|
| yennefer | yen_oneliner_flirt | T1 | 0 | 300 | 10 | !noc && !campfire |
| | yen_postcombat_care | T2 | 20 | 600 | 8 | HP≤55%, walka<300 s |
| | yen_campfire_evening | T2 | 30 | 900 | 7 | campfire; sit `woman_sit_stump_idle` |
| | yen_night_invitation | T3 | 50 | 1800 | 5 | noc → `yenneferFollowWithKiss` |
| | yen_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m + scena |
| | yen_jealousy_snark | T1 | 0 | 480 | 9 | jealousy ON && Triss w drużynie (look-at rywalki) |
| | yen_tavern_wine | T1 | 0 | 600 | 6 | tawerna |
| triss | triss_oneliner_flirt | T1 | 0 | 300 | 10 | !noc |
| | triss_postcombat_hug | T2 | 30 | 600 | 8 | HP≤60%, walka<300 s; `woman_hug_idle` |
| | triss_campfire_warmth | T2 | 20 | 900 | 7 | campfire; sit |
| | triss_night_whisper | T3 | 50 | 1800 | 5 | noc → `trissFollowWithKiss` |
| | triss_garden_kiss | T3 | 70 | 2400 | 4 | (bez extra) → `trissFollowWithKiss` |
| | triss_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m + scena |
| | triss_jealousy_snark | T1 | 0 | 480 | 9 | jealousy ON && Yen w drużynie |
| keira_metz | keira_oneliner_flirt | T1 | 0 | 320 | 10 | !noc |
| | keira_postcombat_heal | T2 | 10 | 600 | 9 | HP≤50%, walka<300 s; `cast_sign_quen_idle` |
| | keira_campfire_witch | T1 | 0 | 600 | 7 | campfire (sam bark) |
| | keira_night_proposal | T3 | 50 | 1800 | 5 | noc → `keiraFollowWithKiss` |
| | keira_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m + scena |
| shani | shani_oneliner_flirt | T1 | 0 | 300 | 10 | !noc |
| | shani_postcombat_medic | T2 | 10 | 600 | 9 | HP≤55%, walka<300 s; `woman_tend_wounds_idle` |
| | shani_night_relax | T3 | 50 | 1800 | 5 | noc → `shaniFollowWithKiss` |
| | shani_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m + scena |
| anna_henrietta | anarietta_oneliner_flirt | T1 | 0 | 350 | 10 | !noc |
| | anarietta_postcombat_pride | T2 | 30 | 600 | 8 | HP≤60%, walka<300 s |
| | anarietta_night_royal | T3 | 60 | 2400 | 4 | noc → `anariettaFollowWithKiss` |
| | anarietta_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m; scena manualna `naughty\anarietta` |
| sq701_vivienne | vivienne_oneliner_flirt | T1 | 0 | 360 | 10 | !noc |
| | vivienne_campfire_mystery | T2 | 20 | 900 | 7 | campfire |
| | vivienne_night_invitation | T3 | 60 | 2400 | 4 | noc → `vivienneFollowWithKiss` |
| | vivienne_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m; manualna `naughty\vivienne` |
| becca (Cerys) | cerys_oneliner_flirt | T1 | 0 | 300 | 10 | !noc |
| | cerys_postcombat_skellige | T2 | 20 | 600 | 8 | HP≤60%, walka<300 s |
| | cerys_night_invitation | T3 | 60 | 2400 | 4 | noc → `cerysFollowWithKiss` |
| | cerys_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m; `PreNaughtyWith` (registered) |

Akcje typu T3 z `RequiresPlayerConsent=false`: zamiast promptu — `WaitForApproach`
(propozycja sama się „realizuje" gdy gracz stoi w miejscu).

## 10. Silnik zażyłości (3 filary)

`MCM_RomanceAffinityResolver.GetAffinity` (Affinity l.163) =
`base` (fakty fabularne, tabela w GetBaseStoryAffinity l.190) +
`earned` (FactsQuerySum `mcme_ar_<npc>_affinity`; +1 za wykonaną akcję, +3 gift)
× `GetAffinityMultiplier` (suwak /10). `ForceRomance` → zawsze 200.

| NPC | Fakty fabularne (suma pkt) |
|---|---|
| yennefer | sq202_yen_girlfriend +50, q208_yen_lover +30, prologue_yen_pleased +10, q201_undress_geralt_sex +15, q401_yen_geralt_fight −20 |
| triss | q309_triss_stayed +50, q309_triss_lover +30, sq301_complimented +10, sq301_necklace_on +10, import_geralt_rescued_triss +10 |
| keira_metz | sq108_keira_romance +50, sq108_keira_to_km +20 |
| shani | q603_shani_romance +50, q603_shani_kiss +20 |
| anna_henrietta | q704_anna_survived +30, q705_syanna_and_anna_survived +20, q701_wine_festival_finished +15 |
| sq701_vivienne | sq701_ritual_success +40, sq701_feather_curse_lifted +30 |
| becca | sq202_cerys_queen +50, q206_berserker_solved +20 |

Bezpieczeństwo save'ów: tylko fakty `mcme_ar_*` + RAM — usunięcie moda = czysty save.

## 11. Mapa API — co mod wywołuje

**MCME Remastered** (`Mods\modMCME_Remastered\content\scripts\`):

| API | Definicja | Użycie w AR |
|---|---|---|
| `class mod_scm` (statemachine) | game\SpawnCompanions.ws l.166 | `mcm.DialogueManager`, `scm.NaughtyManager` |
| `MCM_GetMCM()` | game\mcm\MultiCompanionModEntity.ws l.77 | bezpieczeństwo, AddChat |
| `mod_scm_GetSCM()` | MultiCompanionModEntity.ws l.82 | NaughtyManager |
| `mod_scm_GetSCMEntity()` | l.56 | `mod_scm_delayedDialogue(path,0.05)` (l.43) — scena przez delayedDialogue |
| `mod_scm_GetNPC(nam,ST_Special,…)` | game\mcm\MultiCompanionMod.ws l.35 | check ST_Special przed PreNaughtyWith |
| `enum ST_Special` | game\mcm\MultiCompanionModGlobal.ws l.8 | typ selekcji NPC |
| `MCM_GetAreaName() : EAreaName` | MultiCompanionModGlobal.ws l.12 | Corvo=11 |
| `MCM_DialogueManager.IsBusy/AddChat` | game\mcm\MultiCompanionModDialogueManager.ws l.29/34 | gate + napisy barków |
| `NaughtyManager.PreNaughtyWith/PreDialogue/HideAllExcept/PostNaughty` | game\mcm\MultiCompanionModNaughtyManager.ws l.30/111/48/80 | pipeline intymny |
| `naughtyPoints.GetClosestPoint(r)` | SpawnCompanionsSpecial.ws l.767 | gating 30/20 m |
| `scmcc.PlayAnimSimple(anim,…)` | game\SpawnCompanionsSCMCC.ws l.403 | animy gestów |
| `scmcc.applyNaked/Underwear/NormalAppearance` | SCMCC l.2103–2116 | QoL ubiór |
| `scmcc.StartFollowing/StopFollowing(true)` / `IsFollowing` | SCMCC | suspensja follow (parametr `true` = dontModifyPlayersList!) |
| `scmcc.EnterFriendlyCombat(bool)` / `endFriendlyCombat` | SCMCC l.2015/2055 | sparring (nieużywane jeszcze) |
| `JobManager.getWorker/assignWorker/cancelWorker` | game\mcm\job\MultiCompanionModJobManager.ws l.251/309/292 | worker.forceStop przed sceną |
| `specialData` (MCM_NPCEntry) | — | naked/underwear/defaultAppearance, naughtyScene |
| tagi `GeraltsBFF`, `mod_scm_IsFollowing` | — | selekcja i follow-check |

**Vanilla** (`content\content0\scripts\`):

| API | Źródło | Użycie |
|---|---|---|
| `PlayVoiceset(100,'greeting_geralt')` / `'sleeping'` / `'coughing'` | game\npc\npc.ws l.4287/4290, toxicCloudEntity.ws l.277 | barki voicesetowe |
| `PlayLine(id,true)`, `GetLocStringById(id)` | CActor/engine | linie + napisy PL/EN |
| `EnableDynamicLookAt(target,sec)`, `DisableLookAt` | CActor | staging |
| `ActionMoveToNode(Async)`, `ActionRotateToAsync`, `ActionCancelAll` | CActor | podejścia |
| `theGame.GetStorySceneSystem().PlayScene(scene,"Input")` | CStorySceneSystem | sceny .w2scene |
| `theGame.IsDialogOrCutscenePlaying()` | CGame | gating + wait sceny |
| `theGame.GetNPCsByTag('GeraltsBFF',out)` | CGame | lista companionów |
| `theGame.GetEntitiesByTag('campfire',out)` | CGame | wykrywanie ogniska <6 m |
| `FactsQuerySum/FactsAdd/FactsSet/FactsRemove` | engine | affinity, consent, debug, `player_in_inn` |
| `theInput.RegisterListener/GetActionValue/GetLastActivationTime('SwordSheathe')` | CInput | consent [C] |
| `player.BlockAction/UnblockAction(EIAB_Movement,'MCM_AR_interaction')` | CR4Player | lock HardStage |
| `thePlayer.IsInCombat/IsSwimming/IsOnBoat/IsInInterior/GetUsedVehicle` | CR4Player | gating kontekstu |
| `CR4HudModuleDialog.OnDialogOptionSelected/Accepted` + `SSceneChoice` | HUD dialog | auto-pick |
| `DisplayHudMessage` | CR4Player | HUD |
| `GetWeatherConditionName() : name` | engine\environment.ws l.53 | (nieużywane — kandydat na barki) |
| `W3PlayerWitcher.Meditate()/CanMeditate()`, stany `Meditation`/`MeditationWaiting` | game\player\playerWitcher.ws l.10084+ | (nieużywane — kandydat) |
| `W3WitcherBed` tag `witcherBed`, `GetWasUsed()`, `PEA_GoToSleep` | game\gameplay\interactive\witcherBed.ws l.6 | (nieużywane — kandydat) |
| `thePlayer.OnGwintGameRequested(deck,faction,cards)` → `RequestMenu('DeckBuilder'/'GwintGame')` | game\player\r4Player.ws l.4133 | (nieużywane — kandydat) |

## 12. Kontekst (`MCM_RomanceContext`, BuildContext)

| Pole | Źródło | Użyte przez akcje |
|---|---|---|
| `hourOfDay`, `isNight` (22–4), `isDawn` (6–9) | `theGame.GetGameTime()` | night_* , !noc one-linery |
| `playerHealthRatio` | `GetStat(BCS_Vitality)/GetStatMax` | postcombat_* (progi 50–60%) |
| `areaName` (EAreaName), `isInCorvo` (==11) | `MCM_GetAreaName()` | (rezerwa — sceny Corvo) |
| `isNearCampfire` | tag `campfire` <6 m | campfire_* |
| `isInTavern` | fakt `player_in_inn` | yen_tavern_wine |
| `isNearNaughtySpot` | NaughtyPoint ≤30 m | notifier + rezerwa |
| `rivalCount`, `hasRivals`, `companionsInParty` | pętla po `IsRomanceNPC` | jealousy, snarki |

Poza kontekstem: `GetSecondsSinceCombat()` (core) dla progów post-combat.

## 13. Konfiguracja MCM (`modMCME_AutonomousRomance.xml`)

Grupa `MCM_AR` → `displayName="Mods.AutonomousRomance"`:

| Var | Typ | Domyślna | Znaczenie |
|---|---|---|---|
| MCM_AR_Enabled | TOGGLE | 1 | master switch (TryExecute) |
| MCM_AR_CooldownSlider | SLIDER 60–1200 | 720 | cooldown inicjatywy per NPC |
| MCM_AR_AffinityMult | SLIDER 5–50 | 10 | mnożnik earned /10 (0.5–5.0×) |
| MCM_AR_JealousyMode | TOGGLE | 1 | rivalry vs polyamory |
| MCM_AR_ForceRomance | TOGGLE | 0 | sandbox: affinity=200, bez progów |
| MCM_AR_RequireConsent | TOGGLE | 1 | prompt [C] dla T3 (T4 zawsze) |
| MCM_AR_DebugHud | TOGGLE | 1 | komunikaty [AR] na HUD |

Presety: 0 default, 1 active (300 s), 2 relaxed (1200 s, debug off), 3 sandbox
(60 s, ×5, jealousy off, consent off), 4 disabled.

## 14. Diagnostyka

Log: `LogChannel('MCM_AR',…)` → `Documents\The Witcher 3\scriptslog.txt` — wymaga
startu z `-net -debugscripts` (`scripts\run_game_debug.bat`); bez flag = no-op.
`DebugScriptsForceFlush=true` w user.settings.

| Exec | Funkcja |
|---|---|
| `ar_status` | stan: enabled/sandbox/jealousy, godzina, safe-reason, per-NPC affinity/follow |
| `ar_eval` | dry-run: eligible + blocked:powód dla KAŻDEJ akcji każdego NPC |
| `ar_debug` | toggle digestu ticku na HUD (fakt `mcme_ar_debug`) |
| `ar_logdump(N)` | ostatnie N linii ring-bufora (60) na HUD |
| `ar_trigger` | reset cooldownów + wymuszony ProcessingTick |
| `ar_force` | toggle ForceRomance przez wrapper configu |
| `ar_affinity(npc,n)` | +n earned affinity |
| `ar_reset` | ResetAllCooldowns |
| `ar_test` | init on demand (diagnoza spawnu) |
| `ar_line(npc,id)` | audycja lineId na żywej towarzyszce |
| `ar_dress / ar_undress / ar_naked (npc?)` | ubiór (QoL) |
| `ar_gift(npc?)` | prezent: pierwszy alkohol z EQ → +3 affinity + greeting |

Toolchain: `scripts\precheck_syntax.ps1` (<1 s, struktura .ws + ścieżki scen względem
`known_scenes.txt`) → `scripts\test_compile.ps1` (pełny boot gry, ExitCode 0/1,
~15–20 s) — **żelazna zasada przed oddaniem kodu** (GEMINI.md §1).

## 15. Twarde ograniczenia platformy (czego gra NIE oferuje)

- **Geralt nie siada na meblach/ogniskach.** Enum `EPlayerExplorationAction`
  (playerTypes.ws l.21–39): Meditation, Examine/Smell/Inspect, Igni/Aard, SetBomb,
  PourPotion, DispelIllusion, GoToSleep — **brak PEA_Sit**. W `input.settings`
  `[Exploration]` istnieją wprawdzie akcje `SitDown`/`SitAndWait`/`KneelDown`
  (na `[E]`), ale to **kontekstowe werby interakcji** — dispatchuje je encja
  z komponentem interakcji (engine/data, zero odwołań w `content0\scripts`),
  nie da się ich wyzwolić skryptowo w dowolnym miejscu. Jedyne skryptowalne
  pozycje siedzące gracza: medytacja (`PEA_Meditation`; przy ognisku
  `MeditateWithIgnite` zapala ogień) i łóżko (`PEA_GoToSleep`).
  ⇒ **Companion MOŻE siadać** (slot animami `*_sit_*`/`high_sitting_*` —
  już wykorzystane w `yen_campfire_evening`/`triss_campfire_warmth`,
  `woman_sit_stump_idle`), ale nigdy Geralt poza medytacją/łóżkiem.
- **`.w2scene` to binarki** — nie da się dodawać opcji do istniejących scen;
  brak introspekcji wyborów (SSceneChoice bez id; TODO l.44). Reużywamy sceny MCME
  tak jak są (auto-pick po strukturze).
- **Brak `StringToName`** — porównania nazw po stringach.
- **Kolizje companionów wyłączone celowo przez MCME** („duchy", update4Second
  re-wyłącza w NewIdle) — nasze `EnableCharacterCollisions(true)` trwa max ~4 s.
  Powrót kolizji = wrapowanie mechaniki MCME (ryzykowne) — decyzja w TODO.
- **`@wrapMethod` na `event` = bez jawnego typu zwracanego; latent nie w `if`.**
- **Cień priorytetów wrapów** między modami — init tylko przez `InitRemasterSettings`.
- **Voicesety potwierdzone:** `greeting_geralt`, `sleeping`, `coughing`,
  `HastaLaVista` (gracz), `warning`, `About_trophy`, `Misc*`,
  `Weather*` (Raining/Stormy/Windy/Snowy/Hot/Cold/LooksLikeRain/ClearingUp/
  SeaWillStorm), `FasterHorse/SlowerHorse(/Roach)`, `DetectPlaceOfPower`,
  `OnUsingEye`, `monster`, `Input`. Uwaga: dostępność voicesetu **per NPC**
  zależy od jego danych audio — przy braku `PlayVoiceset` pada po cichu
  (weryfikacja w runtime, patrz wzorzec logu w `PlayMimic`).
- **lineId musi być kuratowane** z istniejących kwestii (baza: `dumps\
  scene_and_dialog_ids.md` + audycje `ar_line`).
- **Menu MCM:** max 2–3 poziomy `displayName`; nasze w `[SCMMenuBase]` input.settings
  nie dispatchuje w eksploracji (lekcja consent).

### 15.1 Cicha degradacja assetów (voiceset / anim / lineId) — mechanika i mitigacje

„Pada po cichu" znaczy dosłownie: **brak wyjątku, brak wpisu do logu, NPC po prostu
nic nie robi**. Źródła i to, co można z tym zrobić:

| Wywołanie | Zwrot | Tryb padnięcia | Wykrywalne? |
|---|---|---|---|
| `npc.PlayVoiceset(p,'name')` | `bool` | brak voicesetu w danych audio tego NPC → `false` | ✅ TAK — sprawdzić zwrot |
| `animComp.PlaySlotAnimationAsync(anim,slot,settings)` (w `scmcc.PlayAnimSimple`) | `bool` | anim nie istnieje w animsecie NPC → `false`, SCMCC ignoruje zwrot | ✅ TAK — możliwa sonda |
| `npc.PlayMimicAnimationAsync(...)` | `bool` | jak wyżej | ✅ TAK |
| `npc.PlayLine(stringId,...)` | `void` | złe/nieistniejące id → cisza | ❌ NIE — tylko audycja `ar_line` + ucho |
| `theGame.GetStorySceneSystem().PlayScene` | — | zła ścieżka → `LoadResource` zwraca `NULL` (kod już sprawdza) | ✅ już obsłużone |

Dlaczego to dotyka roostera: każdy companion ma **własny zestaw audio i animset**.
NPC niehumanoidalne lub o specjalnym szkielecie (Salma = `mh303_succbus_v2`,
sukkubus) niemal na pewno **nie mają** `woman_sit_stump_idle`, `woman_hug_idle`
ani prawdopodobnie `greeting_geralt` — akcje T2 z gestem skończą się „podeszła,
stanęła, odeszła". Humanoidalne DLC-owe NPC (Syanna, Ves, Edna, Fringilla,
Margarita, Orianna, Priscilla) dziedziczą standardowe animsety kobiece —
wysoka szansa, ale do **potwierdzenia per NPC**.

Mitigacje (stan wdrożenia: pkt 1–2 zrobione w W0, kompilacja 0 błędów 07.10):

1. ✅ **`PlayBark` z fallbackiem** — WDROŻONE: `PlayBark` (Interaction ~l.180)
   trzyma zwrot `PlayVoiceset`: `false` → `PlayOneLiner(npc, lineId, lineText)`
   (`PlayLine` + HUD przez `GetLocStringById`, dotychczasowa ścieżka) + log
   `[AR] voiceset missing '<n>' on <npc> - fallback lineId`.
2. ✅ **Sonda animacji** — WDROŻONA: globalna `MCM_AR_ProbeAnim(npc, anim) : bool`
   (Interaction, sekcja helperów na końcu) woła `PlaySlotAnimationAsync`
   bezpośrednio na `CMovingPhysicalAgentComponent` (`NPC_ANIM_SLOT`, przy
   porażce retry `GAMEPLAY_SLOT` — jak `scmcc.PlayAnimSimple`); exec
   `ar_probeanim <npc> <anim>` (Core, obok `ar_line`) wypisuje zwrot przez
   `MCM_AR_Log`. Uwaga interpretacyjna: `false` może też znaczyć „slot
   zajęty" → sondować w stanie idle, ewentualnie dwa podejścia.
3. **Whitelist per NPC** — do wdrożenia po audycjach `ar_probeanim`: flaga/gałąź
   w akcji (NPC bez gestu → wariant bark-only); ewentualnie cache w faktach
   (`mcme_ar_animok_<npc>`) zamiast sondować co tick.
4. **`ar_line` jako pipeline kuratorski** — każdy nowy lineId przechodzi
   audycję na żywym NPC przed wpisem do akcji (PlayLine nie zwraca błędu).

## 16. Roadmapa

### A. Z TODO.md (stan bieżący)

1. **Stabilizacja bazy** — diagnoza „mod nie reaguje" przez `ar_status`/`ar_eval`/
   `ar_trigger`/`ar_debug`; retest `triss_intimate` po fixie klawisza [C].
2. ✅ Done: consent [C]=`SwordSheathe`; auto-pick strukturalny; fixy consent/gating.
3. **Do decyzji:** nocny wypełniacz T1 (dużo `blocked:` nocą = zamierzone filtrowanie);
   kolizje-duchy (design MCME — wrapować czy zostawić).
4. **Ubiór:** Wariant A ✅ (enum `Ubiór:` w `SCMMenuEditCompanion2` + execy).
   Wariant B ⚠️ — auto-zmiana przy scenach: `applyNakedAppearance`/`Underwear`
   działają, ale pipeline naughty MCME sam zarządza wyglądem w scenie
   (PostNaughty re-equip) — implementacja tylko dla ścieżki manualnej + restore
   w `EndInteraction`; ryzyko nakładki z `data.appearance` z QoL.

### B. Prezenty (design zatwierdzony — TODO §49–81)

- **C1 (do implementacji):** `MCM_AR_<npc>_GiftRequest extends MCM_RomanceInteraction`
  — RTT_Prompt, minAffinity ~20, cd ~30 min. Gate: `!PlayerCarriesGift()`→`no_gift`.
  Execute: SoftApproach → bark prośby → `ShowConsentPrompt("[C] Podaruj <item>",10s)`
  → accept: `RemoveItemByName`+`AddAffinity`+bark podziękowania; reject: EndSoft+
  MarkRejected. Lista itemów zostaje z `ar_gift`; preferencje per NPC
  (np. Cerys→Dwarven spirit, Yen→est_est). Potrzebne: lineId/voiceset prośby i
  podziękowania per NPC. Zakres wg TODO = 11 NPC = Etap 0+1 roostera (§16.C).
- **C2 (backlog):** gracz-inicjowane wręczenie — hint „[C] Podaruj prezent" przy
  zbliżeniu z itemem; watcher w ticku + debounce.
- **Custom VO (odległy backlog):** AI-TTS na krótkie odpowiedzi — koszt pipeline
  .wem→sound.bundle + szara strefa praw głosu. Na teraz: kuratowane lineId.

### C. Roster — pełna mapa companionów romance-capable (cel: pokryć WSZYSTKICH)

Krzyżówka: MCME roster (`MultiCompanionModEntityListData.ws`) × sceny
(`known_scenes.txt`: `dialogue\*FollowWithKiss|Hug` + `naughty\<npc>\anywhere`)
× rejestracja `setNaughtyScene` (`MultiCompanionModNPCManager.ws` /
`SpawnCompanionsSpecial.ws`).

| NPC (display) | `nam` w MCME | Scena kiss | Scena naughty | `setNaughtyScene` | Stan AR |
|---|---|---|---|---|---|
| Yennefer | `yennefer` | `yenneferFollowWithKiss` | `naughty\yennefer` | ✅ tak | ✅ **7 akcji** |
| Triss | `triss` | `trissFollowWithKiss` | `naughty\triss` | ✅ | ✅ **7** |
| Keira | `keira_metz` | `keiraFollowWithKiss` | `naughty\keira` | ✅ | ✅ **5** |
| Shani | `shani` | `shaniFollowWithKiss` | `naughty\shani` | ✅ | ✅ **4** |
| Cerys | `becca` | `cerysFollowWithKiss` | `naughty\cerys` | ✅ | ✅ **4** |
| Anna Henrietta | `anna_henrietta` | `anariettaFollowWithKiss` (+`NoKiss`) | `naughty\anarietta` (+`_tm`) | ❌ → manual | ✅ **4** |
| Vivienne | `sq701_vivienne` | `vivienneFollowWithKiss` (+`NoKiss`) | `naughty\vivienne` (+`_bird`) | ❌ → manual | ✅ **4** |
| **Salma** | `mh303_succbus_v2` | `salmaFollowWithKiss` | `naughty\salma` | ❌ → manual | ❌ Etap 1 |
| **Philippa** | `philippa_eilhart` | `philippaFollowWithKiss` | `naughty\philippa` | ❌ → manual | ❌ Etap 1 |
| **Syanna** | `syanna` | `syannaFollowWithKiss` | `naughty\syanna` | ✅ tak | ❌ Etap 1 |
| **Ves** | `ves` | `vesFollowWithKiss` | `naughty\ves` | ❌ → manual | ❌ Etap 1 |
| **Ciri** | `cirilla` | `ciriFollowWithKiss` **+ `ciriFollowWithHug`** | `naughty\ciri` | ✅ | ❌ Etap 2 |
| **Edna var Attre** | `edna_var_attre` | `ednaFollowWithKiss` | `naughty\edna` | ❌ → manual | ❌ Etap 2 |
| **Fringilla** | `fringilla_vigo` | `fringillaFollowWithKiss` | `naughty\fringilla` | ❌ → manual | ❌ Etap 2 |
| **Margarita** | `margarita` | `margaritaFollowWithKiss` | `naughty\margaritta` ⚠️ literówka w katalogu! | ❌ → manual | ❌ Etap 2 |
| **Orianna** | `vampire_diva` | `orianaFollowWithKiss` | `naughty\oriana` (+2 wyłączone warianty `__`/`_`) | ❌ → manual | ❌ Etap 2 |
| **Priscilla** | `pryscilla` | `priscillaFollowWithKiss` | `naughty\priscilla` | ❌ → manual | ❌ Etap 2 |
| Amrynn | ⚠️ **brak w rosterze** MCME | `amrynnFollowWithKiss` | `naughty\amrynn` | ❌ | ❌ pliki są, companiona nie ma — nieosiągalna bez dodania do rosteru MCME |

Follow-only (scena `*Follow` bez kiss/naughty — poza zakresem romansu, max T1):
`avallach`, `baron`, `dandelion`, `dijkstra`, `eskel`, `hjalmar`, `lambert`,
`letho`, `olgierd`, `regis_terzieff_vampire`, `vernon_roche`, `vesemir`,
`zoltan_chivay`. Rosa var Attre — companion bez scen follow; pomijać.
Sceny specjalne: `naughty\lake`, `naughty\yen_skel`, `naughty\triss_yen_trap`.

**Etapy pokrycia:**
- **Etap 0 (gotowe):** 7 NPC, 35 akcji.
- **Etap 1 (= zakres gift C1 z TODO):** Salma, Philippa, Syanna, Ves → 11 NPC.
- **Etap 2:** Ciri, Edna, Fringilla, Margarita, Orianna, Priscilla → 17 NPC.
  Razem: cała dostępna pula romance-capable.

**Checklist dodania nowego NPC (8 kroków):**
1. `MCM_AR_IsRomanceNPC` — dopisać `nam` (Core l.684).
2. `MCM_AR_GetCompanionDisplayName` — nazwa HUD (Interaction l.1089).
3. `GetBaseStoryAffinity` — fakty fabularne (Affinity l.190) lub 0.
4. `NaughtyScenePath` — mapowanie `nam`→katalog (Interaction l.791);
   ⚠️ `margarita`→`margaritta` (typo MCME), `vampire_diva`→`oriana`,
   `mh303_succbus_v2`→`salma`, `pryscilla`→`priscilla`, `edna_var_attre`→`edna`,
   `fringilla_vigo`→`fringilla`, `philippa_eilhart`→`philippa`, `cirilla`→`ciri`.
5. Scena dialogu: `dialogue\<plik>FollowWithKiss.w2scene` — nazwa pliku
   **nie pochodzi z `nam`** (np. `anarietta`, `oriana`, `salma`…) — brać z tabeli.
   ⚠️ Ciri: MCME rejestruje `ciriFollowWithHug` jako domyślny dialog —
   szablon huba może się różnić → auto-pick re-walidować; `ciriFollowWithKiss`
   istnieje jako osobny plik.
6. Pipeline intymny: `setNaughtyScene` zarejestrowane (syanna, cirilla) →
   `PreNaughtyWith` działa; niezarejestrowane → ścieżka manualna już obsłużona.
7. Barki/animy per §15.1: `PlayVoiceset`/`PlaySlotAnimationAsync` zwracają bool —
   sonda + fallback **wdrożone w W0** (`ar_probeanim`, fallback w `PlayBark`);
   ⚠️ niehumanoidalne szkielety (Salma) → T1/T3/T4 bez gestów.
8. Earned affinity `mcme_ar_<nam>_affinity` + gift C1 — działają automatycznie.

### D. Nowe propozycje — zweryfikowane wobec kodu gry

| # | Funkcja | Werdykt | Dowód / mechanika | Powierzchnia zmiany | Ryzyko |
|---|---|---|---|---|---|
| C-N1 | **Barki pogodowe** (deszcz/burza/śnieg/upał) | ✅ | `GetWeatherConditionName()`; voicesety `Weather*` (vanilla npc/temp) | ambient tick: pole `lastWeather` w ctx/channel + akcje `*_weather` | dostępność voicesetu per NPC — fallback lineId |
| C-N2 | **Zaproszenie do sparring'u** (T3-style) | ✅ | `scmcc.EnterFriendlyCombat(true)`; koniec: schowanie miecza (MCME `updateFriendlyCombat`) lub `endFriendlyCombat(won)` | nowa akcja Gesture/Prompt: approach→bark→consent→`EnterFriendlyCombat` | NPC od razu hostile→gracz (MCME blokuje znaki/bomby); testowac końcówkę walki |
| C-N3 | **Zaproszenie do gwinta** | ✅(deck do sprawdzenia) | `thePlayer.OnGwintGameRequested(deckName,faction,cards)` → DeckBuilder→GwintGame | akcja Prompt → consent → wywołanie | nazwa talii przeciwnika z definicji gwint — weryfikacja przed kodem |
| C-N4 | **Companion siada przy medytującym Geralcie** | ✅ | stany `Meditation`/`MeditationWaiting` (playerWitcher.ws); animy sit z katalogu jobów (`high_sitting_ground_determined`, `man_work_meditation`, `low_sitting_ground_happy`, `woman_lying_relaxed_on_grass`) | osobny watcher (AmbientTick omija gate Exploration — Meditation≠Exploration!) | wymaga ścieżki „reactive" obok IsSafeToInitiate; animy per-NPC do sprawdzenia |
| C-N5 | **Reakcja na sen (Corvo/łóżka)** | ✅ | `W3WitcherBed` tag `witcherBed` + `GetWasUsed()` + `PEA_GoToSleep` | tick: wykrycie stanu Sleep → bark + ew. anim `woman_sleep_on_bed_*` obok | punktowość tagu (tylko W3WitcherBed) |
| C-N6 | **Bark przy jeździe konnej / starcie** | ✅ | `thePlayer.GetUsedVehicle()` ≠ NULL; MCME RidingHorse | ctx: `playerMounted`; akcja T1 | rozróżnić koń/łódź (vehicle component) — weryfikacja pola |
| C-N7 | **Bark na łodzi** | ✅ | `thePlayer.IsOnBoat()` (już w gate bezpieczeństwa) | ctx pole + akcja T1 | — |
| C-N8 | **Wspólne picie w tawernie** | ✅ | `player_in_inn` + animy `man_work_drinking`/`woman_wine_tasting` (katalog jobów) | akcja T2: approach→anim drink→bark | anim może nie być we w2anims NPC → test `PlayAnimSimple` |
| C-N9 | **Afterglow bark po scenie** | ✅ | po `EndStagedInteraction` sukcesu → opóźniony bark | flaga w core + akcja T1 z gatem „po scenie <X s" | — |
| C-N10 | **Reakcja na joba companiona** (ona gotuje/czyta/cwiczy) | ⚠️ | `JobManager.getWorker(npc)` istnieje | ctx: `npcBusyWithJob`; akcja T1 komentarza | semantyka `getWorker` (aktywny vs przypisany) — doczytać JobWorker |
| C-N11 | **Rozszerzenie roostera** — pełna mapa i etapy w §16.C | ✅ | sceny istnieją dla 17 companionów (`known_scenes.txt` × roster MCME) | checklist 8 kroków w §16.C; nowe klasy np. `Actions_Extra.ws` | kuratowane lineId; `nam`≠alias sceny; typo `margaritta`; Ciri = Hug jako domyślna; Salma niehumanoidalna (§15.1) |
| C-N12 | **Barki „home" / interior** | ✅ | `IsInInterior()` (player+npc) + `areaName` | ctx pole + akcje T1 | — |
| C-N13 | **Kąpiel/„bath"** | ⚠️ ograniczone | animy `woman_work_sitting_bath`/`high_sitting_determined_bath` (kat. `naked`) istnieją, ale przypięte do stałych AP (nov_bath_*, viz_chamber_bath); gracz NIE ma mechaniki kąpieli | tylko companion-only scenka przy tych lokalizacjach | kruche wykrywanie (koordynaty); bez udziału Geralta |
| C-N14 | **Taniec razem** | ❌ | brak mechaniki/animów parzystych poza scenami questowymi | — | — |
| C-N15 | **Geralt siada przy ognisku z companionem** | ❌ (jako opisane) | brak `PEA_Sit`; `SitDown`/`SitAndWait` = kontekstowe werby encji (patrz §15); zamiast: C-N4 medytacja | — | — |
| C-N16 | **Nowe sceny `.w2scene`** | ❌ | binarki; brak tooling (REDkit nie wspiera NG .w2scene praktycznie) | — | — |
| C-N17 | **Zmienne tempo/preset barków w MCM** | ✅ | nowa var w XML + `ConfigWrapper.GetFloat` | XML + 1 getter | — |
| C-N18 | **Jealousy: konfrontacja po wyborze rywalki** | ✅ | istniejące fakty rywalek + snarki + sceny duel-scene? (brak) → barki | nowe akcje T1 z gatem „po scenie X" | — |
| C-N19 | **Companion rozsiada się przy ognisku** (evolucja `*_campfire_*`) | ✅ | już częściowo jest: `woman_sit_stump_idle` po approachu; wariant „stay": NPC siada i zostaje, dopóki gracz w promieniu / nie odejdzie od ogniska | akcja T2: approach→sit anim (loop)→bark→follow-resume gdy gracz odejdzie >X m | Geralt nie siada (§15) — scenka jest companion-only; anim per-NPC §15.1 |
| C-N20 | **Idle Autonomy / „companion żyje podczas postoju"** | ✅ | mechanizm istnieje: `animsFinished` gra `info.IdleAnimation` gdy `!IsFollowing()` (SCMCC l.464); design w §16.F | detektor postoju w ticku + suspend/resume follow | ⚠️ verify: czy suspendowany NPC nie jest ciągnięty przez follow-AI |

### E. Plan etapów — od najłatwiejszych do zweryfikowania

Kryterium: **koszt weryfikacji** (kompilacja → jedna komenda debug → jeden kontekst
w grze → pełne scenariusze → decyzje architektoniczne).

| Etap | Zawartość | Weryfikacja | Zależności |
|---|---|---|---|
| **W0 — czysto skryptowe** (zero gry) | ✅ komentarze `[E]`→`[C]` w `.ws` (l.665/1085 zostawione — historycznie trafne); ✅ link TODO→ARCHITECTURE (TODO l.3); ✅ **§15.1 mitigacje:** `PlayBark` sprawdza zwrot `PlayVoiceset`→fallback `lineId`→log `voiceset missing`; ✅ helper `MCM_AR_ProbeAnim` (bool z `PlaySlotAnimationAsync`, retry na 2. slocie); ✅ exec `ar_probeanim <npc> <anim>` | `precheck_syntax.ps1` + `test_compile.ps1` — **zdane 07.10 (ExitCode 0)** | — |
| **W1 — jedna sesja `-net -debugscripts`** (~15 min) | `ar_status` → core żyje? `ar_eval` → lista `blocked:`; `ar_trigger`+`ar_force` → wymuszona akcja na otwartym; `ar_logdump` po tickach → logi sond z W0; `ar_line` audycje kandydatów na lineId giftów; `ar_gift` smoke | HUD + `scriptslog.txt` | W0 (logi sond) |
| **W2 — małe akcje, test = 1 kontekst** | consent remap na niezmapowaną akcję (recepta §6 + test: czy listener dostaje event przy `BlockAction(EIAB_SpecialAttackLight)`); C-N7 łódź; C-N12 interior; C-N9 afterglow; C-N6 koń; C-N19 campfire stay-seated; C-N17 preset barków w MCM; **C-N20/I1 idle-suspend** (detektor postoju + `StopFollowing`/`StartFollowing`) | wejść w kontekst → obserwacja; `ar_eval` pokazuje gate; idle = „stać i patrzeć" | W0 |
| **W3 — gift C1** (zatwierdzone TODO) | `PlayerCarriesGift()` + `MCM_AR_<npc>_GiftRequest` + preferencje per NPC; lineId prośby/podziękowania z audycji W1 | pełny cykl: prompt→accept (item−1, +aff, thanks) / reject / timeout / `no_gift` w `ar_eval` | W1 (lineIds) |
| **W4 — roster Etap 1** (Salma, Philippa, Syanna, Ves) | checklist §16.C pkt 1–8; **sondy assetów per NPC na początku** (Salma=sukkubus → prawd. bez gestów T2) | `ar_eval` per NPC + live T1→T4 | W0+W1 (sondy) |
| **W5 — nowe ścieżki reaktywne** | C-N4 medytacja-dołączka (kanał obok `IsSafeToInitiate` — Meditation≠Exploration); C-N2 sparring (`EnterFriendlyCombat` + wykrycie końca); C-N5 sen/łóżko; C-N8 picie w tawernie; **C-N20 I2/I3 + enklawy §16.G** (ambient animy własne / `assignWorker` przy AP/schedules) | scenariusz kontekstowy w grze | W1 (+W2 dla I1) |
| **W6 — duże / warunkowe** | C-N3 gwint (research nazw talii w defs **przed** kodem); Ubiór Wariant B (nakładka z pipeline naughty MCME); roster Etap 2 (6 NPC — Ciri: re-walidacja szablonu `ciriFollowWithHug` dla auto-pick); C-N10 jobs (`getWorker` semantyka) | per-funkcja | W4 |
| **W7 — decyzje / zamknięte** | decyzja kolizje-duchy (wrapować `update4Second`/`NewIdle` vs zostawić); C-N13 kąpiel ⚠️; custom VO backlog; C2; ❌ C-N14 taniec, C-N15 sit-anywhere, C-N16 nowe .w2scene | — | — |

**Rekomendowany start:** W0 → W1 (diagnoza „mod nie reaguje" = TODO priorytet 1)
→ W3 (gift C1, pierwsza nowa mechanika na istniejącym pipeline'ie) → W4.
W2 wciągać równolegle — każda pozycja to ~30–60 min implementacji.

**Otwarte do sprawdzenia przy najbliższej sesji w grze:**
- `shaniFollowWithHug` (rejestracja MCME, SpawnCompanionsSpecial l.492) vs
  `shaniFollowWithKiss` (plik w bundle, używany przez nas) — możliwy martwy
  reference po stronie MCME.
- `ar_eval` nocą — ile `blocked:` to zamierzona selekcja, a ile luka w T1
  (decyzja: nocny wypełniacz).
- Dispatch listenera przy zablokowanym EIAB (wymóg dla W2-consent-remap).

### F. Idle Autonomy — „companion żyje podczas postoju" (design wstępny)

**Problem:** companion w follow stoi nieruchomo obok gracza w nieskończoność —
`animsFinished` (SCMCC l.464) gra `IdleAnimation` tylko gdy `!IsFollowing()`.
Banter werbalny już działa (`specialNPCDialogues.UpdateDialogues`, tempo =
suwak `MCME_BanterDelay`) — brakuje warstwy fizycznej.

**Detektor postoju (nasz):** w ticku staged — `playerPos` delta < ~1.5 m przez
≥N kolejnych ticków (próg ~45–60 s) + `IsSafeToInitiate` → `idleSince` stempel.
Reset natychmiastowy przy ruchu/walce/dialogu. Koszt: ~0 (dane już w ticku).

```
gracz bezczynny ≥60 s (Exploration, safe)
  └─ per companion (tag following, <12 m):
       I1: StopFollowing(true)  → MCME sam gra zarejestrowany IdleAnimation
           (Yen: leżak, Triss: siedzi dumnie, Keira: siedzi…)
       I2: fallback gdy brak HasIdleAnimation → nasz mini-registry ambient anim
           (warm hands przy campfire / sit ground / look around — sonda §15.1)
       I3: jeśli AP jobów w zasięgu (KM/Corvo/karczma) → assignWorker →
           krzesło/ogień/karty/jedzenie  [opcjonalnie, osobny etap]
  └─ wyjście: gracz ruszył >8–10 m od kotwicy / walka / dialog /
       akcja staged na tym NPC → StartFollowing + restore
```

**Reguły współistnienia z akcjami AR:** flaga `arIdleFree` per NPC; akcje staged
**mogą przerywać idle** (companion przerywa siedzenie, żeby podejść do Geralta —
pożądane narracyjnie); `EndInteraction` przywraca stan idle jeśli gracz wciąż
stoi. Watchdog locka działa bez zmian.

**Do zweryfikowania przed kodem:**
- czy `StopFollowing(true)` na trwalszą porę nie jest odwracany przez follow-AI
  MCME (`update4Second`/`NewIdle` mogą re-collować `StartFollowing`?),
- czy `IsFollowing()` (flaga scmcc) vs tag `mod_scm_IsFollowing` — nasza
  eligibility patrzy na tag → follow flag może mrugać bez wpływu na rejestr,
- dystans „anchor" i cooldown re-entry (histereza jak w naughty notifier),
- Vanillove `VMS`/łódź/koń — idle mode wyłączony poza czystym Exploration.

**Proponowany start (W2):** tylko I1 = detektor + suspend + resume. Jeśli MCME
samo odpala idle animy — feature praktycznie „darmowy". I2/I3 = osobne etapy.

### G. „Enklawy" — wykrywanie bezpiecznych rejonów z aktywnościami (design wstępny)

Cel: w zamkniętych/domowych rejonach (Kaer Morhen, Corvo Bianco, Vizima,
karczmy, dom Triss…) companion ma nie tylko „nie-stać", ale **mieć co robić**.

**Warstwy detekcji rejonu (wszystkie realne):**

| Warstwa | API | Ziarnistość |
|---|---|---|
| Region/świat | `MCM_GetAreaName()` → `EAreaName` (Novigrad-land, Skellige, **Kaer Morhen**, White Orchard, **Wyzima**, Toussaint=11…) | cały świat |
| Wnętrze | `thePlayer.IsInInterior()` (+NPC) | budynek y/n |
| Tawerna | fakt `player_in_inn` (już w ctx) | tak/nie |
| Punkty zainteresowań | `JobManager.actionPoints` — **inicjowane tylko dla bieżącego regionu**; pozycje światowe + `activationRadius` + `isOutside` | konkretne „strefy robienia rzeczy" |
| Nazwane enklawy | własna tabela anchorów (jak `naughtyPoints` MCME: Vector+radius) | np. „sala KM", „dom Corvo", „komnata Vizima" |

**Zasoby aktywności (zweryfikowane — `MultiCompanionModJobManager.ws`):**
~**1200 action pointów** w 6 regionach: Kaer Morhen 278, White Orchard 250,
Wyzima 248, Novigrad/Velen 232, Skellige 103, Toussaint 96. Przykłady:

- Kaer Morhen: `km_chair_down_1..7` (krzesła w sali), `km_fire_down_1/2` (ogień),
  `km_gwent_1/2` (karty), `km_woman_eat_1/2`, `km_man_eat`, `km_man_training_sword`,
  `km_man_sitting_sharpening_sword`, `km_man_looking_at_books`,
  `km_woman_looking_at_herbs`, `km_sleep_down_1..5`/`km_sleep_up_1..3` (łóżka).
- Toussaint/Corvo: `bob_corvo_bath_1..3` (kąpiel!), `bob_corvo_greenhouse_1..3`+
  `picking_up_herbs`, `bob_corvo_dining_chair_1/2`, `deckchair`, `creek`,
  `dandelion_playing_lute`, liczne `*_sitting_*`/`*_lying_*`/`*_sleep_*`.
- Wyzima: `viz_chamber_bath` + `viz_chamber_chair_1..4` (komnata w zamku).

**Schedules per NPC** (`newSchedule` + `.addJob(job, sekundy_od, sekundy_do)`
+ `.land(region)`) — istnieją m.in. dla: `yennefer`, `triss`, `keira`, `shani`,
`cerys`, `ciri`, `vivienne`, `anarietta_1/2`, `syanna_1/2/3`, `salma`,
`philippa`, `priscilla`, `ves`, `margarita`, `orianna` + eskel/lambert/witchers…
Np. Yen w KM: sen 22–8 → jedzenie 8–9 → `sorceresses_misc` 9–15 → jedzenie 15–16
→ misc 16–22.

**Worker mechanics (`MCM_Worker`):** `assignWorker(actor, workerName, schedule)`
(JobManager l.251) → stany Waiting/Walking/Working/Hidden/Paused z pathfindingiem
(`MCM_WorldPath` z CSV per region); **auto-pauza** gdy gracz >~150 m
(`shouldPause` l.312) lub input-context ≠ Exploration (`continueInPauseMode`
l.295); `softStop`/`forceStop`/`cancelWorker(ByActor)` do czystego wyjścia.
`canActorDoWork` (l.207) = żywy + brak celu walki — **nie sprawdza follow** →
worker na podążającym NPC wymaga naszego `StopFollowing` (inaczej walka AI
o locomocję).

**Design enklawy:**
```
wejście w enklawę = idle-mode aktywny (§16.F) AND
  ( IsInInterior()  OR  najbliższy AP < ~25 m  OR  anchor w tabeli )
  → per companion:
      schedule[nam] istnieje dla regionu?
        TAK → assignWorker(npc, nam, schedule) → NPC sam wybiera job wg godziny
              (Yen o 22:00 pójdzie spać do km_sleep_*, o 9:00 do sorceresses_misc)
        NIE → I1/I2 (idle anim / ambient anim w miejscu)
  → wyjście: gracz wychodzi z enklawy / rusza >X m / unsafe
      → cancelWorkerByActor + StartFollowing + restore
```

**Do zweryfikowania:**
- czy `assignWorker` na follow-NPC działa po `StopFollowing(true)` (worker Begin
  vs scmcc follow),
- minimalna odległość gracza→AP żeby companion nie „uciekał" za daleko
  (pauza MCME to ~150 m — dla naszego leash potrzebny własny radius ~15–25 m),
- nakładanie okien czasowych schedule'a z rzeczywistą godziną,
- `actionPoints` są `private` w JobManager → potrzebny `@addMethod`-
  getter `MCM_AR_GetNearestAP(pos,r)` albo iteracja (wrapy na private
  metodach są OK — dodajemy metodę, nie nadpisujemy),
- proste enklawy bez AP (losowe obozowiska) → tylko I1/I2.

## 17. Konwencje i jak rozszerzać

- Rejestracja akcji: `RegisterAction(new MCM_AR_<Npc>_<Akcja> in this)` w wrapie
  `InitDefaultActions` (Main/DLC). Zewnętrzne paczki: własny `@wrapMethod
  (MCM_RomanceActionRegistry) InitDefaultActions` + `RegisterAction`.
- Nowa akcja: dziedzicz `MCM_RomanceInteraction`; ustaw `id/targetNpc/minAffinity/
  cooldownSeconds/triggerType/weight` + treść (`lineId` lub `barkVoiceset`+`lineText`,
  `barkMimic`); gate własny TYLKO w `GetExtraBlockReason` (ar_eval pokaże powód);
  `Execute` latent — na każdej ścieżce `EndSoft`/`EndInteraction`!
- Nowy NPC: `MCM_AR_IsRomanceNPC` (Core l.684) + `MCM_AR_GetCompanionDisplayName`
  (Interaction l.1089) + fakty affinity (Affinity l.190) + ścieżki scen
  (`NaughtyScenePath` l.791) + akcje.
- Przed oddaniem `.ws`: `precheck_syntax.ps1` → `test_compile.ps1` (GEMINI.md §1).
- Git: brak commitów bez polecenia użytkownika.

---
*Stan dokumentu: odpowiada kodowi na dzień utworzenia; numeracja linii MCME/vanilla
może dryfować po aktualizacjach modów bazowych — cytowane są też sygnatury.*
