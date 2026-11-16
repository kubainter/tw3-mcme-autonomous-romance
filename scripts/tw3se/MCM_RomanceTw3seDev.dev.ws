// MCM_RomanceTw3seDev.ws — warstwa DEV na TW3SE.
// JEDYNY plik z importami TW3SE_* (wiazane w kompilacji -> release podmienia
// na MCM_RomanceTw3seDev.stub.ws o identycznych sygnaturach).
// Dev: tw3se.config -> natives = on. ReloadScripts zabija latenty w locie
// -> po reloadzie ar_devreset.

import function TW3SE_GetVersion() : int;
import function TW3SE_Log(text : string);
import function TW3SE_WriteNamed(fileName : string, text : string) : bool;
import function TW3SE_AppendNamed(fileName : string, text : string) : bool;
import function TW3SE_ReadNamed(fileName : string) : string;
import function TW3SE_FileSize(fileName : string) : int;
import function TW3SE_DeleteNamed(fileName : string) : bool;
import function TW3SE_FileExists(fileName : string) : bool;
import function TW3SE_GetConfig(key : string) : string;
import function TW3SE_GetConfigKey(setting : string) : int;
import function TW3SE_SetVar(key : string, value : string) : bool;
import function TW3SE_GetVar(key : string) : string;
import function TW3SE_HasVar(key : string) : bool;
import function TW3SE_DeleteVar(key : string) : bool;
import function TW3SE_KeyPressed(vk : int) : bool;
import function TW3SE_KeyJustPressed(vk : int) : bool;
import function TW3SE_Emit(text : string);
import function TW3SE_ReloadScripts();
import function TW3SE_Lua(code : string) : string;

// --- detekcja warstwy (stub zwraca 0/false) -------------------------------

function MCM_AR_DevActive() : bool
{
	return TW3SE_GetVersion() != 0;
}

function MCM_AR_DevVersion() : int
{
	return TW3SE_GetVersion();
}

// --- logowanie ---------------------------------------------------------
// LEAF: NIGDY nie wolac tu MCM_AR_Log ani GetCore (rekursja).
// Tee [AR]: append do ar_log.txt + pipe 'events'.
function MCM_AR_DevLog(msg : string)
{
	var line : string;
	line = "" + RoundMath(theGame.GetEngineTimeAsSeconds()) + "s " + msg;
	TW3SE_AppendNamed("ar_log.txt", line + "\n");
	TW3SE_Emit(line);
}

// Emit bez zapisu do pliku - dla zdarzen strukturalnych ("consent|accept").
function MCM_AR_DevEmit(msg : string)
{
	TW3SE_Emit(msg);
}

// Linia w tw3se.log obok komunikatow natywnych.
function MCM_AR_DevLogNative(msg : string)
{
	TW3SE_Log(msg);
}

// --- pliki w tw3se\out\ -----------------------------------------------------

function MCM_AR_DevWriteFile(f : string, text : string) : bool
{
	return TW3SE_WriteNamed(f, text);
}

function MCM_AR_DevAppendFile(f : string, text : string) : bool
{
	return TW3SE_AppendNamed(f, text);
}

function MCM_AR_DevReadFile(f : string) : string
{
	return TW3SE_ReadNamed(f);
}

function MCM_AR_DevClearFile(f : string) : bool
{
	return TW3SE_DeleteNamed(f);
}

function MCM_AR_DevFileSize(f : string) : int
{
	return TW3SE_FileSize(f);
}

// --- klawiatura (prawdziwy stan VK, dev-only) --------------------------------

function MCM_AR_DevKeyDown(vk : int) : bool
{
	return TW3SE_KeyPressed(vk);
}

// KeyJustPressed jest per-frame i gubi pressy przy poll; do tapow licz zbocza DevKeyDown.
function MCM_AR_DevKeyEdge(vk : int) : bool
{
	return TW3SE_KeyJustPressed(vk);
}

// Kod klawisza z tw3se.config (rebindable), np. ar_consent_key = 0x43.
function MCM_AR_DevConfigKey(setting : string) : int
{
	return TW3SE_GetConfigKey(setting);
}

// Dowolny klucz tekstowy z tw3se.config.
function MCM_AR_DevConfig(key : string) : string
{
	return TW3SE_GetConfig(key);
}

// --- vars.txt: stan DEV poza save'em (nie zanieczyszcza savow) ---------------

function MCM_AR_DevSetVar(k : string, v : string) : bool
{
	return TW3SE_SetVar(k, v);
}

function MCM_AR_DevGetVar(k : string) : string
{
	return TW3SE_GetVar(k);
}

function MCM_AR_DevHasVar(k : string) : bool
{
	return TW3SE_HasVar(k);
}

function MCM_AR_DevDelVar(k : string) : bool
{
	return TW3SE_DeleteVar(k);
}

// --- Lua bridge: mcme_bridge.lua (Clone()/templateParams nie istnieja w WS) --
function MCM_AR_DevLua(code : string) : string
{
	return TW3SE_Lua(code);
}

// --- hot reload (OSTROZNIE: zabija latent-loope -> ar_devreset po powrocie) --

function MCM_AR_DevReloadScripts()
{
	TW3SE_ReloadScripts();
}

// --- exec diagnostyczne ------------------------------------------------------

exec function ar_devinfo()
{
	var v  : int;
	var ok : bool;
	var msg : string;

	v = MCM_AR_DevVersion();
	if (v == 0)
	{
		thePlayer.DisplayHudMessage("[AR-dev] TW3SE inactive (stub/release)");
		return;
	}
	ok = MCM_AR_DevAppendFile("ar_selftest.txt", "L1\nL2\n");
	// v = (major<<16)|(minor<<8)|patch — WS nie ma operatorow bitowych.
	msg = "[AR-dev] TW3SE v" + (v / 65536) + "." + ((v / 256) % 256) + "." + (v % 256) +
	      " | write=" + ok +
	      " | size=" + MCM_AR_DevFileSize("ar_selftest.txt") +
	      " | read='" + MCM_AR_DevReadFile("ar_selftest.txt") + "'" +
	      " | keyC=" + MCM_AR_DevKeyDown(0x43);
	thePlayer.DisplayHudMessage(msg);
	MCM_AR_DevEmit(msg);
}

exec function ar_reload()
{
	if (!MCM_AR_DevActive())
	{
		thePlayer.DisplayHudMessage("[AR-dev] TW3SE inactive - reload unavailable");
		return;
	}
	MCM_AR_Log("[AR] ReloadScripts - po powrocie uruchom ar_devreset!");
	TW3SE_Emit("[AR] reload requested");
	MCM_AR_DevReloadScripts();
}
