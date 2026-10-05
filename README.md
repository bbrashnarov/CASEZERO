# CASE ZERO — Android Vertical Slice 0.1.0

Мобилна детективска игра (portrait, Android ARM64). Този репозиторий съдържа Vertical Slice-а
по `CASE_ZERO_Vertical_Slice_BG.md` (v1.0, 2026-10-05): C01 „Отвореният прозорец“, C02
„Последното обаждане“, C03 „Грешният влак“, Case Board, прогрес, улики, изводи, подсказки,
save/load, audio/haptic hooks, локална analytics, настройки, replay.

Engine: **Godot 4.7.2-stable**, typed GDScript (решение TD-001 в
`docs/TECHNICAL_IMPLEMENTATION_PLAN.md`). Art pack-ът още не е доставен — сцените са GREYBOX.

## Документи

| Файл | Съдържание |
|---|---|
| `CASE_ZERO_Vertical_Slice_BG.md` | Авторитетната спецификация |
| `docs/ARCHITECTURE.md` | Слоеве, поток на данните, persistence, UI |
| `docs/CONTENT_GUIDE.md` | Как се добавя/променя случай само чрез content (C04) |
| `docs/TEST_REPORT.md` | Резултати: unit/persistence/integration/UI, AT01–AT20, kill тест, APK |
| `docs/KNOWN_ISSUES.md` | Непроверено, ограничения на средата, интерпретации, допълнения |
| `docs/FINAL_IMPLEMENTATION_REPORT.md` | Финален отчет (14 раздела) |

## Пускане на desktop

```sh
godot --path .      # играта (SCN_BOOT); с editor binary е dev режим → debug overlay (бутон DBG горе вдясно)
```

## Тестове

```sh
godot --headless --path . --import                       # веднъж след clone
godot --headless --path . -s res://tests/run_tests.gd    # 109 теста: unit, persistence, integration, UI, AT01–AT20
tools/qa/kill_test.sh                                    # истински kill -9 по време на запис (13 точки)
```

Content validator-ът и solvability проверката се пускат при всеки старт на играта (fail fast —
игра със счупен content показва грешка на boot екрана) и в `tests/unit/test_content.gd`.

Скрийншоти на референтните устройства/font scale:

```sh
xvfb-run -a -s "-screen 0 1280x2400x24" godot --path . --rendering-driver opengl3 -s res://tools/screenshots.gd
```

## Android build

Изисква Godot 4.7.2 export templates, JDK 17 и Android build-tools (`apksigner`, `zipalign`).

```sh
tools/build/make_keystores.sh            # веднъж: локален debug + тестов release ключ в build/keystores (извън git)
tools/build/build_android.sh all         # import → тестове → export dev/playtest/release → apksigner verify → inspect
```

| Профил | Package | Debug overlay | Подпис |
|---|---|---|---|
| Dev | `com.casezero.verticalslice.dev` | да | debug keystore |
| Playtest | `com.casezero.verticalslice.playtest` | не | release ключ |
| Release | `com.casezero.verticalslice` | не | release ключ |

Истинският release ключ се подава само през environment (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
`_USER`, `_PASSWORD`); никога не се commit-ва. Без тях скриптът ползва локалния тестов ключ —
такива APK-та не са за разпространение. Нищо не се публикува автоматично в Google Play.
AAB изисква Gradle build с Android SDK (виж KNOWN_ISSUES E1).

## Структура

```
content/        manifest, ui_text, cases/C0x.json — целият gameplay е data
src/core        CZ константи, Log, UUID
src/content     ContentDB, CaseDef, Predicate DSL, ContentValidator
src/state       GameState (schema, validate)
src/gameplay    Reducer, interaction profiles, deduction, hints, timeline, solvability
src/store       Store: dispatch → reduce → persist → commit
src/persistence SaveRepository (checksum, tmp→rename, .bak), migrations
src/navigation  Router (base screen + modal stack)
src/ui          AppShell, screens, modals, investigation view, kit
src/analytics   Локален JSONL log, 5 MiB FIFO, export
src/app         App (composition root), BootService, AppContext, CaseFlow
tests/          runner + unit/persistence/integration/ui/acceptance
tools/          build, QA (kill test), screenshots
```
