# MCME Autonomous Romance - ARCHITEKTURA I FLOW

> Dokument referencyjny moda: jak działa (1:1 z kodu), z jakich API gry/MCME korzysta,
> jakie są twarde ograniczenia platformy i co da się rozszerzyć.
> Cytaty `plik:l.linia` wskazują źródło prawdy - przy zmianach kodu aktualizować.

**Legenda wykonalności (roadmapa):**

- ✅ **Realne** - mechanika/API potwierdzone w kodzie gry lub MCME.
- ⚠️ **Warunkowe** - realne, ale wymaga dodatkowej weryfikacji w runtime lub jest kruche.
- ❌ **Nierealne** - brak mechaniki w grze / brak narzędzi.

---

## 1. Architektura w pigułce

```text
┌──────────────────────────────────────────────────────────────────┐
│  GRA (Witcher 3 Remastered v5.00+)                               │
│   └─ CR4Player.OnSpawned → InitRemasterSettings()  [wrap]        │
│        └─ MCM_AR_OnPlayerReady()                                 │
│             ├─ MCM_AR_InitCore()                                 │
│             │    ├─ MCM_AutonomousRomanceCore   (statemachine)   │
│             │    │    └─ MCM_RomanceActionRegistry → 47 akcji    │
│             │    ├─ MCM_AmbientRomanceChannel   (statemachine)   │
│             │    ├─ timer MCM_AR_AutonomousTick  MCM 20-160s(S)│
│             │    └─ timer MCM_AR_AmbientTick     co 10s (AMBIENT)│
│             ├─ MCM_AR_ConfigWrapper (user.settings / MCM menu)   │
│             └─ input listener: 'SwordSheathe' → consent [C]      │
└──────────────────────────────────────────────────────────────────┘
│ MCM_RomanceCore.ws        - pętla, gating, kontekst, locki, execy
│ MCM_RomanceAffinity.ws    - config wrapper + resolver zażyłości + MCM_AR_Log
│ MCM_RomanceInteraction.ws - klasa bazowa akcji, staging, consent, gesty parne (kiss/hug), rejestr
│ MCM_RomanceActions_Main.ws- 48 akcji: Yen(10) Triss(10) Keira(8) Shani(7) + Rosa(3) Tomira(3) Ciri(1) + generyczne T1(6)
│ MCM_RomanceActions_DLC.ws - 64 akcje: Anarietta(6) Vivienne(6) Cerys(7) Syanna(5) + Philippa(5) Ves(5) Salma(5) Priscilla(5) Edna(5) Fringilla(5) Margarita(5) Orianna(4)
│ MCM_RomanceQoL.ws         - enum ubioru w menu MCME + execy (dress/gift)
│ bin/.../modMCME_AutonomousRomance.xml - konfiguracja MCM (8 opcji, 5 presetów)
│
│ Zależność twarda: modMCME_Remastered 5.00+ (companioni, sceny, NaughtyManager,
│ DialogueManager, JobManager, scmcc, specialData).
│ Integracja wyłącznie przez @wrapMethod/@addMethod/@addField - zero merge'ów.
```

### 1.1 Inwentarz plików (100% pokrycia `_ModDev\MCME_AutonomousRomance`)

| Ścieżka | Rola | Stan |
| --- | --- | --- |
| `repo\Mods\modMCME_AutonomousRomance\content\scripts\local\romance\*.ws` ×7 + stub | cały kod moda (Core/Affinity/Interaction/Actions_Main/Actions_DLC/QoL/Tw3seDev + stub) | ✅ live - wdrożone przez junction 1:1 |
| `repo\Mods\...\romance\*.ws.bak` ×5 | snapshoty sprzed ostatnich edycji | ✅ ignorowane przez kompilator, `.gitignore` i `package_release.ps1` (l.49 filtruje) |
| `repo\Mods\...\content\*.w3strings` ×17 + `en/pl.w3strings.csv` | tablice napisów (CSV = źródło, .w3strings = build); wszystkie locale poza `pl` = kopie `en` | ✅ używane przez `GetLocStringById`/HUD; ⚠️ 15 locale = fallback na EN (brak tłumaczeń); CSV odfiltrowane z zipa |
| `repo\Mods\modMCME_AutonomousRomance\README.md` | README w folderze moda (trafia do zipa) | ✅ zsynchronizowany z `repo\README.md` (14.10) |
| `repo\bin\config\r4game\user_config_matrix\pc\modMCME_AutonomousRomance.xml` | definicja menu MCM | ✅ live (deploy kopiuje do `bin\config\...` gry) |
| `repo\README.md` | dokument publiczny | ✅ aktualny (14.10: tick MCM, consent hold/tap, kanały logów) |
| `repo\ARCHITECTURE.md` | **ten dokument** | ✅ |
| `repo\CODEBASE.md` | **Codebase & Architecture Reference** | ✅ utworzony - mapa 1:1, 30 definicji `exec function` (Core 22, QoL 4, dev TW3SE 4), wytyczne anty-regresyjne |
| `repo\TODO.md` | roadmapa zadań (otwarty backlog; logi sesji → `archive\session_logs\`) | ✅ aktywna |
| `repo\TODO.md` | roadmapa zadań (otwarty backlog; logi sesji → `archive\session_logs\`) | ✅ aktywna |
| `repo\LICENSE`, `repo\.gitignore` | meta | ✅ |
| `repo\scripts\test_compile.ps1` + `repo\scripts\precheck_syntax.ps1` | weryfikacja kompilacji | ✅ zsynchronizowane z kanonicznymi (22.10, w tym fix obciętego `x64.final.redscripts`); uwaga: `repo\scripts\` **nigdy nie było w commitach** (git log - staged list PR nie zawiera `scripts/`) |
| `scripts\test_compile.ps1` (8607 B) + `scripts\precheck_syntax.ps1` | test kompilacji przez `witcher3.exe -headless` + szybki pre-check składni | ✅ kanoniczne - Faza 0 woła `precheck_syntax.ps1` przed grą (`-SkipPrecheck` pomija) |
| `scripts\deploy_junctions.ps1` | junction repo→`Mods\` + kopia XML do `bin\config` | ✅ (po fixie nazwy XML) |
| `scripts\package_release.ps1` | zip release (`Mods\`+`bin\`) | ✅ działa; filtruje `.bak`, `.tmp`, `.csv` oraz foldery Vortexa |
| `scripts\run_game_debug.bat` | odpalenie gry z debug konsolą | ✅ dev |
| `scripts\known_scenes.txt` | lista scen `.w2scene` MCME | ✅ referencja |
| `archive\dumps\scene_and_dialog_ids.md` | baza ścieżek scen, faktów, namespace `mcme_ar_*` | ⚠️ referencja historyczna (STALE — aktualne mapowanie: `AutonomousScenePath`) |
| `nexus\description.bbcode` | opis Nexus | ✅ aktualne (changelog snippet ekstrahuje `package_release.ps1` z `CHANGELOG.md` — nie tworzyć osobnych changelogów) |
| `releases\MCME_AutonomousRomance_v*.zip` | paczki release v1.0.0/v1.1.0/v2.0.0 | ✅ aktualne (wadliwy build 19.10 → `archive\releases_stale\`) |
| `archive\diffbase\*.ws` ×6 + `E1_interaction.diff.txt` | kopie bazowe do diffów | ✅ narzędzie dev (w `archive\`) |
| ~~`compile_out.txt`~~ | dawny log kompilacji | ❌ usunięty (logi builda lądują obok skryptów w `scripts\`) |
| **`Mods\modMCME_AutonomousRomance` (w katalogu gry)** | junction → `repo\Mods\modMCME_AutonomousRomance` | ✅ wdrożone 1:1 (identyczne rozmiary plików) |

**Nieistniejące:** `ar_probe_local.ws` / `ar_probe_mcme.ws` - wpisane w IDE jako
otwarte dokumenty, ale **fizycznie nie istnieją** na dysku (0 trafień `ar_probe*`,
zero referencji poza tym dokumentem). Rolę sond z §15.1 przejęły wdrożone w W0:
`MCM_AR_ProbeAnim` (Interaction.ws) + exec `ar_probeanim` (Core) + fallback
w `PlayBark` - osobne pliki-sondy nie są już potrzebne.

---

## 2. FLOW: Boot / init

```text
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
        │    ├─ AddTimer('MCM_AR_AutonomousTick', GetTickIntervalSeconds(), loop)
        │    └─ AddTimer('MCM_AR_AmbientTick',   10.0, loop)
        ├─ new MCM_AR_ConfigWrapper (lazy; Filar 3 konfiguracji)
        ├─ theInput.RegisterListener(this,'OnMCM_AR_ConsentKey','SwordSheathe')
        └─ core.ResetAllCooldowns()
```

**Dlaczego `InitRemasterSettings`, a nie `CPlayerInput.Initialize`:** Kompilator Remastered nie łączy
wielu `@wrapMethod` różnych modów na tej samej metodzie (cienie priorytetów - np. BIA
Priority 19 zjadłby nasz wrap). `InitRemasterSettings` jest wywoływane na końcu bazowego
`OnSpawned` i nic go nie wrapuje → zawsze odpala (`..\..\..\AGENTS.md` §3.1).

---

## 3. FLOW: Kanał STAGED - tick decyzyjny MCM `MCM_AR_TickInterval` (20-160 s, dom. 30 s; Tiery 2-4)

```text
MCM_AR_AutonomousTick (Core l.110)
  → core w stanie Idle? → GotoState('ProcessingTick') → ProcessTick() (l.737)
  1. UpdateCombatStatus()                         (stempel końca walki)
  2. GATE MCM_AR_IsSafeToInitiate (l.386) - BLOKUJE gdy:
       player state ≠ 'Exploration' | input ctx ≠ 'Exploration'
       | IsInCombat | IsDialogOrCutscenePlaying
       | MCM DialogueManager.IsBusy | IsSwimming | IsOnBoat
  3. theGame.GetNPCsByTag('GeraltsBFF') → pusto? → Idle
       (uwaga: zwraca CAŁY roster ~30 encji MCME włącznie z zaparkowanymi
       - realny filtr to tag 'mod_scm_IsFollowing' + dystans ≤15 m w pętli;
       log „companions=30" NIE znaczy 30 aktywnych towarzyszy)
  4. ctx = BuildContext(companions) (l.449):
       godzina/noc(22-4)/świt(6-9) | HP gracza | obszar (Corvo=11)
       | campfire<6m (tag 'campfire'/'CarriesOpenFire' minus swiece/lampy)
       | tawerna (fakt 'player_in_inn' LUB interior+skan encji 18m/cap200)
       | NaughtySpot<30m | romansowe NPC + rivalCount
  5. Naughty-spot notifier: HUD raz przy wejściu w 30m; reset >40m
  5b. UpdateIdleSuspend (Core ~l.420-530): postój gracza ≥50 s
       → max 2 joby MCM_AR_IdleJob na tick dla NPC z 'mod_scm_IsFollowing'
       ≤15 m; pomija NPC w stagingu/scenie/busyNpc (guard - 14.10 fix)
  6. ShuffleCompanions (fisher-yates - fairness)
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
  9. debug digest (ar_debug) - deduplikacja na lastDebugDigest
```

## 4. FLOW: Kanał AMBIENT - co 10 s (Tier 1 barki)

```text
MCM_AR_AmbientTick (Core l.121) → ProcessAmbient() (l.935)
  0. UpdateIdleAmbient (Core ~l.320-390): progresja jobów idle
       (moving→posed; deadline spaceru 6-12 s, poseDelay 0-10 s per NPC),
       prune martwych guarded-jobów po deadline, WakeIdleJobs przy ruchu
       >1.5 m / unsafe (log „waking X NPCs (busyKept=Y)")
  1. Bramka IsSafeForAmbient (szersza niż staged IsSafeToInitiate - dopuszcza
       konia/łódź) + lista 'GeraltsBFF' + BuildContext
  2. BOOKKEEPING powitań CO TICK (stempel "widziana" tylko gdy NPC jest obecna
       i mogła być powitana - gate-fail nie konsumuje okna absencji):
       NPC zniknęła z tagu >60s i wróciła <10m
       → EnableDynamicLookAt + PlayVoiceset(100,'greeting_geralt')
       → zjada turę barku; cooldown powitania 300s/NPC
  3. Bark cooldown globalny 90s → wolny? pętla NPC:
       nie-busy staged | following | !IsInGameplayScene | !IsSpeaking
       → TryExecute(ambientOnly=true) → tylko RTT_OneLiner → PlayBark → break
```

Dlaczego dwa kanały: latent `Execute` staged (podejście+scena) nigdy nie blokuje
harmonogramu barków - osobne maszyny stanów i timery.

## 5. FLOW: Cykl życia akcji per Tier

```text
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
  → RequiresPlayerConsent? ShowConsentPrompt(tekst, ~20s okno (min 20s clamp), npc)
                            : WaitForApproach (brak promptu)
  → ODMOWA (timeout / gracz odjdzie >12m / brak [C]):
       EndSoft + MarkRejected → backoff 300s → 900s → 1800s
  → AKCEPT ([C] - hold ~1 s albo 2x tap; prompt sugeruje obie metody):
       HardStage (l.356): BlockAction(EIAB_Movement) gracza ~1-2s
         + obrót obojga twarzami + domknięcie dystansu
       → PlayKissScene/PlayHugScene → PlayScene(ar_*.w2scene,
         stripped PChoice) → WaitForSceneEnd → EndInteraction (l.423):
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

## 6. FLOW: Consent Engine v3 (`MCM_AR_Consent` + `SwordSheathe`)

- Historia: wczesne próby nasłuchiwania na klawiszu `[E]` kolidowały z natywnym kołem dialogu MCME. Z kolei bindowanie w sekcji menu `[SCMMenuBase]` nie dispatchowało eventów podczas eksploracji świata.
- Dedykowana akcja `MCM_AR_Consent`: w v2.0 wprowadzono własną akcję wejścia `MCM_AR_Consent`, zdefiniowaną w `MCME_AR.input.settings` pod klawisz [C] oraz D-pad w lewo i w prawo na kontrolerze.
- Vanilla fallback: zachowano równoległy nasłuch na vanilla akcję `'SwordSheathe'` ([C]), dzięki czemu mod działa natychmiast po instalacji nawet bez zmergowania pliku `input.settings`.
- Implementacja w `ShowConsentPrompt` (Interaction L594-750):
  - Wyświetlanie promptu na ekranie HUD z ikoną realnego klawisza (`<<MCM_AR_Consent>>`).
  - Dwuetapowa detekcja zgody: przytrzymanie klawisza przez ok. 1.0s (Hold) lub szybkie podwójne naciśnięcie w czasie <0.7s (Double-Tap).
  - Latch zdarzeń per-akcja (`mcm_ar_consentHeldC` i `mcm_ar_consentHeldS`): zwolnienie syntetycznego zdarzenia pada nie zeruje holda drugiej zarejestrowanej akcji.
  - Okno czasowe min. 20s: prompt nie znika zbyt szybko za kolejką napisów dialogowych i barków NPC.
  - Odmowa: odejście gracza na dystans >12m lub upływ limitu czasu promptu uruchamia backoff odmowy (300s -> 900s -> 1800s).

## 7. FLOW: Sceny autonomiczne kiss/hug (per-NPC stripped .w2scene)

Pierwsza wersja repacku podstawiła **jedną** wyczyszczoną scenę Triss pod wszystkie 6 nazw `*FollowWithKiss` — każda towarzyska grała treść Triss (`id:TRISS`), a ucięty graf psuł elementy menu. Obecna architektura: **osobna wyczyszczona scena per NPC** we własnym bundle moda (`Mods\modMCME_AutonomousRomance\content\blob0.bundle`, ścieżki `dlc\mod_mcme_autonomous_romance\dialogue\ar_*.w2scene`), wygenerowana z oryginału MCME skryptem `scripts\build_ar_bundle.ps1`:

```text
orig *FollowWith*.w2scene (DLC bundle)
  → WolvenKit extract + enum fix ('medium'->'Medium', 1 bajt)
  → cr2w2json -> strip_scene.py:
      CStorySceneInput.nextLinkElement -> sekcja gestu (pomija PChoice)
      sekcja gestu.nextLinkElement     -> CStorySceneOutput
      actorTags kompana                -> [mcme_companion]
      (id, voicetag, linie, animy NPC zostaja nietkniete)
  → json2cr2w -> Bundle.Write -> ar_*.w2scene
```

```text
PlayKissScene(npc) / PlayHugScene(npc)   (Interaction)
  → AutonomousScenePath(npc, isHug)      (mapa nam -> ar_* sciezka;
                                          brak wpisu = false)
  → PlayScene(npc, path)                 (mod_scm_delayedDialogue MCME,
                                          scena bez osiagalnego PChoice
                                          = zero koła dialogowego)
  → WaitForSceneEnd(60s)
  → PlayPostKissReaction / PlayPostHugReaction (bark w marszu)
```

> [!CRITICAL]
> **ŻELAZNA ZASADA ZASOBÓW: kiss/hug = wyłącznie nasze `ar_*` sceny**
> Oryginalne `dlc\mod_spawn_companions\dialogue\*FollowWithKiss.w2scene` należą do DLC MCME (z `PChoice` — to menu dialogowe samego MCME, uruchamiane przez `scmcc.OnPlayerInteract`). **NIGDY** nie kieruj akcji `PlayKissScene`/`PlayHugScene` na te ścieżki — wyrzuci gracza do koła dialogu. Nasz bundle trzyma wyłącznie nazwy `ar_*` — zero shadowingu zasobów MCME.
> Slot-anims (`ActionPlaySlotAnimationAsync` z `determined_gesture_*`/`hug_f`) **nie działają** — sondy live zwróciły false na wszystkich slotach; to nazwy tracków scenowych, nie gameplay-animów. Podobnie `SSST_Accept` sam w sobie soft-lockuje `section_choice_choosing` (wymaga cyklu Flash UI).

Stan wdrożenia (20 scen w bundle'u): `ar_yennefer_kiss`, `ar_triss_kiss`, `ar_keira_kiss`, `ar_shani_kiss`, `ar_cerys_kiss`, `ar_syanna_kiss`, `ar_anna_kiss`, `ar_vivienne_kiss`, `ar_rosa_kiss`, `ar_tomira_kiss`, `ar_philippa_kiss`, `ar_ves_kiss`, `ar_salma_kiss`, `ar_priscilla_kiss`, `ar_edna_kiss`, `ar_fringilla_kiss`, `ar_margarita_kiss`, `ar_orianna_kiss`, `ar_cirilla_kiss` + `ar_cirilla_hug`. Sceny dla 12 NPC rozszerzonego castu są adaptacją scen `*FollowWithKiss` z paczek MCME (Spawn Control Girls, Anarietta & Vivienne plus2, Even More Companions) — ten sam pipeline strip: Input → `section_kissscene` → Output, tag `mcme_companion`. Kolejne NPC dopisujemy do `$SceneJobs` w `build_ar_bundle.ps1` (per-job `Bundle`) i do `AutonomousScenePath` (Interaction). **Operacyjny przepis + pułapki ekstrakcji/bindingu: CODEBASE.md §5.1.**

**Wyjątek `noble_woman_base`:** `ar_anna_kiss`, `ar_vivienne_kiss`, `ar_orianna_kiss` leżą w bundle'u, ale `AutonomousScenePath` **celowo zwraca `""`** dla `anna_henrietta`, `sq701_vivienne` i `vampire_diva`/`oriana`, a ich akcje kiss (`anarietta_night_royal`, `vivienne_night_invitation`, `orianna_kiss`) zostały **usunięte z rejestru na stałe** (decyzja projektowa — assetu animacji kiss dla tego rigu nie ma w całej grze, więc kiss tier nigdy nie powstanie; trio jest wspierane eksperymentalnie). Ich rig `noble_woman_base` ma okrojony animset bez banków `woman_dialog*` (dump `noble_woman_dialog_animation.w2anims` + `ep2_anna_henrietta_dialog_animation.w2anims` + pozostałych banków referencji w2ent: `qq703_anna`, `woman_noble_work`, `woman_noble_movement`, `woman_quest` — zero kiss/hug/intimate), więc event `triss_high_standing_..._kiss` (`animationName` = generyczne `high_standing_determined_gesture_passionate_kiss_front_01`) nie ma się na czym rozegrać → T-pose. Ta sama wada jest **udokumentowana przez autora upstream paczki** — ich sceny to klony scen Yen/Triss 1:1 (zweryfikowane: `anariettaFollowWithKiss` = wariant `yennefer_*`, `vivienneFollowWithKiss`/`orianaFollowWithKiss` = wariant `triss_*`), a readme AnVi przyznaje, że kiss nie działa i podpina opcję dialogową pod scenę `naughty\*`. Nasze `*_intimate_invite` całej trójki to ten sam mechanizm (w tym nowy `orianna_intimate_invite` → `naughty\oriana\anywhere`) — `CStorySceneCutscenePlayer`, nie scene-anim binding na aktywnym rigu.

Bezpieczniki: `EndInteraction` po scenie robi standardowy cleanup (`wasInDialogue` + `RefreshMimicsNextStateChange` + follow-resume); martwy lock pokrywa watchdog `IsStagedBusy`; `PlayScene` ma `WaitForDialogueFree(25s)` i timeout fail-startu.

**Mapa NaughtyPointów** (SpawnCompanionsSpecial.ws l.744-764, 16 punktów):
Triss House, Rosemary & Thyme (3), Kingfisher (2), Var Attre Villa, Passiflora,
Crow's Perch (2), Shani Clinic Oxenfurt, Kaer Trolde pokój Yen, Kaer Morhen (2),
Corvo Bianco (sypialnia + gościnny), Pałac Beauclair, Posiadłość Orianny.
Zaproszenie pada w zasięgu 30 m (ctx.isNearNaughtySpot), scena wymaga ≤20 m.

## 8. Macierz anty-chaos

| Mechanizm | Wartość | Źródło |
| --- | --- | --- |
| Tick staged (decyzyjny) | MCM 20-160 s, krok 10 s (dom. 30 s) | `MCM_AR_TickInterval` / `GetTickIntervalSeconds`; czytany raz przy `AddTimer` - zmiana = reload sesji |
| Tick ambient | 10 s (stały) | Core InitCore |
| Idle-suspend próg | 50 s bezruchu gracza | UpdateIdleSuspend (~l.438) |
| Idle joby | max 2/tick; deadline spaceru 6-12 s; poseDelay 0-10 s | MCM_AR_IdleJob |
| Idle wake | ruch >1.5 m od kotwicy / unsafe | WakeIdleJobs (~l.254) |
| Lock staged (1 naraz) | `interactionBusy` | Core l.150, Begin/End l.587/627 |
| Watchdog locka | >300 s → wymuszone zwolnienie | Core l.600 |
| Cooldown post-staged | 90 s | `lastStagedTime` Core l.651 |
| Cooldown per-NPC | suwak MCM 60-1200 s (dom. 720) | `GetInitiativeCooldown` |
| Cooldown per-akcja | `cooldownSeconds` (300-3600 s) | pole akcji |
| Backoff po odmowie | 300 → 900 → 1800 s | `MarkRejected` Interaction l.83 |
| Bark globalny | 90 s | `GetBarkCooldownRemaining` Core l.908 |
| Powitanie po absencji | gap>60 s, dist<10 m, cd 300 s/NPC | ProcessAmbient l.990-1037 |
| Prompt consent | min 20 s okno (clamp w ShowConsentPrompt); odjście >12 m = odmowa | ShowConsentPrompt l.467 |
| Podejście | timeout 8 s; abort >25 m / walka | WaitForApproach l.331 |
| WaitForSceneEnd | 60 s (dialog) / 90 s (intymna) | Interaction l.574, l.887 |
| Notifier naughty | 30 m in / 40 m out (histereza) | ProcessTick l.780-795 |
| Limit na tick | 1 staged, 1 bark, 1 powitanie | pętle |

## 9. Rejestr akcji (113 klas: 50 w Main + 63 w DLC)

Repertuar akcji moda obejmuje łącznie 113 zarejestrowanych klas akcji, podzielonych logicznie między moduł podstawowy i dodatek:

- **`MCM_RomanceActions_Main.ws` (50 akcji):** Yennefer (10), Triss (10), Keira (8), Shani (7), Rosa var Attre (3), Tomira (3), Ciri (3) oraz akcje pogodowe, obozowe i generyczne T1 (6).
- **`MCM_RomanceActions_DLC.ws` (63 akcje):** Anna Henrietta (6), Vivienne (6), Cerys (7), Syanna (5), Philippa (5), Ves (5), Salma (5), Priscilla (5), Edna var Attre (5), Fringilla Vigo (5), Margarita Laux-Antille (5), Orianna (4) oraz ich dedykowane prośby o trunek.

### Potok pocałunków i uścisków (per-NPC sceny `ar_*`)

Wszystkie akcje pocałunku T3 wywołują `PlayKissScene(npc)` (a `ciri_hug` → `PlayHugScene(npc)`), które przez `AutonomousScenePath` + `PlayScene` odtwarzają nasze własne sceny `ar_*.w2scene` z wyciętym `PChoice` — bez koła dialogowego. Akcje korzystające z tych scen mają flagę `usesAutonomousKiss`/`usesAutonomousHug`: gdy NPC nie ma wpisu w `AutonomousScenePath`, akcja zostaje odfiltrowana w ewaluacji (`blocked: no_scene` w `ar_eval`) zanim wyświetli się prompt zgody — prompt nigdy nie prowadzi w próżnię. Po zakończeniu sceny uruchamia się spersonalizowany po-pocałunkowy bark w marszu (`MCM_AR_AfterglowBark`). Sceny dialogowe `*FollowWithKiss.w2scene` należą wyłącznie do menu MCME (DLC `DLCmod_spawn_companions`).

### Animacje biesiadne (`PlayDrinkingAnimation`)

W klasie bazowej `MCM_RomanceInteraction` wprowadzono latentną funkcję `PlayDrinkingAnimation(npc)`. Gdy towarzyszka poprosi o wino, a gracz zaakceptuje propozycję klawiszem [C], postać odtwarza animację wznoszenia toastu i picia (`woman_wine_tasting` dla modeli kobiecych, `man_work_drinking` dla wariantu uniwersalnego), wzbogaconą o podziękowanie głosowe i napis na ekranie. Ta sama animacja zasila akcje tawerniane `*_tavern_wine` oraz `*_tavern_drink`.

Wspólne bramki kwalifikacji (bazowa metoda `GetBlockReason`):
cooldown akcji -> backoff po odmowie -> `minAffinity` (pomijane w trybie ForceRomance) -> sprawdzanie rywalek dla T2+ przy włączonej zazdrości -> dystans <=15 m -> `GetExtraBlockReason` w klasach pochodnych.

| Postać (nam) | Przykładowe akcje | Zakres Tierów | Główne bramki / mechanika |
| --- | --- | --- | --- |
| yennefer | yen_oneliner_flirt, yen_postcombat_care, yen_campfire_evening, yen_night_invitation, yen_intimate_invite, yen_jealousy_snark, yen_tavern_wine, yen_gift | T1 - T4 | Noc, ognisko, karczma, Corvo Bianco, rany po walce (leczenie 20% max HP), zazdrość wobec Triss |
| triss | triss_oneliner_flirt, triss_postcombat_hug, triss_campfire_warmth, triss_night_whisper, triss_kiss_invite, triss_intimate_invite, triss_jealousy_snark, triss_tavern_drink, triss_gift | T1 - T4 | Ognisko, nocne szepty, czuły uścisk po walce (leczenie 20% max HP), zazdrość wobec Yen |
| keira_metz | keira_oneliner_flirt, keira_postcombat_heal, keira_campfire_witch, keira_night_proposal, keira_intimate_invite, keira_tavern_drink, keira_gift | T1 - T4 | Znak Quen po walce (leczenie 25% max HP), nocne zaproszenie, NaughtyPoint |
| shani | shani_oneliner_flirt, shani_postcombat_medic, shani_night_relax, shani_intimate_invite, shani_tavern_drink, shani_gift | T1 - T4 | Opatrywanie ran po walce (leczenie 25% max HP), relaks wieczorny, NaughtyPoint kliniki |
| cirilla | ciri_oneliner_family, ciri_postcombat_protect, ciri_campfire_tales, ciri_night_stars, ciri_hug, ciri_gift, ciri_kiss†, ciri_intimate_invite† | T1 - T3 (T4 opt-in) | Domyślnie więź rodzinna (hug); †akcje T3 kiss/T4 tylko w trybie `MCM_AR_CiriMode`=Adult — w Lore-Friendly `AutonomousScenePath` zwraca "" (no_scene), a intimate_invite odpada na `lore_mode` |
| anna_henrietta | anarietta_oneliner_flirt, anarietta_postcombat_pride, anarietta_intimate_invite, anarietta_tavern_drink, anarietta_gift | T1, T2, T4 | Pałac Beauclair, duma po walce, wino z Toussaint; brak kiss (noble rig) |
| sq701_vivienne | vivienne_oneliner_flirt, vivienne_campfire_mystery, vivienne_intimate_invite, vivienne_tavern_drink, vivienne_gift | T1, T2, T4 | Ognisko w dziczy, tajemnica klątwy wilgi; brak kiss (noble rig) |
| becca (Cerys) | cerys_oneliner_flirt, cerys_postcombat_skellige, cerys_night_invitation, cerys_intimate_invite, cerys_tavern_drink, cerys_gift | T1 - T4 | Skelligijska duma po walce, biesiadowanie w karczmie, NaughtyPoint Kaer Trolde |
| syanna | syanna_oneliner_cynic, syanna_postcombat_nod, syanna_kiss, syanna_intimate_invite, syanna_gift | T1 - T4 | Cyniczne docinki, bezpośredni pocałunek, NaughtyPoint Krainy Tysiąca Baśni |
| philippa_eilhart | philippa_oneliner_sharp, philippa_postcombat_scorn, philippa_kiss, philippa_intimate_invite, philippa_gift | T1 - T4 | Wyniosłe spojrzenie loży, demonstracja siły po walce, pocałunek (scena `ar_philippa_kiss`) |
| ves | ves_oneliner_soldier, ves_postcombat_respect, ves_kiss, ves_intimate_invite, ves_gift | T1 - T4 | Żołnierski szacunek po starciu, pocałunek (scena `ar_ves_kiss`) |
| mh303_succbus_v2 (Salma) | salma_oneliner_allure, salma_postcombat_touch, salma_kiss, salma_intimate_invite, salma_gift | T1 - T4 | Sukkubia aura, zmysłowy dotyk po walce, pocałunek (scena `ar_salma_kiss`) |
| pryscilla, edna, fringilla, margarita | dedykowane barki T1, gesty T2, `*_kiss`, `*_intimate_invite`, picie wina [C] | T1 - T4 | Dedykowane kwestie dźwiękowe i tekstowe, pocałunek (sceny `ar_*_kiss`), zaproszenie intymne (`naughty\*` cutscene), animacja picia wina |
| orianna | dedykowane barki T1, gesty T2, orianna_intimate_invite, picie wina [C] | T1, T2, T4 | Brak akcji kiss (noble rig); top tier to `naughty\oriana` cutscene — jak upstream (opcja kiss → sex scene) |

\* Gate `no_scene` (`usesAutonomousKiss`/`usesAutonomousHug` w `GetBlockReason`) pozostaje aktywny jako bezpiecznik: akcja scenowa bez wpisu w `AutonomousScenePath` jest odfiltrowywana przed promptem zgody. Jedyny projektowy wyjątek `no_scene`: `ciri_kiss` w trybie Lore-Friendly (patrz wiersz cirilla). Noble-trio (Anna/Vivienne/Orianna) nie ma już akcji kiss w rejestrze — rig `noble_woman_base` bez banku `woman_dialog`, brak animacji kiss (patrz sekcja scen `ar_*`).
| | triss_jealousy_snark | T1 | 0 | 480 | 9 | jealousy ON && Yen w drużynie |
| keira_metz | keira_oneliner_flirt | T1 | 0 | 320 | 10 | !noc |
| | keira_postcombat_heal | T2 | 10 | 900 | 9 | HP≤50%, walka<300 s; `cast_sign_quen_idle`; heal 25% |
| | keira_campfire_witch | T1 | 0 | 600 | 7 | campfire (sam bark) |
| | keira_night_proposal | T3 | 50 | 1800 | 5 | noc → kiss (scena ar_*) |
| | keira_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m + scena |
| shani | shani_oneliner_flirt | T1 | 0 | 300 | 10 | !noc |
| | shani_postcombat_medic | T2 | 10 | 900 | 9 | HP≤55%, walka<300 s; `woman_tend_wounds_idle`; heal 25% |
| | shani_night_relax | T3 | 50 | 1800 | 5 | noc → kiss (scena ar_*) |
| | shani_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m + scena |
| anna_henrietta | anarietta_oneliner_flirt | T1 | 0 | 350 | 10 | !noc |
| | anarietta_postcombat_pride | T2 | 30 | 600 | 8 | HP≤60%, walka<300 s |
| | anarietta_night_royal | T3 | 60 | 2400 | 4 | noc → kiss (`ar_anna_kiss`) — **`no_scene`**, noble rig |
| | anarietta_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m; scena manualna `naughty\anarietta` |
| sq701_vivienne | vivienne_oneliner_flirt | T1 | 0 | 360 | 10 | !noc |
| | vivienne_campfire_mystery | T2 | 20 | 900 | 7 | campfire |
| | vivienne_night_invitation | T3 | 60 | 2400 | 4 | noc → kiss (`ar_vivienne_kiss`) — **`no_scene`**, noble rig |
| | vivienne_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m; manualna `naughty\vivienne` |
| becca (Cerys) | cerys_oneliner_flirt | T1 | 0 | 300 | 10 | !noc |
| | cerys_postcombat_skellige | T2 | 20 | 600 | 8 | HP≤60%, walka<300 s |
| | cerys_night_invitation | T3 | 60 | 2400 | 4 | noc → kiss (scena ar_*) |
| | cerys_intimate_invite | T4 | 80 | 3600 | 3 | NaughtyPoint≤20m; `PreNaughtyWith` (registered) |

Akcje typu T3 z `RequiresPlayerConsent=false`: zamiast promptu - `WaitForApproach`
(propozycja sama się „realizuje" gdy gracz stoi w miejscu).

**Gift-request (11 akcji, RTT_Prompt)** - `MCM_AR_<npc>_GiftRequest` dla
yen/triss/keira/shani (Actions_Main) + anarietta/vivienne/cerys/philippa/syanna/
salma/ves (Actions_DLC). Wspólne pole bazowe: `minAffinity=20`, `cd=3600 s`,
`waga=2`. Gate `GetExtraBlockReason`: `no_gift` gdy brak trunku w EQ,
`not_relaxed` poza kontekstem relaksu (tawerna / Corvo / ognisko <6 m /
idle-suspend >0). Wybór trunku wg preferencji per NPC; sukces:
`RemoveItemByName` + FactsAdd +3 affinity + bark podziękowania
(`thanksLineKey`/`thanksLineId`).

## 10. Silnik zażyłości (3 filary)

`MCM_RomanceAffinityResolver.GetAffinity` (Affinity l.194-197):

```ws
total = (float)(base) + ((float)(earned) * config.GetAffinityMultiplier());
```

- **Filar 1 - `base`:** fakty fabularne z questów (tabela w `GetBaseStoryAffinity` l.221). Baza jest stała i **nie** jest skalowana przez mnożnik.
- **Filar 2 - `earned`:** fakty silnikowe zdobywane w trakcie rozgrywki (`FactsQuerySum("mcme_ar_" + npcName + "_affinity")`; +1 za udaną akcję, +3 za prezent).
- **Filar 3 - `multiplier`:** `GetAffinityMultiplier` (suwak w menu MCM skaluje wyłącznie punkty zarobione `earned`).
- **Tryb Sandbox:** `ForceRomance` → stałe 200 pkt (zawsze pełna zażyłość).

| NPC | Fakty fabularne (suma pkt) |
| --- | --- |
| yennefer | sq202_yen_girlfriend +50, q208_yen_lover +30, prologue_yen_pleased +10, q201_undress_geralt_sex +15, q401_yen_geralt_fight −20 |
| triss | q309_triss_stayed +50, q309_triss_lover +30, sq301_complimented +10, sq301_necklace_on +10, import_geralt_rescued_triss +10 |
| keira_metz | sq108_keira_romance +50, sq108_keira_to_km +20 |
| shani | q603_shani_romance +50, q603_shani_kiss +20 |
| anna_henrietta | q704_anna_survived +30, q705_syanna_and_anna_survived +20, q701_wine_festival_finished +15 |
| sq701_vivienne | sq701_ritual_success +40, sq701_feather_curse_lifted +30 |
| becca | sq202_cerys_queen +50, q206_berserker_solved +20 |

Bezpieczeństwo save'ów: tylko fakty `mcme_ar_*` + RAM - usunięcie moda = czysty save.

## 11. Mapa API - co mod wywołuje

**MCME Remastered** (`Mods\modMCME_Remastered\content\scripts\`):

| API | Definicja | Użycie w AR |
| --- | --- | --- |
| `class mod_scm` (statemachine) | game\SpawnCompanions.ws l.166 | `mcm.DialogueManager`, `scm.NaughtyManager` |
| `MCM_GetMCM()` | game\mcm\MultiCompanionModEntity.ws l.77 | bezpieczeństwo, AddChat |
| `mod_scm_GetSCM()` | MultiCompanionModEntity.ws l.82 | NaughtyManager |
| `mod_scm_GetSCMEntity()` | l.56 | `mod_scm_delayedDialogue(path,0.05)` (l.43) - scena przez delayedDialogue |
| `mod_scm_GetNPC(nam,ST_Special,…)` | game\mcm\MultiCompanionMod.ws l.35 | check ST_Special przed PreNaughtyWith |
| `enum ST_Special` | game\mcm\MultiCompanionModGlobal.ws l.8 | typ selekcji NPC |
| `MCM_GetAreaName() : EAreaName` | MultiCompanionModGlobal.ws l.12 | Corvo=11 |
| `MCM_DialogueManager.IsBusy/AddChat` | game\mcm\MultiCompanionModDialogueManager.ws l.29/34 | gate + napisy barków |
| `NaughtyManager.PreNaughtyWith/PreDialogue/HideAllExcept/PostNaughty` | game\mcm\MultiCompanionModNaughtyManager.ws l.30/111/48/80 | pipeline intymny |
| `naughtyPoints.GetClosestPoint(r)` | SpawnCompanionsSpecial.ws l.767 | gating 30/20 m |
| `scmcc.PlayAnimSimple(anim,…)` | game\SpawnCompanionsSCMCC.ws l.403 | animy gestów |
| `scmcc.applyNaked/Underwear/NormalAppearance` | SCMCC l.2103-2116 | QoL ubiór |
| `scmcc.StartFollowing/StopFollowing(true)` / `IsFollowing` | SCMCC | suspensja follow (parametr `true` = dontModifyPlayersList!) |
| `scmcc.EnterFriendlyCombat(bool)` / `endFriendlyCombat` | SCMCC l.2015/2055 | sparring (nieużywane jeszcze) |
| `JobManager.getWorker/assignWorker/cancelWorker` | game\mcm\job\MultiCompanionModJobManager.ws l.251/309/292 | worker.forceStop przed sceną |
| `specialData` (MCM_NPCEntry) | - | naked/underwear/defaultAppearance, naughtyScene |
| tagi `GeraltsBFF`, `mod_scm_IsFollowing` | - | selekcja i follow-check |

**Vanilla** (`content\content0\scripts\`):

| API | Źródło | Użycie |
| --- | --- | --- |
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
| `DisplayHudMessage` | CR4Player | HUD |
| `GetWeatherConditionName() : name` | engine\environment.ws l.53 | (nieużywane - kandydat na barki) |
| `W3PlayerWitcher.Meditate()/CanMeditate()`, stany `Meditation`/`MeditationWaiting` | game\player\playerWitcher.ws l.10084+ | (nieużywane - kandydat) |
| `W3WitcherBed` tag `witcherBed`, `GetWasUsed()`, `PEA_GoToSleep` | game\gameplay\interactive\witcherBed.ws l.6 | (nieużywane - kandydat) |
| `thePlayer.OnGwintGameRequested(deck,faction,cards)` → `RequestMenu('DeckBuilder'/'GwintGame')` | game\player\r4Player.ws l.4133 | (nieużywane - kandydat) |

## 12. Kontekst (`MCM_RomanceContext`, BuildContext)

| Pole | Źródło | Użyte przez akcje |
| --- | --- | --- |
| `hourOfDay`, `isNight` (22-4), `isDawn` (6-9) | `theGame.GetGameTime()` | night_* , !noc one-linery |
| `playerHealthRatio` | `GetStat(BCS_Vitality)/GetStatMax` | postcombat_* (progi 50-60%) |
| `areaName` (EAreaName), `isInCorvo` (==11) | `MCM_GetAreaName()` | (rezerwa - sceny Corvo) |
| `isNearCampfire` | tag `campfire`/`CarriesOpenFire` <6 m (bez swiec/lamp) | campfire_* |
| `isInTavern` | fakt `player_in_inn` LUB interior+skan encji ≤18 m/cap200 (`*_inn`, `tavern`, barmaid, `sit_drinking_bench`) | `*_tavern_drink` |
| `isNearNaughtySpot` | NaughtyPoint ≤30 m | notifier + rezerwa |
| `rivalCount`, `hasRivals`, `companionsInParty` | pętla po `IsRomanceNPC` | jealousy, snarki |

Poza kontekstem: `GetSecondsSinceCombat()` (core) dla progów post-combat.

## 13. Konfiguracja MCM (`modMCME_AutonomousRomance.xml`)

Grupa `MCM_AR` → `displayName="Mods.AutonomousRomance"`:

| Var | Typ | Domyślna | Znaczenie |
| --- | --- | --- | --- |
| MCM_AR_Enabled | TOGGLE | 1 | master switch (TryExecute) |
| MCM_AR_CooldownSlider | SLIDER 60-1200 | 720 | cooldown inicjatywy per NPC |
| MCM_AR_AffinityMult | SLIDER 5-50 | 10 | mnożnik earned /10 (0.5-5.0×) |
| MCM_AR_JealousyMode | TOGGLE | 1 | rivalry vs polyamory |
| MCM_AR_ForceRomance | TOGGLE | 0 | sandbox: affinity=200, bez progów |
| MCM_AR_TickInterval | SLIDER 20-160 | 30 | interwał ticku decyzyjnego (krok 10 s; `SLIDER;20;160;14` - 3. param to liczba podziałów) |
| MCM_AR_RequireConsent | TOGGLE | 1 | prompt [C] dla T3 (T4 zawsze) |
| MCM_AR_DebugHud | TOGGLE | 1 | komunikaty [AR] na HUD |

Presety: 0 default, 1 active (300 s), 2 relaxed (1200 s, debug off), 3 sandbox
(60 s, ×5, jealousy off, consent off), 4 disabled. Tick w presetach: 30/20/60/20 s.
⚠️ Gra czyta XML z `bin\config\r4game\user_config_matrix\pc\` w katalogu gry -
ten katalog **nie jest** junctionem; po zmianach w `repo\bin\...` trzeba skopiować
plik ręcznie (albo `scripts\deploy_junctions.ps1`) i zrestartować grę.

## 14. Diagnostyka

Log - dwa kanały:

- **TW3SE (dev):** `MCM_AR_Log` → `bin\x64_dx12\tw3se\out\ar_log.txt` + pipe
  `\\.\pipe\tw3se` (kanał `events`). Zero flag startowych; live-follow:
  `scripts\tw3se_pipe.ps1 -Follow`, jeden klik: `scripts\run_game_dev.bat`,
  exec bez konsoli: `tw3se_pipe.ps1 -Cmd "exec ar_status()"`.

- **Vanilla:** `LogChannel('MCM_AR',…)` → `Documents\The Witcher 3\scriptslog.txt`
  - wymaga startu z `-debugscripts` (`scripts\run_game_debug.bat`); bez flagi
  no-op. **Nigdy `-net`** - zabija zapis do pliku po spawnie gracza.
`DebugScriptsForceFlush=true` w user.settings.

| Exec | Funkcja |
| --- | --- |
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
~15-20 s) - **żelazna zasada przed oddaniem kodu** (`..\..\..\AGENTS.md` §2).

## 15. Twarde ograniczenia platformy (czego gra NIE oferuje)

- **Geralt nie siada na meblach/ogniskach.** Enum `EPlayerExplorationAction`
  (playerTypes.ws l.21-39): Meditation, Examine/Smell/Inspect, Igni/Aard, SetBomb,
  PourPotion, DispelIllusion, GoToSleep - **brak PEA_Sit**. W `input.settings`
  `[Exploration]` istnieją wprawdzie akcje `SitDown`/`SitAndWait`/`KneelDown`
  (na `[E]`), ale to **kontekstowe werby interakcji** - dispatchuje je encja
  z komponentem interakcji (engine/data, zero odwołań w `content0\scripts`),
  nie da się ich wyzwolić skryptowo w dowolnym miejscu. Jedyne skryptowalne
  pozycje siedzące gracza: medytacja (`PEA_Meditation`; przy ognisku
  `MeditateWithIgnite` zapala ogień) i łóżko (`PEA_GoToSleep`).
  ⇒ **Companion MOŻE siadać** (slot animami `*_sit_*`/`high_sitting_*` -
  już wykorzystane w `yen_campfire_evening`/`triss_campfire_warmth`,
  `woman_sit_stump_idle`), ale nigdy Geralt poza medytacją/łóżkiem.

- **`.w2scene` to binarki** - nie da się dodawać opcji do istniejących scen;
  brak introspekcji wyborów (SSceneChoice bez id; TODO l.44). Scen dialogowych
  MCME nie reużywamy - kiss/hug to nasze sceny ar_*; ze scen MCME używane są tylko naughty.

- **Brak `StringToName`** - porównania nazw po stringach.
- **Kolizje companionów wyłączone celowo przez MCME** („duchy", update4Second
  re-wyłącza w NewIdle) - nasze `EnableCharacterCollisions(true)` trwa max ~4 s.
  Powrót kolizji = wrapowanie mechaniki MCME (ryzykowne) - decyzja w TODO.

- **`@wrapMethod` na `event` = bez jawnego typu zwracanego; latent nie w `if`.**
- **Cień priorytetów wrapów** między modami - init tylko przez `InitRemasterSettings`.
- **Voicesety potwierdzone:** `greeting_geralt`, `sleeping`, `coughing`,
  `HastaLaVista` (gracz), `warning`, `About_trophy`, `Misc*`,
  `Weather*` (Raining/Stormy/Windy/Snowy/Hot/Cold/LooksLikeRain/ClearingUp/
  SeaWillStorm), `FasterHorse/SlowerHorse(/Roach)`, `DetectPlaceOfPower`,
  `OnUsingEye`, `monster`, `Input`. Uwaga: dostępność voicesetu **per NPC**
  zależy od jego danych audio - przy braku `PlayVoiceset` pada po cichu
  (weryfikacja w runtime, patrz wzorzec logu w `PlayMimic`).

- **lineId musi być kuratowane** z istniejących kwestii (baza: `archive\dumps\
  scene_and_dialog_ids.md` + audycje `ar_line`).

- **Menu MCM:** max 2-3 poziomy `displayName`; nasze w `[SCMMenuBase]` input.settings
  nie dispatchuje w eksploracji (lekcja consent).

### 15.1 Cicha degradacja assetów (voiceset / anim / lineId) - mechanika i mitigacje

„Pada po cichu" znaczy dosłownie: **brak wyjątku, brak wpisu do logu, NPC po prostu
nic nie robi**. Źródła i to, co można z tym zrobić:

| Wywołanie | Zwrot | Tryb padnięcia | Wykrywalne? |
| --- | --- | --- | --- |
| `npc.PlayVoiceset(p,'name')` | `bool` | brak voicesetu w danych audio tego NPC → `false` | ✅ TAK - sprawdzić zwrot |
| `animComp.PlaySlotAnimationAsync(anim,slot,settings)` (w `scmcc.PlayAnimSimple`) | `bool` | anim nie istnieje w animsecie NPC → `false`, SCMCC ignoruje zwrot | ✅ TAK - możliwa sonda |
| `npc.PlayMimicAnimationAsync(...)` | `bool` | jak wyżej | ✅ TAK |
| `npc.PlayLine(stringId,...)` | `void` | złe/nieistniejące id → cisza | ❌ NIE - tylko audycja `ar_line` + ucho |
| `theGame.GetStorySceneSystem().PlayScene` | - | zła ścieżka → `LoadResource` zwraca `NULL` (kod już sprawdza) | ✅ już obsłużone |

Dlaczego to dotyka roostera: każdy companion ma **własny zestaw audio i animset**.
NPC niehumanoidalne lub o specjalnym szkielecie (Salma = `mh303_succbus_v2`,
sukkubus) niemal na pewno **nie mają** `woman_sit_stump_idle`, `woman_hug_idle`
ani prawdopodobnie `greeting_geralt` - akcje T2 z gestem skończą się „podeszła,
stanęła, odeszła". Humanoidalne DLC-owe NPC (Syanna, Ves, Edna, Fringilla,
Margarita, Orianna, Priscilla) dziedziczą standardowe animsety kobiece -
wysoka szansa, ale do **potwierdzenia per NPC**.

Mitigacje (stan wdrożenia: pkt 1-2 zrobione w W0, kompilacja 0 błędów 07.10):

1. ✅ **`PlayBark` z fallbackiem** - WDROŻONE: `PlayBark` (Interaction ~l.180)
   trzyma zwrot `PlayVoiceset`: `false` → `PlayOneLiner(npc, lineId, lineText)`
   (`PlayLine` + HUD przez `GetLocStringById`, dotychczasowa ścieżka) + log
   `[AR] voiceset missing '<n>' on <npc> - fallback lineId`.

2. ✅ **Sonda animacji** - WDROŻONA: globalna `MCM_AR_ProbeAnim(npc, anim) : bool`
   (Interaction, sekcja helperów na końcu) woła `PlaySlotAnimationAsync`
   bezpośrednio na `CMovingPhysicalAgentComponent` (`NPC_ANIM_SLOT`, przy
   porażce retry `GAMEPLAY_SLOT` - jak `scmcc.PlayAnimSimple`); exec
   `ar_probeanim <npc> <anim>` (Core, obok `ar_line`) wypisuje zwrot przez
   `MCM_AR_Log`. Uwaga interpretacyjna: `false` może też znaczyć „slot
   zajęty" → sondować w stanie idle, ewentualnie dwa podejścia.

3. **Whitelist per NPC** - do wdrożenia po audycjach `ar_probeanim`: flaga/gałąź
   w akcji (NPC bez gestu → wariant bark-only); ewentualnie cache w faktach
   (`mcme_ar_animok_<npc>`) zamiast sondować co tick.

4. **`ar_line` jako pipeline kuratorski** - każdy nowy lineId przechodzi
   audycję na żywym NPC przed wpisem do akcji (PlayLine nie zwraca błędu).

## 16. Roadmapa

### A. Z TODO.md (stan bieżący)

1. ✅ **Stabilizacja bazy** - zamknięte po release (diagnoza przez `ar_status`/
   `ar_eval`/`ar_trigger`/`ar_debug`; retest `triss_intimate` po fixie [C]).

2. ✅ **Done (v2.0):** consent [C] = `MCM_AR_Consent` + `SwordSheathe` (dual listener,
   glyph przez `ReplaceTagsToIcons`); kiss/hug jako per-NPC sceny `ar_*` bez PChoice
   we własnym `blob0.bundle` (§7); fixy consent/gating pre-release.

3. ~~**Do decyzji:** nocny wypełniacz T1~~ → rozstrzygnięte jako luka, wdrożone
   `*_night_filler` ×7 (v1.1). **Pozostało do decyzji:** kolizje-duchy
   (design MCME - wrapować `update4Second`/`NewIdle` czy zostawić).

4. **Ubiór:** Wariant A ✅ (enum `Ubiór:` w `SCMMenuEditCompanion2` + execy).
   Wariant B ⚠️ (backlog) - auto-zmiana przy scenach: `applyNakedAppearance`/`Underwear`
   działają, ale pipeline naughty MCME sam zarządza wyglądem w scenie
   (PostNaughty re-equip) - implementacja tylko dla ścieżki manualnej + restore
   w `EndInteraction`; ryzyko nakładki z `data.appearance` z QoL.

### B. Prezenty (design zatwierdzony - TODO §49-81)

- **C1 (do implementacji):** `MCM_AR_<npc>_GiftRequest extends MCM_RomanceInteraction`
  - RTT_Prompt, minAffinity ~20, cd ~30 min. Gate: `!PlayerCarriesGift()`→`no_gift`.
  Execute: SoftApproach → bark prośby → `ShowConsentPrompt("[C] Podaruj <item>",min 20s)`
  → accept: `RemoveItemByName`+`AddAffinity`+bark podziękowania; reject: EndSoft+
  MarkRejected. Lista itemów zostaje z `ar_gift`; preferencje per NPC
  (np. Cerys→Dwarven spirit, Yen→est_est). Potrzebne: lineId/voiceset prośby i
  podziękowania per NPC. Zakres wg TODO = 11 NPC = Etap 0+1 roostera (§16.C).

- **C2 (backlog):** gracz-inicjowane wręczenie - hint „[C] Podaruj prezent" przy
  zbliżeniu z itemem; watcher w ticku + debounce.

- **Custom VO (odległy backlog):** AI-TTS na krótkie odpowiedzi - koszt pipeline
  .wem→sound.bundle + szara strefa praw głosu. Na teraz: kuratowane lineId.

### C. Roster - pełna mapa companionów romance-capable (cel: pokryć WSZYSTKICH)

Krzyżówka: MCME roster (`MultiCompanionModEntityListData.ws`) × sceny naughty
(`naughty\<npc>\anywhere`) × rejestracja `setNaughtyScene`
(`MultiCompanionModNPCManager.ws` / `SpawnCompanionsSpecial.ws`).
Kolumna „Scena kiss" to assety **wyłącznie MCME** (menu dialogowe DLC) — AR
używa scen ar_* kiss/hug dla zmapowanych NPC (§7; reszta dostaje sceny etapowo - build_ar_bundle.ps1).

| NPC (display) | `nam` w MCME | Scena kiss (MCME) | Scena naughty | `setNaughtyScene` | Stan AR (v2.0) |
| --- | --- | --- | --- | --- | --- |
| Yennefer | `yennefer` | `yenneferFollowWithKiss` | `naughty\yennefer` | ✅ tak | ✅ **10 akcji** |
| Triss | `triss` | `trissFollowWithKiss` | `naughty\triss` | ✅ | ✅ **10** |
| Keira | `keira_metz` | `keiraFollowWithKiss` | `naughty\keira` | ✅ | ✅ **8** |
| Shani | `shani` | `shaniFollowWithKiss` | `naughty\shani` | ✅ | ✅ **7** |
| Cerys | `becca` | `cerysFollowWithKiss` | `naughty\cerys` | ✅ | ✅ **7** |
| Anna Henrietta | `anna_henrietta` | `anariettaFollowWithKiss` (+`NoKiss`) | `naughty\anarietta` (+`_tm`) | ❌ → manual | ✅ **6** (kiss gated `no_scene` — noble rig) |
| Vivienne | `sq701_vivienne` | `vivienneFollowWithKiss` (+`NoKiss`) | `naughty\vivienne` (+`_bird`) | ❌ → manual | ✅ **6** (kiss gated — noble rig) |
| Salma | `mh303_succbus_v2` | `salmaFollowWithKiss` | `naughty\salma` | ❌ → manual | ✅ **5** |
| Philippa | `philippa_eilhart` | `philippaFollowWithKiss` | `naughty\philippa` | ❌ → manual | ✅ **5** |
| Syanna | `syanna` | `syannaFollowWithKiss` | `naughty\syanna` | ✅ tak | ✅ **5** (T1-T4, cloud sex Core BaW) |
| Ves | `ves` | `vesFollowWithKiss` | `naughty\ves` | ❌ → manual | ✅ **5** |
| Ciri | `cirilla` | `ciriFollowWithKiss` **+ `ciriFollowWithHug`** | `naughty\ciri` | ✅ | ✅ **3** (hug + dual-mode `MCM_AR_CiriMode`) |
| Edna var Attre | `edna_var_attre` | `ednaFollowWithKiss` | `naughty\edna` | ❌ → manual | ✅ **5** |
| Fringilla | `fringilla_vigo` | `fringillaFollowWithKiss` | `naughty\fringilla` | ❌ → manual | ✅ **5** |
| Margarita | `margarita` | `margaritaFollowWithKiss` | `naughty\margaritta` ⚠️ literówka w katalogu! | ❌ → manual | ✅ **5** |
| Orianna | `vampire_diva` | `orianaFollowWithKiss` | `naughty\oriana` (+2 wyłączone warianty `__`/`_`) | ❌ → manual | ✅ **4** (kiss gated — noble rig) |
| Priscilla | `pryscilla` | `priscillaFollowWithKiss` | `naughty\priscilla` | ❌ → manual | ✅ **5** |
| Rosa var Attre | `rosa_var_attre` | `rosaFollowWithKiss` (→ `ar_rosa_kiss`) | brak | ❌ | ✅ **3** (T1+gift+kiss) |
| Tomira | `prologue_village_herbalist` | `tomiraFollowWithKiss` (→ `ar_tomira_kiss`) | brak | ❌ | ✅ **3** (T1+gift+kiss) |
| Amrynn | ⚠️ **brak w rosterze** MCME | `amrynnFollowWithKiss` | `naughty\amrynn` | ❌ | ❌ pliki są, companiona nie ma - nieosiągalna bez dodania do rosteru MCME |

Follow-only (scena `*Follow` bez kiss/naughty - poza zakresem romansu, max T1):
`avallach`, `baron`, `dandelion`, `dijkstra`, `eskel`, `hjalmar`, `lambert`,
`letho`, `olgierd`, `regis_terzieff_vampire`, `vernon_roche`, `vesemir`,
`zoltan_chivay` — kandydaci na Bro-Tier (§16.H).
Sceny specjalne: `naughty\lake`, `naughty\yen_skel`, `naughty\triss_yen_trap`.

**Etapy pokrycia — WSZYSTKIE WDROŻONE (v2.0):**

- Etap 0 (7 NPC), Etap 1 (Salma/Philippa/Syanna/Ves), Etap 2 (Ciri, Edna,
  Fringilla, Margarita, Orianna, Priscilla) + Rosa var Attre i Tomira.

- **Razem: 19 NPC romance-capable + 6 akcji generic** (rejestr: 113 klas =
  50 Main + 63 DLC). Pokryta cała dostępna pula; brakują tylko Amrynn
  (nieosiągalna — brak w rosterze MCME) i Yoanna (wymaga rejestracji w MCME).

**Checklist dodania nowego NPC (8 kroków):**

1. `MCM_AR_IsRomanceNPC` - dopisać `nam` (Core l.684).
2. `MCM_AR_GetCompanionDisplayName` - nazwa HUD (Interaction l.1089).
3. `GetBaseStoryAffinity` - fakty fabularne (Affinity l.190) lub 0.
4. `NaughtyScenePath` - mapowanie `nam`→katalog (Interaction l.791);
   ⚠️ `margarita`→`margaritta` (typo MCME), `vampire_diva`→`oriana`,
   `mh303_succbus_v2`→`salma`, `pryscilla`→`priscilla`, `edna_var_attre`→`edna`,
   `fringilla_vigo`→`fringilla`, `philippa_eilhart`→`philippa`, `cirilla`→`ciri`.

5. Kiss/hug: brak kroku - `PlayKissScene`/`PlayHugScene` to uniwersalne
   sceny ar_* (§7): dopisz nam→ścieżkę w `AutonomousScenePath` + wygeneruj scenę przez `scripts\build_ar_bundle.ps1`.

6. Pipeline intymny: `setNaughtyScene` zarejestrowane (syanna, cirilla) →
   `PreNaughtyWith` działa; niezarejestrowane → ścieżka manualna już obsłużona.

7. Barki/animy per §15.1: `PlayVoiceset`/`PlaySlotAnimationAsync` zwracają bool -
   sonda + fallback **wdrożone w W0** (`ar_probeanim`, fallback w `PlayBark`);
   ⚠️ niehumanoidalne szkielety (Salma) → T1/T3/T4 bez gestów.

8. Earned affinity `mcme_ar_<nam>_affinity` + gift C1 - działają automatycznie.

### D. Nowe propozycje - zweryfikowane wobec kodu gry

> Werdykt ✅/⚠️/❌ = **wykonalność sprawdzona w kodzie silnika/MCME**, nie stan
> wdrożenia. Faktycznie wdrożone pozycje są oznaczone „WDROŻONE"; reszta to
> otwarty backlog (priorytetyzacja w §16.H / TODO.md).

| # | Funkcja | Werdykt | Dowód / mechanika | Powierzchnia zmiany | Ryzyko |
| --- | --- | --- | --- | --- | --- |
| C-N1 | **Barki pogodowe** (deszcz/burza/śnieg/upał) | ✅ **WDROŻONE** | `GetWeatherConditionName()`; ctx `isBadWeather` (`WT_Rain`/`WT_Storm`/`WT_Snow`) | `MCM_AR_WeatherBark` (generic T1) | - |
| C-N2 | **Zaproszenie do sparring'u** (T3-style) | ✅ | `scmcc.EnterFriendlyCombat(true)`; koniec: schowanie miecza (MCME `updateFriendlyCombat`) lub `endFriendlyCombat(won)` | nowa akcja Gesture/Prompt: approach→bark→consent→`EnterFriendlyCombat` | NPC od razu hostile→gracz (MCME blokuje znaki/bomby); testowac końcówkę walki |
| C-N3 | **Zaproszenie do gwinta** | ✅(deck do sprawdzenia) | `thePlayer.OnGwintGameRequested(deckName,faction,cards)` → DeckBuilder→GwintGame | akcja Prompt → consent → wywołanie | nazwa talii przeciwnika z definicji gwint - weryfikacja przed kodem |
| C-N4 | **Companion siada przy medytującym Geralcie** | ✅ | stany `Meditation`/`MeditationWaiting` (playerWitcher.ws); animy sit z katalogu jobów (`high_sitting_ground_determined`, `man_work_meditation`, `low_sitting_ground_happy`, `woman_lying_relaxed_on_grass`) | osobny watcher (AmbientTick omija gate Exploration - Meditation≠Exploration!) | wymaga ścieżki „reactive" obok IsSafeToInitiate; animy per-NPC do sprawdzenia |
| C-N5 | **Reakcja na sen (Corvo/łóżka)** | ✅ | `W3WitcherBed` tag `witcherBed` + `GetWasUsed()` + `PEA_GoToSleep` | tick: wykrycie stanu Sleep → bark + ew. anim `woman_sleep_on_bed_*` obok | punktowość tagu (tylko W3WitcherBed) |
| C-N6 | **Bark przy jeździe konnej / starcie** | ✅ **WDROŻONE** | `thePlayer.GetUsedVehicle()` ≠ NULL && `!IsOnBoat()` → ctx `isOnHorse` | `MCM_AR_HorseBark` (generic T1); `MCM_AR_IsSafeForAmbient` dopuszcza stan HorseRiding | - |
| C-N7 | **Bark na łodzi** | ✅ **WDROŻONE** | `thePlayer.IsOnBoat()` → ctx `isOnBoat`; `IsSafeForAmbient` dopuszcza `Sailing`/`BoatPassenger` + kontekst `Boat` (tylko barki T1 - sceny/gesty nadal gated przez `IsSafeToInitiate`) | `MCM_AR_BoatBark` (generic T1) | - |
| C-N8 | **Animacje picia (prezenty & tawerna)** | ✅ **WDROŻONE** | `PlayDrinkingAnimation(npc)` w `MCM_AR_GiftRequest_Base` oraz we wszystkich `*_tavern_drink` akcjach tawernianych z probe animów `woman_wine_tasting`/`man_work_drinking` i fallbackiem | Akcja T2 + Gift Request: uniesienie butelki/kielicha i toast przed podziękowaniem/barkiem | - |
| C-N9 | **Spersonalizowany Afterglow w marszu** | ✅ **WDROŻONE** | `lastSceneOkNpc`/`lastSceneOkTime` w core; `MCM_AR_AfterglowBark` z dynamicznym doborem dedykowanych kwestii `ar_afterglow_walk_*` dla 19 towarzyszek w oknie ≤120 s | Pełna personalizacja dla wszystkich 19 towarzyszek z autentycznym głosem lore | - |
| C-N10 | **Reakcja na joba companiona** (ona gotuje/czyta/cwiczy) | ⚠️ | `JobManager.getWorker(npc)` istnieje | ctx: `npcBusyWithJob`; akcja T1 komentarza | semantyka `getWorker` (aktywny vs przypisany) - doczytać JobWorker |
| C-N11 | **Rozszerzenie roostera** - pełna mapa i etapy w §16.C | ✅ | sceny istnieją dla 17 companionów (`known_scenes.txt` × roster MCME) | checklist 8 kroków w §16.C; nowe klasy np. `Actions_Extra.ws` | kuratowane lineId; `nam`≠alias sceny; typo `margaritta`; Ciri = Hug jako domyślna; Salma niehumanoidalna (§15.1) |
| C-N12 | **Barki „home" / interior** | ✅ **WDROŻONE** | `IsInInterior()` → ctx `isInInterior` | `MCM_AR_InteriorBark` (generic T1) | - |
| C-N13 | **Kąpiel/„bath"** | ⚠️ ograniczone | animy `woman_work_sitting_bath`/`high_sitting_determined_bath` (kat. `naked`) istnieją, ale przypięte do stałych AP (nov_bath_*, viz_chamber_bath); gracz NIE ma mechaniki kąpieli | tylko companion-only scenka przy tych lokalizacjach | kruche wykrywanie (koordynaty); bez udziału Geralta |
| C-N14 | **Taniec razem** | ❌ | brak mechaniki/animów parzystych poza scenami questowymi | - | - |
| C-N15 | **Geralt siada przy ognisku z companionem** | ❌ (jako opisane) | brak `PEA_Sit`; `SitDown`/`SitAndWait` = kontekstowe werby encji (patrz §15); zamiast: C-N4 medytacja | - | - |
| C-N16 | **Nowe sceny `.w2scene`** | ❌ | binarki; brak tooling (REDkit nie wspiera NG .w2scene praktycznie) | - | - |
| C-N17 | **Zmienne tempo/preset barków w MCM** | ✅ **WDROŻONE** | `MCM_AR_BarkPreset` (XML slider 1-3) + `GetBarkPreset()` | gate probabilistyczny w `AmbientTickEntry` przed `TryExecute`: 30%/65%/100% | - |
| C-N18 | **Jealousy: konfrontacja po wyborze rywalki** | ✅ **WDROŻONE** | `MCM_AR_AreRivals` (yen↔triss) + `lastSceneOkNpc/Time` | `MCM_AR_JealousyAftermath` - rywalka mówi, okno ≤300 s, wymaga `ctx.hasRivals` | - |
| C-N19 | **Companion rozsiada się przy ognisku** (evolucja `*_campfire_*`) | ✅ | już częściowo jest: `woman_sit_stump_idle` po approachu; wariant „stay": NPC siada i zostaje, dopóki gracz w promieniu / nie odejdzie od ogniska | akcja T2: approach→sit anim (loop)→bark→follow-resume gdy gracz odejdzie >X m | Geralt nie siada (§15) - scenka jest companion-only; anim per-NPC §15.1 |
| C-N20 | **Idle Autonomy / „companion żyje podczas postoju"** | ✅ | mechanizm istnieje: `animsFinished` gra `info.IdleAnimation` gdy `!IsFollowing()` (SCMCC l.464); design w §16.F | detektor postoju w ticku + suspend/resume follow | ⚠️ verify: czy suspendowany NPC nie jest ciągnięty przez follow-AI |

### E. Plan etapów - od najłatwiejszych do zweryfikowania

> **Stan (po v2.0): ZREALIZOWANY / ZASTĄPIONY.** Etapy W0-W7 domknęły cykl
> v1.0–v2.0 (W0 kompilacja ✅, W1 diagnostyka ✅, W2 drobne akcje ✅, W3 gift C1 ✅,
> W4 roster Etap 1 ✅, W5/W6 w większości wdrożone lub jako otwarte pozycje w §16.H,
> W7 decyzje: kolizje-duchy wciąż otwarte). Tabela poniżej = dokument historyczny
> planu; aktualny backlog wyłącznie w §16.H + TODO.md.

Kryterium: **koszt weryfikacji** (kompilacja → jedna komenda debug → jeden kontekst
w grze → pełne scenariusze → decyzje architektoniczne).

| Etap | Zawartość | Weryfikacja | Zależności |
| --- | --- | --- | --- |
| **W0 - czysto skryptowe** (zero gry) | ✅ komentarze `[E]`→`[C]` w `.ws` (l.665/1085 zostawione - historycznie trafne); ✅ link TODO→ARCHITECTURE (TODO l.3); ✅ **§15.1 mitigacje:** `PlayBark` sprawdza zwrot `PlayVoiceset`→fallback `lineId`→log `voiceset missing`; ✅ helper `MCM_AR_ProbeAnim` (bool z `PlaySlotAnimationAsync`, retry na 2. slocie); ✅ exec `ar_probeanim <npc> <anim>` | `precheck_syntax.ps1` + `test_compile.ps1` - **zdane 07.10 (ExitCode 0)** | - |
| **W1 - jedna sesja `-debugscripts`** (~15 min) | `ar_status` → core żyje? `ar_eval` → lista `blocked:`; `ar_trigger`+`ar_force` → wymuszona akcja na otwartym; `ar_logdump` po tickach → logi sond z W0; `ar_line` audycje kandydatów na lineId giftów; `ar_gift` smoke | HUD + `scriptslog.txt` | W0 (logi sond) |
| **W2 - małe akcje, test = 1 kontekst** | consent remap na niezmapowaną akcję (recepta §6 + test: czy listener dostaje event przy `BlockAction(EIAB_SpecialAttackLight)`); C-N7 łódź; C-N12 interior; C-N9 afterglow; C-N6 koń; C-N19 campfire stay-seated; C-N17 preset barków w MCM; ~~C-N20/I1 idle-suspend~~ ✅ wdrożone 14.10 (§16.F) | wejść w kontekst → obserwacja; `ar_eval` pokazuje gate; idle = „stać i patrzeć" | W0 |
| **W3 - gift C1** (zatwierdzone TODO) | `PlayerCarriesGift()` + `MCM_AR_<npc>_GiftRequest` + preferencje per NPC; lineId prośby/podziękowania z audycji W1 | pełny cykl: prompt→accept (item−1, +aff, thanks) / reject / timeout / `no_gift` w `ar_eval` | W1 (lineIds) |
| **W4 - roster Etap 1** (Salma, Philippa, Syanna, Ves) | checklist §16.C pkt 1-8; **sondy assetów per NPC na początku** (Salma=sukkubus → prawd. bez gestów T2) | `ar_eval` per NPC + live T1→T4 | W0+W1 (sondy) |
| **W5 - nowe ścieżki reaktywne** | C-N4 medytacja-dołączka (kanał obok `IsSafeToInitiate` - Meditation≠Exploration); C-N2 sparring (`EnterFriendlyCombat` + wykrycie końca); C-N5 sen/łóżko; C-N8 picie w tawernie; **C-N20 I2/I3 + enklawy §16.G** (ambient animy własne / `assignWorker` przy AP/schedules) | scenariusz kontekstowy w grze | W1 (+W2 dla I1) |
| **W6 - duże / warunkowe** | C-N3 gwint (research nazw talii w defs **przed** kodem); Ubiór Wariant B (nakładka z pipeline naughty MCME); roster Etap 2 (6 NPC); C-N10 jobs (`getWorker` semantyka) | per-funkcja | W4 |
| **W7 - decyzje / zamknięte** | decyzja kolizje-duchy (wrapować `update4Second`/`NewIdle` vs zostawić); C-N13 kąpiel ⚠️; custom VO backlog; C2; ❌ C-N14 taniec, C-N15 sit-anywhere, C-N16 nowe .w2scene | - | - |

**Rekomendowany start:** W0 → W1 (diagnoza „mod nie reaguje" = TODO priorytet 1)
→ W3 (gift C1, pierwsza nowa mechanika na istniejącym pipeline'ie) → W4.
W2 wciągać równolegle - każda pozycja to ~30-60 min implementacji.

**Otwarte do sprawdzenia przy najbliższej sesji w grze:**

- `shaniFollowWithHug` (rejestracja MCME, SpawnCompanionsSpecial l.492) vs
  `shaniFollowWithKiss` (plik w bundle MCME) - możliwy martwy
  reference po stronie MCME (nasza ścieżka hug = scena `ar_cirilla_hug` bez PChoice, niezależna od oryginału).

- `ar_eval` nocą - ile `blocked:` to zamierzona selekcja, a ile luka w T1
  (decyzja: nocny wypełniacz).

- Dispatch listenera przy zablokowanym EIAB (wymóg dla W2-consent-remap).

### F. Idle Autonomy - „companion żyje podczas postoju" (design wstępny)

> **Stan (14.10): ✅ WDROŻONE.** Własny model `MCM_AR_IdleJob` (npc/spot/heading/
> anim/phase/deadline/poseDelay) - nie opiera się na MCME `IdleAnimation`, tylko
> gra slot-anims przez `PlayIdleSlotAnim` (fallback `low_sitting_ground_leaning_back_bored_idle`).
> Detektor: 50 s bezruchu gracza → `StopFollowing(true)` + spacer do spota → poza.
> Wake: ruch >1.5 m / unsafe. Joby tworzone na ticku decyzyjnym, fazy na ambient 10 s.
> **Fix cyklu życia (14.10):** guard przy tworzeniu (wasInTalkInteraction/scena/busyNpc),
> prune guarded-jobów po deadline, `RemoveIdleJobFor(npc)` z `EndSoft`/`EndInteraction`.
> Bez fixa job utworzony w ticku startu stagingu wisiał wiecznie i blokował nowe.

**Problem:** companion w follow stoi nieruchomo obok gracza w nieskończoność -
`animsFinished` (SCMCC l.464) gra `IdleAnimation` tylko gdy `!IsFollowing()`.
Banter werbalny już działa (`specialNPCDialogues.UpdateDialogues`, tempo =
suwak `MCME_BanterDelay`) - brakuje warstwy fizycznej.

**Detektor postoju (nasz):** w ticku staged - `playerPos` delta < ~1.5 m przez
≥N kolejnych ticków (próg ~45-60 s) + `IsSafeToInitiate` → `idleSince` stempel.
Reset natychmiastowy przy ruchu/walce/dialogu. Koszt: ~0 (dane już w ticku).

```text
gracz bezczynny ≥60 s (Exploration, safe)
  └─ per companion (tag following, <12 m):
       I1: StopFollowing(true)  → MCME sam gra zarejestrowany IdleAnimation
           (Yen: leżak, Triss: siedzi dumnie, Keira: siedzi…)
       I2: fallback gdy brak HasIdleAnimation → nasz mini-registry ambient anim
           (warm hands przy campfire / sit ground / look around - sonda §15.1)
       I3: jeśli AP jobów w zasięgu (KM/Corvo/karczma) → assignWorker →
           krzesło/ogień/karty/jedzenie  [opcjonalnie, osobny etap]
  └─ wyjście: gracz ruszył >8-10 m od kotwicy / walka / dialog /
       akcja staged na tym NPC → StartFollowing + restore
```

**Reguły współistnienia z akcjami AR:** flaga `arIdleFree` per NPC; akcje staged
**mogą przerywać idle** (companion przerywa siedzenie, żeby podejść do Geralta -
pożądane narracyjnie); `EndInteraction` przywraca stan idle jeśli gracz wciąż
stoi. Watchdog locka działa bez zmian.

**Do zweryfikowania przed kodem:**

- czy `StopFollowing(true)` na trwalszą porę nie jest odwracany przez follow-AI
  MCME (`update4Second`/`NewIdle` mogą re-collować `StartFollowing`?),

- czy `IsFollowing()` (flaga scmcc) vs tag `mod_scm_IsFollowing` - nasza
  eligibility patrzy na tag → follow flag może mrugać bez wpływu na rejestr,

- dystans „anchor" i cooldown re-entry (histereza jak w naughty notifier),
- Vanillove `VMS`/łódź/koń - idle mode wyłączony poza czystym Exploration.

**Proponowany start (W2):** tylko I1 = detektor + suspend + resume. Jeśli MCME
samo odpala idle animy - feature praktycznie „darmowy". I2/I3 = osobne etapy.

### G. „Enklawy" - wykrywanie bezpiecznych rejonów z aktywnościami (design wstępny)

Cel: w zamkniętych/domowych rejonach (Kaer Morhen, Corvo Bianco, Vizima,
karczmy, dom Triss…) companion ma nie tylko „nie-stać", ale **mieć co robić**.

**Warstwy detekcji rejonu (wszystkie realne):**

| Warstwa | API | Ziarnistość |
| --- | --- | --- |
| Region/świat | `MCM_GetAreaName()` → `EAreaName` (Novigrad-land, Skellige, **Kaer Morhen**, White Orchard, **Wyzima**, Toussaint=11…) | cały świat |
| Wnętrze | `thePlayer.IsInInterior()` (+NPC) | budynek y/n |
| Tawerna | fakt `player_in_inn` LUB fallback interior+skan encji ≤18 m/cap200 (warstwy `*_inn`, `tavern`, karczmarze, `sit_drinking_bench`) | tak/nie |
| Punkty zainteresowań | `JobManager.actionPoints` - **inicjowane tylko dla bieżącego regionu**; pozycje światowe + `activationRadius` + `isOutside` | konkretne „strefy robienia rzeczy" |
| Nazwane enklawy | własna tabela anchorów (jak `naughtyPoints` MCME: Vector+radius) | np. „sala KM", „dom Corvo", „komnata Vizima" |

**Zasoby aktywności (zweryfikowane - `MultiCompanionModJobManager.ws`):**
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

**Schedules per NPC** (`newSchedule` + `.addJob(job, sekundy_od, sekundy_do)` +
`.land(region)`) - istnieją m.in. dla: `yennefer`, `triss`, `keira`, `shani`,
`cerys`, `ciri`, `vivienne`, `anarietta_1/2`, `syanna_1/2/3`, `salma`,
`philippa`, `priscilla`, `ves`, `margarita`, `orianna` + eskel/lambert/witchers…
Np. Yen w KM: sen 22-8 → jedzenie 8-9 → `sorceresses_misc` 9-15 → jedzenie 15-16
→ misc 16-22.

**Worker mechanics (`MCM_Worker`):** `assignWorker(actor, workerName, schedule)`
(JobManager l.251) → stany Waiting/Walking/Working/Hidden/Paused z pathfindingiem
(`MCM_WorldPath` z CSV per region); **auto-pauza** gdy gracz >~150 m
(`shouldPause` l.312) lub input-context ≠ Exploration (`continueInPauseMode`
l.295); `softStop`/`forceStop`/`cancelWorker(ByActor)` do czystego wyjścia.
`canActorDoWork` (l.207) = żywy + brak celu walki - **nie sprawdza follow** →
worker na podążającym NPC wymaga naszego `StopFollowing` (inaczej walka AI
o locomocję).

**Design enklawy:**

```text
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
  (pauza MCME to ~150 m - dla naszego leash potrzebny własny radius ~15-25 m),

- nakładanie okien czasowych schedule'a z rzeczywistą godziną,
- `actionPoints` są `private` w JobManager → potrzebny `@addMethod`-
  getter `MCM_AR_GetNearestAP(pos,r)` albo iteracja (wrapy na private
  metodach są OK - dodajemy metodę, nie nadpisujemy),

- proste enklawy bez AP (losowe obozowiska) → tylko I1/I2.

### H. Backlog otwarty (przeniesione z TODO.md przy czyszczeniu 2026-10-15)

**Naprawy / usprawnienia bieżącej bazy:**

- **Combat-rescue heal** - towarzyszka leczy Geralta W TRAKCIE walki. Wymaga osobnego kanału: `IsSafeToInitiate` blokuje combat, `WaitForApproach` abortuje na `IsInCombat`. Wariant fire-and-forget (bez approach/staging/consentu): bark + `cast_sign_quen_idle` z miejsca + `GainStat`. Bramki: affinity ≥80, hp <30%, raz na walkę / ~20 min cd. Ryzyko: balans + NPC w combat jest „duchem" bez AI walki.
- **Affinity-weighted wybór NPC** - wagi są per-NPC (`TryExecute` filtruje `targetNpc`), wybór między NPC = `ShuffleCompanions` + per-NPC cd 12 min. Warianty: (a) twardy sort po affinity - ODRZUCONY (dominacja ~80%, zabija autonomię); (b) ważony shuffle (szansa ~ affinity); (c) skrócenie initiative cooldown z affinity (najbezpieczniejsze).
- **Prawdziwe siadanie przy ognisku** - seat-entity/prop snap albo ground-sit anim; model Keiry zostaje jako fallback. Idle-suspend już udowadnia `low_sitting_ground_*` w praktyce; wariant „stay seated" pokrywa C-N19.
- ~~**`triss_garden_kiss` → rename `triss_kiss_invite`**~~ ✅ WDROŻONE (v1.1) - MCME nie posiada sceny „ogrodowej"; akcja to generyczny kiss-invite Triss. Gate na Corvo ODRZUCONY. Prawdziwy „garden kiss" pozostaje motywem do ewentualnej sceny dedykowanej.
- ~~**Płynny pocałunek v2.0**~~ → WDROŻONE v2.0 (2026-10) - per-NPC sceny `ar_*.w2scene` z wyciętym PChoice we własnym bundle. Wcześniejsza próba slot-anims upadła - tracki `determined_gesture_*` nie są gameplay-animami (sondy live: false na wszystkich slotach).
- ~~**Auto-pick/auto-EXIT**~~ **USUNIĘTE 2026-10** - martwy kod (`arAutoPick`/`MCM_AR_OnDialogChoices`/wrapy `CR4HudModuleDialog`) wycięty; nieimmersyjny wybór z menu zastąpiony scenami ar_* wyżej. Oryginalny bundle MCME przywrócony do `DLCmod_spawn_companions` (menu MCME znów działa).
- **`_start/_end` w idle-suspend** - joby wchodzą od razu w idle-anim (skok w pozycję). Dodać opcjonalne pola `*_start` (wejście) / `_end` (wyjście) per NPC/spot jak vanilla sit-loopy + `animPhase` w `MCM_AR_IdleJob`. Wymaga audytu anim w w2anims (`ar_probeanim`).
- ~~**Nocny filler T1**~~ ✅ WDROŻONE (2026-10) - `*_night_filler` ×7 z gatem `isNight`; decyzja §16.A rozstrzygnięta: nocna cisza była luką, nie feature.
- ~~**Tavern banter dla pozostałych**~~ ✅ WDROŻONE (2026-10) - `*_tavern_drink` ×6 (Triss/Keira/Shani/Anarietta/Vivienne/Cerys), claim „tavern chatter" może wrócić do opisu Nexus.

**Duże funkcje (dawniej „Roadmap v1.1"):**

- ~~**`MCM_AR_SceneExists(path): bool`**~~ ✅ WDROŻONE (2026-10) - helper w `MCM_RomanceInteraction.ws` + `ResolveIntimateScenePath` (z gałęzią `specialData.naughtyScene` → fallback `NaughtyScenePath`) + cache `path→bool` w core (wymóg: `GetExtraBlockReason` odpala co tick) + gate `no_dlc_scene` we wszystkich 7 klasach T4. Etap 2 odblokowany.
- ~~**Roster Etap 2**~~ ✅ WDROŻONE v2.0 (tabela §16.C): Edna, Fringilla, Margarita, Orianna, Priscilla + Syanna/Salma/Philippa/Ves (Etap 1) + Rosa/Tomira - T1-T3 + gifty + affinity questowe; T4 warunkowe przez `SceneExists`/`no_dlc_scene`; rygorystyczny audyt Core CDPR (zero zależności od zewnętrznych modów nude).
- **Yoanna** (płatnerz, Kasztel Wrońce) - brak w rosterze MCME; wymaga rejestracji followera w cudzym modzie (poza repo) + nasze AR. Sceny kiss/naughty istnieją w paczkach zewnętrznych.
- ~~**Ciri dual-mode**~~ ✅ WDROŻONE (2026-10, wariant minimalny) - opcja MCM `MCM_AR_CiriMode` (TOGGLE, domyślnie 0 = Lore-Friendly). Lore: więź rodzinna — `ar_cirilla_hug` + ambient; `AutonomousScenePath` zwraca "" dla ciri kiss (gate `no_scene`), `NaughtyScenePath` zwraca "" dla `cirilla`/`ciri`. Adult: `ciri_kiss` (aff 60, `ar_cirilla_kiss` z paczki Spawn Control Girls) + `ciri_intimate_invite` (aff 80, `naughty\ciri\anywhere`); gate intymny siedzi w `GetExtraBlockReason` (`lore_mode`), bo `specialData.naughtyScene` z paczek MCME omija nasze mapowanie sceny. Do zrobienia w pełnym wariancie: dedykowane klasy ambient `MCM_AR_Ciri_OneLinerBanter`, `_PostCombatPride`, `_CampfireBond`, `_GiftRequest` (aktualnie Ciri ma tylko `ciri_hug` + generyczne `ciri_gift`).
- **Bro-Tier** - koncept dla męskich companionów (§16.C traktuje ich jako follow-only, max T1): `MCM_AR_Bro_DrinkTogether_Base` - propozycja toastu w tawernie/ognisku → prompt `[C] Wypij z: <imię>` → konsumpcja mocnego alkoholu z EQ (Dwarven spirit / Temerska żytnia / Alcohest) + anim toastu (`ActionPlaySlotAnimationAsync`) + `thePlayer.AddEffectDefault(EET_Drunkenness, NULL, "Drunk")` (EnableDrunkFx, chwiejny krok) + bark toastu + +3 affinity. Postacie: Zoltan (`zoltan_chivay`) - krasnoludzki humor/pieśń bojowa; Regis (`regis`) - mandragora, opatrunek po walce; Jaskier (`dandelion`) - narzekanie na marsz, panika po walce, wino; Eskel (`eskel`) - wiedźmiński szacunek. T1 docinki w marszu; T2 szacunek po walce. Lokalizacja: prompty/linie/toasty w `en/pl.w3strings.csv` + re-encode.

## 17. Konwencje i jak rozszerzać

- Rejestracja akcji: `RegisterAction(new MCM_AR_<Npc>_<Akcja> in this)` w wrapie
  `InitDefaultActions` (Main/DLC). Zewnętrzne paczki: własny `@wrapMethod
  (MCM_RomanceActionRegistry) InitDefaultActions` + `RegisterAction`.

- Nowa akcja: dziedzicz `MCM_RomanceInteraction`; ustaw `id/targetNpc/minAffinity/
  cooldownSeconds/triggerType/weight` + treść (`lineId` lub `barkVoiceset`+`lineText`,
  `barkMimic`); gate własny TYLKO w `GetExtraBlockReason` (ar_eval pokaże powód);
  `Execute` latent - na każdej ścieżce `EndSoft`/`EndInteraction`!

- Nowy NPC: `MCM_AR_IsRomanceNPC` (Core l.684) + `MCM_AR_GetCompanionDisplayName`
  (Interaction l.1089) + fakty affinity (Affinity l.190) + ścieżki scen
  (`NaughtyScenePath` l.791) + akcje.

- Przed oddaniem `.ws`: `precheck_syntax.ps1` → `test_compile.ps1` (`..\..\..\AGENTS.md` §2).
- Git: brak commitów bez polecenia użytkownika.

---
*Stan dokumentu: odpowiada kodowi na dzień utworzenia; numeracja linii MCME/vanilla
może dryfować po aktualizacjach modów bazowych - cytowane są też sygnatury.*
