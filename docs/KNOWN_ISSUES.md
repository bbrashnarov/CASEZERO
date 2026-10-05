# KNOWN ISSUES — CASE ZERO Vertical Slice 0.1.0

Състояние към 2026-10-05. Нито един от проблемите по-долу не е IMPLEMENTATION BLOCKER на
спецификацията: при четенето не е намерено реално противоречие, което да изисква промяна на
дизайна. Тук са (1) непроверените неща, (2) ограниченията на средата, (3) интерпретациите на
неясни места и (4) инженерните допълнения, които спецификацията не описва.

## 1. Непроверено (няма Android устройство / емулатор)

| # | Какво | Защо | Как да се провери |
|---|---|---|---|
| U1 | APK-тата не са инсталирани и пуснати на устройство | В средата няма устройство, няма `/dev/kvm`, няма emulator image | `adb install build/android/casezero-dev-0.1.0.apk`, ръчно минаване на C01→C03 |
| U2 | Performance budgets (60/30 fps, ≤100 ms tap response, ≤2 s scene load, ≤64 MiB textures, ≤250 MiB RAM) | Не са измерени — няма reference device. Не се твърди, че са изпълнени | Godot profiler + `adb shell dumpsys meminfo com.casezero.verticalslice` на mid-range устройство |
| U3 | Android system font scale | Чете се през JNI (`Settings.System.font_scale`) в `PlatformService._android_font_scale()`. Не е пускано на устройство; при грешка пада тихо на 1.0 | Settings → Display → Font size = max, рестарт на играта, debug overlay показва `font` |
| U4 | Safe area / cutout / gesture navigation | Използва `DisplayServer.get_display_safe_area()`; на desktop е проверено само чрез override на insets в тестовете | Устройство с cutout и gesture nav |
| U5 | Вибрация (LIGHT/MEDIUM) | `Input.vibrate_handheld`; VIBRATE permission е в manifest-а | Ръчно на устройство |
| U6 | Background/foreground на Android (`NOTIFICATION_APPLICATION_PAUSED/RESUMED`) | Логиката е тествана чрез директни извиквания (AT15), не с истински Activity lifecycle | Home → връщане; recent apps kill |
| U7 | Activity recreation | Portrait е заключен; recreation = нов процес → същият restore път като kill (покрит от AT15 и kill -9 теста) | Developer options → "Don't keep activities" |
| U8 | Контраст 4.5:1 | Палитрата е от спецификацията; не е мерено на реален build/екран | Скрийншоти от устройство + contrast checker |

## 2. Ограничения на средата за build

| # | Какво | Последица |
|---|---|---|
| E1 | `dl.google.com` е блокиран (403 от proxy) | Няма Android SDK platforms, cmdline-tools, Gradle Android plugin. **AAB не е изграден** (изисква gradle build). APK-тата са от официалните prebuilt templates на Godot 4.7.2 и се подписват с `apksigner` от Ubuntu |
| E2 | Android SDK „изглед“ | `tools/build/build_android.sh` сглобява минимален SDK от системните `adb`/`apksigner`/`zipalign` в `build/android-sdk`. На машина с истински SDK се ползва `ANDROID_SDK_ROOT` |
| E3 | Release ключ | Няма предоставен release keystore. Playtest/Release APK-тата са подписани с **локален тестов ключ** (`build/keystores/release-local.keystore`, извън git). Не са за разпространение. Истинският ключ се подава с `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD` |

## 3. Интерпретации (поведението остава по спецификацията)

| # | Място в спецификацията | Решение |
|---|---|---|
| I1 | Opening text на C01/C02/C03 е даден в обвиващи кавички „…“ | Външните кавички са разделител на документа и са премахнати; вътрешните кавички на репликите са запазени дословно |
| I2 | P_INSPECT: SEEN → TAP показва „Прегледано“ | Показва се само при истински повторен преглед без нова улика. C02_PHONE след зареждане остава SEEN, но дава нова улика (IDENTITY) → показва се като находка с toast, без „Прегледано“ |
| I3 | C02_PHONE при RESTORED: „Първият tap след зареждане добавя и EV_C02_BATTERY… надпис „При намиране: 0%“ | Detail текстът е точно копието от таблицата на обекта (case-specific > global). Архивираното 0% е в картата на EV_C02_BATTERY |
| I4 | `<case>_DETAIL_CARD(evidence_id)` | Route ID е `C0x_DETAIL_CARD`, `evidence_id` е параметър на route-а (analytics `route` полето е без параметъра) |
| I5 | Timeline slots: „при малък екран/large font slots стават три вертикални 48dp rows“ | Използват се вертикални редове винаги — един layout, без хоризонтален scroll на никой екран |
| I6 | Hint target pulse | Pulse-ът (2×600 ms) започва при затваряне на hint панела, защото панелът покрива сцената, докато е отворен |
| I7 | Header при font scale 2.0 | „Не се намалява шрифт; използвай scroll“: header-ът (title + objective) е ограничен до 28% от safe височината и скролира; footer бутоните минават на два реда един под друг, вместо да режат думи |
| I8 | Модал височина | Baseline модал `[48,312,984,1248]`; на други екрани модалът расте до safe височината според съдържанието, тялото скролира, footer CTA е извън scroll |
| I9 | `interaction_index` | Увеличава се при всяко прието UI/game взаимодействие, вкл. Settings (таблицата в Part 10: „each accepted UI/game interaction“) |
| I10 | „Retry once“ (AT17) | Retry повтаря същата транзакция (същия action_id и proposed state); при нов неуспех диалогът остава |
| I11 | Toast позиция | Не е зададена; toast-ът е над footer-а, центриран, не блокира input |
| I12 | Locked feedback | Toast с `locked_text` за 1500 ms (CMP/Part 2: „1500ms“) |
| I13 | F_UI_SEMIBOLD | Няма Noto Sans SemiBold файл в средата; ползва се Noto Sans Bold (OFL). Сменя се само в manifest-а |
| I14 | Детайлното копие на C02_CHARGER съдържа „Свържи“ в кавички | Запазено дословно |

## 4. Инженерни допълнения (не са в спецификацията, не променят gameplay)

* **Microcopy, която спецификацията не дава** — в `content/ui_text.json`, секция `engineering`
  (отделена от `spec`): бутоните на Пауза („Към таблото“, „Започни отначало“, „Продължи“),
  „Да“/„Не“, етикетите в Settings, заглавие „Подсказка %d/3“, текстове на Board, Reward, Boot,
  Recovery, Picker, „Опитай отново“ за G_WRITE_ERROR, build/export етикети, малък индикатор на
  етапа „1/2“ под „Направи извод“. Подменят се само в JSON.
* **Recovery диалог** при повреден/по-нов save (Part 10 изисква поведението, не дава текстове).
* **Dev debug overlay** (само `dev` feature): route, run state, XP, saves, sounds/haptics,
  hitbox outlines, симулиран write failure, font scale / insets override, export. Няма го в
  Playtest и Release.
* **Package ID суфикси**: `com.casezero.verticalslice` (Release), `.dev`, `.playtest` — за да
  съжителстват на едно устройство.
* **Placeholder app icon** `assets/icon/app_icon_placeholder.png` (спецификацията не дава icon).

## 5. Липсващи production assets

* **Art pack: GREYBOX.** Няма доставени binary assets (Part 12 §N, точка 3). Всички 68 Asset ID
  са в `content/manifest.json`; 57-те визуални са с `path: null` (11-те с път са шрифтове и audio); рендерерът рисува етикетирани правоъгълници
  (`Asset ID · GREYBOX`). `greybox_allowed` трябва да стане `false` за финален build — тогава
  липсващ критичен asset дава видима грешка вместо невидима улика.
* **Audio: placeholder тонове** (`assets/audio/*.wav`, генерирани), отбелязани `placeholder: true`.
* Шрифтове: Noto Sans Regular/Bold, OFL (`assets/fonts/NOTO_LICENSE_AND_COPYRIGHT.txt`).

## 6. Технически бележки

* Test runner-ът печата `ObjectDB instances were leaked at exit` при изход: RefCounted цикли
  между services и closures в тестовите App инстанции. Не влияе на резултатите; играта
  (`--quit-after`) излиза без това предупреждение.
* `FileAccess` няма fsync: atomic rename пази от process kill (проверено с `kill -9`), но не
  гарантира durability при внезапно спиране на тока; checksum + `save.bak` откриват и
  възстановяват торн файл.
