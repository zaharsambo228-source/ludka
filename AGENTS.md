# Brainrot Tower — instructions for AI agents

This repository is a Roblox/Luau MVP managed with Rojo. Read this file before running or changing the project.

## Source of truth

- Rojo project: `default.project.json`
- Game code: `src/`
- Product and architecture documents: `BRAINROT_TOWER_CODEX_PACK/`
- Gameplay balance: `src/ReplicatedStorage/Shared/BalanceConfig.lua`
- Runtime/security settings: `src/ReplicatedStorage/Shared/GameConfig.lua`
- Recovery test guide: `STAGE15_RECOVERY_TESTS.md`
- Balance guide: `STAGE16_BALANCE_CONFIG.md`

Do not duplicate production rates, upgrade prices, gameplay timers, tier difficulty, or consolation rewards outside `BalanceConfig.lua`.

## Toolchain

The pinned toolchain is declared in `rokit.toml`:

- Rojo `7.7.0`
- Roblox Studio with the Rojo Studio plugin

If Rojo is unavailable and Rokit is installed, run `rokit install` from the repository root. Installing tools can require network access and user approval.

## Run the game with live Rojo sync

From the repository root, start the Rojo server:

```bash
rojo serve default.project.json
```

Then:

1. Open Roblox Studio and create an empty Baseplate.
2. Open the Rojo plugin.
3. Connect to `localhost:34872`.
4. Wait for synchronization and press **Play**.
5. Open **View → Output** and verify that the server and client bootstraps load.

Expected server messages include:

```text
[BrainrotTower] Server bootstrap loaded 13 services
[BrainrotTower] World generated: lobby, 6 farm plots, 5 tower floors
[Balance] Config v2
```

Keep the `rojo serve` process running while editing files. Rojo synchronization updates Studio from the filesystem; source changes should be made in this repository, not only inside Studio.

## Run without the Studio plugin

Build a place file:

```bash
rojo build default.project.json -o BrainrotTower.rbxlx
```

On macOS, open it with:

```bash
open BrainrotTower.rbxlx
```

Then press **Play** in Roblox Studio.

Do not commit generated `.rbxlx` files unless the user explicitly asks for build artifacts.

## Verification

Always run these non-runtime checks after code or project-map changes:

```bash
rojo sourcemap default.project.json -o /tmp/brainrot-sourcemap.json
rojo build default.project.json -o /tmp/BrainrotTower.rbxlx
git diff --check
```

Rojo build validates the project mapping but does not execute Luau gameplay. Do not claim runtime success unless the project was also tested in Roblox Studio.

For Stage 15 recovery checks, start Play mode, select the Server Command Bar, and run:

```lua
print(require(game.ServerScriptService.Tests.Stage15RecoveryTests).Run())
```

Expected result:

```text
[Stage15RecoveryTests] PASS (13 checks)
```

To print the active balance configuration from the Server Command Bar:

```lua
require(game.ServerScriptService.Services.BalanceDebugService).PrintReport()
```

Multiplayer/disconnect scenarios must be tested through **Test → Start** with at least two players. Follow `STAGE15_RECOVERY_TESTS.md` for the full checklist.

To verify the generated lobby, six farm plots, and five physical Tower floors, run in the Server Command Bar:

```lua
print(require(game.ServerScriptService.Tests.WorldLayoutTests).Run())
```

Expected result: `[WorldLayoutTests] PASS (17 checks)`. Generated map geometry appears only after the Studio server enters Play/Test mode.

## Studio data safety

`GameConfig.PlayerData.UseMockDataInStudio` is currently `true`. Studio profiles persist only for the current Studio server session and reset when it restarts.

Do not disable mock data against a production place. Real DataStore testing requires a separately published test place and **Enable Studio Access to API Services**.

## macOS Studio locale compatibility

The current test machine uses the `ru_RU` macOS region, and Roblox Studio has emitted `Malformed number` for ordinary decimal Luau literals. Project source therefore expresses fractional constants as arithmetic fractions such as `(1 / 20)` instead of `0.05`. Keep `src/**/*.lua` free of decimal literals until Studio no longer reproduces the parser issue. If a player spawns over an empty void, check Studio Output or the latest Roblox Studio log for `Malformed number` before debugging world generation.
