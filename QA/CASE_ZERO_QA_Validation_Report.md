# CASE ZERO — QA VALIDATION REPORT

Дата: 2026-10-05 • Роля: Senior/Lead Game QA • Repository: `bbrashnarov/CASEZERO` • Commit: `9a3509d` • Branch на анализа: `claude/case-zero-qa-spec-gh22bh`

Придружаващи файлове: [`RTM.md`](RTM.md) • [`Findings.md`](Findings.md) • [`Regression_Suite.md`](Regression_Suite.md) • [`tools/`](tools/) (изпълними проверки на спецификацията).

> **Ключов факт.** В repository-то **няма играем артефакт** — няма APK, source code, assets, тестове, CI или build документация. Съдържанието е 2 файла: `README.md` („TEST GAME“) и спецификацията `CASE_ZERO_Vertical_Slice_BG.md`. Следователно **не е изпълнен нито един runtime тест**. Този доклад не твърди, че играта работи или не работи; твърди, че **не може да бъде проверена** и описва какво е установено за спецификацията. Всичко, което е означено „Observed“, е наблюдение върху документа или резултат от скрипт, не поведение на Android.

---

## Phase 1 — Document inventory

| Document / File | Purpose | Version | Authoritative? | Notes |
|---|---|---|---|---|
| `README.md` | Заглавие на проекта | няма | Не | 21 байта: „# CASEZERO / TEST GAME“. Няма build/run/version/known issues. |
| `CASE_ZERO_Vertical_Slice_BG.md` | Game Design + Implementation Specification (Parts 1–14) | 1.0, 5.10.2026 | **Да (единствен нормативен източник в repo)** | Сама определя приоритета: „текущата задача“ над brief-а. Език: български. 189 790 байта, 2 239 реда. |
| „Pasted text(4).txt“ (задача за дизайнера) | Първоизточник | — | **ЛИПСВА** | Цитиран в ред 7. CZ-QA-002. |
| „Pasted text(2).txt“ (GAME DESIGN BRIEF, Marketing) | Първоизточник | — | **ЛИПСВА** | Цитиран в ред 7. CZ-QA-002. |
| Source code, tests, CI | — | — | **ЛИПСВАТ** | CZ-QA-001. |
| APK / release reference | — | — | **ЛИПСВА** | CZ-QA-001. |
| Asset manifest, changelog, known issues, version | — | — | **ЛИПСВАТ** | Спецификацията сама заявя: binary assets и build „предстоят“. |

**Source-of-Truth йерархия:** (1) `CASE_ZERO_Vertical_Slice_BG.md` Parts 5–7 (case-specific) и Part 10 (GameState); (2) Parts 2–4, 8 (общи договори); (3) Part 12 AT01–AT20 (acceptance); (4) Part 13 (бюджети – „непотвърдени цели“). Вътрешните конфликти са в `Findings.md` (CZ-QA-003, 008–011); QA не избира коя версия е вярна.

**Phase 3 Build verification:** APK filename / versionName / versionCode / package ID / build type / architecture / target Android / дата: **НЕ СА УСТАНОВИМИ** (няма APK). **BUILD TRACEABILITY RISK:** недоказуемо съответствие APK ↔ commit; освен това `build_id` е задължително analytics property без дефиниран източник (CZ-QA-014).

---

## 1. Executive Summary

| Показател | Стойност |
|---|---|
| Build tested | **няма** |
| Commit | `9a3509d` (само спецификация) |
| Devices | **няма** (нито физически, нито emulator – няма какво да се инсталира) |
| Runtime tests (Smoke/Core/Full) изпълнени | **0** |
| Runtime PASS / FAIL | 0 / 0 |
| Runtime BLOCKED | **всички (84 requirement реда в RTM)** |
| Static проверки изпълнени | 2 скрипта (геометрия/кръстосани препратки, state-model BFS) + ръчен преглед на 2 239 реда |
| Static резултат | геометрични и логически твърдения на спецификацията **потвърдени**, с изключение на 3 припокривания (един дефект – CZ-QA-003) |
| Findings | 21: **S0 ×1, S1 ×0, S2 ×4, S3 ×6, S4 ×4, DESIGN CONCERN ×6** |

## 2. Release verdict

## FAIL

**Защо:** (1) S0 — build/source/тестове липсват, играта не може да бъде инсталирана, стартирана или тествана (CZ-QA-001). (2) Гейт „известна puzzle ambiguity“ е нарушен в спецификацията (CZ-QA-007). (3) Три геометрични дефекта в UI договора (CZ-QA-003/004/005) ще се проявят при всяка имплементация, която следва текста. „FAIL“ тук означава „не може да бъде сертифициран“, а не „играта е счупена“ — runtime качеството е **неизвестно**.

## 3. Requirements compliance

| Ниво | Резултат |
|---|---|
| Marketing → Game Design | **Не може да се определи** — маркетинговият brief не е в repo (CZ-QA-002). |
| Game Design → Implementation Specification | 84 requirement реда проследени; редове със static констатация: 21 (виж RTM). |
| Implementation Specification → Source code | **Не може да се определи** — няма код. |
| Source → Runtime (APK) | **Не може да се определи** — няма APK. |
| Процент съответствие | **Не се дава** (няма достатъчно traceability data; всеки процент би бил измислен). |

## 4. Critical findings (S0/S1)
- **CZ-QA-001 (S0, P0)** — repository без build/source/тестове/CI. Детайли в `Findings.md`. Няма S1 констатации, **защото няма build, в който да се търсят** (не „няма S1 дефекти“).

## 5. Major findings (S2)
- **CZ-QA-002** — липсват първоизточниците (Marketing brief, задача към дизайнера).
- **CZ-QA-003** — C03 timeline: wrong-feedback rect `[96,1176,888,144]` (z=230) покрива 62% от всеки слот `[…,1104,280,192]` (z=220).
- **CZ-QA-004** — evidence карта 144 px (≈48 dp) срещу ≈68–90 dp нужни за „пълния текст“ (изчислено с допускания).
- **CZ-QA-007** — C03_LINK: {PHOTO, CLOCK_SYNC, DEPARTURE} е втори защитим отговор (PUZZLE AMBIGUITY).

## 6. Minor / Cosmetic findings (S3/S4)
S3: CZ-QA-005 (отговор 168 px), 006 (няма rect за въпрос), 008 (копиран C01 текст), 012 (Back не е дефиниран), 013 (first-run/„Продължи“/replay), 014 (analytics празноти). S4: 009, 010, 011, 021.

## 7. Specification defects
CZ-QA-003, 004, 005, 006, 007, 008, 009, 010, 011, 012, 013, 014, 021 (виж `Findings.md`).

## 8. Design concerns
CZ-QA-015 (най-дългият отговор е верен в 3/4), 016 (Settings само от Board), 017 (C02 CONNECT по елиминация), 018 (C03 TIMELINE = сортиране), 019 (излишен state), 020 (близки C01 hitbox-ове). Не са bugs — спецификацията ги допуска.

## 9. CASE 01 result — The Open Window
| Област | Резултат |
|---|---|
| Functional | **BLOCKED** (няма build) |
| Logic | Static: логиката е вътрешно консистентна (22:11 отваряне, 22:12 оглед; сух под → „вероятно наскоро“, не доказателство). Модел: 7 състояния, решим, Q2 преди ADMISSION и FLOOR→Q1 без WINDOW се отхвърлят. |
| UI | **BLOCKED**; static: CZ-QA-004/005/006, 020. |
| Persistence | **BLOCKED** (AT03, AT12 неизпълнени). |
| PASS/FAIL | **НЕ Е ОЦЕНЕН** (BLOCKED) |

## 10. CASE 02 result — The Last Call
Functional/UI/Persistence: **BLOCKED**. Static logic: Path A и Path B → еднакъв evidence set `{BATTERY, IDENTITY, …}`, BATTERY веднъж; 0% батерия не води до solve (SUCCESS изисква IDENTITY+NETWORK+WATCH_LOG, RESTORED, link_ok); 22:48 → 23:30 = 42 мин ✓. Concern: CZ-QA-017 (CONNECT се решава по елиминация). Няма „CRITICAL GAMEPLAY LOGIC BUG“ в спецификацията; дали **имплементацията** позволява solve само по батерия — неизвестно.

## 11. CASE 03 result — The Wrong Train
Functional/UI/Persistence: **BLOCKED**. Независимо изчислена логика: фото 20:15:29–31 е изцяло в 20:15:00–20:16:00 ✓; R214 заминава 20:10:00 без междинно спиране (пристига 20:35) ✓; перон 4 = R218 20:20 ✓; заключението следва от PHOTO + CLOCK_SYNC. **PUZZLE AMBIGUITY (CZ-QA-007, S2):** LINK приема само {PHOTO, CLOCK_SYNC, PLATFORM}, а {PHOTO, CLOCK_SYNC, DEPARTURE} е също защитим (DEPARTURE също свързва перон 4 с R218). Timeline: CZ-QA-003 (UI), CZ-QA-018 (concern). Модел: 656 състояния, решим, без дублиран token.

## 12. Save / Restore result
**BLOCKED.** Kill matrix (10 точки) и save-failure тестове са проектирани (`Regression_Suite.md`), не изпълнени. Static: договорът (atomic snapshot/journal, idempotent action.id, XP по reward_granted) е недвусмислен; рискове: излишен state (CZ-QA-019), first-run/„Продължи“ (CZ-QA-013).

## 13. Android lifecycle result
**BLOCKED.** Static: поведението при background/kill/rotation е описано (Part 5–7 „Reset/reload“), без противоречие; AT15 неизпълнен.

## 14. UI / Responsive result
**BLOCKED на устройство.** Static: геометрията на сцените е вярна (всички hitbox-ове ≥ 216 px = 72 dp @360, без припокриване); UI модалите съдържат 3 геометрични проблема (CZ-QA-003/004/005) и липсващи rect-ове (CZ-QA-006). Профили 360×640, 360×800, 412×915, tablet и font 1.0/1.3/1.5/2.0 — неизпълнени.

## 15. Accessibility result
**BLOCKED.** Спецификацията сама признава: „Проверка с Android screen reader е production gate, още не е изпълнена“. Контрастът (`#162733` върху `#F3EBDD`) не е измерен.

## 16. Audio / Haptics result
**BLOCKED.** Static: пълно съответствие събитие→тригер→haptic; AMB за EVIDENCE/HINT/DEDUCTION не е дефиниран (CZ-QA-021). Няма доставени аудио assets.

## 17. Analytics result
**BLOCKED.** Static: всичките 19 събития от QA списъка + `APP_STARTED` са дефинирани (20); празноти: CZ-QA-014. Правилото „analytics не променя state“ е дефинирано (Part 10–11).

## 18. Performance result
**Реални измервания: няма** (няма build/устройство). Бюджетите (60/30 fps, ≤100 ms tap, ≤2 s scene load, ≤250 MiB RAM, ≤64 MiB GPU, ≤80 MiB APK) са цели на дизайнера, а не измерени стойности — Part 13.

## 19. Automation coverage
Продуктови автоматични тестове: **0** (няма). QA-създадени проверки на документа (не на продукта): `spec_geometry_check.py` (геометрия, нормализация, кръстосани препратки, часови аритметики, дължини на текстове; **3 FAIL = един дефект CZ-QA-003**), `spec_state_model.py` (BFS на 3 case, инварианти; 0 FAIL).

| Area | Automated | Manual | Coverage | Risk |
|---|---:|---:|---|---|
| State | 0 (модел на спецификацията: да) | 0 | Само spec model | Висок |
| Save | 0 | 0 | Няма | **Висок** |
| C01 | 0 (модел) | 0 | Spec model | Висок |
| C02 | 0 (модел) | 0 | Spec model | Висок |
| C03 | 0 (модел) | 0 | Spec model | Висок |
| Navigation | 0 | 0 | Няма | Висок |
| Analytics | 0 | 0 | Няма | Среден |
| UI | 0 (геометрия на спецификацията) | 0 | Няма на устройство | Висок |
| Android lifecycle | 0 | 0 | Няма | Висок |
| Performance | 0 | 0 | Няма | Среден |

„Coverage“ не е процент — не се твърди никакво покритие на продукта.

## 20. Test coverage gaps
Спецификацията дефинира само AT01–AT20. Без собствен acceptance тест остават: input (rapid/long-press/multi-touch/cancel), 48dp hitbox на устройство, font 1.3/1.5, audio дублиране, haptic off, reduced motion, settings persistence, 20 analytics събития, 5 MiB FIFO, performance/soak, TalkBack, install/upgrade/reinstall, build traceability. Добавени от QA в `Regression_Suite.md` и RTM (**TEST COVERAGE GAP**).

## 21. Regression suite
Изграден: Smoke (10 стъпки, ~5–10 мин), Core Regression, Full Regression, 3 exploratory charters, release gates — `Regression_Suite.md`. **Неизпълнен.**

## 22. Playtest readiness

## NO

Технически: build няма. Игрово/UX: открита puzzle ambiguity (C03), риск от налучкване (CZ-QA-015), UI геометрия, която не побира текста (CZ-QA-004/005). Целите за usability (Part 5–7 „User Test“) са цели, не резултати.

## 23. Recommended fix order
**P0:** CZ-QA-001 — предоставете APK + SHA на commit + source + build инструкции + (по възможност) debug state export.
**P1:** CZ-QA-002 (добавете brief-а), 003, 004, 007 (решете C03_LINK), и потвърдете UI геометрията с greybox преди арт.
**P2:** CZ-QA-005, 006, 008, 012, 013, 014, 015, 019.
**P3:** CZ-QA-009, 010, 011, 016, 017, 018, 020, 021.

## 24. FINAL QA SIGN-OFF

**NOT APPROVED FOR PLAYTEST**

---

## Отговори на 13-те крайни QA въпроса
1. **Маркетинговата концепция реализирана ли е?** Неустановимо — brief-ът не е в repo (CZ-QA-002); реализация няма.
2. **Game Designer specification спазена ли е?** Неустановимо — няма имплементация. Самата спецификация има 13 вътрешни дефекта.
3. **Програмистът реализирал ли е specification без недокументирани промени?** Неустановимо — няма код.
4. **Source code и APK съответстват ли?** Неустановимо — няма нито един от двата (BUILD TRACEABILITY RISK).
5. **Трите cases могат ли да бъдат завършени правилно?** В **спецификацията/модела** — да (C01 7, C02 30, C03 656 достижими състояния, цел достижима). В играта — неизвестно.
6. **Има ли алтернативен gameplay path, който чупи логиката?** В модела — не. Има алтернативен *верен* отговор, който спецификацията отхвърля (CZ-QA-007).
7. **Може ли играчът да получи duplicate XP или reward?** Спецификацията предотвратява (reward_granted + action.id); имплементацията не е тествана.
8. **Може ли save/load да повреди progression?** Неизвестно — не е тествано.
9. **Работи ли Android lifecycle правилно?** Неизвестно.
10. **Спазени ли са UI, hitbox и responsive requirements?** Сцените — да, на ниво числа; модалите — не (CZ-QA-003/004/005); на устройство — не е тествано.
11. **Analytics отчитат ли реалните действия правилно?** Неизвестно (празноти в спецификацията: CZ-QA-014).
12. **Има ли S0/S1/S2 дефекти?** S0 ×1, S1 ×0 (не е търсен в build), S2 ×4.
13. **Готов ли е build-ът за реален external playtest?** **Не** — build няма.

## Какво е нужно, за да бъде завършена QA валидацията
APK(и) + SHA на съответния commit; source code или поне build инструкции; ако е възможно debug build със state/analytics export; устройство или emulator профили (360×640, 360×800, 412×915, tablet); Marketing brief и оригиналната задача към дизайнера. След получаването им се изпълнява `Regression_Suite.md` (Smoke → Core → Full) и докладът се преиздава с реални доказателства (screenshots, видео, logcat, state dump).

## Ограничения на този анализ
Не е изпълнен код на играта. Оценките за препълване на текст (CZ-QA-004/005/006) са **изчисления с допускания** (1080 px ≙ 360 dp; ≈26 символа/ред при 16sp; спецификацията не дефинира px↔dp за canonical canvas) и трябва да се потвърдят на устройство. Моделът в `spec_state_model.py` е интерпретация на QA, а не доказателство за поведение на имплементация. Не са променяни спецификацията, дизайнът, балансът или requirements.
