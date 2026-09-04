# UI / UX FLOW

## Lobby HUD
Top:
- Coins
- Dust
- Collection count

World UI:
- Farm terminal
- Upgrade terminal
- Tower entrance

## Farm slot UI
Empty:
`EMPTY SLOT`
`Place Brainrot`

Occupied:
`[Name]`
`Rare`
`+42 Coins/min`
`Manage`

## Run HUD
Top center:
`STAGE 3 / 5`
`NEXT REWARD TIER: EPIC`

Top right:
room timer.

Bottom/side:
team status icons.

## Reward Reveal
После room success:
- короткая camera/UI reveal;
- Brainrot icon/model;
- name;
- rarity;
- farm production estimate;

Затем Decision UI.

## Decision UI
Большая понятная развилка:

`CURRENT PENDING REWARD`
`RARE - WiFi Pigeon`
`Produces 55 Coins/min base`

`CLAIM & EXTRACT`
Safe: reward becomes permanent

`UPGRADE CHALLENGE`
Next target: EPIC
If the next challenge fails, this pending reward is lost.

Для multiplayer показывать votes X/Y.

## Failure UI
Не использовать только "YOU LOST".

Показать:
`PENDING REWARD LOST`
`Consolation: +20 Dust`
`Permanent collection unchanged`

Это очень важно для понимания правил.

## Farm Collect UI
`Farm produced while you were away: +1,250 Coins`

В upgrade screen всегда показывать before -> after:
`Production: 1.25x -> 1.45x`
`Cost: 7,500 Coins`

## UX rules
- не скрывать, что именно потеряется при Upgrade;
- не использовать misleading countdowns для магазина;
- permanent inventory и pending reward визуально различать;
- любой deterministic upgrade показывает точный эффект;
- mobile touch targets >= разумного размера;
- controller/keyboard navigation добавить после mobile/PC MVP.
