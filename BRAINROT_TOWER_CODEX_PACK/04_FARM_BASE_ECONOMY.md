# FARM / PERSONAL BASE / COIN ECONOMY

## Цель фермы
Ферма превращает коллекцию в долгосрочную прогрессию. Получил Brainrot -> поставил на слот -> он генерирует Coins -> Coins улучшают базу -> следующий Brainrot ценнее для аккаунта.

## Personal plot
В Lobby у каждого игрока есть personal plot/base zone.

MVP:
- 6 физических Farm Slots;
- 2 слота открыты изначально;
- остальные разблокируются за Coins;
- рядом terminal для Collect / Upgrade / Inventory.

## Placement flow
1. Игрок подходит к пустому Farm Slot.
2. Нажимает Interact.
3. Открывается список owned Brainrots, которые не стоят в других слотах.
4. Игрок выбирает конкретный `InstanceId`.
5. Клиент отправляет только запрос place.
6. Сервер проверяет ownership, slot ownership, slot unlocked, instance not already placed.
7. Сервер сохраняет assignment и создаёт display model.

## Production formula
Базовый MVP:

`coinsPerMinute = Brainrot.BaseProductionPerMinute * RarityMultiplier * FarmProductionMultiplier`

Если позже появятся variants:
`* VariantMultiplier`

Не использовать чрезмерно сложную формулу в MVP.

## Online production
Сервер начисляет production по времени, но не обязательно каждую секунду записывает DataStore.

Рекомендуемая схема:
- считать текущее накопление математически от `LastCollectTimestamp`;
- UI обновлять локально для красоты;
- authoritative Collect рассчитывает сервер;
- save state хранит timestamps и placement.

## Offline production
MVP можно включить с cap:
- максимум 4 часа offline production;
- формула использует server timestamp;
- при входе показать `Welcome back: +X Coins`;
- cap хранится в config.

Это предотвращает слишком большой snowball от долгого отсутствия.

## Coin wallet
Coins - soft currency, заработанная gameplay/farm.

В MVP Coins нельзя покупать напрямую за Robux, чтобы не смешивать farm progression с будущими random-reward системами.

## Guaranteed upgrades
Все перечисленные покупки deterministic.

### Slot Unlocks
Slot 3 - 500 Coins
Slot 4 - 2,000
Slot 5 - 7,500
Slot 6 - 20,000

### Farm Efficiency
Level 1 -> 1.00x
Level 2 -> 1.10x
Level 3 -> 1.25x
Level 4 -> 1.45x
Level 5 -> 1.70x

### Offline Storage
Level 1: 30 min
Level 2: 60 min
Level 3: 120 min
Level 4: 240 min

### Collection Display
Deterministic cosmetic expansions: pedestals, signs, plot themes.

## Optional run-prep upgrades
Очень осторожно с power creep.

Допустимые примеры:
- +1 revive token per run at high cost;
- slightly longer decision timer;
- lobby movement quality-of-life;
- extra loadout slot for non-random utility.

Лучше не продавать за Coins прямое увеличение rarity odds в MVP. Это ухудшает баланс и запутывает policy boundary.

## Collect UX
Над terminal:
`UNCLAIMED: 1,842 COINS`

Кнопка:
`COLLECT`

После collect:
- server adds Coins;
- `LastCollectTimestamp = now`;
- feedback: floating `+1,842`;
- sound/VFX.

## Anti-exploit rules
- production рассчитывает server time;
- клиент не отправляет количество Coins;
- клиент не указывает arbitrary Brainrot stats;
- сервер берёт stats только из BrainrotDefinitions;
- slot placement проверяется по `InstanceId`;
- повторный Collect в один timestamp не дублирует доход;
- DataStore writes debounce/batch.

## Economy target
Игрок должен чувствовать прирост в первые 10-20 минут, но не открыть всю ферму за одну сессию.

Пример early progression:
- первый Brainrot: 10-20 coins/min;
- 2 стартовых слота -> 20-40/min;
- Slot 3 достижим после нескольких runs/короткой фермы;
- Rare/Epic заметно ускоряют производство.

Все числа считать placeholders и вынести в BalanceConfig.
