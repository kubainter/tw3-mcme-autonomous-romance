# WitcherScript Documentation Synthesis

WitcherScript (.ws) is the primary scripting language of *The Witcher 3: Wild Hunt*. It allows modders to bring their creations to life, add new features, debug, and implement custom logic. Scripts are natively found in the `\content\content0\scripts\` directory.

---

## 1. Setting Up and Tools

### Enabling the Debug Console
To test scripts and functions directly in-game:
1. Navigate to `The Witcher 3/bin/config/base`.
2. Open `general.ini`.
3. Add the line: `DBGConsoleOn=true`.
4. Press `~` in-game to open the console and enter commands.

### Script Studio
Included with REDkit, Script Studio is the main IDE for modifying WitcherScripts.
- **Workspace checkout**: Files that exist in the base game must be "checked out" so REDkit knows to package them in your mod.
- **Hot Reloading & Debugging**: You can edit scripts, add breakpoints, and step through code while the game is running, thanks to automatic attachment to the game instance.

### Script Compilation & Overrides
When multiple mods edit the same files, a Script Compilation Error occurs.
- **Traditional solution**: Use **Script Merger** (available on NexusMods) to combine conflicting files.
- **Modern solution (Patch 06.06.2024)**: Use script annotations to avoid direct file modifications. This requires creating a new `.ws` file in your mod workspace.

#### Annotations
- `@wrapMethod(class)`: Wraps an existing method. You must call `wrappedMethod(args)` inside your logic to execute the original game method. Supports chaining across different mods.
- `@addMethod(class)`: Injects a brand-new method into an existing class.
- `@replaceMethod(class)` or `@replaceMethod` (for globals): Completely overwrites an existing function in a class or a global function.
- `@addField(class)`: Adds a new variable/field to the target class.

---

## 2. Language Basics

### Comments
Comments help document and explain your code:
- Single-line: `// This is a single line comment`
- Multi-line: `/* This text is multiple lines long */`

### Data Types
WitcherScript utilizes several basic data types to store information:
- `int`: Standard 32-bit integer (value range from -2,147,483,648 to 2,147,483,647).
- `String`: Standard text string. Enclosed in double quotes (e.g., `"This is a string"`).
- `name`: Name type variable, essentially an optimized string used for item names, tags, etc. Enclosed in single quotes (e.g., `'this is an item name'`).
- `float`: Standard floating-point number (e.g., `1.0f`).

### Global Objects
The game engine exposes several global objects that provide quick access to core systems:
- `theGame` = CR4Game
- `theServer` = CServerInterface
- `thePlayer` = CR4Player
- `theCamera` = CCamera
- `theUI` = CGuiWitcher
- `theSound` = CScriptSoundSystem
- `theDebug` = CDebugAttributesManager
- `theTimer` = CTimerScriptKeyword
- `theInput` = CInputManager

*Example*: `thePlayer.DisplayHudMessage('Hello')` instead of `GetWitcherPlayer().DisplayHudMessage('Hello')`.

### Variables
- **Local Variables**: Defined inside functions to process data. Must be defined at the top of the function.
  ```witcherscript
  exec function acquire(skillName : name) {
      var i : int;
      var skills : String;
      // Do something...
  }
  ```
- **Class Variables**: Defined inside classes to store state across methods.
  ```witcherscript
  class Test {
      var SomeText : String;
  }
  ```

### Functions & Parameters
Functions are declared using the `function` keyword, accept parameters, and can optionally return values. Parameters can be passed to functions (e.g., `exec function changeweather(weatherName : name)`).

#### Function Types
There are multiple function flags that define specific use-cases within the game engine:

- **Exec function**: Exposed to the game’s debug console. E.g., `exec function stoprain() { RequestWeatherChangeTo('WT_Clear', 1.0, false); }`.
- **Latent function**: Similar to coroutines, they allow time passage (like `Sleep(1.0f)`) without blocking the game. E.g., `latent storyscene function ShaveGeralt()`.
- **Timer function**: Real-time logic attached to entities, driven by `dt` (delta time). E.g., `timer function Loop(dt : float, id : int) { LoopFunction(dt); }`. Use `AddTimer` or `AddGameTimeTimer` to instantiate them.
- **Storyscene function**: Specialized logic tailored for cinematic scenes.
- **Quest function**: Special functions used directly in Quest nodes.
- **Reward function**: Called when granting specific rewards in the editor (e.g., leveling up the player).
- **Cleanup function**: Cannot return anything or take arguments; runs to clean up resources after an action finishes.
- **Entry function**: State entry logic for state machines.

#### Function Modifiers (Flags)
Functions can be specified as `private`, `protected`, `public`, `native` (C++ implemented), `final` (cannot be overridden), `event`, etc.

---

## 3. Classes and State Machines

WitcherScript leverages Object-Oriented Programming principles.

### Regular Classes
Containers for data and methods that you can reuse.
```witcherscript
class InterpCurve {
    var something: float;
    function doSomething(inVal : float, outVal : float) : int {
        return 10;
    }
}
```

### Native Classes
Classes defined internally in the C++ engine that have been exported for use in scripts. Marked with the `import` keyword.
```witcherscript
import class C2dArray extends CResource {
    import final function GetValueAt(column : int, row : int) : string;
}
```

### State Machines
WitcherScript has robust native support for state machines, enabling entities to transition between defined states seamlessly.
- Classes declare they are state machines via `statemachine class MyClass extends CEntity`.
- A default state is defined via `default autoState = 'StateName';`.
- Individual states are defined using `state StateName in MyClass`.
- States expose events like `OnEnterState` and `OnLeaveState`.

```witcherscript
statemachine class W3WitchesCage extends CEntity {
    default autoState = 'TurnedOff';
}

state TurnedOff in W3WitchesCage {
    event OnEnterState(prevStateName : name) {
        super.OnEnterState(prevStateName);
        parent.ApplyAppearance("roots_off");
    }
}
```
