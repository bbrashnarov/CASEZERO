# CASE ZERO — QA Run 2: тест на реалния build 0.1.0 (ДОПЪЛНЕНИЕ към `CASE_ZERO_QA_Validation_Report.md`)

Дата: 2026-10-05 • Branch на имплементацията: `claude/project-thread-g4as3v` (слят в `claude/case-zero-qa-spec-gh22bh`) • Commit на APK-тата: `169c780` • Engine: Godot 4.7.2-stable (изтеглен от официалния release, `4.7.2.stable.official.ed1daf0bf`)

> **Промяна спрямо Run 1.** В Run 1 проверих само `main`/моя branch и намерих единствено спецификацията (CZ-QA-001, S0). Имплементацията, документите на програмиста, `docs/QA_TEST_PLAN.md` и двата APK-та са в друг branch. Сега са налични → **CZ-QA-001 е ЗАТВОРЕН**. Първият доклад остава като запис на Run 1; там, където Run 2 го опровергава или променя, това е посочено по-долу.

## 0. Ограничения (нищо тук не е измислено)
* **Няма Android устройство и няма emulator** (няма KVM/adb/Android SDK). Следователно **НЕ са изпълнени** ръчните QA01–QA32, които изискват устройство: реален lifecycle, реален font scale, cutout/gesture nav, вибрация, TalkBack, performance (fps, RAM, температура). Те остават **BLOCKED** и са за тестера със телефон.
* Всичко, което е изпълнено, е на **desktop Godot** върху същия код/content, който е в APK: headless тестове, fuzz, рендер на истинския UI през xvfb (1080-px canvas ≙ 360 dp).
* Инструкцията от програмиста (`docs/QA_TEST_PLAN.md`) е прочетена изцяло; нейните решения за C01–C03 са проверени срещу спецификацията и съвпадат.

## 1. Какво е изпълнено

| # | Проверка | Резултат |
|---|---|---|
| R1 | Независимо пускане на `tests/run_tests.gd` (109 теста) | **109 / 109 PASS**, 0 failed (ObjectDB leak предупреждение при изход, документирано в KNOWN_ISSUES §6) |
| R2 | Реален `kill -9` тест `tools/qa/kill_test.sh` (13 точки) | **13 / 13 PASS** |
| R3 | SHA-256 на APK-тата срещу `qa/apk/SHA256SUMS` | **OK** и за двата |
| R4 | Манифест и подпис на APK (androguard) | виж §2 |
| R5 | **Build traceability**: наново експортиран pack от commit-а ↔ съдържанието на APK | playtest: **164/164** файла (всички компилирани скриптове + content + project.binary) идентични; 3 разлики са само engine кешове (`uid_cache.bin`, `global_script_class_cache.cfg`, `SCN_BOOT.scn`). dev: идентично освен `app_icon_placeholder.png.import`. → APK-тата са изградени от този source. |
| R6 | Exact copy: 69 нормативни низа от спецификацията ↔ `content/*.json` ↔ content в двата APK | **0 липсващи** (`QA/tools/copy_check.py`) |
| R7 | Независим fuzz на Store/Reducer/Save (`QA/tools/godot/qa_fuzz.gd`): 300 seeds × 400 стъпки, ≈116 000 действия, 2 185 process-kill/restart, 183 инжектирани write failures, 1 553 replay-я + детерминирана replay фаза | **0 нарушения** на инвариантите O1–O9 (XP, reward, completion, unlock, evidence дубликати, C02 charger/phone, solved⇒success, restore==committed, dup action id) |
| R8 | Валидност на оракула (mutation sanity): внесен дефект „replay дава XP“ в копие | fuzz **го засича** (180 failures); suite-ът на програмиста също го засича (4 failures, §5.1) |
| R9 | Рендер на истинския UI (xvfb) на 360×640 / 412×915, font 1.0 / 1.3 / 2.0 | скрийншоти в `QA/evidence/`; измерване на видимост на грешките (`qa_feedback_probe.gd`) |
| R10 | Преглед на source за bypass/хардкод | няма `cheat/skip/bypass/TODO`; няма хардкоднати case ID в `src/`; debug overlay само при `is_dev` (`app.gd:55`); APK без INTERNET; без tests/tools файлове в APK |

## 2. Build verification (Phase 3)

| Поле | `casezero-dev-0.1.0.apk` | `casezero-playtest-0.1.0.apk` |
|---|---|---|
| Размер | 29 477 076 B | 27 662 069 B |
| SHA-256 | `75c44481…f515` ✓ | `ea923e70…4abc` ✓ |
| Package | `com.casezero.verticalslice.dev` | `com.casezero.verticalslice.playtest` |
| versionName / versionCode | 0.1.0 / 1 | 0.1.0 / 1 |
| minSdk / targetSdk | 24 / 36 | 24 / 36 |
| ABI | само arm64-v8a | само arm64-v8a |
| Debuggable | **true** (очаквано за dev) | не (атрибут липсва = false) |
| Orientation | portrait (`screenOrientation=1`) | portrait |
| Permissions | само `VIBRATE` (няма INTERNET) | само `VIBRATE` |
| Подпис | v1+v2+v3; „Android Debug“ | v1+v2+v3; „CASE ZERO local test release“ (тестов ключ, **не за разпространение**) |
| allowBackup | false | false |
| Release APK / AAB | **не са в repo-то** (AAB не е изграден – KNOWN_ISSUES E1) | |

**BUILD TRACEABILITY RISK (остатъчен, CZ-QA-023, S3):** APK не съдържа commit SHA; `build_id` = `0.1.0-dev|playtest` (само версия+flavor). Съответствието source↔APK е доказано от QA чрез хеш на реекспортирани артефакти (R5), но не може да се докаже от самото приложение или от analytics (`build_id` няма commit).

## 3. Нови констатации (Run 2)

### CZ-QA-022 — SOFTWARE BUG • S2 • P1: Съобщението за грешна подредба/избор не се вижда на малък екран
* **Requirement:** Part 2 Failure contract („Error inline 1500ms“); Part 8 ред 1831 („feedback е в scroll body над fixed footer“); AT16 (отговорите четими със scroll).
* **Environment:** build от commit-а на APK (dev+playtest са един и същи код); desktop render на истинския UI (App → AppShell → StageModal), canvas 1080 px ≙ 360 dp; fresh state.
* **Steps:** 1. Стигни C03 с 5/5 улики. 2. Evidence → „Направи извод“ (TIMELINE). 3. Постави токените в грешен ред. 4. „Потвърди“. (Същото в C03_LINK с грешен набор; в C01_Q1 при font ≥1.3.)
* **Expected:** видим inline текст за грешка (за C03: „Подреди по показаните часове. Началото на алибито е твърдение, не доказан факт.“) на екрана на играча.
* **Actual (измерено, `QA/tools/godot/qa_feedback_probe.gd`):** възелът `Feedback` е `visible=true`, но е **изцяло извън видимата област** на ScrollContainer-а, `scroll_vertical` остава 0:

| Устройство / font | C01 Q1 грешен | C03 timeline грешен | C03 link грешен |
|---|---|---|---|
| 360×640 / 1.0 | видим | **извън екрана** | **извън екрана** |
| 360×800 / 1.0 | видим | **извън** (частично докосва) | **извън** |
| 412×915 / 1.0 | видим | видим | частично |
| 360×640 / 1.3 | **извън** | **извън** | **извън** |
| 360×640 / 2.0 | **извън** | **извън** | **извън** |

  Играчът чува/усеща SFX_WRONG, но при evidence-set и timeline екраните няма друга видима индикация за грешка (само при single-answer бутонът става червен). Не се губи прогрес и не се дава награда — проблемът е във feedback, не в логиката.
* **Reproduction rate:** 15 измервания в таблицата; 9 от 15 са „извън екрана“. Harness-ът е детерминиран, но повторения на едно и също измерване не са правени отделно; на устройство не е проверено.
* **Evidence:** `QA/evidence/360x640_fs1.0_B_c03_timeline_wrong.png` (виждат се редове до „2“ и бутон „Потвърди“, без текст за грешка); числата по-горе.
* **Possible cause (хипотеза):** `Feedback` е последно дете на scroll body (`src/ui/modals/stage_modal.gd:40`) и не се извиква scroll-to-visible при `_show_feedback`.
* **Нужна проверка на устройство:** потвърдете на телефон 360×640 (QA11 е точно този сценарий: „Грешна подредба → Грешка, подредбата остава“ — очаквайте FAIL на видимостта).

### CZ-QA-024 — SOFTWARE BUG (визуален) • S3 • P2: Font 2.0 на 360×640 — заглавие на въпроса се чупи по средата на думата, UI_CLOSE се разтяга
* **Observed** (`QA/evidence/360x640_fs2.0_C_c01_q2_answers.png`): „установяв/ат“, „допълнен/ите“; заглавието заема почти целия viewport, отговорите са под сгъвката (позволено от спецификацията чрез scroll), а бутонът „×“ е ~144×345 px вместо квадрат. Не блокира игра (scroll работи), но нарушава очакването „нищо не е отрязано“ (QA19).
* Не е потвърдено на реално устройство (desktop render).

### CZ-QA-023 — BUILD TRACEABILITY RISK • S3 • P2
Виж §2.

## 4. Какво промени Run 2 в констатациите от Run 1

| ID | Run 1 | Run 2 |
|---|---|---|
| CZ-QA-001 | S0 (няма build) | **ЗАТВОРЕН** — build и source са налични (в другия branch) |
| CZ-QA-002 | S2 | остава (brief-ът пак не е в нито един branch) |
| CZ-QA-003 | S2 spec | **→ S3.** Имплементацията не използва припокриващия rect: timeline слотовете са вертикални редове (KNOWN_ISSUES I5), проблемът се проявява като **CZ-QA-022** |
| CZ-QA-004 | S2 spec | **→ S3.** Имплементацията reflow-ва картите (на 360×640 са ≈280 px високи вместо 144 px, целият текст се чете — `QA/evidence/…_A_c03_evidence_5cards.png`); спецификацията остава с неизпълнима baseline геометрия |
| CZ-QA-005 | S3 | остава за спецификацията; в UI бутоните растат (`custom_minimum_size`) |
| CZ-QA-007 | S2 puzzle ambiguity | **ПОТВЪРДЕНО в имплементацията:** от 10-те тройки в C03_LINK се приема точно 1 (`{CLOCK_SYNC, PHOTO, PLATFORM}`), `{PHOTO, CLOCK_SYNC, DEPARTURE}` се отхвърля. Остава S2/P1 и **нарушава release gate „known puzzle ambiguity“** |
| CZ-QA-017 | concern | **Потвърдено:** C02_CONNECT има 4 карти, всеки грешен набор съдържа BATTERY |
| CZ-QA-019 | concern (redundant state) | Не води до проблем: fuzz O1–O5 (300×400) 0 нарушения; инвариантите се проверяват при всеки commit (`GameState.check` отказва commit — `INVARIANT_VIOLATION`) |
| CZ-QA-012/013/014 | spec gaps | Програмистът ги е затворил с интерпретации (KNOWN_ISSUES §3–4: Pause, Recovery, `interaction_index`, `Продължи`…). Остават като **SPEC DEFECT**: спецификацията няма текст; поведението в build-а е разумно и документирано |

## 5. Преглед на автоматизираните тестове на програмиста (Phase 26)
* 109 теста, реално изпълнени от QA → PASS. Силни страни: тестват през истинския UI/Store/Save (не само през reducer); реален `kill -9` с файлов backend; AT01–AT20 са проследими към спецификацията.
* Риск за false positive: AT15/AT16/AT17 са headless/симулирани (самата документация го казва). Риск за false negative: **няма тест за видимост на грешката** (CZ-QA-022) — asserts проверяват текст/състояние, не че елементът е в видимата област.
* Мутационна проверка на техния suite: резултат — виж `QA/Findings.md` (добавя се след края на пробата) / по-долу §5.1.

### 5.1 Резултат от мутация „replay дава XP“ срещу suite-а на програмиста
Внесена мутация в `src/gameplay/resolution.gd` (наградата се дава при всяко решаване, не само първото): suite-ът на програмиста **пада с 4 теста** (`test_replay_gives_zero_xp_and_keeps_completion`, `test_at13_replay_all_three_keeps_300` ×2, `test_replay_keeps_campaign_and_grants_zero_xp`) → за XP/replay логиката false-negative рискът е нисък. Мутациите на други места не са пробвани (един представителен дефект, не пълен mutation score).

## 6. Release gates (QA brief) — текущо състояние
| Гейт | Състояние |
|---|---|
| S0 | няма (затворен) |
| Неразрешен S1 | няма намерен (fuzz 0 нарушения; но lifecycle/perf на устройство не са изпълнени) |
| Save corruption | не е наблюдавана (kill -9 ×13, fuzz kill ×2 185) |
| Progression blocker | не е наблюдаван (всички 3 случая решими; fuzz достига solved във всички 300 seed-а) |
| Duplicate reward | не е наблюдаван (replay-и: 1 553 + детерминирана фаза; XP винаги 300) |
| **Known puzzle ambiguity** | **ДА — CZ-QA-007** → гейтът е нарушен |
| Reproducible crash в нормален flow | не е наблюдаван (не са правени device тестове) |

## 7. Вердикт за Run 2

## FAIL (за external playtest)

Причини: (1) нарушен гейт — известна puzzle ambiguity (CZ-QA-007); (2) S2 дефект във feedback видимостта (CZ-QA-022), който засяга точно най-важния момент на обучение — грешния отговор; (3) **не са изпълнени** тестовете на устройство (lifecycle, font scale, cutout, haptics, TalkBack, performance), без които build не може да бъде одобрен.
Технически gameplay/state/save слоят е силен: 109/109, fuzz 0 нарушения, kill -9 PASS, exact copy 69/69.

**PLAYTEST READY: CONDITIONAL** — след (а) решение за CZ-QA-007, (б) поправка на CZ-QA-022 и (в) преминат QA01–QA32 на поне един малък (~360×640) и един голям телефон. Подписът остава **NOT APPROVED FOR PLAYTEST** до тогава.

## 8. Препоръчан ред на поправките
**P1:** CZ-QA-022 (scroll-to-visible/фиксиран feedback над footer), CZ-QA-007 (приемай и `{PHOTO,CLOCK_SYNC,DEPARTURE}` или промени въпроса), CZ-QA-002 (brief). **P2:** CZ-QA-024, CZ-QA-023 (commit SHA в `build_id`), CZ-QA-015. **P3:** останалите design concerns. **За тестера със устройство:** изпълни `docs/QA_TEST_PLAN.md` QA01–QA32; особено QA11, QA16–QA20, QA26, QA32; и приложи §3 за всеки bug.

## 9. Как се възпроизвежда това
```sh
git checkout claude/case-zero-qa-spec-gh22bh            # съдържа и имплементацията
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd   # R1
python3 QA/tools/copy_check.py                           # R6
# R7/R9/R10 – от КОПИЕ на проекта (не пишат в repo-то):
cp QA/tools/godot/qa_fuzz.gd <copy>/tests/ ; godot --headless --path <copy> -s res://tests/qa_fuzz.gd -- --seeds=300 --steps=400
cp QA/tools/godot/qa_feedback_probe.gd <copy>/tools/ ; xvfb-run -a godot --path <copy> --rendering-driver opengl3 -s res://tools/qa_feedback_probe.gd
```
