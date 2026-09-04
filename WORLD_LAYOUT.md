# Brainrot Tower — physical world layout

The world is generated on the server when Play starts. The source is `WorldBuilderService.lua`; Rojo Edit mode shows the source tree, while the generated geometry appears during Studio Play/Test.

## Zones

- **Lobby:** large central island, player spawn, five rarity pedestals and the Tower entrance.
- **Farm District:** shared ground with six visibly marked player plots. A joined player's full farm is built over the assigned outline.
- **Tower:** five physical floors stacked vertically. Common is floor 1 and Mythic is floor 5.
- **Challenge rooms:** each active room is generated on the floor matching the current run tier instead of reusing one ground-level platform.

The Tower gate has a server-controlled ProximityPrompt, so a player can start a run physically or use the HUD button.

## Relevant configuration

World dimensions and positions are in `src/ReplicatedStorage/Shared/GameConfig.lua` under `Farm` and `World`. Tier gameplay difficulty remains in `BalanceConfig.lua`.

## Studio check

1. Run `rojo serve default.project.json`.
2. Connect the Rojo Studio plugin.
3. Press **Play**; generated geometry does not appear before the server starts.
4. Verify this Output line:

```text
[BrainrotTower] World generated: lobby, 6 farm plots, 5 tower floors
```

5. Walk to the red Tower gate or press **START TOWER**.
6. Complete a room and choose **UPGRADE** to confirm the next room appears one floor higher.

Automated structure check from the Server Command Bar:

```lua
print(require(game.ServerScriptService.Tests.WorldLayoutTests).Run())
```

Expected result: `[WorldLayoutTests] PASS (17 checks)`.
