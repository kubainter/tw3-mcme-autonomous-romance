# MCME Autonomous Romance - Codebase & Architecture Reference

> **Dokument referencyjny bazy kodu (Codebase Map)** dla deweloperów i agentów AI.
> Stanowi zweryfikowane źródło wiedzy o strukturze plików, mapowaniu logiki 1:1,
> komendach diagnostycznych konsoli, regułach silnika RedEngine 3 / WitcherScript NG
> oraz procedurze rozszerzania moda bez tworzenia regresji.
>
> 📖 **Dokumentacja powiązana i badania architektury:**
> - `..\archive\research\RESEARCH_SEAMLESS_ROMANCE_PLAYBACK.md` (archiwum, poza repo) - Analiza silnikowego odtwarzania cutscen (TGL Scene Selector vs MCM AR) i odrzucona ścieżka Lua/TW3SE dla pocałunku. **Uwaga: ścieżka z researchu NIE jest obecną architekturą** - v2.0 używa natywnych scen `ar_*.w2scene` bez PChoice (§7 ARCHITECTURE).

---

## 1. Struktura Plików i Mapa Odpowiedzialności (1:1)

Cały kod źródłowy moda znajduje się w:
`_ModDev\MCME_AutonomousRomance\repo\Mods\modMCME_AutonomousRomance\content\scripts\local\romance\`

Folder w grze `Mods\modMCME_AutonomousRomance` to **NTFS Junction** wskazujący na powyższy katalog repozytorium.

```text
modMCME_AutonomousRomance/
├── MCM_RomanceCore.ws         - Boot, pętle ticków, Idle-Suspend, kanał ambient (priorytet isTimeCritical), filtry i execy
├── MCM_RomanceInteraction.ws  - Klasa bazowa akcji, GiftRequest_Base, staging lokomocji, Consent Engine v3, Rejestr
├── MCM_RomanceAffinity.ws     - Config wrapper MCM, resolver zażyłości 3 filarów, ring-bufor MCM_AR_Log
├── MCM_RomanceActions_Main.ws - Repertuar 50 klas: Yen, Triss, Keira, Shani + generyczne T1
│    (pogoda/koń/łódź/interior, afterglow, zazdrość, night-fillery) + Rosa var Attre, Tomira, Ciri (hug + dual-mode kiss/intimate) [w tym Gifty C1 i pocałunki/uściski]
├── MCM_RomanceActions_DLC.ws  - Repertuar 63 klas: Anarietta, Vivienne, Cerys, Syanna (pełny T1-T4 Core CDPR cloud sex),
│    Philippa, Ves, Salma, Priscilla, Edna, Fringilla, Margarita (T1-T3 + Gifty), Orianna (T1-T2 + Gift)
├── MCM_RomanceQoL.ws          - Flash UI menu ubioru w MCME, pamięć strojów, ar_gift
├── MCM_RomanceTw3seDev.ws     - Warstwa TW3SE (importy natywne, pipe IPC, odczyt VK, hot-reload)
└── MCM_RomanceTw3seDev.stub.ws             - Pusty zamiennik bez TW3SE dla wersji release
```

---

### Szczegółowy Rozkład Odpowiedzialności w Skryptach

### 1. `MCM_RomanceCore.ws`

* **Boot i Cykl Życia (L11-179):**
  * Wstrzyknięcie pól do gracza: `@addField(CR4Player) mcm_ar_core`, `mcm_ar_ambient`, `mcm_ar_bootlog`.
  * Punkt startowy: `@wrapMethod(CR4Player) InitRemasterSettings()` wywołuje `MCM_AR_OnPlayerReady()`. Omija problem cienia priorytetów modów (np. Brothers in Arms).
  * Rejestracja listenerów akcji klawisza zgody: `'MCM_AR_Consent'` (własna akcja moda: C + pad D-pad L/R,
    mapowanie w `MCME_AR.input.settings`) oraz legacy `'SwordSheathe'` dla kompatybilności.
  * Uruchomienie timerów silnika: `MCM_AR_AutonomousTick` (interwał konfigurowany z MCM: `MCM_AR_TickInterval`, suwak 20-160s co 10s, domyślnie 30s - przez `GetTickIntervalSeconds()`) i `MCM_AR_AmbientTick` (co 10.0s).
* **System Idle-Suspend (W2/I1) (L187-447):**
  * Klasa `MCM_AR_IdleJob`: zarządza zadaniem postoju (NPC, cel, kąt, animacja slotowa, faza).
  * `UpdateIdleSuspend(safe : bool)`: bada bezruch gracza w promieniu 1.5m przez >50s (`arIdleAnchor`). Zawiesza follow przez `StopFollowing(true)` (z zachowaniem tagu `mod_scm_IsFollowing`), kieruje NPC na pozycję obok i uruchamia animację slotową (np. `woman_stand_hand_on_hip_idle` dla Yen, `stand_weight_shift` dla Triss).
  * **Podział zegarów:** tworzenie jobów i próg bezruchu >50s zostają w `ProcessTick` (tick decyzyjny z MCM), natomiast progresja faz jobów (`moving` -> `posed`) oraz pętla wybudzania działają na kanale ambient ~10s (`UpdateIdleAmbient()` + `WakeIdleJobs()`). Dzięki temu pozy towarzyszek pozostają responsywne niezależnie od ustawienia `MCM_AR_TickInterval`.
  * Wybudzenie i wznowienie follow: natychmiast po ruszeniu gracza >1.5m lub wejściu w stan unsafe (walka, menu, dialog).
* **Filtry Bezpieczeństwa i Budowa Kontekstu (L868-1358):**
  * `MCM_AR_IsSafeToInitiate(out reason)`: blokuje akcje w walce, dialogach, pływaniu, łodzi, otwartym menu i stanach innych niż `Exploration`.
  * `MCM_AR_IsSafeForAmbient(out reason)`: łagodniejszy gate dla barków T1 - dopuszcza jazdę konną (`HorseRiding`/`Horse`) i łódź (`Sailing`/`BoatPassenger`/`Boat`), nadal blokuje pływanie, walkę i dialogi/cutsceny.
  * `lastSceneOkNpc`/`lastSceneOkTime` + `sceneExistsCache` (`path→bool`): stempelek ostatniej udanej sceny T3/T4 (fuel dla afterglow/zazdrości) i cache `MCM_AR_SceneExists`.
  * `BuildContext(companions)`: agreguje czas gry (`isNight`, `isDawn`), stan zdrowia, ognisko (<6m; encja z tagiem `campfire` lub `CarriesOpenFire`/TAG_OPEN_FIRE z wykluczeniem świec/lampek/pochodni po ścieżce - `candle|lantern|torch|chandelier|sconce|candelabr|lamp`), karczmę (`MCM_AR_IsInTavern`: fact `player_in_inn` LUB fallback `IsInInterior` + skan encji ≤18m/cap 200 - tagi `innkeep`/`barkeep`/`barmaid`/`bartender`/`tavern_keeper` albo ścieżka warstwy/szablonu `innkeep|barkeep|barmaid|inn\|inn_|inn.|tavern|drinking_bench`; wysoki cap wymagany, bo geste wnetrza zwracaja 100+ encji w kolejnosci silnikowej), Corvo Bianco, odległość NaughtyPoint oraz obecność rywalek (`rivalCount`).
  * `missingVoicesetNpcs` (`MCM_AR_IsVoicesetMissing`/`MCM_AR_MarkVoicesetMissing`): cache per-NPC po 1. nieudanym `PlayVoiceset` - kolejne barki idą od razu ścieżką lineId/napis bez spamu warningów (Rosa/Tomira nie mają `greeting_geralt`).
* **Maszyny Stanów STAGED i AMBIENT (L1359-1785):**
  * `MCM_AutonomousRomanceCore`: stan `Idle` oraz `ProcessingTick` (interwał `MCM_AR_TickInterval`, domyślnie 30s; pętla STAGED z lockiem `interactionBusy`, watchdogiem 300s i post-staged cooldownem 90s).
  * `MCM_AmbientRomanceChannel`: stan `Idle` oraz `AmbientTick` (co 10s; pętla AMBIENT dla powitań po rozłące >60s oraz jednolinijkowców T1).
  * Akcje z flagą `isTimeCritical` (`ar_afterglow`, `ar_jealousy_aftermath`) mają pierwszeństwo w kanale ambient: `ProcessAmbient` pomija los presetu gadatliwości, gdy którakolwiek jest eligible (`HasTimeCriticalEligible`), a `TryExecuteTimeCritical` wybiera eligible o najwyższym `weight` i strzela przed ważonym losem (`[AR] ambient(prio) -> ...`). Globalny cooldown barku ~90s i bramki per-NPC nadal obowiązują.
* **Komendy Diagnostyczne Konsoli (L1790-2628 oraz ar_test L63, ar_test_e2e w dev):**
  * `ar_test`, `ar_status`, `ar_reset`, `ar_force`, `ar_devreset`, `ar_idlenow`, `ar_consent`, `ar_affinity`, `ar_trigger`, `ar_logdump`, `ar_bootlog`, `ar_diag`, `ar_line`, `ar_probeanim`, `ar_probeanim2`, `ar_probeinject`, `ar_debug`, `ar_eval`, `ar_neartags`, `ar_kiss`, `ar_hug`, `ar_dress`, `ar_undress`, `ar_naked`, `ar_gift`, `ar_devinfo`, `ar_reload`, `ar_test_e2e`, `ar_tour_scenes` (29 łącznie; release-stub = 27).
  * `ar_test_e2e`: zestaw asercji automatycznych E2E w dev-layerze TW3SE, sterowany zewnętrznym runnerem `scripts\test_e2e.ps1` (nie trafia do paczki release).

### 2. `MCM_RomanceInteraction.ws`

* **Struktury i Enumy (L10-43):**
  * `enum ERomanceTriggerType`: `RTT_OneLiner` (T1 Bark), `RTT_Gesture` (T2 Gest), `RTT_Prompt` (T3 Prompt ze zgodą), `RTT_Scene` (T4 Scena z pocałunkiem/intymna).
  * `class MCM_RomanceContext`: kontener danych środowiskowych przekazywany do bramek akcji
    (m.in. `isNight`, `isInTavern`, `isNearCampfire`, `hasRivals`, `isBadWeather`, `isOnHorse`, `isOnBoat`, `isInInterior`).
* **Klasa Bazowa `MCM_RomanceInteraction` (L44-1650):**
  * Parametry: `id`, `targetNpc`, `minAffinity`, `cooldownSeconds`, `triggerType`, `weight`, `barkMimic`, `lineId`, `lineText`, `lineKey` (klucz w3strings, `lineText` = fallback EN), `barkVoiceset`; klasy gift dodatkowo `thanksLineId`/`thanksLineText`/`thanksLineKey`.
  * Bramki: `CanExecute()` -> `GetBlockReason()` (cooldowny, backoff odrzucenia 300/900/1800s, minAffinity, zazdrość, max odległość 15m) + `GetExtraBlockReason()` w klasach pochodnych.
  * Staging lokomocji:
    * `SoftApproach`: podejście towarzyszki do Geralta (`ActionMoveToNodeAsync`), wyłączenie kolizji, suspensja follow.
    * `WaitForApproach`: timeout 8s, przerwanie przy walce lub odejściu gracza >25m.
    * `HardStage`: zablokowanie ruchu gracza (`thePlayer.BlockAction(EIAB_Movement, 'MCM_AR_interaction')`), obrót twarzą w twarz.
    * `EndSoft` / `EndInteraction`: czyszczenie stanu, odblokowanie gracza, przywrócenie kolizji i wznawianie podążania.
  * Consent Engine v3 `ShowConsentPrompt(text, timeout, npc)` (L594-750):
    * Komunikat HUD: suffix lokalizowany kluczem `ar_prompt_consent_hint` (EN: `(hold [C] ~1s or tap twice)`).
    * Odejście gracza >12m traktowane jako odmowa.
    * Obsługa Hold (~1.0s) i Double-Tap (<0.7s) oparte na zdarzeniach `OnMCM_AR_ConsentKey`; `nowDown = evHeld` (release) lub `DevKeyDown || evHeld` (dev - unia, pad-hold działa też w devie; wcześniej devVK ignorował eventy i pada). Latch eventowy **per-akcja**: `mcm_ar_consentHeldC`/`mcm_ar_consentHeldS` - syntetyczny `IsReleased` z `Duration,IdleTime=0.3` (pad `SwordSheathe`) nie zabija holda drugiej akcji; uzbrajany przez `pressAt >= tStart`, reset bezwarunkowy przed promptem (też w devVK). `actHeld` tylko do telemetrii. **Okno min. 20s** - `DisplayHudMessage` kolejkuje za linia barku NPC (~4-5s na ekranie); przy 10s prompt renderował się na koniec/po oknie i pressy lądowały po timeoutcie (`awaiting=0` w logach). **Wszystkie pomiary czasu przez `GetEngineTimeAsSeconds() - tStart` - NIE akumulacja `Sleep`**. Licznik tapów = `max(krawędzie VK, fakty eventowe)`; listener deduplikuje to samo fizyczne naciśnięcie odpalające obie zarejestrowane akcje (okno 0.12s).
    * Tekst promptu renderuje glyph realnego bindingu: `<<MCM_AR_Consent>>` + `ReplaceTagsToIcons()`.
    * Pokrycie kontekstów input: `MCM_AR_Consent` zbindowany nie tylko w 5 bazowych kontekstach gameplay (Exploration/Combat/Horse/Boat/Swimming), lecz też w overlay-contextach, które mogą siedzieć na stosie wejścia podczas promptu (`Scene` tylko klawiatura - D-pad nawiguje tam dialogi, `ScriptedAction`, `SCENE_IS_STARTING_HACK`, `JumpClimb`, `Diving`, `ThrowHold`, `ThrowHoldChain`, `LootPopup`, `BoatPassenger`, replacery Ciri). Bez tego binding w aktywnym kontekście nie istnieje → zero zbocz akcji i eventów listenera.
    * Diagnostyka dev (`ar_log.txt`): `consent: ctx=` przy starcie promptu (aktywny `theInput.GetContext()`), sonda `consent probe:` co ~1s (ctx + VK + `GetActionValue` obu akcji + licznik faktu), `consent ev:` na samej górze listenera (każde wywołanie, zanim odpadnie na bramkach - odróżnia "brak eventu" od "event bez press-edge").
  * Odtwarzanie Scen i Integracja MCME (L800-1650):
    * `PlayKissScene(npc)` / `PlayHugScene(npc)`: rozwiązują ścieżkę przez `AutonomousScenePath(npc, isHug)` i grają naszą scenę `ar_*.w2scene` (per-NPC strip PChoice: Input→sekcja gestu→Output) przez `PlayScene`. Brak mapowania = `false`. **NIGDY nie kieruj akcji kiss/hug na sceny `*FollowWithKiss.w2scene`** - te pliki należą do MCME (zawierają `PChoice` i menu dialogowe) i służą wyłącznie własnemu pipeline MCME.
    * `AutonomousScenePath(npc, isHug)`: mapa `nam`→`dlc\mod_mcme_autonomous_romance\dialogue\ar_*.w2scene` — bundle zawiera 20 scen (19 kiss + `ar_cirilla_hug`), z czego mapa zwraca ścieżki dla 16 kiss + hug; `ar_anna/vivienne/orianna_kiss` istnieją w bundle, ale celowo NIE są mapowane → `""` → `no_scene` (ciri kiss dodatkowo gated przez `MCM_AR_CiriMode`: w Lore-Friendly zwraca "" → `no_scene`). **Anna/Vivienne/Orianna celowo zwracają "" i nie mają akcji kiss w rejestrze** — ich `noble_woman_base` rig nie ładuje banku `woman_dialog` i nie istnieje dla niego animacja kiss (w przeciwnym razie T-pose; autor upstream dokumentuje tę samą wadę). Ich `*_intimate_invite` działa, bo `naughty\*` to cutscene-playery, nie scene-anim binding. Zasoby generuje `scripts\build_ar_bundle.ps1` (per-job `Bundle` → ekstrakcja → enum-fix `medium`→`Medium` → strip w JSON → pakowanie własnego `content\blob0.bundle`); sceny dla 12 NPC pochodzą z paczek MCME (Spawn Control Girls, Anarietta & Vivienne plus2, Even More Companions). Aliasy nam: `edna_var_attre`, `prologue_village_herbalist` (Tomira), `mh303_succbus_v2` (Salma), `pryscilla`/`priscilla`, `becca`/`cerys`.
    * `WaitForSceneEnd(npc, timeout)`: latentne oczekiwanie na zakończenie sceny, wczesne zwolnienie ruchu gracza (`UnblockAction(EIAB_Movement)`) po wyjściu z sekwencji animacji. Używane przez pipeline T3 (`PlayScene` pośrednio) i T4 (`PlayIntimateScene`).
    * `PlayIntimateScene(npc)`: pipeline intymny z NaughtyPoints (punkt <=16m w `IsOnNaughtyPoint()`). Obsługuje ścieżkę zarejestrowaną (`PreNaughtyWith`) oraz manualną (`dlc\mod_spawn_companions\naughty\<npc>\anywhere.w2scene`).
    * `MCM_AR_SceneExists(path)`: `LoadResource(path,true)`→`CStoryScene` z cache `path→bool` w core (gate `no_dlc_scene` w klasach T4 - sceny z `dlc_spawn_control_girls` nie zawieszają ewaluacji).
    * `ResolveIntimateScenePath(npc)`: wspólny resolver ścieżki sceny (priorytet `specialData.naughtyScene` — paczki MCME mogą rejestrować własne ścieżki — fallback `NaughtyScenePath`). `NaughtyScenePath` mapuje `cirilla`/`ciri` → `naughty\ciri` TYLKO w `MCM_AR_CiriMode`=Adult; dodatkowy gate `lore_mode` siedzi w `ciri_intimate_invite` (bo `specialData` omija mapowanie).
* **Rejestr Akcji `MCM_RomanceActionRegistry` (L1651-1970):**
  * Centralna tablica `actions: array<MCM_RomanceInteraction>`.
  * `TryExecute(npc, player, ctx, out eligCount, optional ambientOnly)`: filtrowanie wg NPC, kanału, sprawdzanie bramek, losowanie ważone (`weight`) i wywołanie `Execute()`.
  * `TryExecuteTimeCritical(npc, player, ctx)` + `HasTimeCriticalEligible(...)`: wariant ambient dla akcji `isTimeCritical` - bez losowania (max `weight`), wołany przed `TryExecute` w pętli ambient; helper używany do ominięcia losu presetu gadatliwości.
* **Wrappery i Zdarzenia Globalne (L1971-2130):**
  * `event OnMCM_AR_ConsentKey(action)`: rejestruje stan naciśnięcia klawisza consent (`'MCM_AR_Consent'` + legacy `'SwordSheathe'`); `FactsAdd` do licznika tapów z deduplikacją 0.12s (te same fizyczne pressy odpalają obie akcje w jednej klatce); latch holda per-akcja (`consentHeldC`/`consentHeldS`) - `IsReleased` jednej akcji nie zeruje trzymania drugiej.
  * `MCM_AR_AreRivals(a, b)`: helper par rywalizujących (yen↔triss) dla konfrontacji zazdrości.
  * `MCM_AR_GetCompanionDisplayName(npc)`: resolver czytelnych nazw dla HUD.
  * `MCM_AR_ProbeAnim(npc, animName)`: sonda sprawdzająca obecność animacji slotowej w modelu NPC.
  * `PlayDrinkingAnimation(npc)`: latentna animacja picia/toastu (`woman_wine_tasting` / `man_work_drinking`) z fallbackiem dla niestandardowych szkieletów, używana przy akceptacji prezentu [C] oraz w akcjach tawernianych.
  * `@wrapMethod(CR4HudModuleDialog) OnDialogChoicesSet` i `SendDialogChoicesToUI`: standardowe przekazywanie wyborów (usunięto eksperymentalną blokadę Flash UI, która powodowała soft-lock - sceny są teraz czyste na poziomie grafu CR2W).

### 3. `MCM_RomanceAffinity.ws`

* **`MCM_AR_ConfigWrapper` (L11-150):**
  * Dostęp do `user.settings` (`CInGameConfigWrapper`, sekcja `MCM_AR`).
  * Gettery: `IsEnabled()`, `GetInitiativeCooldown()`, `GetTickIntervalSeconds()` (clamp 20-160s, default 30), `GetAffinityMultiplier()`, `IsJealousyModeOn()`, `IsForceRomanceOn()`, `RequiresPlayerConsent()`, `IsDebugHudOn()`, `GetBarkPreset()` (1=cichy→30% / 2=domyślny→65% / 3=gadatliwy→100% szansy barku ambient), `IsCiriAdultMode()` (`MCM_AR_CiriMode`, domyślnie 0 = Lore-Friendly: tylko hug; 1 = Adult: kiss + intimate dla Ciri).
  * `EnsureMCMDefaults()` (wołane przy tworzeniu `MCM_AR_GetConfig()`): zasiewa `MCM_AR_BarkPreset=2` gdy var nieobecny w `user.settings` - MCM UI pokazuje `0` dla vara nieobecnego w sekcji i ignoruje `defaultValue` z XML dopóki gracz nie dotknie suwaka.
  * UWAGA: XML menu (`bin\config\r4game\user_config_matrix\pc\modMCME_AutonomousRomance.xml`) NIE jest junction-em jak `Mods\` - po każdej zmianie opcji kopiuj go ręcznie do `<gra>\bin\config\...` i zrestartuj grę (menu czyta XML przy starcie).
* **Centralne Logowanie `MCM_AR_Log` (L152-200):**
  * Ring-bufor 60 wpisów w pamięci RAM (`ar_logdump`).
  * Zrzut do `LogChannel('MCM_AR', msg)`.
  * Przekazanie do TW3SE przez `MCM_AR_DevLog(msg)`.
  * Opcjonalne wyświetlanie na HUD (`thePlayer.DisplayHudMessage`).
* **Helpery lokalizacji (L204-240):** `AR_T(key, fallback)`, `AR_ReplToken`, `AR_Fmt` - patrz sekcja 6.
* **Silnik Zażyłości `MCM_RomanceAffinityResolver` (L245-420):**
  * **Formuła obliczania:**
    $$\text{Total Affinity} = \text{BaseStory} + (\text{Earned} \times \text{Multiplier})$$
  * Tryb Sandbox (`ForceRomance`): stałe 200 pkt.
  * `GetBaseStoryAffinity(npcName)`: ewaluacja faktów questowych (np. `sq202_yen_girlfriend` +50, `q309_triss_stayed` +50, itd.).
  * `GetEarnedAffinity(npcName)`: odczyt faktów silnikowych `mcme_ar_<npcName>_affinity` (+1 za udaną akcję, +3 za prezent).

### 4. `MCM_RomanceActions_Main.ws` i `MCM_RomanceActions_DLC.ws`

* Łącznie 113 klas akcji wieloetapowych (50 w Main + 63 w DLC: T1 ambient, T2 gest/opieka, T3 uniwersalny pocałunek/uścisk, T4 scena intymna) + dedykowane klasy `*_GiftRequest` (bazowa `MCM_AR_GiftRequest_Base` w Interaction.ws) dziedziczących po `MCM_RomanceInteraction` rejestrowanych w `InitDefaultActions()`:
  * **Yennefer (9):** `yen_oneliner_flirt`, `yen_postcombat_care`, `yen_night_invitation`, `yen_campfire_evening`, `yen_intimate_invite`, `yen_jealousy_snark`, `yen_tavern_wine`, `yen_night_filler` (+gift).
  * **Triss (9):** `triss_oneliner_flirt`, `triss_postcombat_hug`, `triss_night_whisper`, `triss_campfire_warmth`, `triss_kiss_invite`, `triss_intimate_invite`, `triss_jealousy_snark`, `triss_tavern_drink`, `triss_night_filler` (+gift).
  * **Keira (7):** `keira_oneliner_flirt`, `keira_postcombat_heal`, `keira_night_proposal`, `keira_campfire_witch`, `keira_intimate_invite`, `keira_tavern_drink`, `keira_night_filler` (+gift).
  * **Shani (6):** `shani_oneliner_flirt`, `shani_postcombat_medic`, `shani_night_relax`, `shani_intimate_invite`, `shani_tavern_drink`, `shani_night_filler` (+gift).
  * **Anna Henrietta (5):** `anarietta_oneliner_flirt`, `anarietta_postcombat_pride`, `anarietta_intimate_invite`, `anarietta_tavern_drink`, `anarietta_night_filler` (+gift). Brak akcji kiss (noble rig).
  * **Vivienne (5):** `vivienne_oneliner_flirt`, `vivienne_campfire_mystery`, `vivienne_intimate_invite`, `vivienne_tavern_drink`, `vivienne_night_filler` (+gift). Brak akcji kiss (noble rig).
  * **Cerys (6):** `cerys_oneliner_flirt`, `cerys_postcombat_skellige`, `cerys_night_invitation`, `cerys_intimate_invite`, `cerys_tavern_drink`, `cerys_night_filler` (+gift).
  * **Rosa var Attre (3):** `rosa_oneliner_flirt`, `rosa_kiss` (T3 Universal Kiss), `rosa_gift_request`.
  * **Tomira (3):** `tomira_oneliner_flirt`, `tomira_kiss` (T3 Universal Kiss), `tomira_gift_request`.
  * **Ciri (3):** `ciri_hug` (T3 Universal Hug - ciepły uścisk rodzinny, zawsze aktywny), `ciri_kiss` (aff 60, `ar_cirilla_kiss`, tylko Adult Mode), `ciri_intimate_invite` (aff 80, `naughty\ciri`, tylko Adult Mode — gate `lore_mode`).
  * **Syanna (5):** `syanna_oneliner_flirt`, `syanna_postcombat`, `syanna_kiss`, `syanna_intimate_invite` (pełne T4 cloud sex w NaughtyPoints z natywnym meshem CDPR `syanna_naked`), `syanna_gift_request`.
  * **Philippa (5):** `philippa_oneliner_flirt`, `philippa_care`, `philippa_kiss` (T3 Universal Kiss), `philippa_intimate_invite` (`naughty\philippa`), `philippa_gift_request`.
  * **Ves (5):** `ves_oneliner_flirt`, `ves_campfire`, `ves_kiss` (T3 Universal Kiss), `ves_intimate_invite` (`naughty\ves`), `ves_gift_request`.
  * **Salma (5):** `salma_oneliner_flirt`, `salma_allure`, `salma_kiss` (T3 Universal Kiss), `salma_intimate_invite` (`naughty\salma`), `salma_gift_request`.
  * **Priscilla (5):** `priscilla_oneliner_flirt`, `priscilla_care`, `priscilla_kiss` (T3 Universal Kiss), `priscilla_intimate_invite` (`naughty\priscilla`), `priscilla_gift_request`.
  * **Edna var Attre (5):** `edna_oneliner_flirt`, `edna_care`, `edna_kiss` (T3 Universal Kiss), `edna_intimate_invite` (`naughty\edna`), `edna_gift_request`.
  * **Fringilla Vigo (5):** `fringilla_oneliner_flirt`, `fringilla_care`, `fringilla_kiss` (T3 Universal Kiss), `fringilla_intimate_invite` (`naughty\fringilla`), `fringilla_gift_request`.
  * **Margarita Laux-Antille (5):** `margarita_oneliner_flirt`, `margarita_care`, `margarita_kiss` (T3 Universal Kiss), `margarita_intimate_invite` (`naughty\margaritta` — pisownia upstream z podwójnym t), `margarita_gift_request`.
  * **Orianna (4):** `orianna_oneliner_flirt`, `orianna_care`, `orianna_intimate_invite` (aff 80, `naughty\oriana` cutscene — top tier jak w upstream paczce), `orianna_gift_request`. Brak akcji kiss — rig `noble_woman_base` nie posiada żadnej animacji kiss (patrz ARCHITECTURE §sceny).
  * **Generyczne T1 (`targetNpc=''`):** `ar_weather_bark`, `ar_horse_bark`, `ar_interior_bark`, `ar_boat_bark`, `ar_afterglow` (spersonalizowany Afterglow w marszu dla 19 towarzyszek z dedykowanymi kluczami `ar_afterglow_walk_*`), `ar_jealousy_aftermath`.
  * **Tawerna i Noc (T1 ambient):** animowane drinki karczemne (`PlayDrinkingAnimation`) i nocne kwestie dla towarzyszek.

### 5. `MCM_RomanceQoL.ws`

* **Zarządzanie Ubiorem:**
  * `MCM_AR_NPCHasAltLooks(npc)` i `MCM_AR_ApplyOutfit(npc, idx)` (0: normalny, 1: bielizna, 2: nago).
  * `@wrapMethod(SCMCompanionControls) onSpawned()`: autoodtwarzanie zapisanego stroju przy spawnie.
  * `@wrapMethod(SCMMenuEditCompanion2) OnMenuCreated()` i `OnChange()`: wstrzyknięcie enuma ubioru do menu MCME we Flash UI bez ruszania plików `.swf`.
* **Mechanika Prezentów:**
  * `ar_gift`: sprawdza alkohole w ekwipunku (`Est Est`, `Erveluce`, `Beauclair White`, `Mettina Rose`, `Alcohest`, `Dwarven spirit`), usuwa 1 sztukę, dodaje +3 pkt do `mcme_ar_<nam>_affinity`, wyzwala `greeting_geralt` i look-at na Geralta.

### 6. `MCM_RomanceTw3seDev.ws`

* Warstwa izolacji TW3SE: importuje funkcje natywne (`TW3SE_*`).
* Udostępnia fasadę `MCM_AR_Dev*` (telemetria, logi do pliku, IPC pipe, czytanie klawiatury VK).
* W paczce wydania zamieniany na stub `MCM_RomanceTw3seDev.stub.ws`, dzięki czemu mod działa u graczy bez Script Extendera.

---

## 2. Geometria i Histereza NaughtyPoint

Sceny intymne Tier 4 (`RTT_Scene`) korzystają z NaughtyPoints zarejestrowanych przez MCME. Obowiązuje ścisła 4-stopniowa histereza promieni:

| Promień | Funkcja / Miejsce w kodzie | Rola |
| --- | --- | --- |
| **16.0m** | `MCM_RomanceInteraction.ws#L1417` (`IsOnNaughtyPoint`) | **Twarda bramka kwalifikacji:** akcja T4 kwalifikuje się do odpalenia tylko w tej odległości od punktu intymnego. |
| **20.0m** | `MCM_RomanceInteraction.ws#L1446` (`PlayIntimateScene`) | **Check defensywny:** weryfikacja tuż przed startem sceny, czy gracz nie odszedł za daleko. |
| **30.0m** | `MCM_RomanceCore.ws#L858` | **Strefa wejścia:** jednorazowe powiadomienie na HUD o dostępności intymnego miejsca. |
| **40.0m** | `MCM_RomanceCore.ws#L1303` | **Reset histerezy:** odejście na ten dystans resetuje flagę powiadomienia HUD. |

---

## 3. Kompletny Indeks Konsoli Debugującej (30 Komend `exec`; release-stub ukrywa 4 dev-only → 26 w paczce)

| Komenda konsoli | Plik źródłowy | Działanie |
| --- | --- | --- |
| `ar_test()` | `Core.ws:L61` | Szybki test działania moda na `thePlayer` |
| `ar_status()` | `Core.ws:L1642` | Wypisuje status: tryby, bezpieczny stan gry, cooldowny, zażyłość postaci |
| `ar_reset()` | `Core.ws:L1737` | Czyści cooldowny wszystkich akcji |
| `ar_force()` | `Core.ws:L1748` | Włącza/wyłącza tryb Sandbox (`ForceRomance`) |
| `ar_devreset()` | `Core.ws:L1770` | Czyści osierocone flagi stanu zgody gracza |
| `ar_idlenow()` | `Core.ws:L1789` | Wymusza przejście towarzyszek w Idle-Suspend |
| `ar_consent()` | `Core.ws:L1800` | Toggle `MCM_AR_RequireConsent` (wymóg promptu [C] dla Tier3+4) z konsoli |
| `ar_affinity(npc, n)` | `Core.ws:L1821` | Dodaje `n` punktów zażyłości dla wskazanego NPC |
| `ar_trigger()` | `Core.ws:L1835` | Resetuje cooldowny i natychmiast odpala tick decyzyjny |
| `ar_logdump(optional n)` | `Core.ws:L1854` | Wypisuje na HUD ostatnie `n` linii z bufora logów |
| `ar_bootlog()` | `Core.ws:L1883` | Wyświetla logi z fazy ładowania silnika |
| `ar_diag()` | `Core.ws:L1900` | Zrzut markerów diagnostycznych z `user.settings` |
| `ar_line(npc, lineId)` | `Core.ws:L1956` | Odtwarza wybraną kwestię dialogową na żywo (test audio) |
| `ar_probeanim(npc, anim)` | `Core.ws:L1983` | Sprawdza obecność animacji slotowej w modelu postaci |
| `ar_probeanim2(target, anim)` | `Core.ws:L2009` | Wariant proba animacji na dowolnym celu |
| `ar_probeinject(target, animset, anim)` | `Core.ws:L2097` | Test wstrzyknięcia animacji z animsetu |
| `ar_debug(optional mode)` | `Core.ws:L2181` | Włącza/wyłącza powiadomienia o tickach na ekranie HUD |
| `ar_eval()` | `Core.ws:L2215` | **Dry-run:** sprawdza bramki wszystkich akcji i wypisuje powody ewentualnych blokad (m.in. `no_scene`) |
| `ar_neartags()` | `Core.ws:L2309` | Listuje tagi/encje w pobliżu gracza |
| `ar_taverndebug()` | `Core.ws:L2324` | Diagnostyka bramki tawernowej: fakt `player_in_inn`, `IsInInterior`, `isInTavern` + encje inn/tavern w promieniu 18m |
| `ar_kiss(optional npc)` | `Core.ws:L2364` | Natychmiastowy bezpośredni pocałunek ze wskazaną towarzyszką (v2.0) |
| `ar_hug()` | `Core.ws:L2473` | Natychmiastowy bezpośredni uścisk z Ciri (v2.0) |
| `ar_dress(optional npc)` | `QoL.ws:L219` | Zmienia strój towarzyszki na normalny |
| `ar_undress(optional npc)` | `QoL.ws:L228` | Zmienia strój towarzyszki na bieliznę |
| `ar_naked(optional npc)` | `QoL.ws:L242` | Zmienia strój towarzyszki na nagość |
| `ar_gift(optional npc)` | `QoL.ws:L260` | Wręcza butelkę alkoholu z ekwipunku (+3 affinity) |
| `ar_devinfo()` | `Tw3seDev.ws:L169` | Wypisuje status połączenia z TW3SE |
| `ar_reload()` | `Tw3seDev.ws:L193` | Wymusza hot-reload skryptów przez TW3SE |
| `ar_test_e2e()` | `Tw3seDev.ws:L481` | Dev: automatyczny test integracyjny 28 asercji |
| `ar_tour_scenes(optional npc)` | `Tw3seDev.ws:L676` | Dev: tour po scenach danej postaci (gift→kiss/hug→T4) |

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

1. **Rejestracja Nazwy:** W `MCM_RomanceCore.ws#L1146` dopisz voicetag postaci do `MCM_AR_IsRomanceNPC`.
2. **Nazwa dla HUD:** W `MCM_RomanceInteraction.ws#L2117` dopisz mapowanie `nam` na nazwę czytelną w `MCM_AR_GetCompanionDisplayName`.
3. **Baza Zażyłości:** W `MCM_RomanceAffinity.ws#L263` dodaj fakty questowe w `GetBaseStoryAffinity`.
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
2. `AutonomousScenePath(npc, isHug)` (Interaction ~L1165) — dopisz `case` dla `nam`.
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
  * `AR_Fmt(text, arg1, arg2, arg3)` - podmienia tokeny `{1}`/`{2}`/`{3}` (brak `StrReplace` w WitcherScript; implementacja na `StrFindFirst`+`StrMid`).
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
