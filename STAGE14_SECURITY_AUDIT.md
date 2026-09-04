# Stage 14 — Remote security audit

## Trust boundary

The client may request an action, but it never supplies authoritative Coins, Dust, production, rarity, reward definitions, upgrade effects, or another player's profile. All value changes are calculated and committed by server services.

## Remote surface

| Remote | Accepted client request | Server checks |
| --- | --- | --- |
| `RunAction` | Start or abandon a run | Token bucket, exact fields, bounded strings, loaded profile, active run membership, current `RunId` |
| `DecisionVote` | One `CLAIM` or `UPGRADE` vote | Token bucket, exact fields, bounded IDs, participant membership, current `RunId` and `DecisionId`, decision deadline, one vote per player, upgrade availability |
| `RoomAction` | Interact with the active room objective | Token bucket before room logic, exact action-specific fields, bounded IDs, participant membership, current room/state/phase, per-room action cooldown, target existence, server-observed distance |
| `FarmAction` | Collect, place, or remove | Token bucket, exact action-specific fields, finite slot index, bounded instance ID, no active run, own profile, unlocked/empty slot, instance ownership, no duplicate placement; payout calculated from server time |
| `UpgradeAction` | Purchase a known deterministic upgrade | Token bucket, exact fields, bounded ID, no active run, server upgrade whitelist, server price/current level, sufficient server wallet, purchase lock |
| `GetPlayerSnapshot` | Read the caller's own UI snapshot | Token bucket, caller identity supplied by Roblox, cloned caller-only data |
| `UIEvent` | None | Server-to-client only; there is no `OnServerEvent` consumer |

The unused `InventoryAction` remote was removed. Inventory grants have no client remote and remain server-only; debug grants return `DEBUG_ONLY` outside Studio.

## Closed exploit vectors

- Client-selected reward ID, rarity, production value, Coins payout, Dust payout, or upgrade result.
- Claim replay and duplicate permanent instances for the same decision.
- Multiple votes from one player or stale votes from an old decision/run.
- Room completion using stale IDs, an unrelated account, a wrong room action, a wrong phase, a nonexistent target, or an interaction outside the allowed distance.
- Placement of another player's/nonexistent instance, placement into locked or occupied slots, and one instance in multiple slots.
- Client-provided Collect amount, repeated concurrent Collect, arbitrary upgrade IDs, and repeated concurrent purchases.
- Farm or upgrade remote actions while the caller is participating in a Tower run.
- Oversized top-level payloads, unexpected fields, unbounded identifiers, fractional/NaN/infinite slot indices, and high-frequency remote spam.
- Triggering another player's physical Farm or Upgrade terminal. Physical prompts verify plot owner and distance on the server.

## Studio adversarial checks

Run these from a LocalScript or the client command bar while watching Server Output. Every request must be rejected without changing Coins, inventory, farm assignments, upgrades, run state, or rewards.

```lua
local remotes = game:GetService("ReplicatedStorage").Remotes

remotes.FarmAction:FireServer({ Action = "Collect", Coins = 999999 })
remotes.FarmAction:FireServer({ Action = "PlaceBrainrot", SlotIndex = 0/0, InstanceId = "not-owned" })
remotes.UpgradeAction:FireServer({ Action = "PurchaseUpgrade", UpgradeId = "GiveCoins" })
remotes.DecisionVote:FireServer({ Action = "Vote", RunId = "stale", DecisionId = "stale", Choice = "UPGRADE" })
remotes.RoomAction:FireServer({ Action = "ReachExit", RunId = "stale", RoomId = "stale" })
```

Then fire any one remote repeatedly. Valid requests beyond its burst allowance must return `RATE_LIMITED`; the server logs the first rejection and every configured threshold without kicking the player.

## Remaining boundary

This pass validates remote intent and server-observed interaction distance. A dedicated movement anti-cheat for sophisticated teleport/speed manipulation is a separate system; it must use tolerant server movement checks to avoid punishing normal latency. No current reward or economy operation trusts a client-reported position, amount, rarity, or item stat.
