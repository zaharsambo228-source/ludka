# DATA MODELS / CONFIG EXAMPLES

## BrainrotDefinitions
```lua
return {
    ToasterGoblin = {
        Id = "ToasterGoblin",
        DisplayName = "Toaster Goblin",
        Rarity = "Common",
        BaseProductionPerMinute = 12,
        ModelName = "ToasterGoblin",
        CollectionGroup = "Launch01",
    },
}
```

## Player profile schema
```lua
{
    SchemaVersion = 1,
    Coins = 0,
    Dust = 0,
    Brainrots = {
        -- [instanceId] = {
        --   BrainrotId = "ToasterGoblin",
        --   Variant = "Normal",
        --   AcquiredAt = 0,
        --   Source = "Tower",
        --   IsLocked = false,
        -- }
    },
    CollectionIndex = {},
    Farm = {
        UnlockedSlots = 2,
        Slots = {
            -- ["1"] = instanceId
        },
        LastCollectTimestamp = 0,
    },
    Upgrades = {
        FarmEfficiency = 1,
        OfflineStorage = 1,
    },
    Stats = {
        Runs = 0,
        Claims = 0,
        HighestStage = 0,
    },
}
```

## Run session
```lua
{
    RunId = "...",
    State = "ROOM",
    Participants = {},
    Stage = 2,
    CurrentRarity = "Uncommon",
    PendingReward = nil,
    DecisionId = nil,
    Votes = {},
    ActiveRoomId = nil,
}
```

## Farm production calculation
```lua
ProductionPerMinute = 0
for each occupied unlocked slot:
    definition = BrainrotDefinitions[instance.BrainrotId]
    ProductionPerMinute += definition.BaseProductionPerMinute
ProductionPerMinute *= FarmEfficiencyMultiplier

elapsed = min(now - LastCollectTimestamp, OfflineCapSeconds)
coins = floor(ProductionPerMinute * elapsed / 60)
```

## Important persistence rule
Не сохранять визуальную модель Farm как источник истины. Истина - data model. При join FarmService восстанавливает физические display models из сохранённых slot assignments.
