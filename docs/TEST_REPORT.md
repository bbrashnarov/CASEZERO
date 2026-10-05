# TEST REPORT — CASE ZERO Vertical Slice 0.1.0

* Дата: 2026-10-05
* Engine: Godot 4.7.2-stable (official), headless, Linux x86_64 (cloud container)
* Commit: виж `git log` на branch `claude/project-thread-g4as3v` (отчетът е за последния commit в PR-а)
* Как се пуска:
  ```
  godot --headless --path . --import
  godot --headless --path . -s res://tests/run_tests.gd          # всички suites → build/test_results.json
  tools/qa/kill_test.sh                                          # истински SIGKILL → build/kill_test_report.txt
  xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshots.gd   # скрийншоти
  ```

## Обобщение

| Suite | Файл | Тестове | Резултат |
|---|---|---|---|
| Content + validator + solvability | `tests/unit/test_content.gd` | 5 | 5 PASS |
| C01 domain (reducer/store) | `tests/unit/test_c01_reducer.gd` | 22 | 22 PASS |
| C02/C03 domain + campaign | `tests/unit/test_c02_c03_reducer.gd` | 17 | 17 PASS |
| Persistence | `tests/persistence/test_persistence.gd` | 16 | 16 PASS |
| Analytics integration | `tests/integration/test_analytics.gd` | 4 | 4 PASS |
| UI: C01 flow през истинския shell | `tests/ui/test_c01_flow.gd` | 10 | 10 PASS |
| UI: input contract + layout | `tests/ui/test_input_layout.gd` | 10 | 10 PASS |
| UI: C02/C03/campaign | `tests/ui/test_c02_c03_flow.gd` | 5 | 5 PASS |
| Acceptance AT01–AT20 | `tests/acceptance/test_acceptance.gd` | 20 | 20 PASS |
| **Общо (automated)** | | **109** | **109 PASS, 0 FAIL** |
| Process kill (реален `kill -9`) | `tools/qa/kill_test.sh` | 13 | 13 PASS |
| Android build + APK inspection | `tools/build/build_android.sh` | 3 APK × 5 проверки | PASS |
| Устройство / емулатор | — | — | **NOT RUN** (няма устройство) |
| Performance | — | — | **NOT MEASURED** |

Script/engine грешка по време на тест се брои за FAIL (runner-ът регистрира Logger, който
превръща `SCRIPT ERROR`/`ERROR` в failure). Проверено е, че assertion-ите реално се изпълняват:
нарочно грешно очакване в AT13 дава FAIL (`expected <200> got <100>`), после е върнато.

## Acceptance AT01–AT20 (spec Part 12)

Всички се изпълняват през истинския App: composition root → AppShell → screens/modals →
Store → SaveRepository (in-memory backend с fault injection; kill = нова App инстанция от
същото storage). Устройство: 360×640 dp освен ако не е посочено.

| Test ID | Given | When | Expected | Actual | Result |
|---|---|---|---|---|---|
| AT01 | C01 SCENE, нищо открито | Tap FLOOR, отваряне на Evidence; после WINDOW | Q1 disabled с „Нужни са още улики“; след WINDOW enabled | Disabled + текстът; след WINDOW enabled | PASS |
| AT02 | C01 SCENE, Q1 непройден | Tap MANAGER | Locked toast, няма ADMISSION, няма панел | Toast „Първо сравни прозореца и пода.“, route остава SCENE, ADMISSION липсва | PASS |
| AT03 | C01 Q1 решен правилно | App kill → рестарт → resume | MANAGER отключен, няма solve | `solved=false`; tap MANAGER → C01_INSPECT_MANAGER | PASS |
| AT04 | C02 SCENE | PHONE (EMPTY) → CHARGER „Свържи“ → PHONE | BATTERY веднъж; IDENTITY при второто inspect | BATTERY ×1, IDENTITY добавена, 2 CLUE_DISCOVERED | PASS |
| AT05 | C02 SCENE | CHARGER „Свържи“ → PHONE → … → solve | IDENTITY + архивирано BATTERY в една транзакция; solve достижим | `[BATTERY, IDENTITY]`, toast „2 наблюдения добавени“, C02_SOLVED | PASS |
| AT06 | C02, всички 4 улики | Избор BATTERY+NETWORK+WATCH_LOG → „Свържи“ | Грешен set, без загуба на улики | `link_ok=false`, evidence непроменени, feedback текстът от спецификацията | PASS |
| AT07 | C02 Q1 отворен | Грешен отговор A1 | attempts+1, не е решен, изборът editable | attempts=1, solved=false, остава на Q1, error state се чисти при нов избор | PASS |
| AT08 | C03 SCENE | 5 източника в произволен ред | Timeline отключен едва при 5/5, без order lock | CTA blocked до 4/5; при 5/5 → C03_TIMELINE | PASS |
| AT09 | C03 TIMELINE | PHOTO→slot2, после CLAIM→slot2 | Старият occupant в pool, без дубликати | `[null, TL_CLAIM, null]`, PHOTO без slot badge | PASS |
| AT10 | C03 TIMELINE | CLAIM, DEPART, PHOTO → submit | Няма timeline_ok, масивът се пази, inline error | timeline_ok=false, масивът запазен, текстът от спецификацията | PASS |
| AT11 | C03 timeline правилен | Submit → Back → evidence card | Timeline остава valid; evidence review достъпен | Back → C03_EVIDENCE; detail card отваря; timeline_ok=true | PASS |
| AT12 | C01 решен (SOLVED екран) | Kill преди REWARD, два рестарта | completed/reward записани, XP не се удвоява | completed=true, reward_granted=true, XP 100 след двата рестарта | PASS |
| AT13 | C01–C03 решени (300 XP) | Replay confirmation → reset на трите → решаване отново | XP остава 300 | xp_delta=0 за трите; XP 300 след рестарт | PASS |
| AT14 | C01 SCENE | Два tap-а върху WINDOW веднага; повторен dispatch със същия action_id | Една улика, един haptic, детерминиран state | 1 evidence, 1 LIGHT, 1 панел; повторният dispatch → DUPLICATE, interaction_index непроменен | PASS |
| AT15 | C01 SCENE | Tap WINDOW → background → kill по време на анимацията | Portrait; находката не зависи от анимацията | Evidence записана; orientation setting = portrait; resume в SCENE | PASS (headless; Android lifecycle — виж KNOWN_ISSUES U6/U7) |
| AT16 | 360×640 dp, font scale 2.0 | Отваряне на C01 Q1 | Отговорите се четат чрез scroll; CTA не закрива текст | CTA в safe area, извън scroll областта; трите отговора достижими; шрифтът не е намален; без хоризонтален scroll | PASS (симулиран font scale; реален Android font scale — U3) |
| AT17 | C01 Q2 избран | Save fail при solve → Retry | G_WRITE_ERROR, няма фалшив success, retry веднъж | G_WRITE_ERROR, completed=false, XP 0; Retry → C01_SOLVED, XP 100, оцелява kill | PASS |
| AT18 | C01 SCENE | Tap върху покритото тяло (декор) и стената | Няма clue feedback, няма блокиране на input | Без event/звук; следващ tap на WINDOW работи | PASS |
| AT19 | Sound и haptic изключени | Пълен C01 | Играе се изцяло, без audio-only улика | Toast „Улика открита“ видим, 0 haptics, C01_SOLVED | PASS |
| AT20 | C02, всички required улики | Hint ниво 3 → затваряне | Насочва към текущия reasoning stage | Target = UI_EVIDENCE, няма pulse върху обект | PASS |

## Phase 2 — C01 DEVELOPMENT GATE

| Gate изискване | Доказателство | Result |
|---|---|---|
| Complete flow INTRO→SCENE→улики→Q1→MANAGER→Q2→SOLVED→REWARD | `test_c01_flow::test_c01_complete_flow` | PASS |
| Save/load | същия тест (рестарт след solve) + `test_persistence::*` | PASS |
| Restart (confirm reset) | `test_c01_flow::test_android_back_contract`, `test_replay_keeps_campaign_and_grants_zero_xp` | PASS |
| Hint 1→2→3→repeat, pulse след затваряне | `test_c01_flow::test_hint_escalation_and_repeat` | PASS |
| Evidence panel + detail cards | `test_c01_complete_flow`, AT01, AT11 | PASS |
| Deduction (wrong → attempts, correct → CTA „Към показанията“) | `test_c01_complete_flow` | PASS |
| Reward +100 / replay +0 | `test_c01_complete_flow`, `test_replay_keeps_campaign_and_grants_zero_xp` | PASS |
| Android Back (INTRO, SCENE→PAUSE, модали, CONFIRM=Не, BOARD→изход, Back не submit-ва) | `test_c01_flow::test_android_back_contract` | PASS |
| Process kill recovery | `test_c01_flow::test_process_kill_restores_progress` + реален `kill -9` (по-долу) | PASS |

## Process kill — реален SIGKILL (`tools/qa/kill_test.sh`)

Godot процесът играе C01 през истинския UI с истинския файлов backend (`user://qa_kill`),
отпечатва маркер след всяка committed стъпка и се убива с `kill -9`; нов процес boot-ва и
отпечатва възстановения state.

| Test ID | When (kill след) | Expected | Actual | Result |
|---|---|---|---|---|
| K1 | START | started run, 0 улики, route BOARD | LOADED, evidence [] | PASS |
| K2 | WINDOW (панелът отворен) | RAIN | `["EV_C01_RAIN"]` | PASS |
| K3 | FLOOR | RAIN, DRY_FLOOR | двете | PASS |
| K4 | Hint 1 | hint_level 1 | 1 | PASS |
| K5 | Q1 correct | q.C01_Q1 = true | true | PASS |
| K6 | MANAGER | 3 улики | 3 | PASS |
| K7 | Q2 → SOLVED | completed, XP 100 | completed=true, XP 100 | PASS |
| K8 | втори рестарт | XP остава 100 | 100 | PASS |
| K9–K13 | по време на непрекъснати записи (~100…500 writes) | save валиден (LOADED или от backup), boot OK | LOADED, boot OK и в 5-те | PASS |

## Layout / input (`tests/ui/test_input_layout.gd`)

Device classes: 360×640, 360×800, 412×915 dp и 800×1280 dp tablet; font scale 1.0 и 2.0;
insets 32/48 dp. Проверки: сцената в safe area, uniform scale (аспект 1080:1332), header над
и footer под сцената, footer в safe area, HUD бутони ≥48 dp, всеки clickable expanded hitbox
≥48 dp, inverse transform, центърът на всеки hitbox resolve-ва към своя обект, модалът и
затварящият бутон в safe area, intro CTA видим при 2.0, submit на deduction без scroll при 2.0.
Tap contract с истински pointer events през viewport-а: tap → inspect; движение 13 dp → не е
tap; 10 dp → tap; задържане 620 ms → не е tap; tap под модал не стига до сцената. Всички PASS.

Визуална проверка: `tools/screenshots.gd` рендерира intro/scene/inspect/evidence/Q1/hint/pause/
board за C01 и C02 charger/CONNECT, C03 scene/timeline (xvfb + OpenGL, llvmpipe). Прегледани
ръчно; намерени и оправени: прекалено голям toast, пресечени заглавия в модали, footer бутони,
режещи думи при 2.0 (сега стават на два реда).

## Analytics (`tests/integration/test_analytics.gd`)

* Всички 20 събития от Part 11 се emit-ват в реална C02+C03 сесия през UI с всички common и
  required properties; `schema_version=1`; една `session_id`; монотонен `interaction_index`.
* Неуспешен write не emit-ва OBJECT_INSPECTED (събитията описват само committed state).
* Няма story текст, locked текст, пътища или PII ключове в лога; `text`/`name` се изпускат.
* FIFO при budget (20 KB тестов budget): най-новите остават, най-старите отпадат; export JSON.
* Неуспешен analytics storage не блокира gameplay.

## Android build (`tools/build/build_android.sh all`)

| APK | Package | Подпис | Debuggable | ABI | Orientation | Permissions | Размер |
|---|---|---|---|---|---|---|---|
| casezero-dev-0.1.0.apk | com.casezero.verticalslice.dev | Android Debug (v2/v3) | true | arm64-v8a | portrait | VIBRATE | ≈ 29.4 MB |
| casezero-playtest-0.1.0.apk | com.casezero.verticalslice.playtest | локален тестов ключ | false | arm64-v8a | portrait | VIBRATE | ≈ 27.6 MB |
| casezero-release-0.1.0.apk | com.casezero.verticalslice | локален тестов ключ | false | arm64-v8a | portrait | VIBRATE | ≈ 27.6 MB |

versionName 0.1.0, versionCode 1, minSdk 24, targetSdk 36 (от официалния template).
`apksigner verify` минава; `tools/build/inspect_apk.py` проверява: само arm64-v8a, portrait,
без INTERNET, без tests/tools файлове, content JSON вътре — PASS и за трите. Exported pack-ът е
boot-нат на desktop (`--main-pack`) → BOOT OK.

**AAB: NOT BUILT** — изисква Gradle build и Android SDK platforms от `dl.google.com`, който е
блокиран в средата (KNOWN_ISSUES E1).

## NOT RUN

| Какво | Причина |
|---|---|
| Инсталиране и игра на Android устройство/емулатор | Няма устройство, няма KVM/emulator image |
| Performance budgets (fps, tap latency, scene load, памет, texture residency) | Няма reference device; стойности не се измислят |
| Реален Android font scale, cutout, gesture nav, вибрация, lifecycle | Изисква устройство (KNOWN_ISSUES U3–U7) |
| Formative user test (Part 5–7 User Test) | Извън инженерния обхват; целите в спецификацията са за модериран тест |
