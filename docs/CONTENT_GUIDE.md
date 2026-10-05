# CONTENT GUIDE — как се добавя или променя случай

Целият gameplay на един случай е в `content/cases/<CaseID>.json`. Нов случай, който ползва
съществуващите типове поведение, **не изисква код**. Примерът по-долу добавя C04.

## 1. Стъпки за C04

1. Създай `content/cases/C04.json` (копирай най-близкия случай като шаблон).
2. В `content/manifest.json`:
   * добави `"C04"` в `cases` (редът е редът на Case Board);
   * добави `"C04": "res://content/cases/C04.json"` в `case_files`;
   * добави всички asset ID на C04 в `assets` (`path: null`, докато няма art → greybox);
   * при нов ambience — запис в `sound_events`.
3. В C03.json смени `"next_case": null` → `"C04"` и махни `"on_complete": "G_END"` (сложи го на C04).
4. Пусни `godot --headless --path . -s res://tests/run_tests.gd`. `test_shipped_content_is_valid`
   и `test_shipped_content_is_solvable` трябва да минат; иначе съобщенията казват кое поле е грешно.
5. Съществуващи save-ове: при старт `BootService` вижда нов случай в content и добавя run за него
   (log „content extension: new case added to campaign“). Миграция не е нужна.

## 2. Поле по поле

| Поле | Тип | Бележка |
|---|---|---|
| `case_id`, `order` | string, int | ID е и префикс на screen ID (`C04_INTRO`, `C04_SCENE`, …) |
| `title`, `title_en`, `objective`, `opening_text`, `solved_text` | string | Показват се дословно |
| `scene_id`, `thumbnail_asset`, `ambience` | ID | `ambience` е ключ в `sound_events` или `null` |
| `unlock` | predicate | Обикновено `{"campaign_completed": "C03"}` |
| `next_case` / `on_complete` | ID / `"G_END"` | Какво предлага Reward екранът |
| `intro_pulse` | `{object_id, duration_ms}` | По избор |
| `background` | `{object_id, asset_id, rect, z}` | `rect` е в canonical 1080×1920 |
| `run_fields` | map | Допълнителни полета на run-а: `enum` (`values`, `initial`), `bool` (`initial`), `token_slots` (`size`) |
| `invariants` | [predicate] | Трябва винаги да са true; Store отказва transition, който ги нарушава |
| `objects` | [object] | Виж §3 |
| `evidence` | [evidence] | `id`, `name`, `source_object`, `icon`, `required`, `card_text` |
| `stages` | [stage] | Виж §4 |
| `success` | predicate | Кога случаят е решен (проверява се при финалния етап) |
| `hints` | `{texts[3], targets[]}` | `targets`: `{object_id, satisfied, available?}`; първата незадоволена налична цел се pulse-ва |

## 3. Обекти

Задължителни: `id`, `name`, `asset_id`, `rect [x,y,w,h]`, `layer`, `z`, `clickable`, `input`,
`profile`, `physical_state`, `required`. За кликаеми още: `hitbox` (вътре в сцената
`[0,264,1080,1332]`, ≥48 dp, без припокриване с други хитбоксове на baseline), `priority`,
`gate` (predicate; при не-`true` и `locked_text`), `inspect_screen` (`C04_INSPECT_*`),
`detail_asset_id`, `detail_text`, `evidence`.

Profiles (поведение в код, `src/gameplay/profiles/`):

| Profile | Какво прави | Допълнителни полета |
|---|---|---|
| `P_INSPECT` | Първи tap дава `evidence`, повторен показва „Прегледано“ | — |
| `P_MANAGER` | Като P_INSPECT, обикновено зад gate | `gate`, `locked_text` |
| `P_PHONE` | Текст и улики според стойност на run field | `variant_field`, `variants{value: {detail_text, evidence}}` за всяка стойност |
| `P_CHARGER` | CTA бутон в inspect панела, сменя run fields | `cta{action, label, done_label, enabled_when, effects, event, event_prior_fields, sound}` |
| `NONE` | Декор, не е кликаем | `hitbox: null`, `input: "NONE"` |

Нов тип взаимодействие = нов profile клас + регистрация в `Profiles` и `ContentValidator.KNOWN_PROFILES`.

## 4. Етапи (stages)

Общи полета: `id`, `screen`, `type`, `question`, `unlock` (predicate), `required_evidence`,
`result` (`{"question": <stage id>}` или `{"field": <bool run field>}`), `final`,
`incorrect_feedback`, по избор `correct_feedback`, `success_cta`, `waiting_cta`.

| `type` | Полета |
|---|---|
| `single_answer` | `answers[{id, text}]`, `correct` |
| `evidence_set` | `select_count`, `correct_set`, `submit_label` |
| `timeline` | `slots_field` (token_slots run field), `tokens[{id, label, sources}]`, `display_order`, `correct_order`, `slot_labels` |

Точно един етап е `final: true`. Грешен отговор увеличава `attempts`, не дава наказание.

## 5. Predicate DSL

```
true | false
{"all": [p, ...]}   {"any": [p, ...]}   {"not": p}
{"has_all": ["EV_..."]}            уликите са в run-а
{"q": "C04_Q1"}                    въпросът/етапът е минат
{"field": "name", "eq": value}     run field == value
{"campaign_completed": "C03"}
```

Predicates четат само domain state (run + campaign), никога UI.

## 6. Какво проверява validator-ът

Уникални ID; всяка референция (evidence, object, field, asset, sound, stage, case) съществува;
хитбоксове в сцената, ≥48 dp, без baseline припокриване; всяка улика се произвежда от своя
`source_object`; всяка стойност на `variant_field` има вариант; CTA effects са позволени
стойности; точно един финален етап; `result` сочи правилно; задължителни текстове не са празни;
`ui_text` има нужните ключове. `Solvability` обхожда всички достижими състояния и проверява, че
всяка задължителна улика и решението са достижими без заключване (няма цикли в gates).

## 7. Текстове и assets

* UI текстовете извън случаите са в `content/ui_text.json`: `spec` (дословно от спецификацията)
  и `engineering` (допълнени от нас; виж KNOWN_ISSUES §4).
* Asset: `{id, case, type, size, critical, path}`. Попълни `path` с `res://assets/...`, когато
  art-ът е доставен. При `art_pack.greybox_allowed: false` липсващ критичен asset е грешка.
