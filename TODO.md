# MCME Autonomous Romance - Roadmap & TODO

> 📐 Pełna architektura, flow i plan etapów (W0–W7): [ARCHITECTURE.md](ARCHITECTURE.md)

## 🎯 Priorytet 1: Uruchomienie i stabilizacja wersji bazowej (W TOKU)
- [ ] Zdiagnozować dlaczego mod bazowo nie reaguje/nie działa w grze.
- [ ] Sprawdzić logi runtime `scriptslog.txt` oraz diagnostykę komendami exec (`ar_status`, `ar_trigger`, `ar_force`, `ar_eval`).
- [ ] Zweryfikować rejestrację towarzyszek i hooki ticków w `MCME_AutonomousRomance`.
- [ ] Upewnić się, że podstawowe akcje (Tier 1 banter, Tier 2 opieka po walce, Tier 3 zaproszenia) działają poprawnie w grze.

---

## 📋 Backlog / Pomysły do wdrożenia (Po uruchomieniu bazy)

### 👗 Rozbieranie towarzyszek „na zawołanie” (Sposób 3)
- **Cel:** Umożliwienie dynamicznego rozbierania i ubierania towarzyszek bez konieczności instalowania globalnych modów nude (`modNudeAllInOne`), które rozbierają cały świat gry 24/7.
- **Implementacja:**
  - Wykorzystanie istniejących metod w `modMCME_Remastered`:
    ```ws
    npc.ApplyAppearance(specialData.nakedAppearance);    // applyNakedAppearance()
    npc.ApplyAppearance(specialData.defaultAppearance);  // applyNormalAppearance()
    npc.ApplyAppearance(specialData.underwearAppearance);// applyUnderwearAppearance()
    ```
  - **Wariant A (Menu dialogowe):** Opcja interakcji w kole/dialogu towarzyszki: `[Zdejmij ubranie]` / `[Ubierz się]`.
  - **Wariant B (Automatyka romansu):** Automatyczna zmiana stroju na nagi/bieliznę przy wejściu w sceny intymne (Tier 3 / Tier 4) oraz powrót do standardowego stroju po zakończeniu sceny.

---

## 🔧 Do zrobienia (następna sesja — po hardeningu kolizji/consent)

- [x] **Klawisz zgody: `[E]` → `[C]`** (ZROBIONE, v2) — `[E]`/`Interaction`/`Talk` odpalało jednocześnie dialog MCME z towarzyszem (podwójny efekt, dlatego `triss_intimate_invite` kończyło się `Odmowa` 2× w teście). **v2 fix:** pierwsza próba `MCM_K_C` była martwa — binding `IK_C=(Action=MCM_K_C)` siedzi w sekcji `[SCMMenuBase]` input.settings, więc dispatchuje TYLKO gdy aktywne jest menu MCME, nigdy w eksploracji → prompt zawsze timeoutował (to wyjaśnia też "ciszę" intimate po przejściu na `[C]`). Ostatecznie: nasłuch `'SwordSheathe'` (vanilla akcja `[C]` zbindowana w `[Exploration]` + `[Combat]`, zero konfiguracji) — listener w `MCM_AR_OnPlayerReady` (Core l.57), polling `GetActionValue/GetLastActivationTime('SwordSheathe')` w `ShowConsentPrompt` (Interaction l.497-498), teksty `[C]` zostają. Efekt uboczny: zapiecie/schowanie miecza przy akceptacji (kosmetyczne). Prompty nie strzelają w walce (gate `IsInCombat`).
- [ ] **Dużo `blocked:` w `ar_eval` — ANALIZA ZROBIONA, to nie jest bug.** Log z testów (h=22-23, Corvo, rywalki=2, naughty=true): per NPC ~2 eligible (night_invitation + intimate_invite), reszta `blocked:` z poprawnymi powodami kontekstowymi (`night`, `no_campfire`, `hp_ok`, `jealousy_off`, `not_in_tavern`, `cooldown`). To zamierzone filtrowanie repertuaru — ar_eval wypisuje WSZYSTKIE akcje rejestru, nie tylko sezonowe. DO DECYZJI (nie zaimplementowane): nocny „wypełniacz" Tier-1 (whisper-bark bez sceny, np. wariant oneliner_flirt z `isNight`) albo luźniejsze gatingi — wymaga doboru lineId/napisów.
- [x] **Auto-pick opcji "kiss" w scenach `*FollowWithKiss`** (Etap E, ZROBIONE + diag v2) — sceny MCME pokazują hub-menu [follow/kiss/naughty/exit]; nasze akcje `Night*`/`GardenKiss` teraz same wybierają kiss i zamykają menu. Mechanizm: `@wrapMethod OnDialogChoicesSet` **+ `@wrapMethod SendDialogChoicesToUI`** (Interaction, koniec pliku — oba punkty łapiące dostarczenie wyborów; handler idempotentny przez guard `arPendingPickIdx>=0`) → `MCM_AR_OnDialogChoices` (Core; phase 0=kiss keywords EN/PL/DE/FR/ES, phase 1=DialogAction_EXIT+fallback tekstowy) → `WaitForSceneEnd` wykonuje `OnDialogOptionSelected`+`OnDialogOptionAccepted` (wzorcem tw3-automatic-dialog-picker, delay 0.35+0.3s = menu mignie). Arm/disarm: `PlayDialogueScene(..., autoPick)` + bezpieczniki w `EndStagedInteraction`/`ResetAllCooldowns`/watchdog `BeginStagedInteraction`. Diag v2: `OnDialogChoices entry: n=X autoPick=Y phase=Z` przy każdym strzale + `autoPick ARMED/NIE uzbrojony` w PlayDialogueScene → następny test rozstrzygnie "wrap nie strzela" vs "flaga nie uzbrojona". **OTWARTE:** w teście 14:15 scena zagrała ale ZERO logów `dlg choice` — wrap nie strzelił lub arAutoPick=false.
- [ ] **Triss intimate – główna przyczyna znaleziona: martwy klawisz consent.** `MCM_K_C` w `[SCMMenuBase]` nigdy nie dispatchowało w eksploracji → każdy prompt timeoutował → `Odmowa`. Po przejściu na `SwordSheathe` (fix v2) `[C]` działa. `PlayIntimateScene` ma WARN gdy `mod_scm_GetNPC(nm, ST_Special, false)` NULL + log `IntimateScene end: ok=`. Retest: podejdź do punktu (Passiflora / dom Triss / sypialnia Corvo), akceptuj `[C]`, sprawdź w scriptslog.
- [ ] **"NPCe są duchami" (brak kolizji) — ZDIAGNOZOWANE: to design MCME, nie nasz bug.** `SpawnCompanionsSCMCC.ws`: `initCommon` (l.1027) wyłącza kolizje przy spawnie, `update4Second` (l.568) co 4s re-wyłącza w stanie `NewIdle`, `RefreshMimics` (l.1889) po każdym dialogu gdy `wasInDialogue` (nigdy nie resetowane), `endFriendlyCombat` (l.2051). Jedyny `EnableCharacterCollisions(true)` w MCME = `startFriendlyCombat` (l.2041). Companioni są celowo "duchami" żeby nie blokować Geralta. Nasze `EnableCharacterCollisions(true)` w `EndSoft`/`EndInteraction` jest nadpisywane przez MCME w ≤4s. DO DECYZJI: jeśli kolizje companionów mają wrócić na stałe → trzeba wrapować `update4Second`/`RefreshMimics` w MCME (ryzykowne, psuje design moda) albo zostawić.

## 2026-06-10 sesja 15:xx - trzy fixy po runtime-diag
- ShowConsentPrompt: GetLastActivationTime zwraca CZAS OD aktywacji (nie timestamp) - warunek poprawiony na '> 0 && < elapsed' (wcisniecie [C] w oknie promptu). Wczesniejszy '> initTime' auto-akceptowal natychmiast -> sceny intymne bez zgody.
- IsSafeToInitiate: wymagany theInput.GetContext()=='Exploration' (blokada gdy gracz w menu SCMMenuBase/RadialMenu - prompt byl niewidoczny).
- autoPick keywords: sceny FollowWithKiss nie maja opcji 'pocaluj' - linia romansu 'Kocham cie, X'. Dodane: kocham/love/liebe/'aime/ amo/quiero/miluj/adore (bound-owane przeciw IT/ES/FR false-positive: andiamo, vamos, lasciamo, vraiment).
- Wrap dziala! Log potwierdzil OnDialogChoices entry + dlg choice[0..4] dla yen FollowWithKiss.
- TODO test: czy 'Kocham cie' faktycznie odpala animacje kiss w scenie (moze byc tylko voice line).

## 2026-06-10 sesja 16:xx - auto-pick: podejscie strukturalne zamiast keywords

- **Badanie ekstrakcji stringId z .w2scene (odp.: nierealizowalne praktycznie).** Teksty opcji dialogowych nie istnieja jako plaintext: ani w bundlach MCME (dlc_anarietta_vivienne/blob0.bundle), ani w zadnym .w3strings (wszystkie modowe = 0-bajtowe stuby Vortexa), ani w plpc.w3speech, ani w content0\pl.w3strings (vanilla nie zawiera 'Kocham'/'pytania'/'Mam '). Sceny trzymaja tylko LocalizedString = uint32 id w binarnej sekcji obiektow; SSceneChoice nie eksponuje pola id; CStorySceneSystem/CStoryScene nie maja introspekcji wyborow. Ekstrakcja id-ow wymagalaby pelnego parsera CR2W + mapowania id->opcja.
- **Wdrozone: wybor STRUKTURALNY po szablonie sceny.** Wszystkie sceny *FollowWithKiss sa auto-generowane z jednego szablonu (zweryfikowane binarnie: 12288B, passionate_kiss_f, dokladnie 1 element CStorySceneChoice). Hub-menu ma zawsze uklad: [0] wyjscie-link, [1] **linia romansu = kiss**, [2] wejscie naughty, [3] hub pytan, [4] wyjscie z ikona EXIT. Wybor: idx=1 gdy 
>=3, ostatnia opcja dialogAction == DialogAction_EXIT (enum � locale-free) i choices[1] nie jest exit/disabled. Keywords zostaly jako fallback dla scen o odmiennym ukladzie. **100% niezalezne od jezyka gry** (dziala tez w JP/RU/CN itd.).
- Logi runtime potwierdzily szablon: yen [1]='Kocham cie, Yen.', triss [1]='Ja... Kocham cie.', ostatnia opcja ct=8192 (DialogAction_EXIT) w obu.
- Precheck: 0 bledow.
## Gifty dla towarzyszek - design (zatwierdzony kierunek: C1)

Kontekst: r_gift exec (QoL ws ~l.191) juz konsumuje pierwsza butelke wina z EQ i daje +3 affinity. Przeksztalcamy to w pelna mechanike. Lista itemow prezentowych NIE zmienia sie (est_est, erveluce, fiorano, metinna_rosee, Alcohest, Dwarven spirit).

### C1 - NPC prosi, gracz akceptuje [C] (DO IMPLEMENTACJI)

Wzorzec Tier-4 consent przeniesiony na prezenty:

`ws
class MCM_AR_<npc>_GiftRequest extends MCM_RomanceInteraction
    triggerType = RTT_Prompt;  minAffinity ~= 20;  cooldown ~= 30min
    GetExtraBlockReason: !PlayerCarriesGift() -> "no_gift"
    Execute: SoftApproach -> bark(prosba) ->
        ShowConsentPrompt("[C] Podaruj <item> dla <npc>", 10.0)
        -> accept: RemoveItem + AddAffinity + thanks bark/gesture
        -> reject/timeout: EndSoft + MarkRejected + lekka odmowa bark
`

- NPC jest inicjatorem (autonomia), item schodzi tylko po [C] - nigdy bez zgody.
- Reuzycie: ShowConsentPrompt (SwordSheathe polling, odszedl=odmowa, timeout=odmowa).
- Flavor: tabela preferencji per NPC (kolejnosc wyboru itemu; np. Cerys -> Dwarven spirit, Yen -> est_est) - sama LISTA itemow zostaje jak w ar_gift.
- Potrzebne: lineId/barkVoiceset na "prosba" i "podziekowanie" per NPC (kuratowane linie MCME jak w pozostalych akcjach).
- Zero kontaktu z auto-pickiem scen (gift nie uzywa PlayDialogueScene).
- Zakres: wszystkie 11 towarzyszek z akcjami (yen/triss/keira/shani/cerys/anarietta/vivienne/salma/philippa/syanna/ves wg rejestru).

### C2 - gracz-inicjowane wr�czenie (BACKLOG - nie implementowac teraz)

Skrot klawiszowy do ar_gift: gracz blisko towarzyszki + ma prezent -> hint "[C] Podaruj prezent" -> [C] wrecza. Watcher w ticku core, debounce (raz na ~10min per NPC lub na zmiane stanu ma-prezent). Osobny feature, niezalezny od C1 - dopisac pozniej jesli chcemy tez reczne wr�czanie.

### Odrzucone

- Czysta autonomia (NPC bierze wino bez potwierdzenia): konsumpcja EQ bez zgody gracza = zly UX.
- Gift jako opcja w hub-menu sceny: .w2scene to skompilowane binarki, brak narzedzi autorskich; opcje nie dodadza sie do istniejacych scen.
### Custom VO dla linii moda (BACKLOG "przemyslec" - bardzo odlegle)

AI-TTS (klon glosu Triss/Yen/itd.) na krotkie odpowiedzi PL+EN dla naszych akcji (gift prosba/podziekowanie itd.). Realne koszty: pipeline .wem->sound.bundle + wcc_lite/Wwise wiring + prawa do glosu aktorow (szara strefa). Do rozwazenia DOPIERO gdy mod sie przyjmie; na teraz: kuratowane vanilla lineId + HUD tekst.