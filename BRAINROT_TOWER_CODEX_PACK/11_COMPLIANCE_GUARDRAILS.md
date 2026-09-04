# ROBLOX COMPLIANCE GUARDRAILS

Этот файл - продуктовые ограничения, не юридическое заключение. Перед релизом повторно проверить актуальные Roblox Community Standards и Creator Hub.

## Основное правило проекта
Permanent Brainrots, Coins, Robux и другие owned items НЕ используются как ставка на случайный исход.

Нельзя строить core loop как:
`поставь owned Brainrot -> random result -> получи больше или потеряй его`.

В текущей версии Roblox Community Standards запрещают simulated/actual gambling activities и обмен real money, Robux или in-game items of value в связи с gambling activity.

## Что используется вместо этого
- Challenge за gameplay action.
- После success появляется **Pending Reward**, ещё не находящийся в permanent inventory.
- Игрок может Claim его или пойти на более сложный challenge.
- При fail теряется только Pending Reward текущего run.
- Permanent collection не затрагивается.
- Consolation reward гарантирован и deterministic по config.

## Casino-style presentation
Визуальные отсылки к казино сами по себе не должны превращаться в playable gambling. Для более безопасного позиционирования использовать темы: chaos tower, arcade lab, vault, game show, challenge rooms. Не использовать механики roulette/poker/slot wagering как основу прогресса.

## Paid random items - будущая функция, НЕ MVP
Если когда-либо игрок сможет потратить Robux или валюту, купленную за Robux, на random virtual reward, это отдельный policy scope. Roblox Creator Hub требует, среди прочего:
- показать все возможные outcomes и фактические numerical odds до покупки;
- учитывать per-user eligibility через `PolicyService:GetPolicyInfoForPlayerAsync()` и `ArePaidRandomItemsRestricted`;
- учитывать ограничения на trading paid items через `IsPaidItemTradingAllowed`;
- каждый возможный outcome paid random item должен давать benefit пользователю.

MVP намеренно не содержит paid random items.

## Monetization recommendation
Для первых версий использовать:
- guaranteed cosmetics;
- plot themes;
- emotes;
- nameplates;
- deterministic cosmetic bundles;
- private server / convenience where appropriate.

Не продавать "luck", rarity odds или ставки permanent items в MVP.

## Official references to re-check before launch
- Roblox Community Standards - about.roblox.com/community-standards
- Paid random items guidelines - Creator Hub: "Paid random items policy guidelines"
- PolicyService - Creator Hub: "PolicyService / GetPolicyInfoForPlayerAsync"
