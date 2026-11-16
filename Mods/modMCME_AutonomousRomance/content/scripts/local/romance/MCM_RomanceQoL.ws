/*****************************************************************************/
/* MCME Autonomous Romance - QoL                                             */
/* Ubiór w menu towarzysza MCME + prezenty + execy ubioru                    */
/* Wymaga: modMCME_Remastered 5.00+                                          */
/*****************************************************************************/

// Czy NPC ma sensowne warianty ubioru? (puste lub identyczne z default
// = nic do przełączania – np. Cerys ma wszędzie '__q208_crown')
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

// Ubior wg indeksu (0 normal / 1 bielizna / 2 nago), fallback na normal.
// data.appearance + fakt = preselekcja w menu i przetrwanie respawnu.
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

	FactsRemove("mcme_ar_outfit_" + NameToString(npc.scmcc.data.nam));
	FactsAdd("mcme_ar_outfit_" + NameToString(npc.scmcc.data.nam), factVal);
}

// Przywracanie zapisanego stroju przy respawnie / reloadzie gry

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

// Enum ubioru w menu towarzysza MCME (bez własnego SWF - doklejka do
// istniejacego flashowego menu SCMMenuEditCompanion2).

@wrapMethod(SCMMenuEditCompanion2)
function OnMenuCreated()
{
	var enumer  : SCMMenu_Enum;
	var sd      : MCM_NPCEntry;
	var factVal : int;

	wrappedMethod();
	if (MCM_AR_NPCHasAltLooks(COMPANION))
	{
		enumer = AddEnum('ar_outfit', AR_T("ar_menu_outfit", "Outfit: "),
			AR_T("ar_outfit_normal", "Normal") + "," + AR_T("ar_outfit_underwear", "Underwear") + "," + AR_T("ar_outfit_nude", "Nude"), ",");
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
			idx = enumer.selectedIndex;
			if (idx < 0 || idx > 2) idx = 0;
			MCM_AR_ApplyOutfit(COMPANION, idx);
			window.PlaySelectSound();
		}
		window.UpdateAndRefresh();
		return;
	}
	wrappedMethod(element);
}

// Execy pomocnicze: z nazwa albo najblizsza towarzyszka w zasiegu 5m.

// Normalizacja aliasow komend na wewnetrzne scmcc.data.nam.
function MCM_AR_NormalizeCompanionName(input : string) : string
{
	var s : string;
	s = StrLower(input);
	if (s == "yen" || s == "yennefer")                                return "yennefer";
	if (s == "triss")                                                 return "triss";
	if (s == "ciri" || s == "cirilla")                                return "cirilla";
	if (s == "keira" || s == "keira_metz")                            return "keira_metz";
	if (s == "shani")                                                 return "shani";
	if (s == "anarietta" || s == "anna" || s == "anna_henrietta")     return "anna_henrietta";
	if (s == "vivienne" || s == "sq701_vivienne")                     return "sq701_vivienne";
	if (s == "cerys" || s == "becca")                                 return "becca";
	if (s == "syanna")                                                return "syanna";
	if (s == "philippa" || s == "filippa" || s == "philippa_eilhart") return "philippa_eilhart";
	if (s == "ves")                                                   return "ves";
	if (s == "salma" || s == "mh303_succbus_v2")                      return "mh303_succbus_v2";
	if (s == "priscilla" || s == "pryscilla")                         return "priscilla";
	if (s == "edna" || s == "edna_var_attre")                         return "edna_var_attre";
	if (s == "fringilla" || s == "fringilla_vigo")                    return "fringilla_vigo";
	if (s == "margarita" || s == "margaritta")                        return "margarita";
	if (s == "orianna" || s == "oriana" || s == "vampire_diva")       return "vampire_diva";
	if (s == "rosa" || s == "rosa_var_attre")                         return "rosa_var_attre";
	if (s == "tomira" || s == "prologue_village_herbalist")           return "prologue_village_herbalist";
	return s;
}

function MCM_AR_FindCompanion(npcStr : string) : CNewNPC
{
	var companions : array<CNewNPC>;
	var npc        : CNewNPC;
	var best       : CNewNPC;
	var bestDist   : float;
	var dist       : float;
	var i          : int;
	var targetNorm : string;
	var candNorm   : string;

	theGame.GetNPCsByTag('GeraltsBFF', companions);

	// W3Script nie ma StringToName - porownanie tekstowe po aliasach
	if (StrLen(npcStr) > 0)
	{
		targetNorm = MCM_AR_NormalizeCompanionName(npcStr);
		for (i = 0; i < companions.Size(); i += 1)
		{
			npc = companions[i];
			if (!npc || !npc.scmcc || !npc.scmcc.data) continue;
			candNorm = MCM_AR_NormalizeCompanionName(NameToString(npc.scmcc.data.nam));
			if (candNorm == targetNorm || StrLower(NameToString(npc.scmcc.data.nam)) == StrLower(npcStr))
			{
				return npc;
			}
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
	if (!npc) { thePlayer.DisplayHudMessage("[AR] No companion in range."); return; }
	MCM_AR_ApplyOutfit(npc, 0);
	thePlayer.DisplayHudMessage("[AR] " + NameToString(npc.scmcc.data.nam) + ": normal outfit.");
}

exec function ar_undress(optional npcStr : string)
{
	var npc : CNewNPC;
	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc) { thePlayer.DisplayHudMessage("[AR] No companion in range."); return; }
	if (!MCM_AR_NPCHasAltLooks(npc))
	{
		thePlayer.DisplayHudMessage("[AR] " + NameToString(npc.scmcc.data.nam) + " has no outfit variants.");
		return;
	}
	MCM_AR_ApplyOutfit(npc, 1);
	thePlayer.DisplayHudMessage("[AR] " + NameToString(npc.scmcc.data.nam) + ": underwear.");
}

exec function ar_naked(optional npcStr : string)
{
	var npc : CNewNPC;
	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc) { thePlayer.DisplayHudMessage("[AR] No companion in range."); return; }
	if (!MCM_AR_NPCHasAltLooks(npc))
	{
		thePlayer.DisplayHudMessage("[AR] " + NameToString(npc.scmcc.data.nam) + " has no outfit variants.");
		return;
	}
	MCM_AR_ApplyOutfit(npc, 2);
	thePlayer.DisplayHudMessage("[AR] " + NameToString(npc.scmcc.data.nam) + ": nude.");
}

// ar_gift(<npc>): konsumuje pierwsza butelke wina z ekwipunku, +3 affinity.

exec function ar_gift(optional npcStr : string)
{
	var npc         : CNewNPC;
	var npcName     : name;
	var core        : MCM_AutonomousRomanceCore;
	var act         : MCM_RomanceInteraction;
	var gift        : MCM_AR_GiftRequest_Base;
	var best        : name;
	var displayName : string;

	npc = MCM_AR_FindCompanion(npcStr);
	if (!npc)
	{
		thePlayer.DisplayHudMessage("[AR] No companion in range (5m) or invalid name.");
		return;
	}
	if (!npc.scmcc || !npc.scmcc.data)
	{
		thePlayer.DisplayHudMessage("[AR] Companion data not initialized.");
		return;
	}
	npcName     = npc.scmcc.data.nam;
	displayName = MCM_AR_GetCompanionDisplayName(npc);

	core = MCM_AR_GetCore();
	if (!core || !core.registry)
	{
		thePlayer.DisplayHudMessage("[AR] Core not ready.");
		return;
	}
	if (core.IsStagedBusy())
	{
		thePlayer.DisplayHudMessage("[AR] Another interaction is in progress - try again in a moment.");
		return;
	}

	// Akcja gift_request tej postaci z rejestru (klucz: scmcc.data.nam)
	act  = core.registry.FindActionForNpc(npcName, "gift_request");
	gift = (MCM_AR_GiftRequest_Base)act;
	if (!gift)
	{
		thePlayer.DisplayHudMessage("[AR] " + displayName + " has no gift interaction.");
		return;
	}

	// Butelke wybiera akcja (ta sama lista co w grze)
	best = gift.FindBestAvailableGift();
	if (!IsNameValid(best))
	{
		thePlayer.DisplayHudMessage("[AR] No gift in inventory (wine/alcohol).");
		return;
	}

	// TryExecuteSpecificAction = pelna sekwencja bez CanExecute (cooldowny nietkniete).
	core.debugForceAction = gift.id;
	core.debugForceTarget = npcName;
	core.GotoState('ProcessingTick');
	thePlayer.DisplayHudMessage("[AR] " + displayName + " comes over for a drink (" + NameToString(best) + ").");
}
