// ==========================================================================
// MCM_RomanceTw3seDev.stub.ws — RELEASE-STUB warstwy TW3SE.
//
// package_release.ps1 podmienia w paczce MCM_RomanceTw3seDev.ws na ten plik.
// Identyczne sygnatury publiczne jak wersja dev (precheck_syntax.ps1
// weryfikuje parzystosc), ZERO 'import function' - mod nie wymaga TW3SE.
// Wszystkie wrappery zwracaja wartosci neutralne: DevActive()=false przez
// co sciezki dev (consent VK, log tee, emit) sa martwe i zachowanie moda
// jest identyczne jak przed warstwa TW3SE.
//
// NIE UMIESZCZAC tego pliku pod content\scripts obok wersji dev -
// duplikat symboli = fail kompilacji. Zyje wylacznie jako input dla
// package_release.ps1.
// ==========================================================================

function MCM_AR_DevActive() : bool
{
	return false;
}

function MCM_AR_DevVersion() : int
{
	return 0;
}

function MCM_AR_DevLog(msg : string)
{
}

function MCM_AR_DevEmit(msg : string)
{
}

function MCM_AR_DevLogNative(msg : string)
{
}

function MCM_AR_DevWriteFile(f : string, text : string) : bool
{
	return false;
}

function MCM_AR_DevAppendFile(f : string, text : string) : bool
{
	return false;
}

function MCM_AR_DevReadFile(f : string) : string
{
	return "";
}

function MCM_AR_DevClearFile(f : string) : bool
{
	return false;
}

function MCM_AR_DevFileSize(f : string) : int
{
	return -1;
}

function MCM_AR_DevKeyDown(vk : int) : bool
{
	return false;
}

function MCM_AR_DevKeyEdge(vk : int) : bool
{
	return false;
}

function MCM_AR_DevConfigKey(setting : string) : int
{
	return 0;
}

function MCM_AR_DevConfig(key : string) : string
{
	return "";
}

function MCM_AR_DevSetVar(k : string, v : string) : bool
{
	return false;
}

function MCM_AR_DevGetVar(k : string) : string
{
	return "";
}

function MCM_AR_DevHasVar(k : string) : bool
{
	return false;
}

function MCM_AR_DevDelVar(k : string) : bool
{
	return false;
}

function MCM_AR_DevReloadScripts()
{
}

exec function ar_devinfo()
{
	if (thePlayer)
	{
		thePlayer.DisplayHudMessage("[AR-dev] TW3SE nieaktywne (stub/release)");
	}
}

exec function ar_reload()
{
	if (thePlayer)
	{
		thePlayer.DisplayHudMessage("[AR-dev] TW3SE nieaktywne - reload niemozliwy");
	}
}
