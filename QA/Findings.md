# CASE ZERO — Findings (bug / defect register)

> **АКТУАЛИЗАЦИЯ Run 2:** build и source са налични (branch `claude/project-thread-g4as3v`). CZ-QA-001 е затворен; CZ-QA-003/004 са понижени до S3; CZ-QA-007 е потвърден в имплементацията; нови: **CZ-QA-022 (S2 SOFTWARE BUG)**, CZ-QA-023, CZ-QA-024. Вижте `Report_Run2_Build_0.1.0.md`. Записите по-долу са от Run 1 (статичен анализ на спецификацията) и не са пренаписвани.

Среда за всички записи: **няма APK/устройство** (виж CZ-QA-001). Commit на repository: `9a3509d`. Артефакт под тест: `CASE_ZERO_Vertical_Slice_BG.md` v1.0 (5.10.2026). Всички констатации са от **статичен анализ на документа** + скриптовете `QA/tools/spec_geometry_check.py` и `QA/tools/spec_state_model.py`. Няма runtime evidence; това е отбелязано при всяка констатация.

Означения: `Observed` = какво е установено в документа/скрипта. `Possible cause` = хипотеза, не факт. Категории: SOFTWARE BUG / SPECIFICATION DEFECT / DESIGN CONCERN / TEST COVERAGE GAP. Не е намерен нито един SOFTWARE BUG – няма имплементация, която да се сравни със спецификацията.

## Обобщение

| ID | Категория | Sev | Prio | Заглавие |
|---|---|---|---|---|
| CZ-QA-001 | TEST COVERAGE GAP | **S0** | P0 | Repository не съдържа build, source code, тестове или CI – играта не може да бъде тествана |
| CZ-QA-002 | TEST COVERAGE GAP | S2 | P1 | Marketing brief и задачата към дизайнера не са в repository-то – маркетинговата трасируемост е недоказуема |
| CZ-QA-003 | SPECIFICATION DEFECT | S2 | P1 | C03 timeline: wrong-feedback rect покрива 62% от всеки timeline слот |
| CZ-QA-004 | SPECIFICATION DEFECT | S2 | P1 | Evidence карта 144px не побира заявения пълен текст (изчислено) |
| CZ-QA-005 | SPECIFICATION DEFECT | S3 | P2 | Deduction отговор 168px не побира заявените 2–3 реда (изчислено) |
| CZ-QA-006 | SPECIFICATION DEFECT | S3 | P2 | Няма rect за заглавие/въпрос на deduction, CONNECT, LINK, TIMELINE |
| CZ-QA-007 | SPECIFICATION DEFECT (PUZZLE AMBIGUITY) | S2 | P1 | C03_LINK: {PHOTO, CLOCK_SYNC, DEPARTURE} е втори разумен отговор |
| CZ-QA-008 | SPECIFICATION DEFECT | S3 | P2 | C02/C03 screen таблици съдържат копиран C01 текст „C01 Q1 accepted → Към показанията“ |
| CZ-QA-009 | SPECIFICATION DEFECT | S4 | P3 | C01 pulse „първите 5 s“ срещу AN_HINT_PULSE 2×600ms |
| CZ-QA-010 | SPECIFICATION DEFECT | S4 | P3 | Toast „Улика открита“ срещу „Добавена“ |
| CZ-QA-011 | SPECIFICATION DEFECT | S4 | P3 | C01 Q1 success 600ms срещу AN_STAGE_OK „без задължително чакане“ |
| CZ-QA-012 | SPECIFICATION DEFECT | S3 | P2 | Android Back не е дефиниран за PAUSE, CONFIRM_RESET, G_WRITE_ERROR |
| CZ-QA-013 | SPECIFICATION DEFECT | S3 | P2 | First-run, „Продължи“ и replay-карта на Board са двусмислени |
| CZ-QA-014 | SPECIFICATION DEFECT | S3 | P2 | Analytics: DEDUCTION_SUCCEEDED на финален етап, CASE_EXITED тригери, build_id |
| CZ-QA-015 | DESIGN CONCERN | — | P2 | „Най-дългият отговор е верен“ в 3 от 4 финални въпроса |
| CZ-QA-016 | DESIGN CONCERN | — | P3 | Settings само от Board; системна reduced-motion настройка не е упомената |
| CZ-QA-017 | DESIGN CONCERN | — | P3 | C02 CONNECT се решава по елиминация (всеки грешен избор съдържа BATTERY) |
| CZ-QA-018 | DESIGN CONCERN | — | P3 | C03 TIMELINE се решава със сортиране по показаните часове |
| CZ-QA-019 | DESIGN CONCERN (CODE RISK) | — | P2 | Излишно дублиран state: completed / reward_granted / solved / xp; charger / phone_power |
| CZ-QA-020 | DESIGN CONCERN | — | P3 | C01_FLOOR и C01_SHOES hitbox-ове са на 24px (≈8dp) един от друг |
| CZ-QA-021 | SPECIFICATION DEFECT | S4 | P3 | AMB не е дефиниран за EVIDENCE/HINT/DEDUCTION; UI_PRIMARY списъкът е непълен |

Брой: S0 ×1, S1 ×0, S2 ×4, S3 ×6, S4 ×4, DESIGN CONCERN ×6. S1 = 0 е **не** заключение за качеството на играта – няма build, в който да се търси crash/save corruption/duplicate XP.

---

## CZ-QA-001 — Няма build, source code, тестове или CI
- **Категория:** TEST COVERAGE GAP (блокира всички runtime фази) • **Severity:** S0 • **Priority:** P0
- **Environment:** repository `bbrashnarov/CASEZERO`, branch `main`, commit `9a3509d`; няма устройство/Android версия.
- **Steps:** 1. Клонирай repo. 2. `find . -path ./.git -prune -o -type f -print`.
- **Expected:** документация + source + APK/release reference + тестове + build инструкции (QA brief, Phase 1).
- **Actual / Observed:** точно 2 файла — `README.md` (21 байта: „# CASEZERO / TEST GAME“) и `CASE_ZERO_Vertical_Slice_BG.md` (189 790 байта). 2 commit-а, нито един не добавя код. Няма APK, source, assets, тестове, CI, changelog, known-issues, version файл. Самата спецификация (Part 13/14, „Доставено и оставащо“) потвърждава: „интерактивен prototype/build … остава“, „все още няма доставен binary art pack“, „несъществуващ Android build“.
- **Reproduction rate:** 5/5 (детерминирано).
- **Requirement reference:** QA brief Phase 1, 3; Part 14.
- **Evidence:** `git ls-tree -r HEAD`, размери на файловете.
- **Забележка:** потребителското съобщение споменава „готови Android APK builds“. Такива не са налични нито в repo-то, нито в тази сесия. Ако съществуват другаде (releases, artifact storage), са необходими: APK + commit/SHA, с който е изграден.
- **Possible cause:** build-овете са качени на друго място или не са commit-нати.

## CZ-QA-002 — Първоизточниците на спецификацията не са в repository-то
- **Категория:** TEST COVERAGE GAP • **S2 / P1**
- **Observed:** Spec „Източници“ (ред 7) цитира „Pasted text(4).txt“ (задача за дизайнера) и „Pasted text(2).txt“ (GAME DESIGN BRIEF на Marketing/Product Director). Нито един не е в repo-то. Spec твърди, че при разлика „приоритет има текущата задача“.
- **Impact:** не може да се провери RTM звеното *Marketing requirements → Game Design*; DD01–DD12 не могат да се сверят с оригинала. Очевидно разминаване е известно само от самата спецификация (C01 30–60 s → 45–75 s; Daily/Store/Office изключени).
- **Нужно:** добавете двата документа или потвърдете, че спецификацията е единствен нормативен източник.

## CZ-QA-003 — C03 timeline: wrong-feedback rect покрива слотовете
- **Категория:** SPECIFICATION DEFECT / DOCUMENTATION CONFLICT • **S2 / P1**
- **Observed (изчислено, `spec_geometry_check.py`):** Part 8 (ред 1831): wrong feedback `[96,1176,888,144]`, z=230, hitbox NONE. Part 7 (ред 1616): слотове `[96+j*304,1104,280,192]`, z=220. Припокриване 33 600 px² = **62%** от площта на всеки от трите слота; feedback е с по-висок z → закрива етикетите „1 Най-рано / 2 / 3 Най-късно“ и поставените токени. CMP_WRONG_FEEDBACK: „текст остава достъпен до следващ edit“ → закриването не е ограничено до 1500 ms. Едновременно Part 8 таблицата на компонентите казва, че грешката на timeline е „at footer“ (ред 1820–1821) — друг, недефиниран rect.
- **Expected:** feedback да не застъпва активен елемент („Не застъпва активен отговор“, ред 1831).
- **Actual:** правилото е нарушено от самата геометрия за C03_TIMELINE.
- **Repro (спецификация):** отвори ред 1616 и 1831, сравни Y-интервали 1104–1296 и 1176–1320.
- **Possible cause:** общият feedback rect е проектиран за deduction екрана (отговори до y=1152) и не е преизчислен за timeline.
- **Препоръка:** отделен rect за timeline грешка (напр. под слотовете, y≥1296) или footer.

## CZ-QA-004 — Evidence карта не побира заявения текст
- **Категория:** SPECIFICATION DEFECT • **S2 / P1** • **Статус на доказателство:** изчисление с допускания (не измерено на устройство)
- **Observed:** Part 4 фиксира карта `[96,504+i*156,888,144]`; Part 5–7: „Card text е целият низ … timestamp не се изрязва“; CMP_EVIDENCE_CARD = „Icon, title, exact evidence copy“. Дължини на текстовете: 48–72 символа (12 карти; скриптът ги изброява). Допускания: canvas 1080 px ≙ 360 dp (спецификацията не дефинира px↔dp за canonical canvas), body 16sp Noto Sans ≈ 26 символа/ред в ~230 dp (след икона 48 dp), ред ≈ 22 dp, плюс ред заглавие. Нужни ≈ 68–90 dp срещу 48 dp на картата (144 px ≙ 48 dp).
- **Expected:** текстът се вижда изцяло при font scale 1.0 на 360×640.
- **Actual (очаквано):** препълване/отрязване на повечето карти, а при font scale ≥1.3 — на всички.
- **Забележка:** Part 3 разрешава reflow и scroll, но Part 4 казва, че 5-те слота са с фиксирана геометрия и viewport-ът е 780 px; reflow правило за височина на карта не е дадено.
- **Проверка на устройство (TC-EVD-02):** 360×640 dp, font 1.0/1.3/2.0, всички 12 карти.

## CZ-QA-005 — Deduction отговор 168 px не побира 2–3 реда
- **S3 / P2**, изчислено с допускания както в CZ-QA-004. Най-дългият отговор е 66 символа (C01_Q2_A1) → ≈3 реда при 18sp върху ~256 dp ≈ 72–75 dp > 56 dp (168 px ≙ 56 dp @360). Part 3: „Отговорите са … до 2–3 реда“.

## CZ-QA-006 — Няма rect за заглавие/въпрос
- **S3 / P2.** Части 3–4 дават rect за modal surface, close, detail image/body и CTA, но не и за заглавие на modal / текст на въпроса в DEDUCTION, CONNECT, LINK, TIMELINE. Налична свободна зона: ляво от UI_CLOSE (x 96–840, y 336–504 ≈ 248×56 dp @360). Най-дългият въпрос (C03_LINK, 63 символа) иска ≈3 реда ≈ 75 dp.
- Accessibility изисква „focus отива на title“ (Part 8) — title няма ID/rect.

## CZ-QA-007 — C03_LINK: втори разумен отговор (PUZZLE AMBIGUITY)
- **Категория:** SPECIFICATION DEFECT • **S2 / P1** (правило от QA brief: puzzle ambiguity ≥ MAJOR). Не блокира решението (няма наказание, 10 възможни тройки, retry свободен) → не е S1.
- **Observed:** въпрос: „Кои три източника проверяват часа и мястото на Никола в кадъра?“; верен набор `{PHOTO, CLOCK_SYNC, PLATFORM}`. Card text на `EV_C03_DEPARTURE`: „R214 действително тръгва от перон 2 в 20:10:00; **R218 от перон 4** в 20:20.“ — т.е. DEPARTURE също свързва перон 4 с R218 и показва, че R214 вече е напуснал. Самата спецификация (ред 1624) признава: „Подсказката не нарича всичките три минимално логически необходими“, т.е. PLATFORM не е логически необходим. Ред 1626 грешен feedback е еднакъв за всеки грешен набор и споменава билета, дори да не е избран.
- **Expected:** един недвусмислен верен набор или multi-solution валидация.
- **Actual:** `{PHOTO, CLOCK_SYNC, DEPARTURE}` е защитим отговор по текста на картите, но се отхвърля.
- **Possible cause:** критерият „място в кадъра“ е формулиран така, че PLATFORM и DEPARTURE го покриват.
- **Препоръка:** приемай и двата набора, или промени въпроса/картите. Потвърди с playtest (метрика „Обяснява противоречието“).

## CZ-QA-008 — Копиран C01 текст в C02/C03 screen таблици
- **S3 / P2.** Редове 1216 и 1735: `C02_DEDUCTION_Q1` / `C03_DEDUCTION_Q1` — „Close; C01 Q1 accepted → Към показанията“ и „SCENE if C01 Q1“. Правилото е валидно само за C01. Разработчик, който чете буквално, може да добави „Към показанията“ в C02/C03. Същият boilerplate е в „IMPLEMENTATION AMBIGUITY CHECK“ (C01/C03 твърдят „battery“ за evidence purpose).

## CZ-QA-009 / 010 / 011 — Вътрешни разминавания в стойности (S4 / P3)
- **009:** ред 213 „Pulse на WINDOW през първите 5 s“ срещу AN_HINT_PULSE „C01 first 5s | 2×600ms“ (=1.2 s).
- **010:** ред 76 toast „Улика открита“ срещу CMP_EVIDENCE_CARD Success „Добавена“ (ред 1810).
- **011:** ред 671 inline feedback 600 ms с CTA срещу AN_STAGE_OK 180 ms „next route immediately; no compulsory wait“.

## CZ-QA-012 — Back не е дефиниран
- **S3 / P2.** Part 4 дефинира Back за detail/hint/evidence/deduction/picker, SCENE, INTRO, SOLVED/REWARD, BOARD. Липсват: **PAUSE**, **CONFIRM_RESET**, **G_WRITE_ERROR** (само „не допуска uncommitted success screen“), Back по време на AN_MODAL_OUT/AN_SOLVED, и по време на `input_locked`. QA brief изисква тези проверки.

## CZ-QA-013 — First-run, „Продължи“, replay-карта
- **S3 / P2.** (а) „G_BOOT … първа сесия C01_INTRO; следващи G_BOARD“ — „първа сесия“ няма флаг в GameState (има само `fresh_install` в analytics): какво става при kill в C01_INTRO преди START? (б) „BOARD с ‘Продължи’“ (ред 733) — няма компонент, ID или rect; най-близко е „Current run badge“ в CMP_CASE_BOARD_CARD. (в) Карта на решен случай → „confirmation REPLAY“ (ред 142), но след Restart на решен случай runs.X.solved=false, campaign.completed=true и има текущ run: SCENE или REPLAY confirmation?

## CZ-QA-014 — Analytics празноти
- **S3 / P2.** (а) `DEDUCTION_SUCCEEDED` = „Intermediate stage accepted“ — не е казано какво се емитира при верен финален отговор (само `DEDUCTION_SUBMITTED` + `CASE_SOLVED`?). (б) `CASE_EXITED` само за `reason=board` преди solve; Back от INTRO→BOARD и PAUSE→Board не са уточнени. (в) `build_id` е задължително property, но няма дефиниран източник (потвърждава BUILD TRACEABILITY RISK). (г) `CASE_RESUMED.stage` – няма enum за stage.

## CZ-QA-015 — DESIGN CONCERN: „най-дългият е верен“
- Скрипт: C01_Q1 (59/43/50), C01_Q2 (31/**66**/42), C03_Q1 (**69**/48/53) → верният е най-дългият; C02_Q1 (59/50/58) — верният е на 1 символ от най-дългия. Всички грешни отговори в C01_Q1, C01_Q2, C03_Q1 съдържат абсолютни думи („доказва“, „със сигурност“, „доказано“). Позицията на верния: A0, A1, A2, A0. Спецификацията сама назовава риска (Part 13 „C03 налучкване“). Мярка: метрика „налучкване“ при playtest.

## CZ-QA-016 — DESIGN CONCERN: Settings
- `UI_SETTINGS` е видим само в BOARD. Играч не може да изключи звук/haptic по време на случай; QA тестът „disable sound during ambience“ изисква излизане към Board. Системната reduced-motion / animation scale настройка на Android не е упомената.

## CZ-QA-017 — DESIGN CONCERN: C02 CONNECT по елиминация
- Картите са 4 (IDENTITY, NETWORK, WATCH_LOG, BATTERY) и се иска точно 3 → всеки грешен набор съдържа BATTERY → „избери всичко без батерията“. Не изисква разсъждение; моделът го потвърждава (4 възможни набора, 1 верен).

## CZ-QA-018 — DESIGN CONCERN: C03 TIMELINE
- Токените носят изписани часове (20:10:00, 20:15:00, 20:15:30) → решава се със сортиране; „Началото на алибито е твърдение“ е само в грешния feedback.

## CZ-QA-019 — DESIGN CONCERN / CODE RISK: излишен state
- `campaign.completed[c]`, `campaign.reward_granted[c]`, `runs[c].solved`, `campaign.xp` кодират един факт; `charger` и `phone_power` също (инвариант „iff“). Спецификацията сама изисква валидиране при restore. Риск: десинхронизация при частичен запис / миграция. Покрива се от TC-ST-* и kill matrix.

## CZ-QA-020 — DESIGN CONCERN: близки hitbox-ове
- `C01_FLOOR` `[600,912,408,264]` и `C01_SHOES` `[384,1200,216,216]` — минимален отвор 24 px ≈ 8 dp @360. Няма припокриване (скрипт), но е тясно за палец. Проверка с TC-HIT-02.

## CZ-QA-021 — Непълни таблици
- **S4 / P3.** AMB_C01/02/03 „foreground SCENE/inspection“ — не е казано за EVIDENCE, HINT, DEDUCTION, PAUSE, SOLVED. UI_PRIMARY „Visible when“ изброява INTRO/INSPECT/DEDUCTION/SOLVED/REWARD/HINT, но не EVIDENCE, TIMELINE, CONNECT, LINK, CHARGER и G_WRITE_ERROR, които го използват в други части; докато INSPECT таблиците изброяват само UI_CLOSE.

---

## Какво беше проверено независимо и **не** е дефект
`QA/tools/spec_geometry_check.py` потвърди за всичките 17 сцени обекта (C01 ×7 вкл. BODY, C02 ×5, C03 ×5): center = x+w/2,y+h/2; нормализирани координати = cx/1080, cy/1920; hitbox съдържа спрайта и е центриран; всичко е в scene viewport `[0,264,1080,1332]`; няма припокриване на hitbox-ове; най-малкият hitbox е 216 px (72 dp @360 ≥ 48 dp); asset/DETAIL/икони са кръстосано пълни; 22:48→23:30 = 42 мин; фото-прозорец 20:15:29–31 е вътре в 20:15:00–20:16:00. UI таблицата: нормализирани центрове вярни, всички контроли ≥ 48 dp @360.
`QA/tools/spec_state_model.py` (модел на правилата на спецификацията, BFS): C01 7 състояния, C02 30, C03 656; и трите решими; Q2 преди ADMISSION и Q1 без WINDOW се отхвърлят; Path A и Path B на C02 дават еднакъв evidence set `{BATTERY, IDENTITY}` с BATTERY веднъж; няма дублиран token в C03; няма IDENTITY без RESTORED. **Ограничение:** моделът отразява четенето на QA, не реален код.
