# Stage 16 — Balance Config

Все значения, влияющие на экономику и темп MVP, собраны в `src/ReplicatedStorage/Shared/BalanceConfig.lua`:

- production каждого Brainrot;
- цены Slot Unlock, Farm Efficiency и Offline Storage;
- efficiency multipliers и offline caps;
- preparation, travel и decision timers;
- параметры пяти tiers для трёх challenge rooms;
- consolation Dust;
- короткие UI/gameplay timers и interaction distances.

`BrainrotDefinitions` и `UpgradeDefinitions` больше не содержат собственных копий production/price curves — они ссылаются на `BalanceConfig`.

## Быстрый просмотр в Studio

При старте Studio server текущий баланс автоматически печатается в Output с префиксом `[Balance]`.

Повторный вывод из Server Command Bar:

```lua
require(game.ServerScriptService.Services.BalanceDebugService).PrintReport()
```

Автопроверка при bootstrap останавливает запуск, если:

- у Brainrot нет положительного production;
- production ссылается на неизвестный Brainrot;
- пропущена цена уровня upgrade;
- у комнаты не пять tiers;
- timer, difficulty field или consolation имеют неположительное значение.

После изменения `BalanceConfig` перезапусти Studio server и проверь Output, полный игровой цикл и экономические значения в Farm/Upgrade UI.
