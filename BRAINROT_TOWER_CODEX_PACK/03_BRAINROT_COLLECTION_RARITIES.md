# BRAINROT COLLECTION / RARITIES / INDEX

## Brainrot definition
Каждый Brainrot - оригинальное коллекционное существо с:
- уникальным `Id`;
- `DisplayName`;
- `Rarity`;
- `BaseProductionPerMinute`;
- `ModelName`;
- `IconAssetId`;
- `AnimationSet`;
- `CollectionGroup`;
- optional `Variant`;
- optional `FlavorText`.

## Rarities
Пример production multipliers:

| Rarity | Production multiplier | Visual language |
|---|---:|---|
| Common | 1.0x | простой силуэт |
| Uncommon | 1.5x | дополнительный VFX |
| Rare | 2.4x | яркая анимация |
| Epic | 4.0x | заметная aura |
| Mythic | 7.0x | уникальный entrance/VFX |
| Secret (post-MVP) | 12x+ | особая presentation |

Конкретные числа должны быть в config, а не захардкожены.

## Permanent inventory
Inventory хранит экземпляры Brainrot, а не только количество по Id.

Пример instance:
- `InstanceId` UUID/string
- `BrainrotId`
- `Variant`
- `AcquiredAt`
- `Source`
- `IsLocked`
- `FarmSlotId` nullable

Это позволит позже добавить variants, cosmetics, mutations и trading eligibility без миграции базовой модели.

## Collection Index
Index показывает:
- силуэт неизвестного Brainrot;
- открытый Brainrot после первого получения;
- rarity;
- base production;
- сколько экземпляров получено lifetime;
- best variant.

## Duplicate handling
Дубликаты разрешены и полезны для Farm.

Не надо автоматически удалять duplicate. Игрок может поставить несколько одинаковых Brainrots на разные слоты.

Позже можно добавить deterministic `Merge Progress`:
- отдать фиксированное количество дубликатов за гарантированный конкретный upgrade;
- без скрытого random success/fail.

## Initial content example
Создать 12 placeholders с оригинальными названиями, например:
- Toaster Goblin
- WiFi Pigeon
- Banana Router
- Vacuum Wizard
- Microwave Frog
- Printer Gremlin
- Traffic Cone King
- Disco Kettle
- Keyboard Crab
- Satellite Hamster
- Fridge Oracle
- Turbo Spoon

Это только placeholders для разработки; финальный art direction должен быть оригинальным.

## Reward selection
Для бесплатных gameplay rewards можно использовать серверный weighted selection по доступному pool внутри rarity. На этапе выдачи показать конкретный Brainrot. Если в будущем какой-либо random reward связан с Robux или валютой, покупаемой за Robux, понадобится отдельная policy-compliant система с раскрытием odds и PolicyService. MVP этого не делает.
