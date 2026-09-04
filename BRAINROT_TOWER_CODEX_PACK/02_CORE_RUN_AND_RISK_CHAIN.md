# CORE RUN + CLAIM / UPGRADE RISK CHAIN

## Главная идея
Во время run игроки НЕ рискуют permanent inventory. Риск относится только к **Pending Reward**, который ещё не стал собственностью игрока.

## Reward states

### NONE
Награды ещё нет.

### PENDING
Команда успешно прошла комнату и увидела конкретного Brainrot текущего rarity. Он ещё не записан в permanent inventory.

### CLAIMED
Игрок/команда нажали Claim; награда сервером добавлена в inventory и больше не может исчезнуть от результата текущей цепочки.

### LOST_PENDING
Следующая challenge-комната провалена. Pending Brainrot исчезает; permanent inventory не меняется. Игрок получает небольшой consolation reward.

## Пример цепочки
Stage 1 success -> Common Pending
- CLAIM -> Common permanent
- UPGRADE -> Stage 2

Stage 2 success -> Rare Pending
- CLAIM -> Rare permanent
- UPGRADE -> Stage 3

Stage 3 success -> Epic Pending
- CLAIM -> Epic permanent
- UPGRADE -> Stage 4

Stage 4 success -> Mythic Pending
- CLAIM -> Mythic permanent
- UPGRADE -> Stage 5

Stage 5 success -> Secret Pending -> автоматически/ручным Claim закрепить награду.

## Rarity ladder для MVP
1. Common
2. Uncommon
3. Rare
4. Epic
5. Mythic

Secret добавить после MVP как aspirational tier.

## Как повышается риск
Не использовать только скрытый RNG. Желательно, чтобы повышение tier в основном происходило через **более сложное игровое испытание**, где навык игрока влияет на исход.

Пример Difficulty:
- Common: очень легко, tutorial-friendly.
- Uncommon: простая механика + ограничение времени.
- Rare: больше hazards.
- Epic: командная координация.
- Mythic: напряжённая multi-phase room.

## Multiplayer decision
После успешной комнаты сервер запускает `DecisionPhase` на 10-15 секунд.

UI:
CURRENT REWARD: RARE [Brainrot Name]
CLAIM NOW
or
UPGRADE TO EPIC CHALLENGE

Вариант MVP: большинство голосов.
- каждый игрок голосует Claim / Upgrade;
- ничья -> Claim (безопасный default);
- отсутствующий голос -> Claim;
- после решения сервер блокирует повторное голосование.

Позже можно дать Party Leader режим, но только как явно выбранный party option.

## Consolation reward
При `LOST_PENDING` игрок получает гарантированный ресурс, например `Brainrot Dust` или небольшое количество Coins.

Цель:
- поражение не должно быть полностью пустым;
- consolation не должен быть выгоднее Claim;
- он не должен превращать игру в бесконечный AFK farm.

Пример MVP:
Common loss: 5 Dust
Uncommon loss: 10 Dust
Rare loss: 20 Dust
Epic loss: 35 Dust
Mythic loss: 50 Dust

Dust можно использовать для deterministic cosmetics, collection pity progress или гарантированного выбора из известного набора - без ставки owned item на случайный исход.

## Challenge Room A: Reactor Run
Команда переносит Energy Cells через опасную комнату до стабилизатора. Чем выше tier, тем больше hazards и меньше времени.

## Challenge Room B: Signal Sequence
На стенах показывается последовательность символов. Игроки должны активировать панели в правильном порядке. На высоком tier sequence длиннее, появляются decoys.

## Challenge Room C: Laser Grid
Игроки проходят динамический коридор с лазерами/платформами. Fail conditions настраиваются под tier.

## Fail conditions
- весь таймер комнаты истёк;
- командная задача не завершена;
- все активные игроки incapacitated;
- room-specific objective fail.

## Run end
Run заканчивается при:
- Claim + Extraction;
- максимальном tier и Claim;
- провале после Pending;
- voluntary abandon до первой награды;
- server-safe recovery при критической ошибке.

## Anti-frustration
- первые 1-2 стадии короткие;
- после Claim игрок получает награду немедленно на сервере;
- disconnect после server-confirmed Claim не отнимает награду;
- reconnect policy не должна позволять duplications;
- проигрыш в следующей комнате не трогает permanent inventory.
