# ACCEPTANCE CHECKLIST

## Общий gate после каждого Stage
- Roblox Studio Output без новых ошибок.
- Нет infinite yields на ожидаемых объектах.
- Server и client responsibilities не смешаны.
- Новые constants вынесены в config, если они balance-related.
- Multi-client test выполнен минимум с 2 players для multiplayer стадий.

## Data
- [ ] Fresh player получает defaults.
- [ ] Rejoin восстанавливает Coins/Dust/Brainrots/Farm/Upgrades.
- [ ] Duplicate instance ids невозможны.
- [ ] Ошибка save не приводит к silent overwrite пустыми данными.

## Inventory
- [ ] Сервер может выдать Brainrot.
- [ ] Клиент напрямую не может вызвать arbitrary grant.
- [ ] Duplicates допустимы.
- [ ] Collection Index открывается после первого получения.

## Farm
- [ ] Только unlocked slots доступны.
- [ ] Нельзя поставить несуществующий/чужой InstanceId.
- [ ] Один instance не занимает два slots.
- [ ] Placement сохраняется после rejoin.
- [ ] Remove корректно освобождает instance.

## Coins
- [ ] Collect рассчитывает сервер.
- [ ] Spam Collect не дюпает Coins.
- [ ] Offline cap работает.
- [ ] Production пересчитывается после place/remove.

## Upgrades
- [ ] Цена списывается один раз.
- [ ] Недостаток Coins отклоняется.
- [ ] Эффект совпадает с UI.
- [ ] Upgrade сохраняется.

## Run
- [ ] State transitions идут только допустимым путём.
- [ ] RunId меняется на новый run.
- [ ] Stale remote от старого run отклоняется.
- [ ] Room cleanup не оставляет active connections.

## Pending Reward
- [ ] Success создаёт Pending, а не permanent item.
- [ ] Claim создаёт ровно один permanent instance.
- [ ] После Claim следующий fail не может удалить item.
- [ ] Upgrade fail удаляет только Pending.
- [ ] Consolation выдаётся один раз.

## Voting
- [ ] Один vote на player/DecisionId.
- [ ] Tie -> Claim.
- [ ] Timeout -> Claim.
- [ ] UI отображает итог.

## UX
- [ ] Pending визуально помечен.
- [ ] Перед Upgrade явно написано, что pending reward может быть потерян.
- [ ] Permanent inventory не выглядит как stake.
- [ ] Farm production понятен в Coins/min.

## Security
- [ ] Client cannot set Coins amount.
- [ ] Client cannot choose rarity.
- [ ] Client cannot choose arbitrary reward id outside allowed action.
- [ ] Client cannot place чужой instance.
- [ ] Rate limits работают.
- [ ] Physical interactions include distance/state checks.
