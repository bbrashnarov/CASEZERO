# ARCHITECTURE — CASE ZERO Vertical Slice

Engine: Godot 4.7.2, typed GDScript. Решението и алтернативите са в
`docs/TECHNICAL_IMPLEMENTATION_PLAN.md` (TD-001). Тук е описано как е построено.

## 1. Принципи

* **Gameplay е data.** Обекти, хитбоксове, улики, gates, етапи, отговори, подсказки, текстове и
  asset ID идват от `content/`. Кодът знае само *типове* поведение (interaction profiles, stage
  types, predicate оператори).
* **Една посока на данните.** UI → `Action` → Store → Reducer (чиста функция) → проверка на
  инварианти → атомичен запис → commit → сигнал → UI/audio/haptics/analytics.
* **Само committed състояние се вижда.** Звук, вибрация, analytics и успешни екрани реагират
  на `Store.committed`, т.е. след като save-ът е на диска.
* **Зависимостите вървят надолу**, без цикли:

```
UI (AppShell, screens, modals, InvestigationView, DebugOverlay)
  │ AppContext.perform(type, payload)      чете state + Selectors
  ▼
Store ── Reducer ── Profiles / Deduction / Hints / Timeline / Resolution
  │          └── ContentDB / CaseDef / Predicate
  ▼
SaveRepository ── SaveCodec ── SaveBackend (File | Memory)
```

## 2. Слоеве и файлове

| Слой | Файлове | Отговорност |
|---|---|---|
| Core | `src/core/cz.gd`, `log.gd`, `uuid.gd` | Константи от спецификацията (тайминги, 48dp, 12dp/500ms, XP=100), structured log, UUID v4 |
| Content | `src/content/*` | `ContentDB` зарежда manifest/ui_text/cases; `CaseDef` дава индекси; `Predicate` е DSL-ът; `ContentValidator` проверява референции, геометрия, gates, assets |
| State | `src/state/game_state.gd` | Schema на GameState, initial run, `check()` (инварианти + content invariants) |
| Gameplay | `src/gameplay/*` | `Reducer.reduce(state, action, db, ctx)` — чист; profiles (`P_INSPECT`, `P_PHONE`, `P_CHARGER`, `P_MANAGER`); `Deduction` (single_answer / evidence_set / timeline); `Hints`; `Selectors`; `Solvability` (BFS над достижими състояния) |
| Store | `src/store/store.gd` | Idempotency (кеш на резултати + журнал `committed_action_ids`), инварианти, persist, pending при write failure, retry/revert |
| Persistence | `src/persistence/*` | Envelope `{schema, checksum (SHA-256), payload}`; запис tmp → rename; ротация на `save.bak`; повреден файл се пази като `save.corrupt.*`; `Migrations` |
| Boot | `src/app/boot_service.gd` | FRESH → `C01_INTRO`; LOADED → `G_BOARD`; backup recovery; по-нов schema / повреда → Recovery диалог; нов случай в content → разширява кампанията |
| Navigation | `src/navigation/router.gd` | Route = речник `{id, kind, case_id, ...}`; base screen + modal stack; ID-тата са screen ID от спецификацията |
| UI | `src/ui/*` | `AppShell` рендерира Router state; screens/modals; `InvestigationView` (canonical 1080×1332 сцена, hit-test, G_PICKER); `LayoutMetrics` (dp/sp, safe area, scene/modal rect); `TapGesture` |
| Services | `audio`, `haptics`, `analytics`, `platform`, `assets` | Hooks; analytics е локален JSONL; platform дава build flavor, font scale, insets |
| App | `src/app/app.gd`, `app_context.gd`, `case_flow.gd` | Composition root, lifecycle, Back, active time; `AppContext.perform` с продължение през G_WRITE_ERROR |
| Debug | `src/debug/debug_overlay.gd` | Само при feature `dev` |

## 3. Actions и резултати

Actions (`CZ`): `START_CASE`, `INSPECT_OBJECT`, `CONNECT_CHARGER`, `PLACE_TIMELINE_TOKEN`,
`SUBMIT_STAGE`, `REQUEST_HINT`, `RESET_RUN`, `SET_SETTING`, `NAVIGATE`, `CHECKPOINT_ACTIVE_TIME`.
Всеки action има `id` (UUID). Резултат: `OK | NOOP | REJECTED | DUPLICATE | WRITE_FAILED` плюс
`code` (`CORRECT`, `WRONG`, `SOLVED`, `GATE_LOCKED`, …), `feedback` (sfx, haptic, toast),
`events` (за analytics) и `persist`.

* **Idempotency:** повторен `action_id` връща предишния резултат без промяна (AT13).
* **Атомичен solve:** финалният верен отговор в един transition задава въпроса, `solved`,
  `campaign.completed[case]`, отключва следващия случай и добавя XP — само при първо решаване
  (100), при replay 0. Записва се като един snapshot.
* **Write failure:** state не се сменя; предложеното състояние остава `pending`; G_WRITE_ERROR
  предлага Retry (същия action и proposed state) или връща назад. Back = revert.

## 4. Persistence

`user://save/save.json` + `save.bak`. Запис: encode → (ако текущият е валиден → копие в `.bak`)
→ запис в `.tmp` → rename. При зареждане: primary → проверка на checksum и schema → при
неуспех `.bak` → при неуспех Recovery. Проверено с истински `kill -9` по време на 13 точки от
записа (`tools/qa/kill_test.sh`). `FileAccess` няма fsync (виж KNOWN_ISSUES).

## 5. UI

* Canvas 1080×1920, stretch `canvas_items` + `expand`, portrait. `LayoutMetrics` превръща dp/sp
  в логически пиксели и смята safe area; сцената се мащабира равномерно в `scene_rect` (без
  разтягане, letterbox).
* Input: `TapGesture` приема tap на pointer-up при движение ≤12 dp и продължителност ≤500 ms.
  Хитбоксовете се разширяват до ≥48 dp на екрана; ако повече от един обект покрива точката с
  >25% припокриване → G_PICKER.
* Модалите блокират сцената; затварянето е 120 ms fade без click-through.
* Font scale 1.0–2.0: шрифтът не се намалява; header и тела скролират, footer бутоните минават
  един под друг, CTA остава видим (тествано на 3 референтни устройства × 2 font scale).

## 6. Analytics

`user://analytics/events.jsonl`, общ лимит 5 MiB, FIFO изтриване на най-старите редове.
Всички 20 събития от спецификацията, с `event_id`, `session_id`, `run_id`, `build_id`,
`content_version`, `route`, `interaction_index`, `active_ms`. Без PII (няма device ID, имена,
свободен текст). Export копира файла в `user://exports/`; нищо не се изпраща по мрежата и APK-то
няма INTERNET permission.

## 7. Build flavors

Feature tags в `export_presets.cfg`: `dev` (overlay, DEBUG логове, симулирани грешки),
`playtest`, release (без tag). `PlatformService.is_dev` е единствената проверка за cheats.
