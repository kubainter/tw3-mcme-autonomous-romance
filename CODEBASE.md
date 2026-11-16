# MCME Autonomous Romance - Codebase & Architecture Reference

> **Dokument referencyjny bazy kodu (Codebase Map)** dla deweloperów i agentów AI.
> Stanowi zweryfikowane źródło wiedzy o strukturze plików, mapowaniu logiki 1:1,
> komendach diagnostycznych konsoli, regułach silnika RedEngine 3 / WitcherScript NG
> oraz procedurze rozszerzania moda bez tworzenia regresji.
>
> 📖 **Dokumentacja powiązana i badania architektury:**
> - [`ACTION_DISPATCH_MAP.md`](file:///G:/GOG%20Galaxy/Games/The%20Witcher%203%20Wild%20Hunt%20GOTY/_ModDev/MCME_AutonomousRomance/repo/ACTION_DISPATCH_MAP.md) (w repozytorium) - Szczegółowa mapa dyspozytora akcji, logiki decyzyjnej, bramek kontekstowych i cyklu ticków.
> - `..\archive\research\RESEARCH_SEAMLESS_ROMANCE_PLAYBACK.md` (archiwum, poza repo) - Analiza silnikowego odtwarzania cutscen (TGL Scene Selector vs MCM AR) i odrzucona ścieżka Lua/TW3SE dla pocałunku. **Uwaga: ścieżka z researchu NIE jest obecną architekturą** - v2.0 używa natywnych scen `ar_*.w2scene` bez PChoice (§7 ARCHITECTURE).

---

## 1. Struktura Plików i Mapa Odpowiedzialności (1:1)

Cały kod źródłowy moda znajduje się w:
`_ModDev\MCME_AutonomousRomance\repo\Mods\modMCME_AutonomousRomance\content\scripts\local\romance\`

Folder w grze `Mods\modMCME_AutonomousRomance` to **NTFS Junction** wskazujący na powyższy katalog repozytorium.

```text
modMCME_AutonomousRomance/
├── MCM_RomanceCore.ws         - Boot, 5 timerów (Autonomous/Ambient/Downtime/IdlePhase/AnimPump), Idle-Suspend z przejściami
│    animacyjnymi i manual-slot sync-instances, kanał Downtime (medytacja/sen + partner łóżka), kanał ambient, filtry i execy
├── MCM_RomanceInteraction.ws  - Klasa bazowa akcji, GiftRequest_Base, Dance_Base/DanceRefuse_Base, staging lokomocji,
│    Consent Engine v3, Rejestr
├── MCM_RomanceAffinity.ws     - Config wrapper MCM, resolver zażyłości 3 filarów, ring-bufor MCM_AR_Log
├── MCM_RomanceActions_Main.ws - Repertuar 52 klas: Yen, Triss, Keira, Shani + generyczne T1
│    (pogoda/koń/łódź/interior, afterglow, zazdrość, night-fillery) + Rosa var Attre, Tomira, Ciri (hug + dual-mode kiss/intimate),
│    uniwersalny dyspozytor T4 MCM_AR_Generic_IntimateInvite [w tym Gifty C1 i pocałunki/uściski]
├── MCM_RomanceActions_DLC.ws  - Repertuar 76 klas: Anarietta, Vivienne, Cerys, Syanna (T1-T3, taniec, prezenty),
│    Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita (T1-T3 + Gifty), Orianna (T1-T2 + Gift + Naughty T4)
│    + akcje DANCE (priscilla/cerys/triss/keira/shani/tomira/ciri_dance, philippa/yen/ves/ciri_dance_refuse) + *_tavern_drink/ves_tavern_drink
├── MCM_RomanceQoL.ws          - Flash UI menu ubioru w MCME, pamięć strojów, ar_gift, MCM_AR_FindCompanion
├── MCM_RomanceTw3seDev.ws     - Warstwa TW3SE (importy natywne, pipe IPC, odczyt VK, hot-reload)
└── MCM_RomanceE2EDev.ws       - DEV-ONLY: suita ar_test_e2e + ar_tour_scenes + ar_e2e_rebuild_registry
     (usuwana z paczki przez package_release.ps1)
```

Stub `MCM_RomanceTw3seDev.stub.ws` (zamiennik release bez importów TW3SE) żyje poza `content\scripts`
w `repo\scripts\tw3se\` — do paczki trafia przez `package_release.ps1`. Źródło warstwy dev:
`repo\scripts\tw3se\MCM_RomanceTw3seDev.dev.ws` (kopia robocza = plik w `content\scripts`).

---

### Szczegółowy Rozkład Odpowiedzialności w Skryptach

### 1. `MCM_RomanceCore.ws`

* **Boot i Cykl Życia (L1-165):**
  * Wstrzyknięcie pól do gracza: `@addField(CR4Player) mcm_ar_core`, `mcm_ar_ambient`, `mcm_ar_bootlog`.
  * Punkt startowy: `@wrapMethod(CR4Player) InitRemasterSettings()` (L74) wywołuje `MCM_AR_OnPlayerReady()` (L35). Omija problem cienia priorytetów modów (np. Brothers in Arms).
  * Rejestracja listenerów akcji klawisza zgody: `'MCM_AR_Consent'` (własna akcja moda: C + pad D-pad L/R,
    mapowanie w `input.settings.txt`) oraz legacy `'SwordSheathe'` dla kompatybilności.
  * Uruchomienie timerów silnika w `MCM_AR_InitCore()` (L83): `MCM_AR_AutonomousTick` (L102, interwał MCM `MCM_AR_TickInterval` 20-160s, dom. 30s), `MCM_AR_AmbientTick` (L103, co 10.0s — barki + `UpdateIdleAmbient`), `MCM_AR_DowntimeTick` (L104, co 1.0s — `UpdateDowntimeWatch`), `MCM_AR_IdlePhaseTick` (L105, co 1.0s — `AdvanceIdlePhases`); `MCM_AR_AnimPumpTick` (0.01s — pompa sync-instancji) rejestrowany NA ŻĄDANIE przez `EnsureAnimPump` (L514, sam AddTimer L517) i zdejmowany gdy `arIdleJobs` puste.
* **System Idle-Suspend (W2/I1) + przejścia animacyjne (L185-1680):**
  * Klasa `MCM_AR_IdleJob` (L185): NPC, cel, kąt, animacja, faza lokomocji (`phase`: 0 moving → 1 arrived → 2 posed), `animStart`/`animEnd`/`animPhase` (0 nie zagrano → 1 start-grany → 2 loop → 3 end-grany), `animAt` (deadline fazy), `reissueAt` (re-issue loopa), `isBed`+`bedFloor` (job łóżkowy), `syncInst`/`syncSeq` (manual-slot sync instance).
  * `UpdateIdleSuspend(safe : bool)` (L1287): bada bezruch gracza w promieniu 1.5m przez >50s (`arIdleAnchor`; >6s przy ognisku). Pomija NPC busy w `arAmbientBusy` (`IsAmbientBusy`, licznik `skipAmbient`) - sekwencje dance/drink v2.2.1. Zawiesza follow przez `StopFollowing(true)` (z zachowaniem tagu `mod_scm_IsFollowing`), kieruje NPC na punkt ~1.6m obok gracza. Joby idle-suspend: deadline spaceru 6-12s, `poseDelay` 0-10s, max 2 joby/tick (loteria 70%).
  * **Przejścia animacyjne (v2.1):** `IdleAnimStartFor`/`IdleAnimEndFor` (L1664/L1593) mapują tylko 2 pozy na pary start/end — `woman_work_sitting_on_ground_loop` → `_start`/`_end` i `woman_noble_lying_relaxed_on_grass_loop_01` → `_start`/`_stop`; reszta puli (`IdleAnimPool` L1573, 7 poz) gra od razu loop. Start trwa ~2.5s (`animAt`), potem loop; przy wybudzeniu `WakeIdleJobs` (L326) gra `animEnd` i zwalnia joba ~2.5s później przez `animPhase=3` w `AdvanceIdlePhases` (L546).
  * **Manual-slot sync instances (L385-477):** `StartIdleSyncAnim`/`StopIdleSyncAnim` grają pozy przez `CAnimationManualSlotSyncInstance` w `GAMEPLAY_SLOT` poza kolejką akcji aktora (wzorzec `W3SyncAnimationManager` + worker MCME). Powód: `ActionPlaySlotAnimationAsync` zwraca `false` na wszystkim w stanie gracza `PlayerDialogScene` (medytacja/sen). Pompa per-frame: `PumpIdleAnims` (L521) na `MCM_AR_AnimPumpTick` 0.01s; feet-IK wyłączane na czas sync-instancji; fallback animu `low_sitting_ground_leaning_back_bored_idle` gdy nazwa z puli nie istnieje w animsecie.
  * **Podział zegarów:** tworzenie jobów i próg bezruchu >50s (>6s przy ognisku) w `UpdateIdleSuspend` (tick decyzyjny), progresja faz `moving→posed` i wybudzanie w `UpdateIdleAmbient` (L1197, kanał ambient ~10s), przejścia `_start/_end` w `AdvanceIdlePhases` (1s), pompa animów 0.01s.
  * Wybudzenie i wznowienie follow: natychmiast po ruszeniu gracza >1.5m lub wejściu w stan unsafe (walka, menu, dialog); w trakcie `dtActive` wake-check pomijany (patrz kanał downtime).
* **Kanał Downtime - C-N4 medytacja / C-N5 sen (L580-1142):**
  * `MCM_AR_IsPlayerInDowntime(out kind)` (L580): klasyfikator - `PEA_GoToSleep`→`'ar_dt_bed'`, `PEA_Meditation`→`'ar_dt_meditation'`; stany `Meditation`/`MeditationWaiting` (okno menu zegara / tranzycje) rozstrzyga tagowana encja `witcherBed` (`W3WitcherBed.GetWasUsed()` + dystans <3m: użyte łóżko blisko gracza = sen bez akcji → `false` i tak obsłuży go sticky-session, medytacja na piechotę → `'ar_dt_meditation'`). Patrzy na stan/akcję, NIE na input-context (otwarte menu przestawia kontekst na `EMPTY_CONTEXT` przy stanie nadal `Meditation`) - dzięki temu alchemia i zwykłe menu **nigdy** nie klasyfikują się jako downtime, a czysty IDLE też nie.
  * `UpdateDowntimeWatch()` (L634): edge-detect na **dedykowanym** `MCM_AR_DowntimeTick` (**1s**), nie na AmbientTick. Debounce `dtCount>=2` ticki (~2s) tylko dla medytacji (odfiltruje mikro-medytacje alchemiczne); `ar_dt_bed` wchodzi od razu (akcja `PEA_GoToSleep` jest jednoznaczna). Cooldowny rozdzielone per-kind: `dtCooldownEnd` (medytacja) i `dtBedCooldownEnd` (łóżko) = **60s** po sesji, **300s** przy wyjściu walką. Sticky-session: przy aktywnej sesji stan `!= 'Exploration'` (menu zegara, time-pass) NIE kończy downtime; END dopiero po powrocie do `Exploration` + exit-debounce `dtMiss>=3` ticki. Force-exit tylko na `IsInCombat()` (`IsDialogOrCutscenePlaying` jest TRUE przez całą sesję - nie może być wyjściówką).
  * Pozycjonowanie: `job.spot = DowntimeRingSpotFree(playerPos, npcPos, R)` (L1087; wariant `DowntimeRingSpot` L1074) — pierścień wokół Geralta (medytacja R=1.4, floor przy łóżku R=1.9; każdy NPC trzyma własny bearing). Przy `ar_dt_bed` jeden partner (max affinity z `MCM_AR_GetAffinity().GetAffinity`, eligibility jak w pętli, wykluczone męskie rigi `DowntimeIsMaleRig` L1004) dostaje job `isBed` na wolnej stronie łóżka.
  * Łóżko (WŁASNA tabela, zero referencji do MCME JobManager): `DowntimeBedLookup` (L1091) mapuje pozycję encji `witcherBed` na parę bocznych AP **na podłodze** (Corvo master-bed parter + guest-bed piętro); `DowntimeBedChooseSide` (L1130) bierze stronę dalszą od leżącego Geralta, `DowntimeBedApFree` (L1115) = własny occupancy-check (sfera 0.25m bez CActor). Partner teleportuje się na `bedFloor`/`spot` (ten sam AP na podłodze - MCME też pinuje aktora na AP, bez offsetu Z) i gra sekwencję `woman_sleep_on_bed_lf|rf_start→_loop→_end` przez **sync-instancję** (`syncInst`, GAMEPLAY_SLOT) — slotowe `woman_sleep_on_bed_*` NIE grają przez `PlaySlotAnimationAsync` w `PlayerDialogScene`, dlatego cały kanał poz leci przez `CAnimationManualSlotSyncInstance`. `animStart` rf = `'woman_sleep_on_bed_rf_start'` (zweryfikowane w vanilla `.w2job`: `sleep_bed_r`, `lie_mwdc_sleep_bed_r_jt`; wariant `_strat` z MCME JobManager był literówką). `DowntimeBedDress` (L1184) = underwear przy położeniu, `DowntimeBedUndress` (L1190) = powrót normalnego ubrania przy wybudzeniu - oba honorują `MCM_DisableAppearanceChanging`. Pin per-pump w `PumpIdleAnims` trzyma ją na AP + re-issue loopa co ~30s (wygląda jak wiercenie się we snie). Brak wpisu w tabeli / obie strony zajęte → partner nie wybierany, wszyscy na floor.
  * Reakcje consent-free: wszyscy followers <15 m dostają joby idle z puli `DowntimeAnimFor` (L987; split per-rig: `DowntimeIsMaleRig` → pula `man_work_sleep_ground_*`/`low_sitting_*`; `ar_dt_bed` floor → `woman_noble_lying_*`/`low_sitting_*`/`woman_work_sitting_*`; medytacja → `woman_work_sitting`/`low_sitting_*`/`woman_crouch_loop_3`). **Join-bark usunięty** (decyzja usera - nachodził na początek sesji); `dtBarker` = najbliższy <10 m mówi tylko na krawędzi END → `ar_line_dt_end`/`ar_line_dt_wake` (`DowntimeBark` L942: HUD + `DialogueManager.AddChat` bez voicesetu; konsumuje `lastBarkTime` kanału ambient). Gałąź join (`isJoin`) i jej klucze usunięte jako martwe.
  * Integracja z idle-suspend: pozy downtime żyją w `arIdleJobs` (ta sama maszyna `moving→posed` i `_start/_end`; job łóżkowy niesie `isBed` + `bedFloor`). W trakcie `dtActive`: `UpdateIdleAmbient` pomija wake-check (L1166), `UpdateIdleSuspend` wcześnie returnuje (L1317) - kanał downtime jest właścicielem `arIdleJobs` do końca sesji. Po END edge: normalne wybudzanie ruchem; `ReleaseIdleJob`/`WakeIdleJobs`/`ForceResetRuntimeState` przywracają appearance dla `isBed`.
* **Filtry Bezpieczeństwa i Budowa Kontekstu (L1708-2175):**
  * `MCM_AR_IsSafeToInitiate(out reason)` (L1708): blokuje akcje w walce, dialogach, pływaniu, łodzi, otwartym menu, downtime (medytacja/sen - zamyka okno `PEA_GoToSleep` ze stanem `'Exploration'`, w którym staged/consent strzelałby na unieruchomionym graczu w łóżku) i stanach innych niż `Exploration`.
  * `MCM_AR_IsSafeForAmbient(out reason)` (L1755): łagodniejszy gate dla barków T1 - dopuszcza jazdę konną (`HorseRiding`/`Horse`) i łódź (`Sailing`/`BoatPassenger`/`Boat`), nadal blokuje pływanie, walkę, dialogi/cutsceny i downtime (barki w medytacji/snie trzyma wyłącznie kanał downtime).
  * `lastSceneOkNpc`/`lastSceneOkTime` + `sceneExistsCache` (`path→bool`): stempelek ostatniej udanej sceny T3/T4 (fuel dla afterglow/zazdrości) i cache `MCM_AR_SceneExists`.
  * `BuildContext(companions)`: agreguje czas gry (`isNight`, `isDawn`), stan zdrowia, ognisko (<6m; encja z tagiem `campfire` lub `CarriesOpenFire`/TAG_OPEN_FIRE z wykluczeniem świec/lampek/pochodni po ścieżce - `candle|lantern|torch|chandelier|sconce|candelabr|lamp`), karczmę (`MCM_AR_IsInTavern`: fact `player_in_inn` LUB fallback `IsInInterior` + skan encji ≤18m/cap 200 - tagi `innkeep`/`barkeep`/`barmaid`/`bartender`/`tavern_keeper` albo ścieżka warstwy/szablonu `innkeep|barkeep|barmaid|inn\|inn_|inn.|tavern|drinking_bench`; wysoki cap wymagany, bo geste wnetrza zwracaja 100+ encji w kolejnosci silnikowej), Corvo Bianco, odległość NaughtyPoint oraz obecność rywalek (`rivalCount`).
  * `missingVoicesetNpcs` (`MCM_AR_IsVoicesetMissing`/`MCM_AR_MarkVoicesetMissing`): cache per-NPC po 1. nieudanym `PlayVoiceset` - kolejne barki idą od razu ścieżką lineId/napis bez spamu warningów (Rosa/Tomira nie mają `greeting_geralt`).
* **Maszyny Stanów STAGED i AMBIENT (L2242-2570):**
  * `MCM_AutonomousRomanceCore` (L216): stan `Idle` (L2242) oraz `ProcessingTick` (L2246, `ProcessTick` L2259; interwał `MCM_AR_TickInterval`, domyślnie 30s; pętla STAGED z lockiem `interactionBusy`, watchdogiem 300s i post-staged cooldownem 90s).
  * `MCM_AmbientRomanceChannel` (L2465): stan `Idle` (L2500) oraz `AmbientTick` (L2504, co 10s; pętla AMBIENT dla powitań po rozłące >60s oraz jednolinijkowców T1 + notifier NaughtyPoint + `UpdateIdleAmbient`).
  * Akcje z flagą `isTimeCritical` (`ar_afterglow`, `ar_jealousy_aftermath`) mają pierwszeństwo w kanale ambient: `ProcessAmbient` pomija los presetu gadatliwości, gdy którakolwiek jest eligible (`HasTimeCriticalEligible`), a `TryExecuteTimeCritical` wybiera eligible o najwyższym `weight` i strzela przed ważonym losem (`[AR] ambient(prio) -> ...`). Globalny cooldown barku ~90s i bramki per-NPC nadal obowiązują.
* **Komendy Diagnostyczne Konsoli (29×Core + 4×QoL + 2×Tw3seDev = 35 w paczce; +3 dev-only E2E = 38 łącznie):**
  * Pełna tabela w sekcji 3. `ar_test` (L78) siedzi tuż po boot-sekcji, reszta Core L2711-3694.

### 2. `MCM_RomanceInteraction.ws`

* **Struktury i Enumy (L10-43):**
  * `enum ERomanceTriggerType`: `RTT_OneLiner` (T1 Bark), `RTT_Gesture` (T2 Gest), `RTT_Prompt` (T3 Prompt ze zgodą), `RTT_Scene` (T4 Scena z pocałunkiem/intymna).
  * `class MCM_RomanceContext`: kontener danych środowiskowych przekazywany do bramek akcji
    (m.in. `isNight`, `isInTavern`, `isNearCampfire`, `hasRivals`, `isBadWeather`, `isOnHorse`, `isOnBoat`, `isInInterior`).
* **Klasa Bazowa `MCM_RomanceInteraction` (L43-2118):**
  * Parametry: `id`, `targetNpc`, `minAffinity`, `cooldownSeconds`, `triggerType`, `weight`, `barkMimic`, `lineId`, `lineText`, `lineKey` (klucz w3strings, `lineText` = fallback EN), `barkVoiceset`; klasy gift dodatkowo `thanksLineId`/`thanksLineText`/`thanksLineKey`.
  * Bramki: `CanExecute()` -> `GetBlockReason()` (cooldowny, backoff odrzucenia 300/900/1800s, minAffinity, zazdrość, max odległość 15m) + `GetExtraBlockReason()` w klasach pochodnych.
  * Staging lokomocji:
    * `SoftApproach`: podejście towarzyszki do Geralta (`ActionMoveToNodeAsync`), wyłączenie kolizji, suspensja follow.
    * `WaitForApproach`: timeout 8s, przerwanie przy walce lub odejściu gracza >25m.
    * `HardStage`: zablokowanie ruchu gracza (`thePlayer.BlockAction(EIAB_Movement, 'MCM_AR_interaction')`), obrót twarzą w twarz.
    * `EndSoft` / `EndInteraction`: czyszczenie stanu, odblokowanie gracza, przywrócenie kolizji i wznawianie podążania.
  * Consent Engine v3 `ShowConsentPrompt(text, timeout, npc)` (L863):
    * Komunikat HUD: suffix lokalizowany kluczem `ar_prompt_consent_hint` (EN: `(hold [C] ~1s or tap twice)`). Literalny `[C]` we wszystkich `ar_prompt_*` to **kotwica podmiany** - `StrReplaceAll(..., "[C]", "<<"+consentTag+">>")` + `ReplaceTagsToIcons` zamienia KAZDE wystapienie na glyph realnego bindingu (promptText i hint; `StrReplace` bez All podmienial tylko pierwsze -> bug TIK-010). Nie usuwac `[C]` z CSV!
    * Odejście gracza >12m traktowane jako odmowa.
    * Obsługa Hold (~1.0s) i Double-Tap (<0.7s) oparte na zdarzeniach `OnMCM_AR_ConsentKey`; `nowDown = evHeld` (release) lub `DevKeyDown || evHeld` (dev - unia, pad-hold działa też w devie; wcześniej devVK ignorował eventy i pada). Latch eventowy **per-akcja**: `mcm_ar_consentHeldC`/`mcm_ar_consentHeldS` - syntetyczny `IsReleased` z `Duration,IdleTime=0.3` (pad `SwordSheathe`) nie zabija holda drugiej akcji; uzbrajany przez `pressAt >= tStart`, reset bezwarunkowy przed promptem (też w devVK). `actHeld` tylko do telemetrii. **Okno min. 20s** - `DisplayHudMessage` kolejkuje za linia barku NPC (~4-5s na ekranie); przy 10s prompt renderował się na koniec/po oknie i pressy lądowały po timeoutcie (`awaiting=0` w logach). **Wszystkie pomiary czasu przez `GetEngineTimeAsSeconds() - tStart` - NIE akumulacja `Sleep`**. Licznik tapów = `max(krawędzie VK, fakty eventowe)`; listener deduplikuje to samo fizyczne naciśnięcie odpalające obie zarejestrowane akcje (okno 0.12s).
    * Tekst promptu renderuje glyph realnego bindingu: `<<MCM_AR_Consent>>` + `ReplaceTagsToIcons()`.
    * Pokrycie kontekstów input: `MCM_AR_Consent` zbindowany nie tylko w 5 bazowych kontekstach gameplay (Exploration/Combat/Horse/Boat/Swimming), lecz też w overlay-contextach, które mogą siedzieć na stosie wejścia podczas promptu (`Scene` tylko klawiatura - D-pad nawiguje tam dialogi, `ScriptedAction`, `SCENE_IS_STARTING_HACK`, `JumpClimb`, `Diving`, `ThrowHold`, `ThrowHoldChain`, `LootPopup`, `BoatPassenger`, replacery Ciri). Bez tego binding w aktywnym kontekście nie istnieje → zero zbocz akcji i eventów listenera.
    * Diagnostyka dev (`ar_log.txt`): `consent: ctx=` przy starcie promptu (aktywny `theInput.GetContext()`), sonda `consent probe:` co ~1s (ctx + VK + `GetActionValue` obu akcji + licznik faktu), `consent ev:` na samej górze listenera (każde wywołanie, zanim odpadnie na bramkach - odróżnia "brak eventu" od "event bez press-edge").
  * Odtwarzanie Scen i Integracja MCME (L1216-2110):
    * `PlayKissScene(npc)` / `PlayHugScene(npc)`: rozwiązują ścieżkę przez `AutonomousScenePath(npc, isHug)` i grają naszą scenę `ar_*.w2scene` (per-NPC strip PChoice: Input→sekcja gestu→Output) przez `PlayScene`. Brak mapowania = `false`. **NIGDY nie kieruj akcji kiss/hug na sceny `*FollowWithKiss.w2scene`** - te pliki należą do MCME (zawierają `PChoice` i menu dialogowe) i służą wyłącznie własnemu pipeline MCME.
    * `AutonomousScenePath(npc, isHug)`: mapa `nam`→`dlc\mod_mcme_autonomous_romance\dialogue\ar_*.w2scene` — bundle zawiera 36 scen (23 dialogowe `dialogue\ar_*`, 2 cutscenki, 11 kopii T4 `naughty\*`), z czego mapa zwraca ścieżki dla 16 kiss + hug; `ar_anna/vivienne/orianna_kiss` istnieją w bundle, ale celowo NIE są mapowane → `""` → `no_scene` (ciri kiss dodatkowo gated przez `MCM_AR_CiriMode`: w Lore-Friendly zwraca "" → `no_scene`). **Anna/Vivienne/Orianna celowo zwracają "" i nie mają akcji kiss w rejestrze** — ich `noble_woman_base` rig nie ładuje banku `woman_dialog` i nie istnieje dla niego animacja kiss (w przeciwnym razie T-pose; autor upstream dokumentuje tę samą wadę). Ich `*_intimate_invite` działa, bo `naughty\*` to cutscene-playery, nie scene-anim binding. Zasoby generuje `scripts\build_ar_bundle.ps1` (per-job `Bundle` → ekstrakcja → enum-fix `medium`→`Medium` → strip w JSON → pakowanie własnego `content\blob0.bundle`); sceny dla 12 NPC pochodzą z paczek MCME (Spawn Control Girls, Anarietta & Vivienne plus2, Even More Companions). Aliasy nam: `edna_var_attre`, `prologue_village_herbalist` (Tomira), `mh303_succbus_v2` (Salma), `pryscilla`/`priscilla`, `becca`/`cerys`.
    * `WaitForSceneEnd(npc, timeout)`: latentne oczekiwanie na zakończenie sceny, wczesne zwolnienie ruchu gracza (`UnblockAction(EIAB_Movement)`) po wyjściu z sekwencji animacji. Używane przez pipeline T3 (`PlayScene` pośrednio) i T4 (`PlayIntimateScene`).
    * `PlayIntimateScene(npc)`: pipeline intymny z NaughtyPoints (punkt <=16m w `IsOnNaughtyPoint()`). Obsługuje ścieżkę zarejestrowaną (`PreNaughtyWith`, tylko gdy `path == specialData.naughtyScene`) oraz manualną (`naughty\<npc>\anywhere.w2scene`, w tym kopie T4 w bundle moda).
    * `MCM_AR_SceneExists(path)` (L1585): `LoadResource(path,true)`→`CStoryScene` z cache `path→bool` w core (gate `no_dlc_scene` w klasach T4 - sceny z `dlc_spawn_control_girls` nie zawieszają ewaluacji).
    * `ResolveIntimateScenePath(npc)` (L1610): wspólny resolver ścieżki sceny (priorytet: kopia T4 z bundla moda, potem `specialData.naughtyScene` z paczek MCME/annotation, na końcu fallback `NaughtyScenePath` L1688). `NaughtyScenePath` mapuje `cirilla`/`ciri` → `naughty\ciri` TYLKO w `MCM_AR_CiriMode`=Adult; dodatkowy gate `lore_mode` siedzi w `ciri_intimate_invite` (bo `specialData` omija mapowanie). Kopie T4 z bundla moda (`NaughtyScenePath`, `dlc\mod_mcme_autonomous_romance\naughty\*`) mają pierwszeństwo przed `specialData.naughtyScene` z paczek annotation (SCG: Priscilla, Edna, Orianna, Fringilla, Margarita; AnVi: Philippa, Ves, Salma, Anarietta, Vivienne). Annotation jest tylko fallbackiem, gdy kopia nie istnieje. Cerys nie ma wpisu annotation; jej T4 pochodzi wyłącznie z bundla AnVi i została skopiowana do bundla moda. Kopie idą ścieżką ręczną (NaughtyPoint + AP), a `PreNaughtyWith` zostaje tylko dla `path == specialData.naughtyScene` (MCME core).
  * Pipeline tańca (w klasie bazowej, L505-627):
    * `PlayDrinkingAnimation(npc)` (wrapper ~L681 → `PlayDrinkingAnimationInner` ~L699): przed wywołaniem `RemoveIdleJobFor(npc)` + `MarkAmbientBusy(npc)`, po `ClearAmbientBusy` - latentna animacja picia/toastu (`woman_wine_tasting` / `man_work_drinking`) z fallbackiem dla niestandardowych szkieletów, używana przy akceptacji prezentu [C] oraz w akcjach tawernianych.
    * `GetDanceAnimsForNpc(nam)` (L542): mapowanie `nam`→zestaw tańca: `triss|keira|keira_metz|shani|priscilla|pryscilla`→`"woman_dance"`, `becca|cerys|tomira|prologue_village_herbalist`→`"woman_cheering"`, `cirilla|ciri`→`"woman_dance"` TYLKO w `IsCiriAdultMode()` (ves nie ma mappingu - ma tylko `ves_dance_refuse`) (gate Ciri-mode siedzi tu, nie w klasie); reszta→`""` (gate `no_dance_anim`).
    * `RunDanceSequence(npc, animSet)` (wrapper ~L799 → `RunDanceSequenceInner` ~L818; także `RemoveIdleJobFor`+`Mark/ClearAmbientBusy` jak wyżej): sekwencja `MCM_AR_ProbeAnim`+`Sleep` per krok; `woman_dance` = start + 3×`prostitute_dance_0X` + stop (~15.5s), `woman_cheering` = 4×`cheering_arena_loop`, `ves_sword` = 3×`work_training_sword_*` (niezweryfikowane na rigu Ves - komentarz DANCE_AUDIT; przy braku animów sekwencja zwraca 0 bez T-pose). Zwroty: 0 brak zestawu, 1 zagrana w całości, 2 przerwana (`DanceStepOk` co krok - bail na odjeździe/walce).
  * Klasy tańca (L2280-2328):
    * `MCM_AR_Dance_Base` (L2280): T1 (`RTT_OneLiner`), minAffinity 30, cooldown 600s, weight 16, barkMimic `'flirt'`. Gate: `ctx.isInTavern || (ctx.isNearCampfire && ctx.isNight)` → `no_dance_scene`; pusty `GetDanceAnimsForNpc` → `no_dance_anim`. Execute: `EnableDynamicLookAt` + `PlayBark` + `RunDanceSequence`.
    * `MCM_AR_DanceRefuse_Base` (L2308): T1, minAffinity 30, cooldown 600s, weight 8, barkMimic `'concern'`. Ten sam gate środowiskowy, bez gate'a animów; Execute = tylko bark odmowy (brak tańca).
    * `MCM_AR_TargetMatches(target, npcName)` (L2330): dopasowanie celu z aliasem `priscilla`↔`pryscilla`.
* **Rejestr Akcji `MCM_RomanceActionRegistry` (L2339-2684):**
  * Centralna tablica `actions: array<MCM_RomanceInteraction>`.
  * `TryExecute(npc, player, ctx, out eligCount, optional ambientOnly)`: filtrowanie wg NPC, kanału, sprawdzanie bramek, losowanie ważone (`weight`) i wywołanie `Execute()`.
  * `TryExecuteTimeCritical(npc, player, ctx)` + `HasTimeCriticalEligible(...)`: wariant ambient dla akcji `isTimeCritical` - bez losowania (max `weight`), wołany przed `TryExecute` w pętli ambient; helper używany do ominięcia losu presetu gadatliwości.
* **Wrappery i Zdarzenia Globalne (L2685-2776):**
  * `event OnMCM_AR_ConsentKey(action)`: rejestruje stan naciśnięcia klawisza consent (`'MCM_AR_Consent'` + legacy `'SwordSheathe'`); `FactsAdd` do licznika tapów z deduplikacją 0.12s (te same fizyczne pressy odpalają obie akcje w jednej klatce); latch holda per-akcja (`consentHeldC`/`consentHeldS`) - `IsReleased` jednej akcji nie zeruje trzymania drugiej.
  * `MCM_AR_AreRivals(a, b)`: helper par rywalizujących (yen↔triss) dla konfrontacji zazdrości.
  * `MCM_AR_GetCompanionDisplayName(npc)` (L2696): resolver czytelnych nazw dla HUD.
  * `MCM_AR_ProbeAnim(npc, animName)` (L2753): sonda sprawdzająca obecność animacji slotowej w modelu NPC.
  * `@wrapMethod(CR4HudModuleDialog) OnDialogChoicesSet` i `SendDialogChoicesToUI`: standardowe przekazywanie wyborów (usunięto eksperymentalną blokadę Flash UI, która powodowała soft-lock - sceny są teraz czyste na poziomie grafu CR2W).

### 3. `MCM_RomanceAffinity.ws`

* **`MCM_AR_ConfigWrapper` (L9-146):**
  * Dostęp do `user.settings` (`CInGameConfigWrapper`, sekcja `MCM_AR`).
  * Gettery: `IsEnabled()`, `GetInitiativeCooldown()`, `GetTickIntervalSeconds()` (clamp 20-160s, default 30), `GetAffinityMultiplier()`, `IsJealousyModeOn()`, `IsForceRomanceOn()`, `RequiresPlayerConsent()`, `IsDebugHudOn()`, `GetBarkPreset()` (1=cichy→30% / 2=domyślny→65% / 3=gadatliwy→100% szansy barku ambient), `IsCiriAdultMode()` (`MCM_AR_CiriMode`, domyślnie 0 = Lore-Friendly: tylko hug; 1 = Adult: kiss + intimate dla Ciri).
  * `EnsureMCMDefaults()` (wołane przy tworzeniu `MCM_AR_GetConfig()`): zasiewa `MCM_AR_BarkPreset=2` gdy var nieobecny w `user.settings` - MCM UI pokazuje `0` dla vara nieobecnego w sekcji i ignoruje `defaultValue` z XML dopóki gracz nie dotknie suwaka.
  * UWAGA: XML menu (`bin\config\r4game\user_config_matrix\pc\modMCME_AutonomousRomance.xml`) NIE jest junction-em jak `Mods\` - po każdej zmianie opcji kopiuj go ręcznie do `<gra>\bin\config\...` i zrestartuj grę (menu czyta XML przy starcie).
* **Centralne Logowanie `MCM_AR_Log` (L148-193):**
  * Ring-bufor 60 wpisów w pamięci RAM (`ar_logdump`).
  * Zrzut do `LogChannel('MCM_AR', msg)`.
  * Przekazanie do TW3SE przez `MCM_AR_DevLog(msg)`.
  * Opcjonalne wyświetlanie na HUD (`thePlayer.DisplayHudMessage`).
* **Helpery lokalizacji (L194-226):** `AR_T(key, fallback)` (L194), `AR_ReplToken`, `AR_Fmt` (L214) - patrz sekcja 6.
* **Silnik Zażyłości `MCM_RomanceAffinityResolver` (L227-~430):**
  * **Formuła obliczania:**
    $$\text{Total Affinity} = \text{BaseStory} + (\text{Earned} \times \text{Multiplier})$$
  * Tryb Sandbox (`ForceRomance`): stałe 200 pkt.
  * `GetBaseStoryAffinity(npcName)`: ewaluacja faktów questowych (np. `sq202_yen_girlfriend` +50, `q309_triss_stayed` +50, itd.).
  * `GetEarnedAffinity(npcName)`: odczyt faktów silnikowych `mcme_ar_<npcName>_affinity` (+1 za udaną akcję, +3 za prezent).

### 4. `MCM_RomanceActions_Main.ws` i `MCM_RomanceActions_DLC.ws`

* Łącznie **131 rejestracji** `RegisterAction` w `InitDefaultActions()` (55 w Main + 76 w DLC; zweryfikowane 2026-11-08 po dodaniu wildcard T1-T3). Klasy `*_GiftRequest` dziedziczą po `MCM_AR_GiftRequest_Base` (Interaction.ws: minAff 20, cd 3600s, w 2). T4 dla większości woman_base = wyłącznie `generic_intimate_invite`; dedykowane `*_intimate_invite` mają tylko syanna/anarietta/vivienne/orianna/ciri(Adult).
  * **Yennefer (11):** yen_oneliner_flirt, yen_postcombat_care, yen_campfire_evening, yen_night_invitation†, yen_kiss, yen_jealousy_snark×2, yen_tavern_wine, yen_gift_request, yen_night_filler, yen_dance_refuse.
  * **Triss (10):** triss_oneliner_flirt, triss_postcombat_hug, triss_campfire_warmth, triss_night_whisper†, triss_kiss_invite, triss_jealousy_snark, triss_tavern_drink, triss_gift_request, triss_night_filler, triss_dance.
  * **Keira (9):** keira_oneliner_flirt, keira_postcombat_heal, keira_campfire_witch, keira_night_proposal†, keira_kiss, keira_tavern_drink, keira_gift_request, keira_night_filler, keira_dance.
  * **Shani (7):** shani_oneliner_flirt, shani_postcombat_medic, shani_night_relax†, shani_tavern_drink, shani_gift_request, shani_night_filler, shani_dance.
  * **Anna Henrietta (6):** anarietta_oneliner_flirt, anarietta_postcombat_pride, anarietta_intimate_invite (T4), anarietta_tavern_drink, anarietta_gift_request, anarietta_night_filler. Brak kiss (noble rig).
  * **Vivienne (6):** vivienne_oneliner_flirt, vivienne_campfire_mystery, vivienne_intimate_invite (T4), vivienne_tavern_drink, vivienne_gift_request, vivienne_night_filler. Brak kiss (noble rig).
  * **Cerys (7):** cerys_oneliner_flirt, cerys_postcombat_skellige, cerys_night_invitation†, cerys_tavern_drink, cerys_gift_request, cerys_night_filler, cerys_dance (woman_cheering).
  * **Rosa var Attre (4):** rosa_oneliner_flirt, rosa_kiss, rosa_gift_request, rosa_night_filler.
  * **Tomira (5):** tomira_oneliner_flirt, tomira_kiss, tomira_gift_request, tomira_night_filler, tomira_dance (woman_cheering).
  * **Ciri (6):** ciri_hug (zawsze), ciri_kiss†, ciri_intimate_invite† (T4), ciri_night_filler, ciri_dance†, ciri_dance_refuse - †=tylko Adult Mode.
  * **Syanna (6):** syanna_oneliner_flirt, syanna_postcombat, syanna_kiss, syanna_intimate_invite (T4 cloud sex), syanna_gift_request, syanna_night_filler.
  * **Philippa (6):** philippa_oneliner_flirt, philippa_care (HP+combat gate v2.2.1), philippa_kiss, philippa_gift_request, philippa_night_filler, philippa_dance_refuse.
  * **Ves (7):** ves_oneliner_flirt, ves_campfire, ves_kiss, ves_tavern_drink, ves_gift_request, ves_night_filler, ves_dance_refuse.
  * **Salma (5):** salma_oneliner_flirt, salma_allure (HP+combat gate v2.2.1), salma_kiss, salma_gift_request, salma_night_filler.
  * **Priscilla (6):** priscilla_oneliner_flirt, priscilla_care (HP+combat gate), priscilla_kiss, priscilla_gift_request, priscilla_night_filler, priscilla_dance.
  * **Edna (5):** edna_oneliner_flirt, edna_care (HP+combat gate), edna_kiss, edna_gift_request, edna_night_filler.
  * **Fringilla (5):** fringilla_oneliner_flirt, fringilla_care (HP+combat gate), fringilla_kiss, fringilla_gift_request, fringilla_night_filler.
  * **Margarita (5):** margarita_oneliner_flirt, margarita_care (HP+combat gate), margarita_kiss, margarita_gift_request, margarita_night_filler.
  * **Orianna (5):** orianna_oneliner_flirt, orianna_care (HP+combat gate), orianna_intimate_invite (T4), orianna_gift_request, orianna_night_filler. Brak kiss (noble rig).
  * **Generyczne (`targetNpc=''`):** ar_weather_bark, ar_horse_bark, ar_interior_bark, ar_boat_bark, ar_afterglow, ar_jealousy_aftermath (T1) + **generic_flirt_bark** (T1, rotacja 4 linii, exclusja named + woman_base gate), **generic_care** (T2, HP<60% + combat<300s), **generic_kiss** (T3, usesAutonomousKiss → shared ar_tomira_kiss przez default fallback AutonomousScenePath) + **generic_intimate_invite** (T4). Wszystkie cztery wildcard akcje romantyczne wymagają `IsWomanBaseCompanion` i wykluczają 19 named towarzyszek przez global helper `MCM_AR_IsNamedCompanion` (Main.ws) - brak dublowania dedykowanych akcji i omijania gate Ciri Adult.
  * **`*_night_filler` (v2.2.1: 19 NPC):** wszyscy companioni mają nocną kwestię ambientową (w8, cd 600s, gate isNight).
  * **Dance (T1 ambient, 11 akcji):** tańce priscilla/cerys/triss/keira/shani/tomira/ciri(Adult); odmowy philippa/yen/ves/ciri(Lore). Brama `isInTavern || (isNearCampfire && isNight)`; sekwencje przez wrappery z `RemoveIdleJobFor`+`MarkAmbientBusy` (v2.2.1).

### 5. `MCM_RomanceQoL.ws`

* **Zarządzanie Ubiorem:**
  * `MCM_AR_NPCHasAltLooks(npc)` i `MCM_AR_ApplyOutfit(npc, idx)` (0: normalny, 1: bielizna, 2: nago).
  * `@wrapMethod(SCMCompanionControls) onSpawned()`: autoodtwarzanie zapisanego stroju przy spawnie.
  * `@wrapMethod(SCMMenuEditCompanion2) OnMenuCreated()` i `OnChange()`: wstrzyknięcie enuma ubioru do menu MCME we Flash UI bez ruszania plików `.swf`.
* **Mechanika Prezentów:**
  * `ar_gift` (L250): sprawdza alkohole w ekwipunku (`Est Est`, `Erveluce`, `Beauclair White`, `Mettina Rose`, `Alcohest`, `Dwarven spirit`), usuwa 1 sztukę, dodaje +3 pkt do `mcme_ar_<nam>_affinity`, wyzwala `greeting_geralt` i look-at na Geralta.
* **Resolver celu:** `MCM_AR_NormalizeCompanionName(input)` (L139) + `MCM_AR_FindCompanion(npcStr)` (L165) - wspólny lookup towarzyszki po nazwie dla komend `ar_dress`/`ar_undress`/`ar_naked`/`ar_gift`.

### 6. `MCM_RomanceTw3seDev.ws`

* Warstwa izolacji TW3SE: importuje funkcje natywne (`TW3SE_*`).
* Udostępnia fasadę `MCM_AR_Dev*` (telemetria, logi do pliku, IPC pipe, czytanie klawiatury VK) + exec `ar_devinfo` (L151) i `ar_reload` (L174).
* W paczce wydania zamieniany na stub `MCM_RomanceTw3seDev.stub.ws` (identyczne sygnatury publiczne w tym oba exec jako no-op), dzięki czemu mod działa u graczy bez Script Extendera.

### 7. `MCM_RomanceE2EDev.ws` (DEV-ONLY)

* Nie trafia do paczki release - `package_release.ps1` usuwa plik ze stagingu.
* `ar_e2e_rebuild_registry` (L919) - rebuild rejestru dla testów.
* Suita E2E `ar_test_e2e` (L933): ~91 checków + ~24 skipów, sterowana zewnętrznym runnerem `scripts\test_e2e.ps1` przez pipe TW3SE; m.in. floor rejestru `n >= 106`, dry-run bramek, tabela scen `ar_*`, przypadki dance (`ciri_dance` oczekiwany jako missing).
* `ar_tour_scenes` (L1119) - tour po scenach postaci.

---

## 2. Geometria i Histereza NaughtyPoint

Sceny intymne Tier 4 (`RTT_Scene`) korzystają z NaughtyPoints zarejestrowanych przez MCME. Obowiązuje ścisła 4-stopniowa histereza promieni:

| Promień | Funkcja / Miejsce w kodzie | Rola |
| --- | --- | --- |
| **16.0m** | `MCM_RomanceInteraction.ws#L2008` (`IsOnNaughtyPoint`) | **Twarda bramka kwalifikacji:** akcja T4 kwalifikuje się do odpalenia tylko w tej odległości od punktu intymnego. |
| **20.0m** | `MCM_RomanceInteraction.ws#L2179` (`PlayIntimateScene`) | **Check defensywny:** weryfikacja tuż przed startem sceny, czy gracz nie odszedł za daleko. |
| **30.0m** | `MCM_RomanceCore.ws#L1917` | **Strefa wejścia:** jednorazowe powiadomienie na HUD o dostępności intymnego miejsca. |
| **40.0m** | `MCM_RomanceCore.ws#L2462` | **Reset histerezy:** odejście na ten dystans resetuje flagę powiadomienia HUD. |

---

## 3. Kompletny Indeks Konsoli Debugującej (38 komend `exec` w źródłach; 35 trafiają do paczki, 3 dev-only z `MCM_RomanceE2EDev.ws` są usuwane ze stagingu)

| `ar_unhide()` | `Core.ws:L2889` | Awaryjne odkrycie towarzyszek zasłoniętych po scenie (`SetHideInGame(false)` + `NaughtyManager.ShowAllExcept`) — komenda recovery, celowo pominięta w README gracza |
| Komenda konsoli | Plik źródłowy | Działanie |
| --- | --- | --- |
| `ar_test()` | `Core.ws:L78` | undefined |
| `ar_status()` | `Core.ws:L2796` | undefined |
| `ar_reset()` | `Core.ws:L2911` | undefined |
| `ar_force()` | `Core.ws:L2933` | undefined |
| `ar_devreset()` | `Core.ws:L2955` | undefined |
| `ar_idlenow()` | `Core.ws:L2973` | undefined |
| `ar_downtime()` | `Core.ws:L2985` | undefined |
| `ar_consent()` | `Core.ws:L3041` | undefined |
| `ar_affinity(npc, n)` | `Core.ws:L2944` | Dodaje `n` punktów zażyłości dla wskazanego NPC |
| `ar_trigger()` | `Core.ws:L3076` | undefined |
| `ar_logdump(optional n)` | `Core.ws:L2977` | Wypisuje na HUD ostatnie `n` linii z bufora logów |
| `ar_bootlog()` | `Core.ws:L3124` | undefined |
| `ar_diag()` | `Core.ws:L3141` | undefined |
| `ar_line(npc, lineId)` | `Core.ws:L3078` | Odtwarza wybraną kwestię dialogową na żywo (test audio) |
| `ar_probeanim(npc, anim)` | `Core.ws:L3103` | Sprawdza obecność animacji slotowej w modelu postaci |
| `ar_probeanim2(target, anim)` | `Core.ws:L3127` | Wariant proba animacji na dowolnym celu |
| `ar_probesync()` | `Core.ws:L3332` | undefined |
| `ar_probesyncstop()` | `Core.ws:L3354` | undefined |
| `ar_npcsweep()` | `Core.ws:L3366` | undefined |
| `ar_probeinject(target, animset, anim)` | `Core.ws:L3277` | Test wstrzyknięcia animacji z animsetu |
| `ar_dance(optional npc)` | `Core.ws:L3665` | Test: wymusza jeden taniec lub odmowę dla towarzyszki w drużynie, bez bramki tawerna/ognisko. Nazwy: priscilla, triss, keira, shani, tomira, cerys, ves, ciri, philippa, yen, ciri_refuse |
| `ar_debug(optional mode)` | `Core.ws:L3360` | Włącza/wyłącza powiadomienia o tickach na ekranie HUD |
| `ar_eval()` | `Core.ws:L3512` | undefined |
| `ar_neartags()` | `Core.ws:L3606` | undefined |
| `ar_taverndebug()` | `Core.ws:L3660` | undefined |
| `ar_kiss(optional npc)` | `Core.ws:L3578` | Natychmiastowy bezpośredni pocałunek ze wskazaną towarzyszką (v2.0) |
| `ar_intimate(optional npc)` | `Core.ws` | Test/Wymuszenie: natychmiastowe zaproszenie do intymnosci (T4) lub informacja na HUD/w konsoli o braku obslugi dla danego NPC (v2.1) |
| `ar_hug()` | `Core.ws:L3885` | undefined |
| `ar_dress(optional npc)` | `QoL.ws:L211` | Zmienia strój towarzyszki na normalny |
| `ar_undress(optional npc)` | `QoL.ws:L220` | Zmienia strój towarzyszki na bieliznę |
| `ar_naked(optional npc)` | `QoL.ws:L234` | Zmienia strój towarzyszki na nagość |
| `ar_gift(optional npc)` | `QoL.ws:L250` | Wręcza butelkę alkoholu z ekwipunku (+3 affinity) |
| `ar_devinfo()` | `Tw3seDev.ws:L151` | undefined |
| `ar_reload()` | `Tw3seDev.ws:L174` | undefined |
| `ar_e2e_rebuild_registry()` | `E2EDev.ws:L919` | undefined |
| `ar_test_e2e()` | `E2EDev.ws:L933` | undefined |
| `ar_tour_scenes(optional npc)` | `E2EDev.ws:L1094` | **DEV-ONLY** (wycięty z paczki): tour po scenach danej postaci (gift→kiss/hug→T4) |

---

## 4. Żelazne Reguły dla Agentów (Ochrona Przed Regresjami)

Każdy agent modyfikujący kod **musi bezwzględnie** przestrzegać poniższych reguł:

1. **Weryfikacja Kompilacji przed Zakończeniem Zadania:**
   Nigdy nie przekazuj użytkownikowi kodu bez sprawdzenia kompilatorem:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "_ModDev\MCME_AutonomousRomance\scripts\test_compile.ps1" -TimeoutSeconds 35
   ```

   Wcześniej wykonaj natychmiastowy pre-check: `scripts\precheck_syntax.ps1`. Wynik musi mieć `ExitCode 0`.
2. **Zakaz Inicjalizacji w `CPlayerInput`:**
   Nie przenoś startu moda do `CPlayerInput.Initialize` ani `CPlayerInput.OnSpawned`. Zostaje w `@wrapMethod(CR4Player) InitRemasterSettings()`.
3. **Sygnatury Zdarzeń (`event`):**
   W `@wrapMethod(...)` dla zdarzeń silnikowych nie wolno podawać typu zwracanego (`: bool` ani `: void`). Rzuca to błąd: `Event function should not have an explicit return type`.
4. **Funkcje Utajone (`latent`):**
   Nie wolno umieszczać funkcji latentnych wewnątrz warunków logicznych (`if (LatentFunc())` jest nielegalne: `Conditional expression must not be latent`).
5. **Natywne Metody C++:**
   Ścisła wielkość liter: `CActor.GetVoicetag()` (małe `t`), a **nie** `GetVoiceTag()`.
6. **Brak Funkcji `StringToName`:**
   Dopasowania nazw rób przez `StrLower(NameToString(nam)) == StrLower(targetStr)`.
7. **Brak Twardych Kolizji Companionów:**
   Nie włączaj kolizji fizycznych u towarzyszek MCME (`EnableCharacterCollisions`) - celowo są przenikalne, aby nie blokować drzwi i AI.
8. **Klawisz Akceptacji Romansu:**
   Nigdy nie używaj `[E]` (konflikt z menu MCME). Zgoda gracza jest podpięta pod `'SwordSheathe'` ([C]).
9. **Izolacja Warstwy TW3SE:**
   Wszelkie odwołania do funkcji `TW3SE_*` mogą znajdować się wyłącznie w `MCM_RomanceTw3seDev.ws`.

---

## 5. Checklist Dodawania Nowej Postaci (Rozszerzanie Roostera)

Procedura dodawania nowej postaci (np. Salma, Philippa, Syanna, Ves):

1. **Rejestracja Nazwy:** W `MCM_RomanceCore.ws#L2181` dopisz voicetag postaci do `MCM_AR_IsRomanceNPC`.
2. **Nazwa dla HUD:** W `MCM_RomanceInteraction.ws#L2696` dopisz mapowanie `nam` na nazwę czytelną w `MCM_AR_GetCompanionDisplayName`.
3. **Baza Zażyłości:** W `MCM_RomanceAffinity.ws#L249` dodaj fakty questowe w `GetBaseStoryAffinity`.
4. **Pocałunek (T3 Kiss):** Wszelkie akcje pocałunku wołają `PlayKissScene(npc)` → `AutonomousScenePath` → `PlayScene(ar_*.w2scene)`. Nowa postać wymaga wygenerowania sceny `scripts\build_ar_bundle.ps1` (dopisz job) i wpisu w `AutonomousScenePath`. **NIGDY nie kieruj akcji kiss/hug na sceny MCME `*FollowWithKiss.w2scene`** - zawierają `PChoice`/menu dialogowe i należą do pipeline MCME. Szczegóły: §5.1 poniżej.
5. **Ścieżka Sceny Naughty (T4):** Jeśli postać posiada dedykowaną scenę łóżkową MCME bez menu, dopisz jej ścieżkę do `NaughtyScenePath(npcName)` w `MCM_RomanceInteraction.ws`.
6. **Weryfikacja Zasobów Scen:** Upewnij się, że ścieżka `.w2scene` znajduje się w `scripts\known_scenes.txt`.
7. **Implementacja Klas Akcji:** Utwórz nową klasę dziedziczącą po `MCM_RomanceInteraction`:
   * Zdefiniuj parametry w konstruktorze (`id`, `targetNpc`, `minAffinity`, `cooldownSeconds`, `triggerType`, `weight`).
   * Wszelkie warunki umieszczaj w `GetExtraBlockReason()`.
   * Zaimplementuj latentną metodę `Execute(npc, player, ctx)` pamiętając, aby na każdej ścieżce wyjścia wywołać `EndSoft()` lub `EndInteraction()`.
7. **Lokalizacja tekstów:** każdy nowy tekst renderowany graczowi dostaje `lineKey`/`thanksLineKey`/`AR_T("ar_*", "fallback EN")` oraz wpisy w `en.w3strings.csv` i `pl.w3strings.csv` (kolejne id 211880xxxx) + re-encode obu plików `w3stringsr`.
8. **Rejestracja w Rejestrze:** Zarejestruj nową akcję przez `RegisterAction(new MCM_AR_<npc>_<akcja> in this)` wewnątrz `@wrapMethod(MCM_RomanceActionRegistry) InitDefaultActions()`.
9. **Weryfikacja Kompilatorem:** Uruchom `precheck_syntax.ps1` oraz `test_compile.ps1`.

### 5.1 Pipeline scen `ar_*` — jak dodać kiss/hug dla nowej postaci (synteza v2.0)

Sceny `ar_*` to **adaptacje, nie autorstwo**: źródłem są oryginalne `*FollowWithKiss.w2scene` z paczek MCME. Struktura we wszystkich paczkach jest identyczna (~8.4 KB CR2W, `CStorySceneInput #6` → `section_kissscene #53` → `CStorySceneOutput`, `voicetag` + numeryczne vanilla `dialogLine`, wspólny bank animacji szkieletu kobiet). Licencjonowanie: substancja = assety vanilla + cienka warstwa wiringu paczek — wystarczy linia credits na Nexusie.

**Źródła ekstrakcji (bundle → sceny):**

| Paczka (zainstalowana) | `*FollowWithKiss` dla |
|---|---|
| `dlc\dlc_spawn_control_girls\content\blob0.bundle` | edna, fringilla, margarita, oriana, priscilla (+amrynn, ciri) |
| `dlc\dlc_anarietta_vivienne\content\blob0.bundle` | anarietta, vivienne (+`NoKiss`), philippa, salma, ves |
| `!Downloads\EvenMoreCompanions\DLCmod_spawn_companions\content\blob0.bundle` (niezainstalowana, tylko pobrana) | rosa, tomira (+alternatywy powyższych) |

**Kroki:**
1. `$SceneJobs` w `scripts\build_ar_bundle.ps1` — dopisz job (ścieżka źródła w bundle + docelowa `ar_<npc>_kiss.w2scene`). Skrypt robi per-job `Bundle` → ekstrakcję WolvenKit → enum-fix `medium`→`Medium` → `cr2w2json` → `strip_scene.py` → `json2cr2w` → własny `blob0.bundle` + `metadata.store`.
2. `AutonomousScenePath(npc, isHug)` (Interaction L1280) — dopisz `case` dla `nam`.
3. `scripts\known_scenes.txt` — dopisz ścieżkę `dlc\mod_mcme_autonomous_romance\dialogue\ar_*.w2scene` (precheck to weryfikuje).
4. Akcja scenowa: flaga `usesAutonomousKiss`/`usesAutonomousHug` → `GetBlockReason` oddaje `no_scene` zanim dojdzie do promptu (NPC bez sceny = cichy gate, nie martwy prompt).
5. **Zweryfikuj runtime `nam`** przez `ar_status`/log PRZED wydaniem — dev-name ≠ display-name (precedens: Cerys ma `nam='becca'`; aliasy: `keira_metz`/`keira`, `pryscilla`/`priscilla`, `becca`/`cerys`, `mh303_succbus_v2`, `prologue_village_herbalist`).

**Kontrakt bindingu (warunki konieczne — bez nich scena ładuje się, ale nie gra):**
- `actorTags` aktora kompana → `[mcme_companion]` **+ `dontSearchByVoicetag=true`** (bez flagi silnik binduje po voicetag i tag jest ignorowany).
- `PlayScene` robi `npc.AddTag('mcme_companion')` przed `mod_scm_delayedDialogue` i `RemoveTag` po pętli — binding rozwiązuje się raz, przy starcie sceny.
- `metadata.store` jest **WYMAGANY** dla bundle'ów w `Mods\` — bez niego `LoadResource` zwraca NULL (scena "nie gra wizualnie" mimo `ok=true`). WolvenKit `Metadata_Store.Write` to stub → writer `_work\write_metadata_store.py` (FNV-1a-64 jako signed int64).

**Pułapki ekstrakcji:**
- Naiwny parsing TOC bundle'u daje bloki **POTATO70** (magia CR2W siedzi pod koniec chunka) — ekstrahuj wyłącznie `WolvenKit.Bundles.Bundle.Items[path].Extract`, jak robi `build_ar_bundle.ps1` / `_work\probe_extract.ps1`.
- `scripts\_extract_scenes.ps1` jest **blokowany przez AV** (false positive) — do pojedynczej sceny użyj `_work\probe_extract.ps1`.
- Strip przepina `nextLinkElement`: `Input → sekcja gestu → Output #7` (Output #8 = ścieżki `doNaughty`/`normal_dialog` — celowo odcięte). `id`/`voicetag`/linie/animy zostają — brak głosu sceny by design (gest + post-kiss bark).
- Deploy po rebuildzie: pełny `blob0.bundle` + `metadata.store` — zabity `Bundle.Write` zostawia obcięty bundle z 1 itemem.
- `IsInGameplayScene` po scenie może zostać `true` (quirk MCME + idle-pose) — wait-loop `PlayScene` ma bail po ciszy/twardy cap; `EndInteraction` self-heal >6 s.

**Ślad audytu (raw):** raporty BoteX `..\.botex\memory\mem_task_4968601d_report.md` (ryzyka strip), `mem_task_c875aaa0_report.md` (diff scen — OverridePlacement odparty), `mem_task_a2af519a_report.md` (wait-loop), `mem_task_136d9211_report.md` (mapowania/becca), notatki `mem_df1b45c9` (źródła ekstrakcji), `mem_f120fbbd`/`mem_e860bf35` (pilot); research silnikowy `..\archive\research\`. Narzędzia `_work\`: `strip_scene.py`, `write_metadata_store.py`, `probe_extract.ps1`, `ar_src\`, `strip_*.json`, `src_*FollowWithKiss.json`.

---

## 6. Lokalizacja (W3Strings)

Wszystkie teksty renderowane graczowi (napisy barków, prompty zgody, komunikaty HUD, etykiety menu) przechodzą przez paczkę `.w3strings` w `Mods\modMCME_AutonomousRomance\content\`.

* **Helpery (`MCM_RomanceAffinity.ws`):**
  * `AR_T(key, optional fallback)` - pobiera tekst przez `GetLocStringByKeyExt`; gdy klucza brak (starsza/brakująca paczka) zwraca zaszyty na sztywno fallback angielski. Zawsze podawaj fallback = tekst EN.
  * `AR_Fmt(text, arg1, arg2, arg3)` - podmienia tokeny `{1}`/`{2}`/`{3}` (implementacja na `StrFindFirst`+`StrMid`; natywny `StrReplace`/`StrReplaceAll` z `core\string.ws` istnieje - `StrReplace` podmienia TYLKO pierwsze wystapienie).
* **Konwencja kluczy (id-space `211880xxxx`):**
  * `ar_line_*` - napisy barków akcji (pole `lineKey` w klasach akcji; `lineText` pozostaje jako fallback EN i treść dla `lineId`),
  * `ar_thanks_*` - linie podziękowania po prezencie (`thanksLineKey`),
  * `ar_prompt_*` - prompty zgody `[C]` (w tym `ar_prompt_consent_hint` = wspólny suffix),
  * `ar_msg_*` - komunikaty HUD (heal, prezent, nastrój intymny, generyczna nazwa towarzyszki),
  * `ar_menu_*`/`ar_outfit_*` - enum ubioru w menu MCME,
  * `option_mcm_ar_opt_*` / `option_MCM_AR_*` - etykiety opcji MCM (podwójne klucze wg istniejącej konwencji).
* **Pliki:** źródła `en`/`pl`/`es`/`esmx`.w3strings.csv (UTF-8), binaria enkodowane przez `Tools\w3stringsr encoder\w3stringsr.exe --id-space 18800 <csv> <w3strings>`. Pozostałe języki (`ar/br/cn/cz/de/fr/hu/it/jp/kr/ru/tr/zh`) to bajtowe kopie `en.w3strings` = fallback na angielski. CSV nie trafiają do paczki release (usuwane przez `package_release.ps1`) - binaria muszą być aktualne.
* **Nazwy itemów prezentów:** nie tłumaczymy ręcznie - `GetLocStringByKeyExt(thePlayer.inv.GetItemLocalizedNameByName(item))` zwraca nazwę w języku gry (fallback na surowe id). Uwaga: `inv.GetItemName(item)` zwraca surowy `name`, NIE tekst zlokalizowany.
* **Kanał deweloperski `[AR]`:** logi `MCM_AR_Log` i komunikaty komend `ar_*` (status, eval, logdump itd.) są kanałem dev/diagnostycznym - pozostają **po angielsku** i celowo nie są lokalizowane.
* **Podmiany w tekstach:** `{1}`/`{2}`/`{3}` zastępowane przez `AR_Fmt` - w tłumaczeniach zachowuj tokeny i dostosuj kolejność do gramatyki języka.