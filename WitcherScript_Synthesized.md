# WitcherScript Remastered (v5.00+) & REDengine 3 Developer Reference

> **Comprehensive Technical Synthesis** for Witcher 3 Script Modding, REDengine 3 Internals, Global Functions, Console `exec` Architecture, and Remaster (v5.00+) Annotations.

---

<a id="top"></a>

## Table of Contents
1. [WitcherScript Overview & Execution Environment](#1-witcherscript-overview--execution-environment)
2. [Language Syntax & Type System](#2-language-syntax--type-system)
3. [Remaster (v5.00+) Annotation Architecture](#3-remaster-v500-annotation-architecture)
4. [Engine Lifecycle Hooks & The Priority Shadowing Trap](#4-engine-lifecycle-hooks--the-priority-shadowing-trap)
5. [Persistent State: Game Facts System vs Saved Variables](#5-persistent-state-game-facts-system-vs-saved-variables)
6. [Globally Accessible Engine Singletons](#6-globally-accessible-engine-singletons)
7. [Essential Global Functions Library](#7-essential-global-functions-library)
8. [Exec Functions & Console Development Architecture](#8-exec-functions--console-development-architecture)
9. [Logging & Runtime Diagnostics Pipeline](#9-logging--runtime-diagnostics-pipeline)
10. [Classes, State Machines & Latent Mechanics](#10-classes-state-machines--latent-mechanics)
11. [REDengine 3 Trap & Gotcha Matrix](#11-redengine-3-trap--gotcha-matrix)

---

## 1. WitcherScript Overview & Execution Environment

WitcherScript (`.ws`) is the object-oriented scripting language powering *The Witcher 3: Wild Hunt* (REDengine 3). Scripts control quest logic, companion artificial intelligence, combat states, user interface controllers, camera behavior, and gameplay mechanics.

### Script Directory Hierarchy
- **Vanilla Core Scripts:** Located in `<Witcher 3>\content\content0\scripts\` (unbundled into `core/`, `game/`, and `engine/`).
- **Mod Scripts:** Located in `<Witcher 3>\Mods\<modName>\content\scripts\local\...`. The engine automatically traverses all `.ws` files inside `content\scripts` during engine startup.

### Compilation Pipeline
When the game executable (`bin\x64_dx12\witcher3.exe` or `bin\x64\witcher3.exe`) launches:
1. The engine scans the `Mods/` directory in alphabetical/priority order.
2. It compiles all `.ws` scripts into an in-memory bytecode representation.
3. If any syntax error, missing symbol, or conflicting signature occurs, the game halts immediately, displaying the native modal:  
   `The Witcher 3: Wild Hunt - Script Compilation Errors`.
4. If compilation succeeds, the 3D viewport (`W2ViewportClass`) initializes, and the main menu boots.

### Enabling the Debug Console
Testing scripts and calling console `exec` functions requires the debug console:
1. Open `<Witcher 3>\bin\config\base\general.ini`.
2. Add under `[General]`:
   ```ini
   DBGConsoleOn=true
   ```
3. Press `~` (tilde) in-game to toggle the native console input bar.

---

## 2. Language Syntax & Type System

WitcherScript is strongly typed and statically compiled.

### Basic Data Types
| Type | Description | Example |
| :--- | :--- | :--- |
| `int` | Signed 32-bit integer (-2,147,483,648 to 2,147,483,647). | `var count : int; count = 42;` |
| `float` | 32-bit floating point number. | `var dist : float; dist = 3.5f;` |
| `bool` | Boolean flag (`true` or `false`). | `var isReady : bool; isReady = true;` |
| `string` | Dynamic text string (double quotes). | `var text : string; text = "Hello Geralt";` |
| `name` | Hashed 64-bit engine identifier / symbol (single quotes). Fast comparison. | `var tag : name; tag = 'Yennefer';` |
| `Vector` | 4D float vector (X, Y, Z, W) for positions and headings. | `var pos : Vector; pos = thePlayer.GetWorldPosition();` |
| `EulerAngles` | Pitch, Yaw, Roll rotations. | `var rot : EulerAngles; rot = thePlayer.GetWorldRotation();` |
| `array<T>` | Dynamic resizable array of type `T`. | `var companions : array<CActor>;` |

> [!NOTE]
> **Variable Declarations:** In WitcherScript, **all local variables must be declared at the very top of the function body** before any procedural statements. Declaring a variable midway through a function triggers a compilation error.

### Arrays (`array<T>`) Native Methods
Dynamic arrays provide built-in methods:
```witcherscript
var list : array<name>;
var foundIdx : int;

list.PushBack('Yennefer');  // Appends item to array
list.PushBack('Triss');
list.Size();                // Returns element count (2)
list.Contains('Triss');     // Returns true
foundIdx = list.FindFirst('Triss'); // Returns 1 (-1 if not found)
list.Remove('Triss');       // Removes first occurrence
list.Erase(0);              // Removes element at index 0
list.Clear();               // Empties array
list.Grow(5);               // Reserves and expands size
```

### Structs and Enums
```witcherscript
enum ERomanceTier {
    RTT_Banter    = 1,
    RTT_Care      = 2,
    RTT_Prompt    = 3,
    RTT_Intimate  = 4
};

struct SCompanionRomanceContext {
    var npcName        : name;
    var affinityPoints : int;
    var isInCombat     : bool;
};
```

---

## 3. Remaster (v5.00+) Annotation Architecture

The Remaster (v5.00+) introduced native script annotations (REDengine Remaster). These allow non-destructive injection into vanilla classes without modifying base files, eliminating Script Merger conflicts.

### Annotation Directives

#### 1. `@wrapMethod(TargetClass)`
Wraps an existing method. You **must** call `wrappedMethod(args)` inside your logic to forward execution to the original method.
```witcherscript
@wrapMethod(CR4Player)
function InitRemasterSettings() {
    // Forward to original execution first
    wrappedMethod();

    // Custom mod initialization hook
    MCM_AR_OnPlayerReady();
}
```

#### 2. `@addMethod(TargetClass)`
Injects a brand new method into an existing engine or gameplay class:
```witcherscript
@addMethod(CNewNPC)
function IsAutonomousRomanceCompanion() : bool {
    return this.HasTag('mcme_companion');
}
```

#### 3. `@addField(TargetClass)`
Injects a new member variable into an existing class:
```witcherscript
@addField(CR4Player)
var ar_lastInteractionTimestamp : float;
```

#### 4. `@replaceMethod(TargetClass)`
Completely replaces an existing method. Use sparingly as this breaks mod compatibility if multiple mods target the same method.

---

## 4. Engine Lifecycle Hooks & The Priority Shadowing Trap

### The Priority Shadowing Trap
In The Witcher 3 Remastered (v5.00+), when multiple mods use `@wrapMethod` on the same method (e.g., `CPlayerInput.Initialize` or `CR4Player.OnSpawned`), **the compiler does NOT chain them across separate unmerged mods**.  
The mod loaded with higher priority completely shadows the lower-priority mod's wrap. If Mod A (Priority 19) wraps `CPlayerInput.Initialize`, our Mod B (Priority 30) wrap is silently discarded and never executes.

### The Reliable Entry Point: `InitRemasterSettings()`
To guarantee mod initialization across any load order:
```witcherscript
@wrapMethod(CR4Player)
function InitRemasterSettings() {
    wrappedMethod();
    MCM_AR_OnPlayerReady();
}
```
`InitRemasterSettings` was introduced specifically in the Remaster (v5.00+). It executes safely once the player entity, input subsystem, and world environments are fully initialized.

### Method vs Event Wrapping Rules
- **Regular Method:**
  ```witcherscript
  @wrapMethod(CR4Player)
  function OnSpawned(spawnInfo : SEntitySpawnInfo) {
      wrappedMethod(spawnInfo);
  }
  ```
- **Engine Event (`event`):**  
  In REDengine, engine events implicitly return `bool`. In `@wrapMethod`, you **MUST NOT** declare an explicit return type (`: bool` or `: void`), or the compiler throws:  
  `Event function '...' should not have an explicit return type.`
  ```witcherscript
  @wrapMethod(CNewNPC)
  function OnInteraction(actionName : string, activator : CEntity) {
      // wrappedMethod handles implicit bool return
      return wrappedMethod(actionName, activator);
  }
  ```

---

## 5. Persistent State: Game Facts System vs Saved Variables

### Why `saved var` is Dangerous for Mods
Adding `saved var` fields to player or entity classes serializes your mod's binary data directly into the user's `.sav` file. If the player uninstalls or updates the mod, loading that savegame can crash the game or flood logs with orphaned variable warnings.

### The Stateless Game Facts Architecture
REDengine provides a native, robust persistent key-value facts database (`facts.ws`) designed for quest progression and persistent flags:
```witcherscript
import function FactsAdd(ID : string, optional value : int, optional validFor : int);
import function FactsQuerySum(ID : string) : int;
import function FactsDoesExist(ID : string) : bool;
import function FactsRemove(ID : string);
```

#### Fact Mechanics:
- `FactsAdd("fact_id", 1)`: Appends an entry for `"fact_id"` with value 1.
- `FactsQuerySum("fact_id")`: Sums all existing values of `"fact_id"`. If 5 entries of +1 exist, returns 5.
- `validFor`: Optional expiration time in game seconds. If omitted (`-1`), persists indefinitely in savegames.
- `FactsRemove("fact_id")`: Erases all entries for that fact key.

#### Clean-Save Implementation in Autonomous Romance:
```witcherscript
// Reading affinity points safely:
function GetSavedAffinity(npcTag : name) : int {
    return FactsQuerySum("mcme_ar_" + NameToString(npcTag) + "_affinity");
}

// Adding affinity points:
function AddSavedAffinity(npcTag : name, delta : int) {
    FactsAdd("mcme_ar_" + NameToString(npcTag) + "_affinity", delta);
}
```
If the mod is removed, the engine simply ignores these factual keys. **Saves remain 100% clean and stable.**

---

## 6. Globally Accessible Engine Singletons

REDengine exposes global singleton references accessible anywhere in scripts:

| Global Variable | Underlying Class | Purpose & Capabilities |
| :--- | :--- | :--- |
| `theGame` | `CR4Game` | Central game engine: time, world loading, quests, fast travel, spawning. |
| `thePlayer` | `CR4Player` | The player character (Geralt): inventory, stats, HUD messages, combat state. |
| `theInput` | `CInputManager` | Input context, action listener polling, key states (`GetContext()`). |
| `theUI` | `CGuiWitcher` | Scaleform / Flash UI manager, hud notifications, dialog menus. |
| `theCamera` | `CCamera` | Game camera view, FOV, rotation vectors. |
| `theSound` | `CScriptSoundSystem` | Wwise audio events, sound banks, acoustic triggers. |
| `theTimer` | `CTimerScriptKeyword` | Engine timer registration (`AddTimer`, delta time). |
| `theDebug` | `CDebugAttributesManager` | Visual debugging lines, debug geometries, screen text. |
| `theServer` | `CServerInterface` | Internal server interface. |

---

## 7. Essential Global Functions Library

### 1. String & Symbol Utilities
```witcherscript
function StrLen(str : string) : int;
function StrLower(str : string) : string;
function StrUpper(str : string) : string;
function StrMid(str : string, first : int, optional length : int) : string;
function StrFindFirst(str : string, match : string) : int;
function StrSplit(str : string, divider : string, out list : array<string>);

// Conversions
function NameToString(n : name) : string;
function IntToString(val : int) : string;
function FloatToString(val : float) : string;
function StringToInt(str : string, optional defaultVal : int) : int;
function StringToFloat(str : string, optional defaultVal : float) : float;
```

> [!CAUTION]
> **No `StringToName` in REDengine:** The engine does **not** provide a function to cast arbitrary strings into `name` symbols at runtime. To compare a dynamic string with a name, always convert the name to string:  
> `if (StrLower(NameToString(companionTag)) == StrLower(searchStr))`

### 2. Array Algorithms
```witcherscript
function ArraySortStrings(out strings : array<string>);
function ArraySortNames(out names : array<name>);
function ArraySortInts(out ints : array<int>);
function ArraySortFloats(out floats : array<float>);
function ArrayFindMaxF(const floats : array<float>) : float;
function ArrayFindMinF(const floats : array<float>) : float;
```

### 3. Math & Spatial Vectors
```witcherscript
function VecDistance(posA : Vector, posB : Vector) : float;
function VecDistance2D(posA : Vector, posB : Vector) : float;
function VecHeading(headingVec : Vector) : float;

function Abs(val : int) : int;
function AbsF(val : float) : float;
function Min(a, b : int) : int;
function Max(a, b : int) : int;
function MinF(a, b : float) : float;
function MaxF(a, b : float) : float;
function Clamp(val, min, max : int) : int;
function ClampF(val, min, max : float) : float;
function RandRange(max : int, optional min : int) : int;
function RandRangeF(max : float, optional min : float) : float;
```

### 4. Localization & Subtitles
```witcherscript
// Retrieves localized text from compiled .w3strings by string key or string ID:
function GetLocStringByKey(key : string) : string;
function GetLocStringById(stringId : int) : string;
```

### 5. Time & Scheduling
```witcherscript
function GameTimeToFloat(time : GameTime) : float;
function EngineTimeToFloat(time : EngineTime) : float;

// Registering periodic timers on entities:
// AddTimer(functionName : name, timePeriod : float, optional isRepeating : bool);
thePlayer.AddTimer('AR_DecisionTick', 4.0f, true);
```

---

## 8. Exec Functions & Console Development Architecture

### Anatomy of an `exec function`
An `exec function` is exposed to the in-game debug console (`~`). When typed into the console, the engine dynamically parses parameters and executes the logic:

```witcherscript
exec function ar_affinity(companionName : string, points : int) {
    var tag : name;
    tag = '';
    if (StrLower(companionName) == "yen")   tag = 'Yennefer';
    if (StrLower(companionName) == "triss") tag = 'Triss';

    if (tag != '') {
        MCM_AR_AddAffinity(tag, points);
        GetWitcherPlayer().DisplayHudMessage("Added " + points + " affinity to " + NameToString(tag));
    }
}
```

### Essential Built-in Console Commands for Mod Testing
| Command | Usage | Description |
| :--- | :--- | :--- |
| `settime(h, m)` | `settime(23, 0)` | Sets current game time (hours, minutes). |
| `telltime` | `telltime` | Prints current world time to console. |
| `changeweather(w)` | `changeweather('WT_Clear')` | Changes active weather pattern. |
| `additem(item, n)` | `additem('Wine Erveluce', 2)` | Injects items into Geralt's inventory. |
| `removeitem(item)` | `removeitem('Wine Erveluce')` | Removes item from inventory. |
| `god` | `god` | Toggles player invulnerability. |
| `healme` | `healme` | Instantly restores 100% player health. |
| `appearance(app)` | `appearance('naked')` | Changes targeted NPC or player appearance mesh. |
| `spawn(name, n)` | `spawn('triss', 1)` | Spawns NPC entities near player. |
| `gotoW3(x, y, z)` | `gotoW3(-120, 450, 10)` | Teleports player to exact XYZ coordinates. |

---

## 9. Logging & Runtime Diagnostics Pipeline

### Native Script Logging (`LogChannel`)
The engine includes a dedicated script logging system:
```witcherscript
LogChannel('MCME_Romance', "Evaluating companion initiative for: " + NameToString(npcTag));
```

### Enabling `scriptslog.txt`
By default, retail builds ignore `LogChannel()` calls to save CPU cycles.  
To write logs to `Documents\The Witcher 3\scriptslog.txt`:
1. Launch the game with arguments:  
   `witcher3.exe -debugscripts` (or use `scripts\run_game_debug.bat`). Never add `-net`: it reroutes script output to a debugger socket nothing listens on, which kills `scriptslog.txt` writes after the player spawns.
2. Ensure `<Documents>\The Witcher 3\user.settings` contains:
   ```ini
   [Scripts]
   DebugScriptsLogDir=Documents\The Witcher 3
   DebugScriptsForceFlush=true
   ```

### HUD Diagnostic Buffers
Because alt-tabbing to inspect logs interrupts gameplay, Autonomous Romance maintains an in-memory string ring buffer displayed directly on the HUD via:
```witcherscript
exec function ar_logdump(optional lineCount : int);
```

---

## 10. Classes, State Machines & Latent Mechanics

### Classes & Inheritance
```witcherscript
class MCM_RomanceInteraction {
    protected var minAffinity : int;
    protected var cooldown    : float;

    public function CanExecute(actor : CActor) : bool {
        return true;
    }
}

class MCM_AR_Yen_Kiss extends MCM_RomanceInteraction {
    default minAffinity = 40;

    public function CanExecute(actor : CActor) : bool {
        return super.CanExecute(actor) && !thePlayer.IsInCombat();
    }
}
```

### State Machines
REDengine features native finite state machines:
```witcherscript
statemachine class W3CompanionAI extends CActor {
    default autoState = 'Idle';
}

state Idle in W3CompanionAI {
    event OnEnterState(prevStateName : name) {
        super.OnEnterState(prevStateName);
    }

    event OnLeaveState(nextStateName : name) {
        super.OnLeaveState(nextStateName);
    }
}
```

### Latent Functions
Functions declared with the `latent` keyword execute across multiple engine frames without blocking the main render thread. They can invoke `Sleep(seconds)`:
```witcherscript
latent function PlayCompanionGreeting(companion : CActor) {
    companion.PlayVoiceset(100, "greeting");
    Sleep(2.5f);
    companion.ActionPlaySlotAnimation('ITEM_GIVE', 'upper_body');
}
```

> [!WARNING]
> **Latent Condition Restriction:** A `latent` function cannot be called within an `if (...)`, `while (...)`, or ternary operator. Doing so raises:  
> `Conditional expression must not be latent.`

---

## 11. REDengine 3 Trap & Gotcha Matrix

| Trap / Issue | Cause | Solution |
| :--- | :--- | :--- |
| **C++ Case Sensitivity** | Native engine methods are strictly case-sensitive. E.g., `CActor.GetVoiceTag()` fails. | Always use exact C++ export casing: `CActor.GetVoicetag()` (lowercase `t`). |
| **Event Return Type** | Declaring `: bool` or `: void` on `@wrapMethod` for an engine `event`. | Omit the return type completely in the wrap signature. |
| **Companion Collisions** | Enabling permanent physical collisions on companions. | Companions become solid walls, trapping the player in doors. Keep MCME ghost collision rules. |
| **Interaction Key Conflict** | Using `[E]` (`'Interact'`) for romance consent prompts. | Triggers both romance and the vanilla MCME dialogue menu. Always use `[C]` (`'SwordSheathe'`). |
| **Scaleform XML Nesting** | Nesting mod options deeper than 2–3 levels in `modName.xml`. | Corrupts Flash igmOptions buttons into garbage characters (`E■Z`). Keep paths shallow: `Mods.AutonomousRomance`. |
| **`StringToName` Missing** | Trying to convert dynamic string to `name` type. | Function does not exist. Compare by converting names to strings: `NameToString(nameVal)`. |

---

<p align="right">(<a href="#top">back to top</a>)</p>
