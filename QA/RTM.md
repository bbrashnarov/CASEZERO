# CASE ZERO — Requirements Traceability Matrix (RTM)

Версия на спецификацията: v1.0 (5.10.2026). Repository commit: `9a3509d`. Дата на анализа: 2026-10-05.

> **Важно.** В repository-то няма source code, APK, тестове или CI. Колоната *Code/Component* е компонентът, който самата спецификация (Part 12) очаква; **не е проверен**. Всеки runtime статус е **BLOCKED**, защото няма build за изпълнение. Колоната *Static spec check* е единственото реално изпълнено ниво (анализ на документа + `QA/tools/*.py`). Requirement ID са присвоени от QA – спецификацията няма собствена номерация (освен DD01–DD12 и AT01–AT20).

| Requirement ID | Requirement | Source | Code/Component (очакван) | Test ID | Runtime status | Static spec check |
|---|---|---|---|---|---|---|
| REQ-MKT-01 | Точно 3 завършени случая (C01–C03) в slice | Part 1 | не съществува (няма код) | TC-FULL-01 | BLOCKED | OK |
| REQ-MKT-02 | Loop Tap→Investigate→Find clue→Deduce→Solve разбираем без външно знание | Part 2; QA brief | не съществува | TC-UX-01 (QA) | BLOCKED | OK; усещане – само playtest |
| REQ-MKT-03 | Offline, без login/ads/IAP/energy/store (DD08) | Part 1 DD08, Part 4 | не съществува | TC-INST-05, TC-UX-02 (QA) | BLOCKED | OK |
| REQ-MKT-04 | Целево активно време C01 45–75s, C02 75–120s, C03 120–180s | Part 1 | не съществува | TC-PERF-05 (QA) | BLOCKED | OK (цел, не гаранция) |
| REQ-MKT-05 | Първо решение на случай = 100 XP, replay = 0 (DD09) | Part 1 DD09, Part 10 | atomicSolve | AT12,AT13,TC-XP-* | BLOCKED | OK; виж CZ-QA-019 |
| REQ-CORE-01 | Tap при pointer-up: ≤12dp, ≤500ms, същия hitbox | Part 2 Input | input layer | TC-INP-01..04 | BLOCKED | OK |
| REQ-CORE-02 | Един активен pointer; допълнителните се игнорират; cancel чисти pressed | Part 2 | input layer | TC-INP-05,06 | BLOCKED | OK |
| REQ-CORE-03 | Double tap/duplicate dispatch → една транзакция | Part 2, Part 10, AT14 | reducer dispatch | AT14,TC-INP-02 | BLOCKED | OK |
| REQ-CORE-04 | Overlap приоритет: modal>backdrop>HUD>scene; после priority, z, ID | Part 2 | hit-test | TC-INP-07 | BLOCKED | OK |
| REQ-CORE-05 | Декорации/фон никога не прихващат input | Part 2, AT18 | hit-test | AT18 | BLOCKED | OK |
| REQ-CORE-06 | Failure contract: грешен отговор → attempts+1, 1500ms inline, SFX_WRONG, без shake | Part 2 | deduction | TC-DED-* | BLOCKED | OK |
| REQ-CORE-07 | Недостатъчни улики → CTA disabled „Нужни са още улики“, guard PRECONDITION_MISSING, без attempt | Part 2 | deduction | TC-DED-04 | BLOCKED | OK |
| REQ-CORE-08 | Hint винаги свободен, не намалява XP | Part 2 | hint system | TC-HINT-* | BLOCKED | OK |
| REQ-CORE-09 | Камера 1.0×, без pan/zoom, Zoomable=NO | Part 2 | scene renderer | TC-UI-09 | BLOCKED | OK |
| REQ-CORE-10 | P_INSPECT: UNSEEN→SEEN, evidence идемпотентно, toast 180–880ms | Part 2 | P_INSPECT | TC-C01-* | BLOCKED | OK; виж CZ-QA-010 |
| REQ-UI-01 | Portrait lock; ротация не губи state | Part 3, AT15 | manifest/activity | TC-LIFE-06,AT15 | BLOCKED | OK |
| REQ-UI-02 | Uniform scale s=min(w/1080,h/1332), inverse transform за input, без crop на улика | Part 3 | scene transform | TC-UI-01..03 | BLOCKED | OK |
| REQ-UI-03 | Физически hitbox ≥48dp, симетрично разширение | Part 3 | hit-test | TC-HIT-01 | BLOCKED | Геометрия OK (виж скрипт); CZ-QA-020 (24px gap) |
| REQ-UI-04 | Overlap >25% → G_PICKER, два 48dp реда | Part 3, Part 8 | G_PICKER | TC-HIT-03 | BLOCKED | OK |
| REQ-UI-05 | Профили 360×640, 360×800, 412×915 dp + tablet (600dp max) | Part 3 | layout | TC-UI-01..04 | BLOCKED | OK |
| REQ-UI-06 | Font scale 1.0–2.0 без смаляване; scroll при голям шрифт; footer извън scroll | Part 3, AT16 | UI text | TC-FONT-* | BLOCKED | DEFECT CZ-QA-004/005 |
| REQ-UI-07 | Evidence панел: 5 слота [96,504+i*156,888,144], пълен card text, без отрязан timestamp | Part 4, Part 5-7 | evidence panel | TC-EVD-* | BLOCKED | DEFECT CZ-QA-004 |
| REQ-UI-08 | Deduction: 3 отговора [96,600+i*192,888,168]; отговори 2–3 реда | Part 3-4 | deduction UI | TC-DED-* | BLOCKED | DEFECT CZ-QA-005, CZ-QA-006 |
| REQ-UI-09 | Timeline: токени и слотове, wrong feedback, без припокриване | Part 7, Part 8 | timeline UI | TC-C03-TL-* | BLOCKED | DEFECT CZ-QA-003 |
| REQ-UI-10 | Hint панел: нива 1–3, 'Повтори насоката' на 3 | Part 4 | hint panel | TC-HINT-* | BLOCKED | OK |
| REQ-UI-11 | Pause/Restart/Confirm; Yes чисти само run | Part 4 | pause | TC-NAV-05,TC-RST-* | BLOCKED | OK; Back не е дефиниран – CZ-QA-012 |
| REQ-UI-12 | Settings: sound/haptic/reduced_motion, persist веднага | Part 8 | settings | TC-SET-* | BLOCKED | OK; CZ-QA-016 |
| REQ-UI-13 | Safe-area/cutout: header/footer към insets, 16dp margin | Part 3 | insets | TC-UI-06 | BLOCKED | OK |
| REQ-NAV-01 | Android Back карта (detail/hint/evidence/deduction/picker→предишен; SCENE→PAUSE; INTRO→BOARD; SOLVED/REWARD→BOARD) | Part 4 | nav stack | TC-NAV-* | BLOCKED | OK; празноти CZ-QA-012 |
| REQ-NAV-02 | Back не подава deduction, не губи улики, не дава награда | Part 4 | nav stack | TC-NAV-07 | BLOCKED | OK |
| REQ-NAV-03 | C01 винаги unlocked; C02 iff completed[C01]; C03 iff completed[C02] | Part 4 | unlock logic | TC-NAV-08, TC-ST-UNLOCK | BLOCKED | OK |
| REQ-NAV-04 | Boot: първа сесия → C01_INTRO; иначе BOARD; kill → BOARD „Продължи“ | Part 4, 5 | boot router | TC-BOOT-* | BLOCKED | AMBIGUOUS CZ-QA-013 |
| REQ-C01-WINDOW | C01_WINDOW: hitbox/позиция/P_INSPECT → EV_C01_RAIN, haptic LIGHT само първо откриване | Part 5 | P_INSPECT | TC-C01-OBJ | BLOCKED | OK |
| REQ-C01-FLOOR | C01_FLOOR: hitbox/позиция/P_INSPECT → EV_C01_DRY_FLOOR, haptic LIGHT само първо откриване | Part 5 | P_INSPECT | TC-C01-OBJ | BLOCKED | OK |
| REQ-C01-SHOES | C01_SHOES: optional, SEEN без evidence, без haptic, точен текст | Part 5 | P_INSPECT | TC-C01-OBJ | BLOCKED | OK |
| REQ-C01-CUP | C01_CUP: optional, SEEN без evidence, без haptic, точен текст | Part 5 | P_INSPECT | TC-C01-OBJ | BLOCKED | OK |
| REQ-C01-CLOCK | C01_CLOCK: optional, SEEN без evidence, без haptic, точен текст | Part 5 | P_INSPECT | TC-C01-OBJ | BLOCKED | OK |
| REQ-C01-MANAGER | C01_MANAGER: заключен до Q1; locked toast „Първо сравни прозореца и пода.“; после EV_C01_ADMISSION | Part 5, AT02 | P_MANAGER | AT02,TC-C01-ALT-02 | BLOCKED | OK |
| REQ-C01-BODY | C01_BODY/BACKGROUND: не интерактивни, без hitbox | Part 5, AT18 | — | AT18 | BLOCKED | OK |
| REQ-C01-Q1 | Q1 unlock hasAll(RAIN,DRY_FLOOR); верен A0; грешни A1/A2 → attempts+1 | Part 5, AT01 | deduction | AT01,TC-C01-DED-* | BLOCKED | OK |
| REQ-C01-Q2 | Q2 unlock hasAll(3) AND q.Q1; верен A1 | Part 5 | deduction | TC-C01-DED-* | BLOCKED | OK |
| REQ-C01-SOLVE | SUCCESS=3 evidence AND Q1 AND Q2 → atomicSolve, +100 XP веднъж, C02 unlock | Part 5, 10 | atomicSolve | AT12,TC-C01-SOLVE | BLOCKED | OK |
| REQ-C01-REPLAY | Replay C01: нов run, +0 XP, completion остава | Part 5, AT13 | replay | AT13,TC-REPLAY-* | BLOCKED | OK; Board карта – CZ-QA-013 |
| REQ-C01-PERSIST | AT03: Q1 верен + kill → MANAGER отключен, без преждевременен solve | Part 12 AT03 | save/restore | AT03,TC-KILL-* | BLOCKED | OK |
| REQ-C01-COPY | Точни текстове (opening, detail, feedback, SOLVED) – exact copy | Part 5 | content manifest | TC-COPY-C01 | BLOCKED | OK |
| REQ-C01-HINT | Hints H1–H3 и target order WINDOW,FLOOR,MANAGER; pulse UI_EVIDENCE | Part 5 | hint system | TC-HINT-C01 | BLOCKED | CZ-QA-009 |
| REQ-C02-PHONE | C02_PHONE: EMPTY→BATTERY; RESTORED→IDENTITY(+BATTERY); toast „2 наблюдения добавени“; един haptic | Part 2 P_PHONE, Part 6 | P_PHONE | AT04,AT05 | BLOCKED | OK |
| REQ-C02-CHARGER | C02_CHARGER: CTA „Свържи“ само в panel; connected+RESTORED атомарно; SFX_CONNECT; без реално чакане | Part 2 P_CHARGER | P_CHARGER | TC-C02-CHG-* | BLOCKED | OK |
| REQ-C02-CHG-INV | charger==CONNECTED iff phone_power==RESTORED (валидирай при restore) | Part 10 | state validator | TC-C02-INV | BLOCKED | OK (излишно дублиран state – CZ-QA-019) |
| REQ-C02-RECORD | C02_RECORD → EV_C02_NETWORK; C02_WATCH → EV_C02_WATCH_LOG; C02_CLOCK optional | Part 6 | P_INSPECT | TC-C02-OBJ | BLOCKED | OK |
| REQ-C02-BAT-ONCE | EV_C02_BATTERY точно веднъж при всеки ред (Path A / Path B) | Part 6, AT04/05 | evidence set | AT04,AT05 | BLOCKED | OK (модел) |
| REQ-C02-CONNECT | CONNECT: до 3 избора, submit само при 3; верен {ID,NET,WATCH}; wrong → feedback, attempts+1 | Part 6, Part 4 | C02_CONNECT | AT06,TC-C02-CON-* | BLOCKED | DESIGN CZ-QA-017 |
| REQ-C02-Q1 | Q1 unlock IDENTITY,NETWORK,WATCH_LOG AND link_ok; верен A2 | Part 6 | deduction | AT07 | BLOCKED | OK |
| REQ-C02-SUCCESS | SUCCESS изисква пълния set + RESTORED + link_ok; 0% батерия сама не решава | Part 6; QA brief | atomicSolve | TC-C02-NEG-01 | BLOCKED | OK (модел: не е решим само с BATTERY) |
| REQ-C02-HINT | Hint order CHARGER,PHONE,RECORD,WATCH; PHONE изпълнен само с IDENTITY | Part 6 | hint system | TC-HINT-C02 | BLOCKED | OK |
| REQ-C03-OBJ | 5 източника в произволен ред; без order lock (AT08) | Part 7 | P_INSPECT | AT08 | BLOCKED | OK |
| REQ-C03-TL | Timeline: tap token→tap slot, замяна връща стария token в pool, без дубликати | Part 7, AT09 | timeline | AT09,AT10,AT11 | BLOCKED | OK (модел) |
| REQ-C03-TL-PERSIST | Timeline слотове се възстановяват след kill/Back; timeline_ok се пази | Part 7, AT11 | save/restore | AT11,TC-KILL-TL | BLOCKED | OK |
| REQ-C03-LINK | LINK точно 3 от 5; верен {PHOTO,CLOCK_SYNC,PLATFORM} | Part 7 | C03_LINK | TC-C03-LINK-* | BLOCKED | PUZZLE AMBIGUITY CZ-QA-007 |
| REQ-C03-Q1 | Q1 unlock всички 5 + timeline_ok + link_ok; верен A0 | Part 7 | deduction | TC-C03-Q1 | BLOCKED | OK |
| REQ-C03-LOGIC | Логика: фото 20:15:30±1s вътре в 20:15:00–20:16:00; R214 тръгва 20:10:00 без междинно спиране | Part 7 Logic | content | TC-C03-LOGIC (QA, изчислено) | BLOCKED | OK (изчислено: 42 мин/прозорец) |
| REQ-C03-END | След C03 REWARD → G_END → BOARD; XP общо 300 | Part 7, Part 4 | G_END | TC-FULL-01 | BLOCKED | OK |
| REQ-ST-01 | XP инвариант: xp=100*count(reward_granted) | Part 10 | campaign state | TC-ST-XP | BLOCKED | OK |
| REQ-ST-02 | Reward инвариант: reward_granted не се изчиства при reset | Part 10 | campaign state | AT13 | BLOCKED | OK |
| REQ-ST-03 | Completion инвариант: solved → completed остава | Part 10 | campaign state | TC-ST-COMP | BLOCKED | OK |
| REQ-ST-04 | Evidence set без дубликати; непознат ID → corrupt snapshot, reset на run, не на campaign | Part 10 | restore validator | TC-SAVE-CORR | BLOCKED | OK |
| REQ-ST-05 | Atomic transaction + action.id idempotency; commit преди success UI | Part 10 | dispatch | TC-SAVE-* | BLOCKED | OK |
| REQ-SAVE-01 | Критични writes: clue, charger, stage, timeline, hint, reset, solve; без OnQuit | Part 10, K | persistence | TC-KILL-01..10 | BLOCKED | OK |
| REQ-SAVE-02 | Save failure → G_WRITE_ERROR, Retry/Revert; без фалшив success | Part 4, Part 8, AT17 | G_WRITE_ERROR | AT17,TC-SAVE-FAIL-* | BLOCKED | OK; кой екран е Back – CZ-QA-012 |
| REQ-SAVE-03 | Solve → kill преди REWARD: completed/reward запазени, XP не се удвоява | AT12 | atomicSolve | AT12 | BLOCKED | OK |
| REQ-LIFE-01 | Background: flush транзакция, пауза на audio/animation/timer; state непроменен | Part 5-7 Reset | lifecycle | TC-LIFE-01..05 | BLOCKED | OK |
| REQ-LIFE-02 | Activity recreation (low memory) = същото restore поведение | Part 5-7 | lifecycle | TC-LIFE-06,07 | BLOCKED | OK |
| REQ-AUD-01 | SFX_* и AMB_* събития с точни тригери; max 1 UI tap/100ms | Part 9 | audio | TC-AUD-* | BLOCKED | OK; AMB в EVIDENCE/HINT не е дефиниран – CZ-QA-021 |
| REQ-AUD-02 | Sound OFF изключва всичко; background спира audio, resume от loop boundary | Part 9 | audio | TC-AUD-05 | BLOCKED | OK |
| REQ-HAP-01 | LIGHT при ≥1 нова улика (еднократно), MEDIUM при първи solve на run; haptic off/без actuator = NONE | Part 9 | haptics | TC-HAP-* | BLOCKED | OK |
| REQ-MOT-01 | reduced_motion: без scale/accent анимации, функционално състояние същия frame | Part 8 | UI anim | TC-MOT-* | BLOCKED | OK; системна настройка не е упомената – CZ-QA-016 |
| REQ-AN-01 | 20 събития с описаните properties (Part 11; 19 от QA списъка + APP_STARTED) | Part 11 | analytics | TC-AN-* | BLOCKED | OK; CZ-QA-014 |
| REQ-AN-02 | Analytics failure не блокира gameplay/save/state | Part 10-11 | analytics | TC-AN-FAIL | BLOCKED | OK |
| REQ-AN-03 | Local log ≤5 MiB, FIFO за analytics, никога save | Part 12 L | analytics store | TC-AN-LIMIT | BLOCKED | OK |
| REQ-AN-04 | Без PII: имена, телефони, свободен текст, ad ID | Part 11 | analytics | TC-AN-PII | BLOCKED | OK |
| REQ-ACC-01 | Labels, focus order, scene скрита от a11y tree при modal; не само цвят/звук | Part 8 | a11y | TC-ACC-* | BLOCKED | OK (самата спецификация признава, че TalkBack gate не е изпълнен) |
| REQ-PERF-01 | 60fps цел/30fps floor, tap ≤100ms, scene load ≤2s, RAM ≤250MiB, GPU tex ≤64MiB, APK ≤80MiB | Part 13 | engine | TC-PERF-* | BLOCKED | OK (непотвърдени бюджети) |
| REQ-BLD-01 | Build ID/версия проследими до commit; package ID, versionName/Code | QA brief; Part 11 build_id | build pipeline | TC-BUILD-* | BLOCKED | липсва дефиниция (CZ-QA-014) |
| REQ-AST-01 | Всеки clickable има BASE + DETAIL asset; evidence има икона; manifest loader валидира assets | Part 9, 12D | manifest | TC-AST-01 | BLOCKED | OK (кръстосана проверка със скрипт) |

**Общо requirement реда: 84.** Runtime PASS: 0. Runtime FAIL: 0. BLOCKED: 84. NOT IMPLEMENTED: не може да се установи (няма имплементация).
Редове със static констатация (DOCUMENTATION CONFLICT / PUZZLE AMBIGUITY / SPEC GAP – виж `Findings.md`): 21.

## TEST COVERAGE GAP (тестове, които спецификацията не дефинира)

Спецификацията съдържа само 20 acceptance сценария (AT01–AT20). Нямат покритие в AT-списъка и са добавени от QA в `Regression_Suite.md` (ID с „(QA)“ или `TC-*`): input (rapid/long-press/multi-touch/cancel), hitbox 48dp на устройство, разделители на font scale 1.3/1.5, audio дублиране, haptic off, reduced motion, settings persistence, analytics (всичките 20 събития), analytics FIFO лимит, performance/soak, accessibility (TalkBack), install/upgrade/reinstall, build traceability.

## UNDOCUMENTED BEHAVIOUR

Не може да бъде оценено — няма build, срещу който да се търсят недокументирани функции или debug bypass.
