# TECHNICAL ARCHITECTURE - ROBLOX / LUAU

## Principles
1. Server authoritative.
2. Modular Services + Controllers.
3. Config-driven content.
4. Explicit state machines.
5. No giant scripts.
6. Idempotent reward/save operations where possible.
7. Client never chooses reward amount, rarity result, Coins payout or owned item identity without server validation.

## Suggested hierarchy

ReplicatedStorage
- Remotes
  - RunAction
  - DecisionVote
  - RoomAction
  - FarmAction
  - InventoryAction
  - UIEvent
- Shared
  - GameConfig
  - BalanceConfig
  - BrainrotDefinitions
  - RoomDefinitions
  - UpgradeDefinitions
  - Types
  - Util

ServerScriptService
- Services
  - GameService
  - RunService
  - RoomService
  - RewardService
  - InventoryService
  - FarmService
  - EconomyService
  - UpgradeService
  - PlayerDataService
  - PolicyServiceWrapper
  - AntiExploitService

StarterPlayer/StarterPlayerScripts
- Controllers
  - HUDController
  - RunController
  - RoomController
  - FarmController
  - InventoryController
  - InteractionController
  - AudioController

StarterGui
- MainHUD
- DecisionUI
- RewardRevealUI
- InventoryUI
- FarmUI
- UpgradeUI
- CollectionUI

Workspace
- Lobby
- FarmPlots
- Tower
  - Biome01
    - RoomSpawnPoints

## Game state machine
WAITING
-> PREPARATION
-> TRAVEL
-> ROOM
-> DECISION
-> ROOM / EXTRACTION
-> RESULTS
-> RETURN_TO_LOBBY

## RunService owns
- current run id;
- participants;
- current stage/tier;
- current pending reward;
- current room;
- run timestamps;
- transition rules;
- extraction/failure.

## RewardService owns
- choosing a reward from a rarity pool;
- generating permanent `InstanceId` only on Claim;
- atomic-ish claim guard per RunId/Stage;
- consolation reward;
- collection discovery signal.

## FarmService owns
- slot unlock state;
- slot -> Brainrot InstanceId assignment;
- production calculation;
- offline cap;
- collect operation;
- display model spawn/despawn.

## PlayerDataService owns
Versioned profile schema:
- Coins
- Dust
- BrainrotInstances
- CollectionIndex
- Farm
- Upgrades
- Stats
- Settings

Use session locking/profile pattern appropriate for Roblox. Do not implement naïve GetAsync/SetAsync on every click.

## Remote validation
Every remote validates:
- player is in expected game state;
- distance from interacted object if physical;
- rate limit;
- referenced id exists;
- ownership;
- slot unlocked;
- run/session id matches;
- action is valid for current room phase.

## Concurrency
Critical operations use server guards:
- Claim reward once;
- Collect Coins once;
- Place instance in one slot only;
- Purchase upgrade once per balance check;
- Vote once per DecisionId.

## Recovery
If a room script errors:
- cancel active room;
- do not silently delete claimed inventory;
- if Pending existed, choose conservative recovery (return to Decision/Claim or end run with explicit safe compensation depending on implementation);
- log error with RunId.
