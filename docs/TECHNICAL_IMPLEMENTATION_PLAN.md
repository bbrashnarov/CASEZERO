# CASE ZERO — Technical Implementation Plan

Източник: `CASE_ZERO_Vertical_Slice_BG.md` (Версия 1.0, 5 октомври 2026), прочетен изцяло.
Документът е authoritative за поведението. Този план описва само инженерните решения, които
спецификацията оставя отворени (Part 12 §N, точка 1–4).

---

## TECHNICAL DECISION TD-001 — ENGINE

**Решение:** Godot Engine **4.7.2-stable** (official build), език **GDScript 2.0** (typed).

**Аргументация**

| Критерий | Godot 4.7 | Unity 6 |
|---|---|---|
| 2D/portrait UI | Control/Container система с anchors, ScrollContainer, theme; няма нужда от 3rd party UI | uGUI/UI Toolkit, добре, но по-тежко |
| Android build | Prebuilt export templates, ARM64, APK/AAB, export presets в текстов файл | Изисква Unity Hub, лиценз, Android module |
| Автоматизиран headless CI | `godot --headless` пуска тестове, validator и export без лиценз и без GPU | batchmode изисква лиценз/активация |
| Git-friendly | `.tscn`, `.tres`, `project.godot`, `export_presets.cfg` са текст | YAML scenes + .meta файлове, merge конфликти |
| Размер на runtime | APK ≈ 30–40 MB за ARM64 2D | обикновено по-голям |
| Rapid iteration | Редакторът стартира за секунди; hot reload на скриптове | по-бавен domain reload |
| Developer availability | По-малък пазар от Unity, но GDScript е лесен; домейн слоят е чист код | най-голям пазар |
| Лиценз | MIT, без runtime fees | търговски условия |

За този slice (2D, портрет, UI-heavy, без физика и 3D) Godot покрива всички изисквания с по-малко
инфраструктура, а решаващият аргумент е, че целият тестов и build pipeline (unit, integration,
acceptance, content validation, process-kill тестове и Android export) върви headless в CI
без лицензи. Рискът „по-малко Godot разработчици“ е ограничен, защото gameplay логиката е чист
GDScript без зависимост от сцени (виж Architecture) и съдържанието е JSON.

**Ограничение, което не променя поведението:** спецификацията е engine-agnostic (Part 12 §A).
Не използваме Godot physics, Area2D input или camera zoom за gameplay; всичко е собствен
hit-test в canonical координати.

---

## 1–4. Engine, version, language, Android target

| # | Решение |
|---|---|
| 1 | Godot Engine |
| 2 | 4.7.2-stable (`project.godot` → `config/features=4.7`) |
| 3 | GDScript 2.0, static typing задължително в domain слоя |
| 4 | Android: minSdk/targetSdk = стойностите на официалния prebuilt template за 4.7.2 (виж README, проверяват се от `tools/inspect_apk.py`); ABI **arm64-v8a**; portrait lock |

Gradle build не е нужен за slice-а (няма native plugins). Prebuilt templates дават
възпроизводим build без Android SDK platform download.

## 5. Project architecture

Слоеве (зависимостите са само надолу; няма цикли):

```
UI (screens, modals, investigation view, debug overlay)
   │ dispatch(Action) / чете read-only state и selectors
   ▼
Store (dispatcher: idempotency → reducer → invariants → persist → commit → signal)
   │                         │
   ▼                         ▼
Gameplay / Domain       Persistence (SaveRepository + backend + migrations)
(reducer, profiles,
 deduction, timeline,
 hint, resolution,
 predicates, selectors)
   │
   ▼
Content (typed definitions от JSON + validator)      State (schema, factory, invariants)

Подписчици на Store.committed (никога не пишат в state):
  Analytics · Audio feedback · Haptics · UI render
Platform (safe area, dp, font scale, vibration, lifecycle) — използва се от UI/Haptics
Assets (manifest registry AssetID → ресурс, greybox fallback, critical failure)
Navigation (Router: screen IDs, modal stack, Android Back contract)
```

Правила: domain кодът е `RefCounted`/static функции без `Node`, без `get_tree()`, без UI.
Reducer-ът е чиста функция `(state, action, content, ctx) → ReduceResult`; часовникът и UUID
генераторът са инжектирани (детерминистични тестове).

## 6. Folder structure

```
project.godot, export_presets.cfg
content/                  ← всичко, което case designer пипа
  manifest.json           ← content_version, case order, asset manifest, sound events
  ui_text.json            ← общи UI текстове (spec Part 2/4/8)
  cases/C01.json …        ← CaseDefinition (objects, evidence, stages, hints, texts)
src/
  core/        ids, logger, uuid, result codes
  content/     content_db, definitions, predicate, validator
  state/       game_state (schema/factory/invariants), selectors
  gameplay/    reducer, actions, profiles/, deduction, timeline, hints, resolution
  store/       store (transaction contract)
  persistence/ save_repository, file backend, memory backend (тестове), migrations
  navigation/  router, routes
  analytics/   analytics_service (local queue, 5 MiB FIFO, export)
  audio/       audio_service (Sound Event ID → AssetID)
  haptics/     haptics_service (NONE/LIGHT/MEDIUM)
  platform/    platform_service (safe area, dp, font scale, lifecycle)
  assets/      asset_registry (manifest resolve, greybox, critical failure)
  ui/          shell, theme, components, screens, modals, investigation
  debug/       debug_overlay
  app/         bootstrap (SCN_BOOT), composition root
scenes/        SCN_BOOT.tscn (main), shell scenes
assets/        greybox/placeholder art и audio (явно маркирани)
tests/         runner, unit/, integration/, acceptance/, kill/
tools/         validate_content, build scripts, apk inspection
docs/          този план, ARCHITECTURE, CONTENT_GUIDE, TEST_REPORT, KNOWN_ISSUES
```

## 7. Scene architecture

Conceptual сцени от спецификацията са `scene_id` в content и маршрути в Router:

| Conceptual | Реализация |
|---|---|
| SCN_BOOT | `scenes/SCN_BOOT.tscn` — main scene, composition root, Boot screen |
| SCN_BOARD | Board screen в shell-а |
| SCN_C01_ROOM / SCN_C02_DESK / SCN_C03_STATION | един reusable `InvestigationView`, параметризиран от `CaseDefinition.scene_id` |

Inspection, evidence, hint, deduction, pause, confirm, picker, write error, solved, reward са
reusable modal components в един `ModalHost`, не отделни engine сцени. При смяна на случай
предишният InvestigationView и неговите текстури се освобождават (един активен case).

## 8. UI architecture

* `AppShell` (Control, full-rect) със слоеве: Screen → HUD → Modal → Feedback(toast) → Debug.
* `LayoutMetrics`: canonical 1080×1920, U = Android safe rect, header/footer anchored към U
  с 16dp margin, scene viewport `s = min(availW/1080, availH/1332)`, center; inverse transform за input.
* `TapGesture`: единствената имплементация на input contract-а (pointer-up, ≤12dp, ≤500ms,
  един pointer, cancel) — ползва се и от scene objects, и от UI бутоните.
* Hit-test: canonical hitbox → разширение до 48dp → priority/z/ID ред → G_PICKER при >25% overlap.
* Текст: sp × system font scale (1.0–2.0); модалите са title + ScrollContainer body + fixed footer
  CTA, така primary CTA никога не излиза извън viewport.
* UI компонентите (CMP_*) са общи; case-специфичен UI widget няма.

## 9. Data / content architecture

* `CaseDefinition` JSON: метаданни, run_fields (case-specific state като phone_power/charger/
  link_ok/timeline), invariants, objects (rect, hitbox, z, priority, profile, gate, detail копие,
  evidence, variants), evidence registry, stages (single_answer / evidence_set / timeline),
  success predicate, hints (texts + target order), solved текст.
* Predicate DSL (JSON): `has_all`, `q`, `field/eq`, `campaign_completed`, `all/any/not`, `true`.
  Използва се за gates, stage unlock, success, hint targets, invariants.
* Interaction profiles (`P_INSPECT`, `P_PHONE`, `P_CHARGER`, `P_MANAGER`) са код в registry;
  обектът избира profile + параметри. Нов case = нов JSON + assets.
* Validator (dev/build time, fail fast) — всички проверки от заданието.

## 10. GameState architecture

Точно Part 10 schema (`schema_version`, `content_version`, `campaign{xp,completed,reward_granted}`,
`settings`, `last_case`, `runs{}`), плюс persisted `interaction_index` и journal
`committed_action_ids` (bounded) за idempotency. Run = started, run_id, evidence (set → sorted
array без дубликати), objects[id].inspection, questions, hint_level, attempts, solved, active_ms +
case run_fields. Derived (deduction_unlocked, evidence_counter, case_unlocked, stage, gates) са
selectors, не се записват. Runtime-only (route, selected_*, input_locked) живеят в UI/Router.

## 11. Persistence architecture

* Snapshot файл `user://save/save.json` с envelope `{format, schema_version, checksum(SHA-256),
  payload}`; запис: temp → flush/close → readback verify → rotate текущия в `.bak` → atomic rename.
* Load: primary → при corruption `.bak` → при двойна corruption recovery dialog; повреденото копие
  се пази за диагностика; campaign не се трие автоматично.
* `Store.dispatch` персистира преди commit на live state; при грешка → `G_WRITE_ERROR`
  (Retry със същия action_id / Revert към последния committed snapshot).
* Migration registry `schema_version → migrate()`; текуща версия 1; по-нова версия → unsupported
  dialog без презапис; content_version несъвместимост → валидиране на runs срещу content,
  невалиден run → предложение за reset само на него.
* Записи при всяко semantic action (clue, charger, stage, timeline, hint, reset, solve, settings,
  progression) + active time checkpoint на 5 s; никога разчитане на quit callback.

## 12. Navigation architecture

`Router` държи base route + modal stack от Screen IDs от спецификацията (`G_*`, `<CASE>_INTRO`,
`<CASE>_SCENE`, `<CASE>_INSPECT_<OBJ>`, `<CASE>_EVIDENCE`, `<CASE>_DETAIL_CARD(ev)`, `<CASE>_HINT`,
`<CASE>_PAUSE`, `<CASE>_CONFIRM_RESET`, stage screens, `<CASE>_SOLVED`, `<CASE>_REWARD`).
Бутоните не сменят сцени директно — викат Router/Store. Android Back се обработва централно
(`NOTIFICATION_WM_GO_BACK_REQUEST`) по таблицата от Part 4. Input lock при transitions и writes.

## 13. Asset loading strategy

`AssetRegistry` резолвира AssetID → manifest entry → ресурс. Липсващ non-critical → greybox
(labelled rectangle). Липсващ critical (BG, interactive sprite, evidence icon) при production
build → readable error с Asset ID / Case ID / expected type; в dev build greybox е позволен и
видимо маркиран. Сцената се preload-ва преди показване; предишният case се освобождава.

## 14. Analytics architecture

Локален `AnalyticsService` слуша `Store.committed` и Router; добавя common properties
(Part 11), пише JSONL в `user://analytics/events.jsonl`; бюджет 5 MiB с FIFO drop на най-старите;
никога не пипа save; грешка при запис = log + продължаваме. Export бутон само в playtest/dev build
(файл + clipboard). Няма мрежови извиквания.

## 15. Audio architecture

Gameplay дава само Sound Event ID (`SFX_*`, `AMB_*`); `AudioService` мапва към AssetID по manifest,
пул от плейъри, rate limit 1 UI tap / 100 ms, master toggle, пауза на ambience при background.
Placeholder звуците са генерирани тонове, маркирани като placeholder.

## 16. Testing strategy

* Собствен headless test runner (`tests/run_tests.gd`, без външни addon-и).
* Unit: predicates, reducer за всеки action, profiles, deduction типове, timeline, hints, atomicSolve,
  reward idempotency, evidence uniqueness, unlock rules, migrations, validator.
* Persistence: write/read, atomic failure, corrupted primary/backup, schema mismatch, restore.
* Integration: happy paths, alternative flows, wrong deductions, restart, replay през Store + Router.
* Acceptance: AT01–AT20 като именувани тестове; AT15/16 частично headless + ръчна проверка.
* UI: headless инстанциране на shell + симулирани touch събития върху изчислени координати
  за 360×640, 360×800, 412×915 dp и tablet.
* Process kill: реален `kill -9` на Godot процес след commit на critical transition, рестарт и проверка.
* Device/performance: само реално измерени стойности; без устройство → NOT RUN в TEST_REPORT.

## 17. Android build strategy

* `export_presets.cfg`: `Android Dev` (debug, dev features), `Android Playtest` (playtest feature,
  analytics export, без debug overlay), `Android Release` (release, тих log).
* package `com.casezero.verticalslice`, version name `0.1.0`, version code `1`, portrait, arm64-v8a.
* Keystores извън git: debug keystore се генерира от `tools/make_debug_keystore.sh`; release
  чрез `GODOT_ANDROID_KEYSTORE_RELEASE_*` env vars.
* `tools/build_android.sh` прави validate → tests → export APK (AAB само при наличен gradle pipeline).
* Не публикуваме в Google Play.

---

## Implementation order и C01 gate

Следваме Phase 1–9 от заданието. C02 съдържание не се добавя, докато C01 не изпълни gate-а:
complete flow, save/load, restart, hint, evidence, deduction, reward, replay, Android Back,
process kill recovery — с тестове в TEST_REPORT.

## Наблюдения при четене на спецификацията

Не са открити IMPLEMENTATION BLOCKER-и. Неясноти, решени без промяна на видимото поведение,
се водят в `docs/KNOWN_ISSUES.md` (раздел „Interpretations“) и в Deviations от финалния отчет.
