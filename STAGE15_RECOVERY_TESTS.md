# Stage 15 — Save / Failure Recovery

Stage 15 делает подтверждённые `Collect` и `PurchaseUpgrade` повторяемыми без повторного начисления или списания. Клиент создаёт `RequestId`, а сервер сохраняет результат операции в профиле атомарно с изменением Coins/upgrade level. Success отправляется только после немедленного сохранения профиля. Повтор того же запроса возвращает сохранённый результат; использование одного `RequestId` для другой операции отклоняется.

## Что изменено

- `Collect`: начисление Coins и receipt фиксируются одним изменением профиля.
- `PurchaseUpgrade`: списание Coins, новый level и receipt фиксируются одним изменением профиля.
- При временной ошибке сохранения UI предлагает retry с тем же `RequestId`, а не создаёт вторую денежную операцию.
- Disconnect/rejoin: release профиля повторяется при временной ошибке и безопасно принимает повтор уже подтверждённого release.
- Room disconnect: переносимый предмет сбрасывается; требования Reactor/Laser уменьшаются под оставшуюся команду.
- Decision disconnect: игрок удаляется из electorate и его голос удаляется; результат пересчитывается, безопасный default остаётся `CLAIM`.
- После Claim: существующий `ClaimReceipt` гарантирует ровно один permanent instance, а success отправляется только после немедленного save.
- Журнал операций ограничен 128 последними записями.

## Автоматический Studio-тест

1. Запусти Play в Roblox Studio.
2. Открой **View → Command Bar** на стороне Server.
3. Выполни:

```lua
print(require(game.ServerScriptService.Tests.Stage15RecoveryTests).Run())
```

Ожидаемый результат в Output:

```text
[Stage15RecoveryTests] PASS (13 checks)
```

Повтор `Collect` можно отдельно проверить в Server Command Bar на запущенном сервере:

```lua
local player = game.Players:GetPlayers()[1]
local farm = require(game.ServerScriptService.Services.FarmService)
print(farm.CollectCoins(player, "manual-stage15-collect"))
print(farm.CollectCoins(player, "manual-stage15-collect"))
```

Оба вызова вернут один и тот же результат операции, но wallet изменится только после первого вызова. Для повторного прогона используй новый id или перезапусти Studio server.

## Обязательная ручная проверка disconnects

Используй **Test → Start** с двумя Players.

1. **Room:** один игрок берёт Energy Cell и отключается. Cell должен вернуться, требование комнаты — пересчитаться, оставшийся игрок может завершить room.
2. **Decision:** один игрок голосует `UPGRADE` и отключается. Его vote исчезает; решение считается только для оставшихся игроков. При отсутствии большинства результат — `CLAIM`.
3. **После Claim:** дождись успешного Claim, отключись и зайди снова. В permanent inventory должен быть ровно один полученный instance.
4. **Во время Collect:** нажми Collect и сразу отключись после success-ответа. После входа баланс не меньше подтверждённого и повторный запрос с тем же `RequestId` не начисляет Coins второй раз.
5. **Во время purchase:** купи upgrade и сразу отключись после success-ответа. После входа level сохранён, цена списана ровно один раз; повтор того же `RequestId` не покупает следующий level.
6. Проверь Server Output: нет `PROFILE_MUTATOR_FAILED`, `SESSION_LOCK_LOST` для обычного rejoin и новых runtime errors.

Для настоящей проверки DataStore выключи `UseMockDataInStudio` только в отдельной опубликованной тестовой версии с включённым **Enable Studio Access to API Services**. Не делай это в рабочем place с production-данными.
