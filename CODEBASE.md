# MCME Autonomous Romance — Codebase & Architecture Reference

> **Dokument referencyjny bazy kodu (Codebase Map)** dla deweloperów i agentów AI.
> Stanowi zweryfikowane źródło wiedzy o strukturze plików, mapowaniu logiki 1:1,
> komendach diagnostycznych konsoli, regułach silnika RedEngine 3 / WitcherScript NG
> oraz procedurze rozszerzania moda bez tworzenia regresji.
>
> 📖 **Dokumentacja powiązana i badania architektury:**
> - [`RESEARCH_SEAMLESS_ROMANCE_PLAYBACK.md`](file:///g:/GOG%20Galaxy/Games/The%20Witcher%203%20Wild%20Hunt%20GOTY/_ModDev/MCME_AutonomousRomance/repo/RESEARCH_SEAMLESS_ROMANCE_PLAYBACK.md) — Analiza silnikowego odtwarzania cutscen (TGL Scene Selector vs MCM AR), ominięcie menu dialogu i roadmapa animacji pocałunku na v2.0.

---

## 1. Struktura Plików i Mapa Odpowiedzialności (1:1)

Cały kod źródłowy moda znajduje się w:
`_ModDev\MCME_AutonomousRomance\repo\Mods\modMCME_AutonomousRomance\content\scripts\local\romance\`

Folder w grze `Mods\modMCME_AutonomousRomance` to **NTFS Junction** wskazujący na powyższy katalog repozytorium.

```text
modMCME_AutonomousRomance/
├── MCM_RomanceCore.ws         — Boot, pętle ticków, Idle-Suspend, Auto-Pick, filtry i execy
├── MCM_RomanceInteraction.ws  — Klasa bazowa akcji, GiftRequest_Base, staging lokomocji, Consent Engine v3, Rejestr
├── MCM_RomanceAffinity.ws     — Config wrapper MCM, resolver zażyłości 3 filarów, ring-bufor MCM_AR_Log
├── MCM_RomanceActions_Main.ws — Repertuar 27 akcji: Yen (8), Triss (8), Keira (6), Shani (5) [w tym Gifty C1]
├── MCM_RomanceActions_DLC.ws  — Repertuar 19 akcji: Anarietta (5), Vivienne (5), Cerys (5), Philippa (1), Syanna (1), Salma (1), Ves (1)
├── MCM_RomanceQoL.ws          — Flash UI menu ubioru w MCME, pamięć strojów, ar_gift
├── MCM_RomanceTw3seDev.ws     — Warstwa TW3SE (importy natywne, pipe IPC, odczyt VK, hot-reload)
└── MCM_RomanceTw3seDev.stub.ws             — Pusty zamiennik bez TW3SE dla wersji release
```

---

### Szczegółowy Rozkład Odpowiedzialności w Skryptach

### 1. `MCM_RomanceCore.ws`

* **Boot i Cykl Życia (L11-179):**
  * Wstrzyknięcie pól do gracza: `@addField(CR4Player) mcm_ar_core`, `mcm_ar_ambient`, `mcm_ar_bootlog`.
  * Punkt startowy: `@wrapMethod(CR4Player) InitRemasterSettings()` wywołuje `MCM_AR_OnPlayerReady()`. Omija problem cienia priorytetów modów (np. Brothers in Arms).
  * Rejestracja listenera akcji klawisza zgody: `'SwordSheathe'` ([C]).
  * Uruchomienie timerów silnika: `MCM_AR_AutonomousTick` (interwał konfigurowany z MCM: `MCM_AR_TickInterval`, suwak 20-160s co 10s, domyślnie 30s — przez `GetTickIntervalSeconds()`) i `MCM_AR_AmbientTick` (co 10.0s).
* **System Idle-Suspend (W2/I1) (L187-447):**
  * Klasa `MCM_AR_IdleJob`: zarządza zadaniem postoju (NPC, cel, kąt, animacja slotowa, faza).
  * `UpdateIdleSuspend(safe : bool)`: bada bezruch gracza w promieniu 1.5m przez >50s (`arIdleAnchor`). Zawiesza follow przez `StopFollowing(true)` (z zachowaniem tagu `mod_scm_IsFollowing`), kieruje NPC na pozycję obok i uruchamia animację slotową (np. `woman_stand_hand_on_hip_idle` dla Yen, `stand_weight_shift` dla Triss).
  * **Podział zegarów:** tworzenie jobów i próg bezruchu >50s zostają w `ProcessTick` (tick decyzyjny z MCM), natomiast progresja faz jobów (`moving` -> `posed`) oraz pętla wybudzania działają na kanale ambient ~10s (`UpdateIdleAmbient()` + `WakeIdleJobs()`). Dzięki temu pozy towarzyszek pozostają responsywne niezależnie od ustawienia `MCM_AR_TickInterval`.
  * Wybudzenie i wznowienie follow: natychmiast po ruszeniu gracza >1.5m lub wejściu w stan unsafe (walka, menu, dialog).
* **Auto-Pick Wyborów w Scenach Dialogowych (L449-603):**
  * `MCM_AR_OnDialogChoices(choices)`: strukturalna detekcja opcji w scenie `*FollowWithKiss`.
  * Faza 0: wybiera opcję o indeksie 1, jeśli ostatnia opcja to `DialogAction_EXIT`, a choices[1] nie jest wyjściem (niezależne od języka, z fallbackiem słów kluczowych).
  * Faza 1: po pocałunku automatycznie wybiera opcję EXIT, zamykając menu.
* **Filtry Bezpieczeństwa i Budowa Kontekstu (L618-1051):**
  * `MCM_AR_IsSafeToInitiate(out reason)`: blokuje akcje w walce, dialogach, pływaniu, łodzi, otwartym menu i stanach innych niż `Exploration`.
  * `BuildContext(companions)`: agreguje czas gry (`isNight`, `isDawn`), stan zdrowia, ognisko (<6m; encja z tagiem `campfire` lub `CarriesOpenFire`/TAG_OPEN_FIRE — obejmuje palone paleniska, bez aktorów), karczmę (`player_in_inn`), Corvo Bianco, odległość NaughtyPoint oraz obecność rywalek (`rivalCount`).
* **Maszyny Stanów STAGED i AMBIENT (L1052-1418):**
  * `MCM_AutonomousRomanceCore`: stan `Idle` oraz `ProcessingTick` (interwał `MCM_AR_TickInterval`, domyślnie 30s; pętla STAGED z lockiem `interactionBusy`, watchdogiem 300s i post-staged cooldownem 90s).
  * `MCM_AmbientRomanceChannel`: stan `Idle` oraz `AmbientTick` (co 10s; pętla AMBIENT dla powitań po rozłące >60s oraz jednolinijkowców T1).
* **Komendy Diagnostyczne Konsoli (L1419-1876):**
  * `ar_status`, `ar_reset`, `ar_force`, `ar_devreset`, `ar_idlenow`, `ar_consent`, `ar_affinity`, `ar_trigger`, `ar_logdump`, `ar_bootlog`, `ar_diag`, `ar_line`, `ar_probeanim`, `ar_debug`, `ar_eval`.

### 2. `MCM_RomanceInteraction.ws`

* **Struktury i Enumy (L10-43):**
  * `enum ERomanceTriggerType`: `RTT_OneLiner` (T1 Bark), `RTT_Gesture` (T2 Gest), `RTT_Prompt` (T3 Prompt ze zgodą), `RTT_Scene` (T4 Scena z pocałunkiem/intymna).
  * `class MCM_RomanceContext`: kontener danych środowiskowych przekazywany do bramek akcji.
* **Klasa Bazowa `MCM_RomanceInteraction` (L44-1238):**
  * Parametry: `id`, `targetNpc`, `minAffinity`, `cooldownSeconds`, `triggerType`, `weight`, `barkMimic`, `lineId`, `lineText`, `lineKey` (klucz w3strings, `lineText` = fallback EN), `barkVoiceset`; klasy gift dodatkowo `thanksLineId`/`thanksLineText`/`thanksLineKey`.
  * Bramki: `CanExecute()` -> `GetBlockReason()` (cooldowny, backoff odrzucenia 300/900/1800s, minAffinity, zazdrość, max odległość 15m) + `GetExtraBlockReason()` w klasach pochodnych.
  * Staging lokomocji:
    * `SoftApproach`: podejście towarzyszki do Geralta (`ActionMoveToNodeAsync`), wyłączenie kolizji, suspensja follow.
    * `WaitForApproach`: timeout 8s, przerwanie przy walce lub odejściu gracza >25m.
    * `HardStage`: zablokowanie ruchu gracza (`thePlayer.BlockAction(EIAB_Movement, 'MCM_AR_interaction')`), obrót twarzą w twarz.
    * `EndSoft` / `EndInteraction`: czyszczenie stanu, odblokowanie gracza, przywrócenie kolizji i wznawianie podążania.
  * Consent Engine v3 `ShowConsentPrompt(text, timeout, npc)` (L522-713):
    * Komunikat HUD: suffix lokalizowany kluczem `ar_prompt_consent_hint` (EN: `(hold [C] ~1s or tap twice)`).
    * Odejście gracza >12m traktowane jako odmowa.
    * Obsługa Hold (~1.0s) i Double-Tap (<0.7s) oparte na zdarzeniach `OnMCM_AR_ConsentKey` oraz weryfikacji akcji `IsPressed(theInput.GetAction('SwordSheathe'), true)`. W trybie DEV bezpośredni odczyt VK przez `MCM_AR_DevKeyDown`.
  * Odtwarzanie Scen i Integracja MCME (L740-1238):
    * `PlayDialogueScene(npc, path, autoPick)`: zatrzymanie joba MCME (`worker.forceStop()`), uzbrojenie flag auto-pick, start sceny przez `StorySceneSystem`.
    * `WaitForSceneEnd(npc, timeout)`: latentne oczekiwanie z auto-wyborem opcji dialogowych (`OnDialogOptionSelected` + `OnDialogOptionAccepted`), wczesne zwolnienie ruchu gracza po wyjściu gracza z cutsceny.
    * `PlayIntimateScene(npc)`: pipeline intymny z NaughtyPoints (punkt <=16m w `IsOnNaughtyPoint()`). Obsługuje ścieżkę zarejestrowaną (`PreNaughtyWith`) oraz manualną (`dlc\mod_spawn_companions\naughty\<npc>\anywhere.w2scene`).
* **Rejestr Akcji `MCM_RomanceActionRegistry` (L1239-1400):**
  * Centralna tablica `actions: array<MCM_RomanceInteraction>`.
  * `TryExecute(npc, player, ctx, out eligCount, optional ambientOnly)`: filtrowanie wg NPC, kanału, sprawdzanie bramek, losowanie ważone (`weight`) i wywołanie `Execute()`.
* **Wrappery i Zdarzenia Globalne (L1401-1547):**
  * `event OnMCM_AR_ConsentKey(action)`: rejestruje stan naciśnięcia klawisza `'SwordSheathe'`.
  * `MCM_AR_GetCompanionDisplayName(npc)`: resolver czytelnych nazw dla HUD.
  * `MCM_AR_ProbeAnim(npc, animName)`: sonda sprawdzająca obecność animacji slotowej w modelu NPC.
  * `@wrapMethod(CR4HudModuleDialog) OnDialogChoicesSet` i `SendDialogChoicesToUI`: przechwytują wybory dla auto-picku.

### 3. `MCM_RomanceAffinity.ws`

* **`MCM_AR_ConfigWrapper` (L11-100):**
  * Dostęp do `user.settings` (`CInGameConfigWrapper`, sekcja `MCM_AR`).
  * Gettery: `IsEnabled()`, `GetInitiativeCooldown()`, `GetTickIntervalSeconds()` (clamp 20-160s, default 30), `GetAffinityMultiplier()`, `IsJealousyModeOn()`, `IsForceRomanceOn()`, `RequiresPlayerConsent()`, `IsDebugHudOn()`.
  * UWAGA: XML menu (`bin\config\r4game\user_config_matrix\pc\modMCME_AutonomousRomance.xml`) NIE jest junction-em jak `Mods\` — po każdej zmianie opcji kopiuj go ręcznie do `<gra>\bin\config\...` i zrestartuj grę (menu czyta XML przy starcie).
* **Helpery lokalizacji (L174-211):** `AR_T(key, fallback)`, `AR_ReplToken`, `AR_Fmt` — patrz sekcja 6.
* **Centralne Logowanie `MCM_AR_Log` (L117-160):**
  * Ring-bufor 60 wpisów w pamięci RAM (`ar_logdump`).
  * Zrzut do `LogChannel('MCM_AR', msg)`.
  * Przekazanie do TW3SE przez `MCM_AR_DevLog(msg)`.
  * Opcjonalne wyświetlanie na HUD (`thePlayer.DisplayHudMessage`).
* **Silnik Zażyłości `MCM_RomanceAffinityResolver` (L171-306):**
  * **Formuła obliczania:**
    $$\text{Total Affinity} = \text{BaseStory} + (\text{Earned} \times \text{Multiplier})$$
  * Tryb Sandbox (`ForceRomance`): stałe 200 pkt.
  * `GetBaseStoryAffinity(npcName)`: ewaluacja faktów questowych (np. `sq202_yen_girlfriend` +50, `q309_triss_stayed` +50, itd.).
  * `GetEarnedAffinity(npcName)`: odczyt faktów silnikowych `mcme_ar_<npcName>_affinity` (+1 za udaną akcję, +3 za prezent).

### 4. `MCM_RomanceActions_Main.ws` i `MCM_RomanceActions_DLC.ws`

* Łącznie 35 klas akcji czteroetapowych + 11 klas `*_GiftRequest` (bazowa `MCM_AR_GiftRequest_Base` w Interaction.ws) dziedziczących po `MCM_RomanceInteraction` rejestrowanych w `InitDefaultActions()`:
  * **Yennefer (7):** `yen_oneliner_flirt`, `yen_postcombat_care`, `yen_night_invitation`, `yen_campfire_evening`, `yen_intimate_invite`, `yen_jealousy_snark`, `yen_tavern_wine`.
  * **Triss (7):** `triss_oneliner_flirt`, `triss_postcombat_hug`, `triss_night_whisper`, `triss_campfire_warmth`, `triss_garden_kiss`, `triss_intimate_invite`, `triss_jealousy_snark`.
  * **Keira (5):** `keira_oneliner_flirt`, `keira_postcombat_heal`, `keira_night_proposal`, `keira_campfire_witch`, `keira_intimate_invite`.
  * **Shani (4):** `shani_oneliner_flirt`, `shani_postcombat_medic`, `shani_night_relax`, `shani_intimate_invite`.
  * **Anna Henrietta (4):** `anarietta_oneliner_flirt`, `anarietta_postcombat_pride`, `anarietta_night_royal`, `anarietta_intimate_invite`.
  * **Vivienne (4):** `vivienne_oneliner_flirt`, `vivienne_campfire_mystery`, `vivienne_night_invitation`, `vivienne_intimate_invite`.
  * **Cerys (4):** `cerys_oneliner_flirt`, `cerys_postcombat_skellige`, `cerys_night_invitation`, `cerys_intimate_invite`.

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
| **16.0m** | `MCM_RomanceInteraction.ws#L1053` (`IsOnNaughtyPoint`) | **Twarda bramka kwalifikacji:** akcja T4 kwalifikuje się do odpalenia tylko w tej odległości od punktu intymnego. |
| **20.0m** | `MCM_RomanceInteraction.ws#L1109` (`PlayIntimateScene`) | **Check defensywny:** weryfikacja tuż przed startem sceny, czy gracz nie odszedł za daleko. |
| **30.0m** | `MCM_RomanceCore.ws#L772` | **Strefa wejścia:** jednorazowe powiadomienie na HUD o dostępności intymnego miejsca. |
| **40.0m** | `MCM_RomanceCore.ws#L1131` | **Reset histerezy:** odejście na ten dystans resetuje flagę powiadomienia HUD. |

---

## 3. Kompletny Indeks Konsoli Debugującej (22 Komendy `exec`)

| Komenda konsoli | Plik źródłowy | Działanie |
| --- | --- | --- |
| `ar_test()` | `Core.ws:L76` | Szybki test działania moda na `thePlayer` |
| `ar_status()` | `Core.ws:L1419` | Wypisuje status: tryby, bezpieczny stan gry, cooldowny, zażyłość postaci |
| `ar_reset()` | `Core.ws:L1487` | Czyści cooldowny wszystkich akcji |
| `ar_force()` | `Core.ws:L1498` | Włącza/wyłącza tryb Sandbox (`ForceRomance`) |
| `ar_devreset()` | `Core.ws:L1523` | Czyści osierocone flagi stanu zgody gracza |
| `ar_idlenow()` | `Core.ws:L1542` | Wymusza przejście towarzyszek w Idle-Suspend |
| `ar_consent()` | `Core.ws:L1553` | Symuluje naciśnięcie klawisza zgody [C] z konsoli |
| `ar_affinity(npc, n)` | `Core.ws:L1574` | Dodaje `n` punktów zażyłości dla wskazanego NPC |
| `ar_trigger()` | `Core.ws:L1588` | Resetuje cooldowny i natychmiast odpala tick decyzyjny |
| `ar_logdump(optional n)` | `Core.ws:L1601` | Wypisuje na HUD ostatnie `n` linii z bufora logów |
| `ar_bootlog()` | `Core.ws:L1630` | Wyświetla logi z fazy ładowania silnika |
| `ar_diag()` | `Core.ws:L1648` | Zrzut markerów diagnostycznych z `user.settings` |
| `ar_line(npc, lineId)` | `Core.ws:L1713` | Odtwarza wybraną kwestię dialogową na żywo (test audio) |
| `ar_probeanim(npc, anim)` | `Core.ws:L1740` | Sprawdza obecność animacji slotowej w modelu postaci |
| `ar_debug(optional mode)` | `Core.ws:L1762` | Włącza/wyłącza powiadomienia o tickach na ekranie HUD |
| `ar_eval()` | `Core.ws:L1793` | **Dry-run:** sprawdza bramki wszystkich akcji i wypisuje powody ewentualnych blokad |
| `ar_dress(optional npc)` | `QoL.ws:L188` | Zmienia strój towarzyszki na normalny |
| `ar_undress(optional npc)` | `QoL.ws:L197` | Zmienia strój towarzyszki na bieliznę |
| `ar_naked(optional npc)` | `QoL.ws:L211` | Zmienia strój towarzyszki na nagość |
| `ar_gift(optional npc)` | `QoL.ws:L230` | Wręcza butelkę alkoholu z ekwipunku (+3 affinity) |
| `ar_devinfo()` | `Tw3seDev.ws:L159` | Wypisuje status połączenia z TW3SE |
| `ar_reload()` | `Tw3seDev.ws:L183` | Wymusza hot-reload skryptów przez TW3SE |

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
   Nie włączaj kolizji fizycznych u towarzyszek MCME (`EnableCharacterCollisions`) – celowo są przenikalne, aby nie blokować drzwi i AI.
8. **Klawisz Akceptacji Romansu:**
   Nigdy nie używaj `[E]` (konflikt z menu MCME). Zgoda gracza jest podpięta pod `'SwordSheathe'` ([C]).
9. **Izolacja Warstwy TW3SE:**
   Wszelkie odwołania do funkcji `TW3SE_*` mogą znajdować się wyłącznie w `MCM_RomanceTw3seDev.ws`.

---

## 5. Checklist Dodawania Nowej Postaci (Rozszerzanie Roostera)

Procedura dodawania nowej postaci (np. Salma, Philippa, Syanna, Ves):

1. **Rejestracja Nazwy:** W `MCM_RomanceCore.ws#L684` dopisz voicetag postaci do `MCM_AR_IsRomanceNPC`.
2. **Nazwa dla HUD:** W `MCM_RomanceInteraction.ws#L1089` dopisz mapowanie `nam` na nazwę czytelną w `MCM_AR_GetCompanionDisplayName`.
3. **Baza Zażyłości:** W `MCM_RomanceAffinity.ws#L190` dodaj fakty questowe w `GetBaseStoryAffinity`.
4. **Ścieżka Sceny Naughty:** W `MCM_RomanceInteraction.ws#L1061` dopisz ścieżkę `.w2scene` do `NaughtyScenePath`.
5. **Weryfikacja Zasobów Scen:** Upewnij się, że ścieżka `.w2scene` znajduje się w `scripts\known_scenes.txt`.
6. **Implementacja Klas Akcji:** Utwórz nową klasę dziedziczącą po `MCM_RomanceInteraction`:
   * Zdefiniuj parametry w konstruktorze (`id`, `targetNpc`, `minAffinity`, `cooldownSeconds`, `triggerType`, `weight`).
   * Wszelkie warunki umieszczaj w `GetExtraBlockReason()`.
   * Zaimplementuj latentną metodę `Execute(npc, player, ctx)` pamiętając, aby na każdej ścieżce wyjścia wywołać `EndSoft()` lub `EndInteraction()`.
7. **Lokalizacja tekstów:** każdy nowy tekst renderowany graczowi dostaje `lineKey`/`thanksLineKey`/`AR_T("ar_*", "fallback EN")` oraz wpisy w `en.w3strings.csv` i `pl.w3strings.csv` (kolejne id 211880xxxx) + re-encode obu plików `w3stringsr`.
8. **Rejestracja w Rejestrze:** Zarejestruj nową akcję przez `RegisterAction(new MCM_AR_<npc>_<akcja> in this)` wewnątrz `@wrapMethod(MCM_RomanceActionRegistry) InitDefaultActions()`.
9. **Weryfikacja Kompilatorem:** Uruchom `precheck_syntax.ps1` oraz `test_compile.ps1`.

---

## 6. Lokalizacja (W3Strings)

Wszystkie teksty renderowane graczowi (napisy barków, prompty zgody, komunikaty HUD, etykiety menu) przechodzą przez paczkę `.w3strings` w `Mods\modMCME_AutonomousRomance\content\`.

* **Helpery (`MCM_RomanceAffinity.ws`):**
  * `AR_T(key, optional fallback)` — pobiera tekst przez `GetLocStringByKeyExt`; gdy klucza brak (starsza/brakująca paczka) zwraca zaszyty na sztywno fallback angielski. Zawsze podawaj fallback = tekst EN.
  * `AR_Fmt(text, arg1, arg2, arg3)` — podmienia tokeny `{1}`/`{2}`/`{3}` (brak `StrReplace` w WitcherScript; implementacja na `StrFindFirst`+`StrMid`).
* **Konwencja kluczy (id-space `211880xxxx`):**
  * `ar_line_*` — napisy barków akcji (pole `lineKey` w klasach akcji; `lineText` pozostaje jako fallback EN i treść dla `lineId`),
  * `ar_thanks_*` — linie podziękowania po prezencie (`thanksLineKey`),
  * `ar_prompt_*` — prompty zgody `[C]` (w tym `ar_prompt_consent_hint` = wspólny suffix),
  * `ar_msg_*` — komunikaty HUD (heal, prezent, nastrój intymny, generyczna nazwa towarzyszki),
  * `ar_menu_*`/`ar_outfit_*` — enum ubioru w menu MCME,
  * `option_mcm_ar_opt_*` / `option_MCM_AR_*` — etykiety opcji MCM (podwójne klucze wg istniejącej konwencji).
* **Pliki:** źródła `en.w3strings.csv` / `pl.w3strings.csv` (UTF-8), binaria enkodowane przez `Tools\w3stringsr encoder\w3stringsr.exe --id-space 18800 <csv> <w3strings>`. Pozostałe języki (`ar/br/cn/cz/de/es/esmx/fr/hu/it/jp/kr/ru/tr/zh`) to bajtowe kopie `en.w3strings` = fallback na angielski. CSV nie trafiają do paczki release (usuwane przez `package_release.ps1`) — binaria muszą być aktualne.
* **Nazwy itemów prezentów:** nie tłumaczymy ręcznie — `GetLocStringByKeyExt(thePlayer.inv.GetItemLocalizedNameByName(item))` zwraca nazwę w języku gry (fallback na surowe id). Uwaga: `inv.GetItemName(item)` zwraca surowy `name`, NIE tekst zlokalizowany.
* **Kanał deweloperski `[AR]`:** logi `MCM_AR_Log` i komunikaty komend `ar_*` (status, eval, logdump itd.) są kanałem dev/diagnostycznym — pozostają **po angielsku** i celowo nie są lokalizowane.
* **Podmiany w tekstach:** `{1}`/`{2}`/`{3}` zastępowane przez `AR_Fmt` — w tłumaczeniach zachowuj tokeny i dostosuj kolejność do gramatyki języka.
