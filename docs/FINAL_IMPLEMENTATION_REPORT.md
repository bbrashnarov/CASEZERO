# FINAL IMPLEMENTATION REPORT — CASE ZERO Android Vertical Slice 0.1.0

Дата: 2026-10-05 · Спецификация: `CASE_ZERO_Vertical_Slice_BG.md` v1.0 · Branch:
`claude/project-thread-g4as3v` · Engine: Godot 4.7.2-stable

## 1. Architecture Summary

Data-driven, еднопосочен поток: UI → Action (UUID `action_id`) → Store → чист Reducer →
проверка на GameState инварианти → атомичен запис → commit → сигнал. Gameplay (обекти,
хитбоксове, улики, gates, етапи, отговори, подсказки, текстове, asset ID) е в `content/*.json`;
кодът познава само типове поведение. UI рендерира Router state (base screen + modal stack) и не
решава gameplay. Звук, вибрация и analytics реагират само на committed резултати. Подробно:
`docs/ARCHITECTURE.md`.

## 2. Engine & Technical Decisions

* TD-001: Godot 4.7.2-stable, typed GDScript (аргументация в `docs/TECHNICAL_IMPLEMENTATION_PLAN.md`).
* Canvas 1080×1920, `canvas_items` + `expand`, portrait; собствен hit-test в canonical координати
  (без physics/Area2D).
* Save: JSON envelope със SHA-256 checksum, запис tmp → rename, `save.bak`, schema version + migrations.
* Android: официални prebuilt templates (без Gradle), arm64-v8a, minSdk 24 / targetSdk 36,
  три профила: Dev / Playtest / Release с отделни package ID и ключове.
* Analytics: локален JSONL, 5 MiB FIFO, ръчен export, без мрежа (APK без INTERNET permission).

## 3. Implemented Systems

Content loader + validator + solvability; GameState + инварианти; Reducer (10 action типа),
interaction profiles P_INSPECT / P_PHONE / P_CHARGER / P_MANAGER; stage типове single_answer /
evidence_set / timeline; hints (3 нива + target pulse); Store (idempotency, атомичен solve,
write-failure pending/retry/revert); SaveRepository + BootService (FRESH, LOADED, backup
recovery, Recovery диалог, content extension); Router и всички screen ID (G_BOOT, G_BOARD,
G_SETTINGS, G_END, G_PICKER, G_WRITE_ERROR, C0x_INTRO/SCENE/INSPECT_*/EVIDENCE/DETAIL_CARD/
HINT/DEDUCTION/PAUSE/CONFIRM_RESET/SOLVED/REWARD); Case Board; Settings (звук, вибрация,
намалено движение); Android Back contract; input contract (pointer-up, ≤12 dp, ≤500 ms), ≥48 dp
хитбоксове, G_PICKER при >25% припокриване; safe area; font scale 1.0–2.0; audio/haptic hooks;
active time (без background/пауза); analytics (20 събития); dev debug overlay; structured logging.

## 4. CASE 01 Status — DONE

„Отвореният прозорец“: 4 обекта + декор, 3 улики, 2 етапа, gate на C01_MANAGER, 3 подсказки,
solve → 100 XP, replay → 0 XP. C01 DEVELOPMENT GATE: PASS (UI flow, save/load, рестарт, hint,
evidence, deduction, reward, replay, Back, реален kill -9) — таблица в TEST_REPORT.

## 5. CASE 02 Status — DONE

„Последното обаждане“: P_PHONE варианти EMPTY/RESTORED, P_CHARGER CTA „Свържи“ → `charger=CONNECTED`,
`phone_power=RESTORED`, събитие CHARGER_CONNECTED, content инварианти; етапи C02_CONNECT
(evidence_set) и C02_Q1 (финален). Отключва се след C01.

## 6. CASE 03 Status — DONE

„Грешният влак“: 5 улики, C03_TIMELINE (3 slot-а), C03_LINK (evidence_set), C03_Q1 (финален);
след solve → G_END. Отключва се след C02.

## 7. Persistence Status — DONE

16 persistence теста + реален SIGKILL на 13 точки по време на C01 (`tools/qa/kill_test.sh`):
13/13 PASS, без загубен или фалшив прогрес. Повреден primary → `.bak`; повреден или по-нов
save → Recovery диалог и копие `save.corrupt.*`. Write failure не сменя state (AT17).
Ограничение: няма fsync (KNOWN_ISSUES §6).

## 8. Analytics Status — DONE

Всички 20 събития от спецификацията, общи полета, `interaction_index`, `active_ms`; 5 MiB FIFO;
без PII; export в `user://exports/`; грешка при запис не спира играта. 4 integration теста + AT18.

## 9. Automated Tests

109 теста, 109 PASS, 0 FAIL (последно пускане на commit-а на този отчет): content 5, C01 domain 22,
C02/C03 domain 17, persistence 16, analytics 4, UI C01 10, UI input/layout 10, UI C02/C03 5,
acceptance 20. Kill тест: 13/13 PASS. Детайли: `docs/TEST_REPORT.md`.

## 10. Acceptance Tests

AT01–AT20: 20/20 PASS, изпълнени през истинския App (shell → screens → Store → SaveRepository).
Таблица Given/When/Expected/Actual/PASS-FAIL в `docs/TEST_REPORT.md`.

## 11. Android Device Tests — NOT RUN

Няма Android устройство или емулатор в средата (няма KVM). Изградени и проверени са 3 APK
(`apksigner verify` + inspect: arm64-only, portrait, без INTERNET, без тестове, content вътре),
но **не са инсталирани и пускани на устройство**. Нужно: ръчен тест по KNOWN_ISSUES U1–U8.

## 12. Performance Results — NOT MEASURED

Няма reference device; стойности не се измислят. Бюджетите от спецификацията са непроверени
(KNOWN_ISSUES U2).

## 13. Known Issues

Пълен списък: `docs/KNOWN_ISSUES.md`. Основни: непроверено на устройство (U1–U8); AAB не е
изграден, защото `dl.google.com` е блокиран (E1); Playtest/Release са подписани с локален
тестов ключ, не за разпространение (E3); art pack липсва → GREYBOX; audio е placeholder;
няма fsync. Няма IMPLEMENTATION BLOCKER — при четенето не е намерено противоречие, което да
изисква промяна на дизайна.

## 14. Deviations From Specification

Интерпретациите на неясни места са в KNOWN_ISSUES §3 и не променят поведението. Следните точки
се отклоняват от буквата на спецификацията:

```
Specification:  Timeline slots са хоризонтални; при малък екран/large font стават три вертикални 48dp реда.
Implementation: Винаги три вертикални 48dp реда.
Reason:         Един layout, който работи на всички референтни устройства и font scale без хоризонтален scroll.
Impact:         Само визуално; редът, слотовете, етикетите и проверката са същите.
Approved/Unapproved: Unapproved
```

```
Specification:  F_UI_SEMIBOLD = Noto Sans SemiBold.
Implementation: Noto Sans Bold (OFL), посочен в manifest-а под ID F_UI_SEMIBOLD.
Reason:         SemiBold файлът не е наличен офлайн в средата.
Impact:         По-плътни заглавия и бутони; подменя се само в manifest-а.
Approved/Unapproved: Unapproved
```

```
Specification:  Hint target pulse 2×600 ms при показване на подсказката.
Implementation: Pulse-ът започва при затваряне на hint панела.
Reason:         Панелът покрива сцената, докато е отворен; pulse под него не се вижда.
Impact:         Същата анимация и цел, ~затварянето по-късно.
Approved/Unapproved: Unapproved
```

```
Specification:  P_INSPECT: повторен tap на SEEN обект показва „Прегледано“.
Implementation: C02_PHONE след зареждане е SEEN, но дава нова улика (IDENTITY) → показва се като находка с toast, без „Прегледано“.
Reason:         Спецификацията на C02 изисква новата улика при първия tap след зареждане; „Прегледано“ би я скрило.
Impact:         Само етикетът при този един tap.
Approved/Unapproved: Unapproved
```

```
Specification:  Art и audio по Asset ID (Part 9); labeled greybox rectangles са разрешени в debug build.
Implementation: И трите build-а (вкл. Playtest/Release) рисуват GREYBOX правоъгълници с Asset ID; audio е генериран placeholder.
Reason:         Binary art pack не е доставен (Part 12 §N, точка 3).
Impact:         Визуално/звуково; хитбоксовете и gameplay са от content, не от art. Playtest с greybox не оценява art качество.
Approved/Unapproved: Approved за Dev (спецификацията го позволява); Unapproved за Playtest/Release до доставката на assets
```

```
Specification:  Android deliverables: APK и AAB, подписани за playtest/release.
Implementation: 3 APK; AAB не е изграден; Playtest/Release с локален тестов ключ.
Reason:         Блокиран dl.google.com (няма Gradle/SDK platforms); release keystore не е предоставен.
Impact:         APK-тата са за вътрешен тест; за store е нужен AAB build и истински ключ.
Approved/Unapproved: Unapproved
```

Инженерни допълнения без промяна на gameplay (microcopy в `ui_text.engineering`, Recovery
диалог, dev overlay, package суфикси, placeholder icon) са описани в KNOWN_ISSUES §4.
