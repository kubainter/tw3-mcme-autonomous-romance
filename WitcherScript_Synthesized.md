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

### Data Types and Variables
WitcherScript supports basic types and object references.
- **Variables**: Declared with `var`, e.g., `var something: float;`.
- **Global objects**: Accessible globally, such as `thePlayer` (the instance of the player) or `theGame` (the main game manager).

### Functions
Functions are declared using the `function` keyword and can optionally return values. There are multiple function flags that define their specific use-cases:

- **Exec function**: E.g., `exec function addKey(key_name : name)`. Can be called directly from the debug console.
- **Latent function**: E.g., `latent storyscene function ShaveGeralt()`. Similar to coroutines, they allow time passage (like `Sleep(1.0f)`) without blocking the game.
- **Timer function**: Used for real-time loops attached to entities, usually driven by `dt` (delta time).
- **Storyscene & Quest functions**: Specialized logic tailored for cinematic scenes or quest nodes.
- **Reward function**: Called when granting specific rewards in the editor (e.g., leveling up the player).
- **Cleanup function**: Cannot return anything or take arguments; runs to clean up resources after an action finishes.
- **Entry function**: State entry logic, rarely used in the base game.

#### Modifiers (Flags)
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
