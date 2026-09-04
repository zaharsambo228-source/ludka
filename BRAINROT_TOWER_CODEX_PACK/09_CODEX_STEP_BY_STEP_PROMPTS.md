# CODEX - ПОЭТАПНЫЕ ПРОМПТЫ

## Правило
Перед каждым этапом Codex должен прочитать GDD и текущий код. Не позволять ему переписывать рабочую архитектуру без причины.

---

## STAGE 0 - AUDIT
**Отправить:**

Прочитай все markdown-документы из BRAINROT_TOWER_CODEX_PACK. Затем проанализируй текущий Roblox-проект. Пока ничего не меняй. Составь краткую карту существующей структуры, конфликтов с целевой архитектурой и точный список файлов/instances, которые потребуется создать или изменить для Stage 1. Не придумывай APIs, которых нет. Сохрани серверную authoritative модель как главный принцип.

---

## STAGE 1 - PROJECT SKELETON
Создай только каркас из `05_TECHNICAL_ARCHITECTURE.md`: Shared configs, Services, Controllers, Remotes и базовые Types. Не реализуй геймплей целиком. Добавь минимальный Bootstrap, который запускается без ошибок. Не создавай giant script. После изменений перечисли созданные файлы и как проверить запуск в Studio.

Acceptance: проект стартует без runtime errors; модули require-ятся корректно.

---

## STAGE 2 - PLAYER DATA
Реализуй versioned PlayerDataService для Coins, Dust, BrainrotInstances, CollectionIndex, Farm, Upgrades и Stats согласно `08_DATA_MODELS_AND_CONFIGS.md`. Нужна безопасная загрузка/сохранение, defaults, migration hook и session-safe подход. Не сохраняй каждую секунду. Добавь mock/test path для Studio, если DataStore недоступен.

Acceptance: join/leave не теряет данные; defaults валидны; повторный join восстанавливает профиль.

---

## STAGE 3 - BRAINROT DEFINITIONS + INVENTORY
Реализуй BrainrotDefinitions для 12 placeholder Brainrots, InventoryService и server API для выдачи Brainrot instance по definition id. InstanceId должен быть уникальным. Добавь CollectionIndex discovery. Клиент не может сам выдать себе Brainrot. Сделай debug-only server command/function для Studio теста.

Acceptance: server grants instance; inventory UI/debug output видит его; duplicate instances работают.

---

## STAGE 4 - FARM PLOT + SLOTS
Реализуй Personal Farm Plot MVP. 6 slots, стартово 2 unlocked. FarmService должен уметь Place/Remove конкретный owned Brainrot instance. Проверяй ownership и двойное размещение. В Workspace создавай display model из definition, но data model остаётся источником истины.

Acceptance: place/remove работает после rejoin; один instance не может занять два слота.

---

## STAGE 5 - FARM PRODUCTION + COINS
Реализуй authoritative production calculation и Collect. Используй timestamps, OfflineCap и FarmEfficiency. Клиент никогда не сообщает сумму Coins. UI может показывать прогноз, но collect рассчитывает сервер. Добавь floating feedback.

Acceptance: два быстрых Collect не дюпают Coins; offline cap соблюдается; production меняется от состава farm.

---

## STAGE 6 - DETERMINISTIC UPGRADES
Реализуй UpgradeService и UpgradeDefinitions: Slot Unlocks, Farm Efficiency, Offline Storage. Покупка проверяет Coins server-side и точно применяет заявленный эффект. UI показывает before/after и cost.

Acceptance: недостаток Coins блокирует purchase; повторное нажатие не дюпает upgrade; rejoin сохраняет level.

---

## STAGE 7 - RUN STATE MACHINE
Реализуй RunService state machine: WAITING -> PREPARATION -> TRAVEL -> ROOM -> DECISION -> ROOM/RESULTS -> RETURN_TO_LOBBY. Пока без сложных комнат. Добавь RunId и participant tracking.

Acceptance: state transitions предсказуемы; stale client event не меняет новый run.

---

## STAGE 8 - FIRST ROOM: REACTOR RUN
Создай первую полноценную challenge room - Reactor Run. Цель skill-based: перенести/активировать Energy Cells до конца времени, с hazards. Tier влияет на difficulty. RoomService должен иметь Start/Action/Resolve/Cancel/Cleanup. Сервер определяет success/fail.

Acceptance: solo и 2-player проходят; fail корректно завершает room; cleanup не оставляет connections/objects.

---

## STAGE 9 - PENDING REWARD + CLAIM
После room success RewardService выбирает конкретного Brainrot из текущего rarity и создаёт только PendingReward в run session. Реализуй Claim: только сервер создаёт permanent instance, очищает Pending и помечает Claim выполненным для DecisionId. Claim должен быть idempotent.

Acceptance: spam Claim даёт ровно один instance; disconnect после confirmed Claim не удаляет награду.

---

## STAGE 10 - UPGRADE DECISION / VOTING
Добавь Decision Phase 10-15 секунд. Игроки голосуют CLAIM или UPGRADE. Majority wins; tie/no vote defaults to CLAIM. При UPGRADE стартует следующий tier room. При следующем fail PendingReward теряется, permanent inventory не меняется, выдаётся consolation Dust.

Acceptance: vote counted once/player; stale DecisionId rejected; loss удаляет только Pending.

---

## STAGE 11 - TWO MORE ROOMS
Добавь Signal Sequence и Laser Grid через тот же RoomService contract. Не дублируй общую state logic. Difficulty config зависит от tier.

Acceptance: 3 room types можно случайно выбрать; каждый cleanly resolves/cancels.

---

## STAGE 12 - REWARD REVEAL + UI
Сделай MainHUD, RewardReveal, DecisionUI, FailureUI, FarmUI, UpgradeUI, InventoryUI. Чётко различай Pending и Permanent. Показывай farm production и конкретный эффект upgrades. Mobile-first touch areas.

Acceptance: игрок всегда понимает, что именно он может потерять при Upgrade.

---

## STAGE 13 - COMPLETE MVP LOOP
Свяжи: Lobby/Farm -> Tower Run -> Claim/Upgrade -> reward -> Return -> Place Brainrot -> Collect Coins -> Upgrade -> next run. Добавь simple tutorial hints на первый цикл.

Acceptance: новый аккаунт может пройти полный loop без debug tools.

---

## STAGE 14 - SECURITY / EXPLOIT PASS
Проведи audit всех RemoteEvents. Добавь server-side validation, rate limiting, distance checks, ownership checks, RunId/DecisionId/session validation. Клиент не может выбрать reward, Coins payout, rarity result или чужой InstanceId. Составь список закрытых exploit vectors.

Acceptance: намеренно некорректные remote payloads не создают ценность и не ломают state.

---

## STAGE 15 - SAVE / FAILURE RECOVERY TESTS
Проверь disconnects в: Room, Decision, после Claim, во время Collect, во время purchase. Добавь conservative recovery. Не допускай item/Coins duplication или loss после confirmed transaction.

---

## STAGE 16 - BALANCE CONFIG
Вынеси production, upgrade prices, timers, tier difficulty и consolation в BalanceConfig. Не хардкодь числа в UI/Services. Добавь developer debug panel или server config print для быстрой настройки.

---

## STAGE 17 - POLISH
Только теперь добавить VFX/SFX hooks, animations, farm idle animations, reward reveal polish, lobby signage и collection index presentation. Не использовать copyrighted assets.

---

## STAGE 18 - POST-MVP ROADMAP
После стабильного MVP предложи архитектурно совместимый план для новых biomes, 40+ Brainrots, variants, cosmetics, quests и seasonal content. Ничего не внедряй без отдельного запроса.
