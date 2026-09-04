# PRODUCT VISION / GDD

## Working title
**BRAINROT TOWER**

Название рабочее. Перед релизом выбрать оригинальный бренд и оригинальные персонажи/ассеты. Не копировать чужие конкретные мем-персонажи, модели, музыку, логотипы или названия без прав.

## Genre
Co-op party roguelite + collection + tycoon/farm meta.

## Players
1-6 игроков на сервер/забег.

## Player fantasy
Игрок собирает абсурдных существ Brainrots, рискует незакреплённой наградой ради более редкой версии, затем выставляет пойманных существ на своей базе и превращает коллекцию в растущую фабрику Coins.

## Три столпа

### 1. Social push-your-luck
Команда постоянно решает: забрать уже заработанную награду или идти дальше за более высокой редкостью.

### 2. Collection obsession
Каждый Brainrot имеет rarity, production value, visual identity и запись в Index. Игрок хочет закрыть коллекцию и находить более редкие варианты.

### 3. Persistent farm progression
Полученные существа не просто лежат в инвентаре. Их можно разместить на Farm Slots, и они производят Coins. Это превращает каждый удачный забег в заметное усиление базы.

## Основной цикл сессии

LOBBY / FARM
-> собрать накопленные Coins
-> купить deterministic upgrades
-> выбрать loadout
-> войти в Tower
-> пройти Challenge Room
-> получить Pending Brainrot
-> CLAIM или UPGRADE
-> следующий более сложный challenge
-> CLAIM / fail / extraction
-> Brainrot попадает в permanent inventory
-> вернуть на Farm
-> поставить в слот
-> Brainrot генерирует Coins
-> покупать upgrades
-> следующий run

## Session targets
- Короткий run: 6-10 минут.
- Полный цикл lobby -> run -> reward -> farm должен ощущаться законченным за 10-15 минут.
- Первого Brainrot игрок должен получить в первые 2-4 минуты знакомства.
- Первое farm placement - сразу после первого успешного run.

## Emotional beats
1. "О, выпал Rare!"
2. "Забираем или идём дальше?"
3. "Ещё одна комната - будет Epic."
4. "Надо было забирать..."
5. "Ладно, получил Dust/Coins consolation, ещё раз."
6. "Поставил нового на ферму - теперь база производит заметно больше."

## Необходимая социальная драма
Команда должна видеть текущий Pending Reward, следующий возможный tier и последствия решения. Важно, чтобы друзья могли обсуждать решение, но система не должна позволять одному игроку бесконечно grief-ить всех без согласия. Для multiplayer решения использовать voting/ready confirmation.

## MVP content
- 1 Lobby.
- 1 Personal Farm Plot на игрока.
- 1 Tower biome.
- 3 room archetypes.
- 12 оригинальных Brainrots.
- 5 rarities.
- 6 farm slots (2 открыты в начале).
- 4 farm upgrades.
- 5-8 минут на run.
- DataStore.
- Collection Index.

## Post-MVP
- 3-4 Tower biomes.
- 40-80+ Brainrots.
- mutations/variants.
- social display plots.
- quests.
- seasonal collections.
- cosmetics.
- achievements.
- matchmaking/party improvements.
- deterministic crafting that does not consume owned items for a chance-based gamble.
