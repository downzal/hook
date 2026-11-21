<div align="center">
  <img src="hookDocs/hook.png" alt="hook" width="400">
  <h1>Hook</h1>
  <p>Optimized ROBLOX signals for both Luau and TypeScript</p>

  <a href="https://www.npmjs.com/package/@downzal/hook"><img src="/hookDocs/npmHook.png" alt="npm" width="125"></a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://wally.run/package/downzal/hook?version=1.0.1"><img src="/hookDocs/hookWally.png" alt="wally" width="125"></a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="/LICENSE"><img src="/hookDocs/hookLicense.png" alt="license" width="125"></a>
</div>

<br>

## Installation

You can install Hook in different ways depending on your workflow:

### Roblox Studio
1. Download the `.rbxm` file from the [releases tab](../releases)
2. Drop the file into `ReplicatedStorage` or your desired location
3. Profit

### Rojo (Wally)
1. Install Hook via Wally (`@downzal/hook`)
2. Connect Rojo
3. Profit

### TypeScript (roblox-ts)
1. Install Hook via npm:
   ```bash
   npm install @rbxts/downzal/hook
   ```
2. Profit

---

## Code Examples

**Creating and listening to a Hook in Luau:**

```lua
local hook = require(game:GetService("ReplicatedStorage").hook)

local onDamage = hook.new()
onDamage:send(25, somePlayer)

local conn = onDamage:listen(function(amount : number, source : Player)
  print(string.format("%s took %d damage", amount, source))
end)

conn:disconnect()
```

**Creating and listening in TypeScript:**

```typescript
import { hook } from "./hook"

const onDamage = new hook<[amount: number, source: Player]>()
onDamage.send(25, somePlayer)

const conn = onDamage.listen((amount, source) => {
  print(`took ${amount} damage from ${source.Name}`)
})

conn.disconnect()
```

---

## API Reference

### Luau API

| Method | Description |
| :--- | :--- |
| `hook.new() : ()` | Creates a hook |
| `hook:send(...) : ()` | Fires given Hook |
| `hook:listen(cb : (T...) -> ()) : connection` | Runs given callback upon given Hook firing |
| `hook:wait() : T...` | Pauses the thread until given Hook fires once |
| `hook:once(cb : (T...) -> ()) : connection` | Runs given callback once upon given Hook getting emitted, then disconnects itself |
| `hook:disconnectAll() : ()` | Disconnects all nodes of given Hook |

### TypeScript API

| Method | Description |
| :--- | :--- |
| `hook.new<[]>()` | Creates a hook |
| `hook.send(...args) : void` | Fires given hook |
| `hook.listen(cb : (...args : T) => void) : connection` | Runs given callback upon given Hook firing |
| `hook.wait() : LuaTuple<T>` | Pauses the thread until given Hook fires once |
| `hook.once(cb : (...args : T) => void) : connection` | Runs given callback once upon given Hook firing |
| `hook.disconnectAll() : void` | Disconnects all nodes of given Hook |
