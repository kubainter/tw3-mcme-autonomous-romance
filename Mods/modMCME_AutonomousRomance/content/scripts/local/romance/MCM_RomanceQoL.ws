/*****************************************************************************/
/* MCME Autonomous Romance - QoL                                             */
/* Ubiór w menu towarzysza MCME + prezenty + execy ubioru                    */
/* Wymaga: modMCME_Remastered 5.00+                                          */
/*****************************************************************************/

// ---------------------------------------------------------------------------
// Czy NPC ma sensowne warianty ubioru? (puste lub identyczne z default
// = nic do przełączania – np. Cerys ma wszędzie '__q208_crown')
// ---------------------------------------------------------------------------
function MCM_AR_NPCHasAltLooks(npc : CNewNPC) : bool
{
	var sd : MCM_NPCEntry;

	if (!npc || !npc.scmcc) return false;
	sd = npc.scmcc.specialData;
	if (!sd) return false;

	if (IsNameValid(sd.nakedAppearance) && sd.nakedAppearance != sd.defaultAppearance) return true;
	if (IsNameValid(sd.underwearAppearance) && sd.underwearAppearance != sd.defaultAppearance) return true;
	return false;
}

// Zastosuj ubiór wg indeksu enuma (0 normalny / 1 bielizna / 2 nago),
// z fallbackiem na normalny gdy wariantu brak. Zapisuje też wybor
// w data.appearance (pole trwale MCME) – ubior przetrwa respawn
// i preselekcja enuma w menu bedzie prawdziwa.
function MCM_AR_ApplyOutfit(npc : CNewNPC, idx : int)
{
	var sd : MCM_NPCEntry;
	var factVal : int;
	if (!npc || !npc.scmcc) return;
	sd = npc.scmcc.specialData;
	if (!sd) return;

	if (idx == 2 && IsNameValid(sd.nakedAppearance) && sd.nakedAppearance != sd.defaultAppearance)
	{
		npc.scmcc.applyNakedAppearance();
		npc.scmcc.data.appearance = sd.nakedAppearance;
		factVal = 3;
	}
	else if (idx == 1 && IsNameValid(sd.underwearAppearance) && sd.underwearAppearance != sd.defaultAppearance)
	{
		npc.scmcc.applyUnderwearAppearance();
		npc.scmcc.data.appearance = sd.underwearAppearance;
		factVal = 2;
	}
	else
	{
		npc.scmcc.applyNormalAppearance();
		npc.scmcc.data.appearance = sd.defaultAppearance;
		factVal = 1;
	}

	FactsSet("mcme_ar_outfit_" + NameToString(npc.scmcc.data.nam), factVal);
}

// ---------------------------------------------------------------------------
// Automatyczne przywracanie zapisanego stroju przy respawnie / reloadzie gry
// ---------------------------------------------------------------------------

@wrapMethod(SCMCompanionControls)
function onSpawned()
{
	var factVal : int;
	wrappedMethod();

	if (this.data && IsNameValid(this.data.nam))
	{
		factVal = FactsQuerySum("mcme_ar_outfit_" + NameToString(this.data.nam));
		if (factVal == 3)
		{
			this.applyNakedAppearance();
			if (this.specialData) this.data.appearance = this.specialData.nakedAppearance;
		}
		else if (factVal == 2)
		{
			this.applyUnderwearAppearance();
			if (this.specialData) this.data.appearance = this.specialData.underwearAppearance;
		}
		else if (factVal == 1)
		{
			this.applyNormalAppearance();
			if (this.specialData) this.data.appearance = this.specialData.defaultAppearance;
		}
	}
}

// ---------------------------------------------------------------------------
// Rozszerzenie menu towarzysza MCME (SCMMenuEditCompanion2) o enum ubioru.
// Bez własnego SWF – doklejamy się do istniejącego flashowego menu.
// ---------------------------------------------------------------------------

@wrapMethod(SCMMenuEditCompanion2)
function OnMenuCreated()
{
	var enumer  : SCMMenu_Enum;
	var sd      : MCM_NPCEntry;
	var factVal : int;

	wrappedMethod();
	if (MCM_AR_NPCHasAltLooks(COMPANION))
	{
		enumer = AddEnum('ar_outfit', "Ubior: ", "Normalny,Bielizna,Nago", ",");
		// Preselekcja na AKTUALNY ubiorz (z bazy faktow lub data.appearance)
		sd = COMPANION.scmcc.specialData;
		if (enumer && sd)
		{
			factVal = FactsQuerySum("mcme_ar_outfit_" + NameToString(COMPANION.scmcc.data.nam));
			if (factVal == 3 || COMPANION.scmcc.data.appearance == sd.nakedAppearance)
				enumer.selectedIndex = 2;
			else if (factVal == 2 || COMPANION.scmcc.data.appearance == sd.underwearAppearance)
				enumer.selectedIndex = 1;
			else
				enumer.selectedIndex = 0;
		}
	}
}

@wrapMethod(SCMMenuEditCompanion2)
function OnChange(element : SCMMenu_BaseElement)
{
	var enumer : SCMMenu_Enum;
	var idx    : int;

	if (element.ID == 'ar_outfit')
	{
		enumer = (SCMMenu_Enum)element;
		if (enumer)
		{
			if (enumer.GetSelectedEnum() == "Bielizna")       idx = 1;
			else if (enumer.GetSelectedEnum() == "Nago")      idx = 2;
			else                                              idx = 0;
			MCM_AR_ApplyOutfit(COMPANION, idx);
			window.PlaySelectSound();
		}
		window.UpdateAndRefresh();
		return;
	}
	wrappedMethod(element);
}

// ---------------------------------------------------------------------------
// Execy pomocnicze (działają na towarzyszce o podanej nazwie; bez argumentu
// biorą najbliższą romansową towarzyszkę w zasiegu 5m).
// ---------------------------------------------------------------------------

function MCM_AR_FindCompanion(npcStr : string) : CNewNPC
{
	var companions : array<CNewNPC>;
	var npc        : CNewNPC;
	var best       : CNewNPC;
	var bestDist   : float;
	var dist       : float;
	var i          : int;

	theGame.GetNPCsByTag('GeraltsBFF', companions);

	// W3Script nie ma StringToName – porownujemy tekstowo (name -> string)
	if (StrLen(npcStr) > 0)
	{
		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc) continue;
			if (StrLower(NameToString(npc.scmcc.data.nam)) == StrLower(npcStr)) return npc;
		}
		return NULL;
	}

	bestDist = 5.0;
	for (i = 0; i < companions.Size(); i += 1)
	{
		npc = companions[i];
		if (!npc || !npc.scmcc) continue;

		dist = VecDistance(thePlayer.GetWorldPosition(), npc.GetWorldPosition());
		if (dist < bestDist)
		{
			bestDist = dist;
			best = npc;
		}
	}
	return best;
}

exec function ar_dress(optional npcStr : string)
{
	var npc : CNewNPC;
	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc) { thePlayer.DisplayHudMessage("[AR] Brak towarzysza w zasiegu."); return; }
	MCM_AR_ApplyOutfit(npc, 0);
	thePlayer.DisplayHudMessage("[AR] " + NameToString(npc.scmcc.data.nam) + ": ubior normalny.");
}

exec function ar_undress(optional npcStr : string)
{
	var npc : CNewNPC;
	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc) { thePlayer.DisplayHudMessage("[AR] Brak towarzysza w zasiegu."); return; }
	if (!MCM_AR_NPCHasAltLooks(npc))
	{
		thePlayer.DisplayHudMessage("[AR] " + NameToString(npc.scmcc.data.nam) + " nie ma wariantow ubioru.");
		return;
	}
	MCM_AR_ApplyOutfit(npc, 1);
	thePlayer.DisplayHudMessage("[AR] " + NameToString(npc.scmcc.data.nam) + ": bielizna.");
}

exec function ar_naked(optional npcStr : string)
{
	var npc : CNewNPC;
	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc) { thePlayer.DisplayHudMessage("[AR] Brak towarzysza w zasiegu."); return; }
	if (!MCM_AR_NPCHasAltLooks(npc))
	{
		thePlayer.DisplayHudMessage("[AR] " + NameToString(npc.scmcc.data.nam) + " nie ma wariantow ubioru.");
		return;
	}
	MCM_AR_ApplyOutfit(npc, 2);
	thePlayer.DisplayHudMessage("[AR] " + NameToString(npc.scmcc.data.nam) + ": nago.");
}

// ---------------------------------------------------------------------------
// Prezent: ar_gift(<npc>) – konsumuje pierwszą znalezioną butelkę wina
// z ekwipunku Geralta, +3 affinity, reakcja towarzyszki.
// ---------------------------------------------------------------------------

exec function ar_gift(optional npcStr : string)
{
	var npc      : CNewNPC;
	var npcName  : name;
	var wines    : array<name>;
	var w        : name;
	var i        : int;

	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc)
	{
		thePlayer.DisplayHudMessage("[AR] Brak towarzysza w zasiegu (5m) lub zla nazwa.");
		return;
	}
	npcName = npc.scmcc.data.nam;

	// Kandydaci prezentowi – wina/alkohole z inventory gry
	wines.PushBack('est_est');
	wines.PushBack('erveluce');
	wines.PushBack('fiorano');
	wines.PushBack('metinna_rosee');
	wines.PushBack('Alcohest');
	wines.PushBack('Dwarven spirit');

	w = '';
	for (i = 0; i < wines.Size(); i += 1)
	{
		if (thePlayer.inv.GetItemQuantityByName(wines[i]) > 0)
		{
			w = wines[i];
			break;
		}
	}

	if (!IsNameValid(w))
	{
		thePlayer.DisplayHudMessage("[AR] Brak prezentu w ekwipunku (wino/alkohol).");
		return;
	}

	// Zdejmij item DOPIERO po potwierdzeniu, że istnieje
	thePlayer.inv.RemoveItemByName(w, 1);
	MCM_AR_GetAffinity().AddAffinityPoints(npcName, 3);

	// Reakcja: head look-at + mimika + napis
	npc.EnableDynamicLookAt(thePlayer, 6.0);
	npc.PlayVoiceset(100, 'greeting_geralt');
	thePlayer.DisplayHudMessage("[AR] Podarowano " + NameToString(w) + " dla " + NameToString(npcName) + " (+3 zazylosci)");
	MCM_AR_Log("[AR] Gift: " + NameToString(w) + " -> " + NameToString(npcName));
}
