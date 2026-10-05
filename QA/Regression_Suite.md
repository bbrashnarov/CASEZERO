# CASE ZERO — CORE REGRESSION (изграден от QA, **неизпълнен**: няма build)

Всички тестове са проектирани от спецификацията v1.0. Статус на всички: **NOT RUN – BLOCKED (CZ-QA-001)**. Очакваните резултати са от спецификацията; QA не ги променя. AT01–AT20 са сценариите на самата спецификация (Part 12).

Подготовка за всяко изпълнение: запиши APK име, `versionName/versionCode`, package ID, SHA на commit, устройство, Android, DPI/размер, font scale, install тип (fresh/upgrade). Без доказан commit↔APK = **BUILD TRACEABILITY RISK**.

## 1. SMOKE (~5–10 мин)
| # | Стъпка | Очаквано | Реф. |
|---|---|---|---|
| S1 | Fresh install | инсталира се, няма permission/login | TC-INST-01 |
| S2 | Launch (замери launch→първа интеракция) | boot без чакане → C01_INTRO | TC-BOOT-01 |
| S3 | „Разследвай“ → C01 сцена | objective видим, hint=0 | C01 flow 1–2 |
| S4 | WINDOW, FLOOR → Evidence → Q1 A0 | RAIN+DRY; Q1 верен | AT01 |
| S5 | MANAGER → Q2 A1 | ADMISSION; SOLVED | C01 flow 8–11 |
| S6 | Продължи → REWARD | +100 XP, C02 unlocked | AT12 |
| S7 | Force-stop + relaunch | BOARD, XP=100, C01 completed, C02 unlocked | TC-KILL-07 |
| S8 | Влез в C01 replay | confirmation; Yes → INTRO; XP остава 100 | AT13 |
| S9 | Back от SCENE → PAUSE → Resume | без загуба | TC-NAV-05 |
| S10 | Няма crash/ANR; logcat без FATAL | — | — |

## 2. CORE REGRESSION
**Gameplay/логика:** AT01–AT20; C01 canonical + alt (FLOOR преди WINDOW, MANAGER преди Q1, optional първи, repeat taps – TC-C01-ALT-01..04); C02 Path A (PHONE празен→CHARGER→CTA→PHONE) и Path B (CHARGER→CTA→PHONE); `EV_C02_BATTERY` ×1 (AT04/05); CONNECT: 0–4 избора, wrong set, 4-ти tap „Избери до 3“, deselect, Back/reopen (TC-C02-CON-01..06); C03 timeline: select/place/replace/displace/duplicate/empty slot/Back/kill/restore (AT09–AT11, TC-C03-TL-01..08); LINK 10 комбинации (вкл. {PHOTO,CLOCK_SYNC,DEPARTURE} – виж CZ-QA-007); Q1 неверни A1/A2.
**State инварианти (TC-ST-*):** xp=100·count(reward_granted); без втори reward; completed остава след replay; evidence без дубликати; charger⇔phone_power; unlock зависи от предходен completion. Метод: state dump (debug export или adb run-as при debuggable build) след всяка транзакция.
**Save (kill matrix – TC-KILL-01..10):** `adb shell am force-stop <pkg>` след: CASE START; CLUE; Q1 верен; CHARGER connect; TIMELINE placement; финален верен submit; SOLVED екран; REWARD екран; REPLAY start; по време на запис (ако build позволява). Очаквано: без загубен commit, без дубликат улика/XP, route валиден. Save failure (TC-SAVE-FAIL-01..03): пълно хранилище / read-only dir → G_WRITE_ERROR, Retry, Revert; без фалшив success (AT17).
**Navigation (TC-NAV-01..10):** Back от всеки екран (Scene, Evidence, Detail card, Hint, Inspect, Deduction, Picker, Settings, Pause, Confirm, Solved, Reward, G_END, Board, Write error); Back не решава, не губи улики, не дава XP; Back по време на анимация.
**Input (TC-INP-01..08):** tap, rapid tap, double tap, long press >500 ms, движение >12dp, drag, multitouch, pointer cancel; rapid tap върху clue, Submit, Reward „Следващ случай“, Charger CTA → един commit/event/haptic/XP (AT14).
**Analytics (TC-AN-*):** всяко от 20 събития: тригер, timing, properties, дублиране, ред, case_id/object_id/run_id/evidence IDs/attempt counts; analytics failure не променя state; лимит 5 MiB FIFO без загуба на save; няма PII.

## 3. FULL REGRESSION (всичко по-горе + )
- **Install:** fresh, upgrade (ако има предишен build), reinstall, uninstall→install, launch offline (TC-INST-01..05).
- **Lifecycle:** Home, app switch, lock/unlock, входящо обаждане (emulator), background→foreground, process death (`am kill`), low-memory recreate (`adb shell am send-trim-memory`), ротация/промяна на конфигурация (AT15) (TC-LIFE-01..08).
- **UI/Responsive:** 360×640, 360×800, 412×915, tablet; font 1.0/1.3/1.5/2.0 (AT16); cutout/notch/punch-hole; gesture nav; всички модали, footer, evidence карти (виж CZ-QA-003..006), hitbox debug overlay (min 48dp, overlap>25% → G_PICKER) (TC-UI-*, TC-FONT-*, TC-HIT-*).
- **Audio/Haptics/Motion/Settings:** всяко SFX/AMB; без дублиране; sound off; background/resume; LIGHT/MEDIUM; haptic off; устройство без актуатор; reduced_motion (без промяна на timing); settings persist след restart (TC-AUD-*, TC-HAP-*, TC-MOT-*, TC-SET-*).
- **Copy:** точни текстове (opening, detail, feedback, SOLVED, hints) срещу спецификацията; български правопис; без placeholder/debug (TC-COPY-*).
- **Accessibility:** TalkBack (focus order, labels, modal скрива сцената), контраст ≥4.5:1 (`#162733` на `#F3EBDD` и др.), информация не само с цвят (TC-ACC-*).
- **Performance/Soak:** cold/warm start, FPS/frame pacing, памет, tap latency ≤100 ms, scene load ≤2 s, RAM ≤250 MiB, APK ≤80 MiB; C01→C02→C03 + 10× replay; наблюдавай leak, звук акумулация, дублирани обекти (TC-PERF-*).
- **Negative/Exploratory:** виж charters по-долу.

## 4. Exploratory charters (подготвени, **НЕ изпълнени**)
| Сесия | Charter | Фокус | Времева рамка |
|---|---|---|---|
| A — Gameplay abuse | Опитай нестандартни последователности: Q след Q, CTA без prereq, replay многократно, MANAGER преди Q1, C02 CTA повторно, C03 токени с празни слотове | логика, дубликати, XP | 45 мин |
| B — Lifecycle abuse | Background/kill/reopen по средата на всяка транзакция, lock по време на deduction, rotate при анимация | save/restore | 45 мин |
| C — UI/interaction abuse | Rapid tap, ръбове, font 2.0, 360×640, cutout, multi-touch | hitbox, layout | 45 мин |
Запис за всяка: Charter, Duration, Areas, Defects, Questions — **не са попълнени, защото няма build.**

## 5. Release gates (от QA brief)
Блокират playtest: S0; неразрешен S1; save corruption; progression blocker; duplicate reward; известна puzzle ambiguity; възпроизводим crash в нормален flow. **Текущо:** S0 (CZ-QA-001) и известна puzzle ambiguity (CZ-QA-007) → гейтът е нарушен.

## 6. Прилагане срещу всеки нов build
1. Smoke (10 мин) → ако пада, спри и върни build. 2. Core Regression при всеки RC. 3. Full Regression преди външен playtest и при промяна на save schema, content_version или engine. 4. Всяка поправка на S1/S2 добавя регресионен TC с ID на дефекта.
