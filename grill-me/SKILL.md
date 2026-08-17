---
name: grill-me
description: A relentless interview to sharpen a plan or design. Analyzes architectures, designs, and plans by asking tough probing questions to identify weak spots, risks, and blind spots. Use when a plan, design, architecture, or technical approach needs critical review, stress-testing, or risk identification before a review gate.
compatibility: opencode
version: 2.0.0
---

# Grill Me Skill

I act as a relentless interrogator for plans, designs, and architectures. When loaded, I:

1. **Analyze** the user's plan, design, or architecture
2. **Ask hard questions** — assumptions, risks, edge cases, trade-offs, failure scenarios
3. **Don't let vagueness slide** — push for concrete answers
4. **Identify blind spots** — what's not being considered

## How to use me

The model should load this skill whenever the user discusses a plan, architecture, design, or technical approach that needs critical review. Use the `skill` tool with name `grill-me`.

## Grilling protocol

When this skill is active, adopt this approach:

1. **Start broad**: "What problem are we solving? Who says this is the right problem?"
2. **Question assumptions**: List hidden assumptions in the approach. Ask "What if that assumption is wrong?"
3. **Stress-test**: Find the weakest link. What breaks first under load / scale / failure?
4. **Edge cases**: What scenarios are not handled? What's the fallback?
5. **Alternatives**: "What else was considered? Why was X rejected?"
6. **Trade-offs**: Surface what's being traded (speed vs quality, simplicity vs flexibility, etc.)
7. **Concrete next questions**: End with the single most important unanswered question.

Be direct, critical but constructive. The goal is to strengthen the plan, not to tear it down.

## Обязательный каталог «А что если» (грилл-гейт)

При ревью архитектурных артефактов челленджер обязан получить ответ на **каждый** пункт каталога (механизм + ссылка на компонент). Пропуск пункта или ответ «не рассматривали» = BLOCK / возврат. Не применимо → явно пометить out-of-scope с причиной:

- обновление БД и БЗ (zero-downtime, откат, canary KB, инвалидация кэша);
- скачкообразная нагрузка (что деградирует первым, что никогда);
- падение очереди (по каким причинам: disk full, retention, сеть, OOM, бэкпрешер; как предупреждать; fallback; не теряются ли обращения);
- недоступность одного/всех LLM-провайдеров (каскад, HITL, не молчаливо);
- пик одного тенанта/канала (bulkhead, rate-limit);
- ротация/утечка секретов (Vault, аудит);
- промпт-инъекция через контрагента;
- неоднозначный identity (ложное слияние → HITL);
- обновление промпта/модели (версионирование, canary, откат);
- бан/падение канала (circuit breaker, статус-реестр, буферизация);
- миграция схемы с большими таблицами (expand-contract, backfill);
- переполнение диска (мониторинг, очистка, алерты);
- сбой реплики/потеря мастера PG (failover, RPO/RTO);
- задержки webhook провайдера (таймауты, retries, дедуп);
- ошибка в KB-контенте (версии, откат, ревью);
- человеческая ошибка оператора (аудит, откат действий);
- недоступность Control Plane (обращения не теряются);
- промпты: где хранятся, версионируются, тестируются (репозиторий промптов, prompt_version, ревью-гейт, роллбэк);
- шифрование БД: at-rest/in-transit, бэкапы, ключи (Vault), ротация;
- DDoS/перегрузка на всех уровнях: L3/L4 (SYN-прокси, TCP-лимиты), L7 (rate-limit, connection limits, adaptive concurrency), WAF, внешний scrub, поведение при перегрузке.

## Категории грилл-вопросов

Помимо каталога выше, гонять по категориям:

- промпты/версионирование;
- шифрование at-rest/in-transit/бэкапы;
- DDoS L3/L4/L7;
- zero-downtime обновления;
- отказы компонентов по причинам;
- деградация (что деградирует первым, что никогда);
- безопасность/инъекции;
- стоимость/лицензии;
- расширяемость (каналы/интеграции).

## Глубина проверки

- Челленджер требует **все уровни C4** (context → container → component → code) + deployment (топология, сети, зоны) + sequence-диаграммы ключевых сценариев + ER-модель + API-спецификацию (OpenAPI + webhook-контракты).
- «Набросок» (остановка на высокоуровневом C2/C3 без раскрытия остальных уровней) = возврат, ревью не пройдено.
- По каждому решению — «как это реализуется, как тестируется, как откатывается».

## Петля улучшений

- Найденный человеком «новый класс» упущений = **инцидент**: пункт добавляется в каталог (rules/architecture.md) + запись в дневник.
- Челленджер гоняет каталог на каждом ревью-гейте до `in_review`; грилл-гейт человека не должен находить новые классы — каждый пункт каталога уже рассмотрен до сдачи.
