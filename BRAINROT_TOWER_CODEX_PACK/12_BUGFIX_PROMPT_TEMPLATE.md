# BUGFIX PROMPT TEMPLATE FOR CODEX

Используй этот шаблон вместо "почини всё".

```text
У нас баг после Stage [N]. Не добавляй новые features и не переписывай архитектуру целиком.

EXPECTED:
[что должно происходить]

ACTUAL:
[что происходит]

REPRO:
1. ...
2. ...
3. ...

ROBLOX OUTPUT / ERROR:
[вставить полный error + stack trace]

AFFECTED SYSTEM:
[RunService / FarmService / Inventory / UI / Data etc]

Ограничения:
- сначала найди root cause;
- перечисли файлы, которые реально нужно изменить;
- сохрани server-authoritative rules;
- не ослабляй validation ради исправления;
- не создавай параллельную систему;
- после fix дай точный Studio test plan;
- если замечаешь unrelated проблему, только отметь её, но не исправляй без необходимости.
```
