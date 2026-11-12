# auto_podbor_mobile

Мобильное приложение «БитНеБит» — маркетплейс подбора автомобиля. Заказчик
размещает заказ, исполнитель откликается, находит кандидатов и проводит осмотр:
13 деталей кузова на схеме и 4 пункта в боковых колонках — двигатель, пороги,
окна, документы (`InspectionPanel.kind == 'extra'`, `widgets/inspection_schematic.dart`).
Дефекты у каждого пункта свои: `/defects` отдаёт коды пунктов, стор держит индекс.

Flutter-клиент к JSON API на Laravel (Sanctum-токены). Единственный реальный
клиент этого API; без поднятого бекенда работают только тесты.

## Быстрый старт

```bash
flutter pub get
flutter run -d emulator-5554   # Android-эмулятор — основная цель разработки
flutter run -d chrome          # веб тоже собирается
```

Бекенд нужен на `:8083` (docker compose: nginx + php-fpm + MySQL), с накатанными
миграциями и сидерами — иначе списки заказов пустые, а вход не пройдёт.

### Сборки и адрес бекенда

Приложение собирается в двух вариантах — `dev` и `prod` — через Flutter flavors.
Адрес API выбирается автоматически в `lib/config/api_config.dart`:

| Flavor | applicationId (Android) | bundle ID (iOS) | API |
| --- | --- | --- | --- |
| `dev` | `com.bitnebit.dev` | `com.bitnebit.dev` | локальный бекенд: `http://10.0.2.2:8083/api` (Android-эмулятор), `http://localhost:8083/api` (iOS-симулятор) |
| `prod` | `com.bitnebit.app` | `com.bitnebit.app` | `https://bitnebit.com/api` |

Dev и prod имеют разный `applicationId`/`bundle ID`, поэтому могут стоять на одном телефоне рядом.

Основные команды (`Makefile`):

```bash
make run-dev               # локальная разработка
make run-prod              # проверка прод-сборки
make build-apk-dev         # dev APK
make build-apk-prod        # prod APK для установки на телефон
make build-appbundle-prod  # AAB для Google Play
make analyze
make test
```

Под капотом: `flutter run --flavor dev` / `flutter build apk --flavor prod`.
Без `--flavor` (тесты, `flutter run` без флага) адрес — dev; релизная сборка
без флага — prod.

Номер сборки (`versionCode` / `CFBundleVersion`) у `build-*` задаёт Makefile:
число коммитов этого репозитория (`git rev-list --count HEAD`), в CI —
`BUILD_NUMBER=…`. `+1` в `pubspec.yaml` не трогают. prod-release Gradle не
соберёт без релизного ключа (`android/key.properties` — ссылка на
`~/keys/bitnebit/key.properties`) и с номером 1 (собрали не через `make`);
devRelease без ключа подписывается отладочным — для эмулятора.

**Принудительное обновление.** Каждый запрос несёт номер сборки
(`X-App-Build`, ставит `HttpTransport`). Сервер держит минимальную
(`min_build` в `GET /config`, `APP_MIN_BUILD` в `.env` бекенда): старой
сборке он отвечает 426, и `AppUpdate` (`lib/state/app_update.dart`) вместо
всего приложения показывает «Обновите приложение»
(`UpdateRequiredScreen`) — со ссылкой в магазин, откуда поставили
(`installerStore`: Google Play или RuStore; APK вручную — оба). При запуске
`AppUpdate.checkOnStart` сверяется с `/config` сразу, не дожидаясь запроса.

iOS: минимум **15.5** — этого требует ML Kit (скан VIN). Версию держат
`ios/Runner.xcodeproj/project.pbxproj` и `ios/Podfile`; в Podfile перечислены
flavor-конфигурации `DebugDev`/`DebugProd`/`ReleaseDev`/`ReleaseProd`. Поды
ставятся при первой сборке на Mac.

Для запуска dev-сборки на **реальном телефоне** в той же сети с компьютером
подставьте в `lib/config/api_config.dart` LAN-адрес машины с бекендом
(`http://192.168.1.5:8083/api`) вместо `10.0.2.2`/`localhost`.

### Демо-аккаунты

Вход — по телефону и коду: SigmaSMS шлёт его в Telegram, а нет Telegram —
звонит и диктует (порядок настраивается на бекенде; канал приходит полем
`channel`: `telegram_call` / `call_telegram`, экран пишет, откуда ждать код). Повторный запрос —
после паузы `resend_in`, на 429 экран показывает отсчёт по `retry_after`. Драйвер
`log` на dev-бекенде ничего не отправляет: в окружении `local` код приходит прямо
в ответе (`dev_code`) и подставляется сам.

| Кто | Телефон | Почта (для `POST /login`) |
| --- | --- | --- |
| Максим, исполнитель | `+79000000001` | `inspector@autopodbor.local` |
| Андрей, заказчик | `+79000000002` | `customer@autopodbor.local` |
| Ещё пять исполнителей | `+79000000003…7` | — |

Пароль у всех — `password`.

## Проверки

```bash
flutter analyze
flutter test                                    # suites на мок-репозиториях, бекенд не нужен
flutter test test/vin_test.dart --plain-name 'обрезает до 17 знаков'
```

Тесты в `test/integration/` в обычный прогон **не входят**: они помечены тегом
`integration`, и `dart_test.yaml` их пропускает. Им нужен поднятый засиданный
бекенд:

```bash
flutter test --run-skipped -t integration
```

Без `--flavor` адрес API — локальный (dev), в релизной сборке — прод. С
`--flavor prod` интеграционный тест откажется работать: он правит данные.

Снимки экрана для проверки вёрстки кладите в `screenshots/`. Координаты тапов для
`adb shell input tap` — в пикселях устройства (1080×2400 на типовом эмуляторе), а
не в масштабе картинки, которую вы читаете обратно.

## Структура

```
lib/
  config/     ApiConfig — адрес бекенда, SupportConfig — контакты поддержки
  data/       репозитории (api_* и mock_*), ApiClient, AuthService
  models/     доменные модели и enum'ы, зеркала PHP-энамов
  state/      OrderStore, InspectionStore, ChatStore, NotificationStore — ChangeNotifier; SupportChatScope, NotificationScope
  push/       PushService, PushMessaging (обёртка над Firebase)
  payments/   PaymentFlow — оплата по payment.checkout, PaymentSdk (ЮKassa)
  screens/    экраны
  widgets/    переиспользуемые блоки макета
  theme/      палитры (тёмная и светлая), тема, ThemeController
design/       HTML-макеты — источник правды по дизайну, см. design/README.md
fonts/        Inter и JetBrains Mono, зашиты чтобы не зависеть от сети
```

Данные текут в одну сторону: **экран → стор → репозиторий → API**. У
`InspectionRepository`, `OrderRepository` и `VerificationRepository` по две
реализации — `api_*` (весь прод) и `mock_*` (только тесты).

В сеть приложение ходит только через `HttpTransport`
(`lib/data/http_transport.dart`): таймаут 30 с, у загрузок файлов — 3 мин;
таймаут экраны показывают как «Нет связи». Над ним `ApiClient` — базовый
адрес, bearer-токен из `AuthService`, разбор JSON, 401; загрузки фото, аудио,
VIN и вложений чата — `ApiClient.multipart`. Напрямую транспортом пользуются
только `AuthService` и гостевая витрина.

`AuthService` один на приложение: создаётся в `main()` и уходит и в `_RootGate`,
и в `SupportChatScope` (в `MaterialApp.builder`, выше `Navigator`).
`AuthService` хранит токен в `flutter_secure_storage` (Keystore на Android,
Keychain на iOS) и восстанавливает сессию при старте, так что вход переживает
перезапуск.

### Темы

Две палитры — `AppColors.dark` и `AppColors.light` в `lib/theme/app_colors.dart`,
значения из `design/first-launch-screen.html`. Палитра и типографика (`AppText`)
лежат в `ThemeData` как `ThemeExtension`, экраны читают их через
`context.colors.*` и `context.text.*`. Захардкоженных `Color(0x…)` в экранах нет:
что меняется между темами — токен палитры, включая цвета схемы кузова
(`SchematicColors`) и карты (`MapColors`). Видоискатель VIN всегда тёмный.

`ThemeController` хранит выбор в `flutter_secure_storage` (ключ `app_theme`),
по умолчанию тёмная. Переключатель (`ThemeSwitch`) — на стартовом экране и в
профиле. Смена темы перестраивает `MaterialApp`, стек маршрутов живёт дальше, но
`builder` у `MaterialPageRoute` вызывается заново, поэтому сторы и прочее
состояние создавайте **до** маршрута, а не внутри `builder`.

## Что стоит знать о домене

**Два вида заказа** (`OrderKind`):

- `selection` — подбор: марка, бюджет, города, требования. Исполнитель заводит
  несколько машин-кандидатов и осматривает их. Вместо нового выезда он может
  прикрепить свой готовый осмотр — «Из моих осмотров» в карточке подбора
  (`widgets/library_sheet.dart`): список `GET /orders/{id}/library`
  (`InspectionLibraryPage`, срок — поле `days`), подтверждение «Машина ещё
  продаётся?», затем `POST /orders/{id}/library/{inspection}`. Кнопка видна, только
  если список не пуст; что в него попадает, решает сервер. Такой кандидат приходит
  с `OrderCar.fromLibrary` и `inspectionCompletedAt` — карточка пишет «осмотрена
  N дней назад» обеим сторонам.

  Закрывает подбор заказчик — «Зафиксировать покупку» (`POST
  /orders/{id}/complete`, лист `widgets/purchase_sheet.dart`). Если он забыл,
  подборщик жмёт «Заказчик купил машину» (`Order.canReportPurchase` с сервера,
  `POST /orders/{id}/purchase-report`): заказ не закрывается, обе стороны видят
  `Order.purchaseReport`. Заказчику — «Да, купил» (тот же `/complete` с этой
  машиной, без листа) или «Нет, не покупал» (`…/purchase-report/decline`),
  исполнителю — «Ждём подтверждения заказчика». Сервер ещё напоминает заказчику
  через 7 и 14 дней (`purchase_reminder`). Сутки после закрытия заказчик может
  выбрать другую купленную машину — «Изменить покупку» по
  `Order.purchaseEditableUntil` (`PATCH /orders/{id}/purchase`).
- `inspection` — разовый осмотр найденной машины: город, адрес, дата и слот
  времени, ссылка на объявление, телефон продавца. Машина создаётся вместе с
  заказом и всегда ровно одна, итог — вердикт осмотра. Год обязателен, пробег —
  нет (`OrderCar.mileageKm`, `Car.mileageKm` и `Order.mileageTo` бывают null).

**Город и адрес осмотра.** Город — один, из справочника (`showSingleCityPickerSheet`,
по умолчанию — по геопозиции через `CityLocator`), уходит в `cities`. Адрес — улица
и дом без города (`AddressField`): подсказки DaData идут через бекенд
(`AddressRepository`), выбранная подсказка даёт точку `lat`/`lon`; свой текст тоже
принимается, тогда сервер ставит центр города. Без сети, без ключа DaData на
сервере или с исчерпанным лимитом подсказок просто нет. Улицу, дом и точную точку
сервер отдаёт только сторонам заказа; остальные видят город и «Химки · 8 км» в
ленте (точка огрублена до ~1 км, расстояние — от `CityLocator.position()`).

Статусы: подбор `awaiting_executor → sourcing → inspecting → completed`, осмотр
`awaiting_executor → scheduled → inspecting → report_ready → payment_sent →
completed`, из `report_ready`/`payment_sent` — `disputed`; `cancelled` у подбора
— до завершения, у осмотра — до `report_ready`. Сам заказчик отменяет заказ
кнопкой «Отменить заказ» (`POST /orders/{id}/cancel`); видна она по
`Order.canCancel` с сервера — правило (сейчас «пока исполнитель не выбран»)
клиент не повторяет.

**Срок осмотра — весь день осмотра** до 00:00 по времени города (считает
сервер). На «сегодня» после 21:00 форма не предлагает чип «Сегодня»
(`InspectionWhenPicker`, по часам устройства; сервер проверит по городу).
Исполнитель сорвал день или день прошёл без выбранного исполнителя → статус
`awaiting_decision` («ждёт решения», причина — `Order.decisionReason`): заказчик
видит плашку «Нужно решение» и выбирает «Разместить заново» (`repost_sheet.dart`:
новая дата, время, цена → `POST /orders/{id}/repost`) или «Отменить заказ».
Число срывов исполнителя (`UserSummary.missedOrdersCount`) сервер отдаёт только
заказчику в откликах — «12 заказов · 1 срыв»; свои срывы исполнитель видит в
профиле (плашка «сорвано»).

**Разовый осмотр оплачивается напрямую исполнителю** (схема — в бекенде,
`docs/plan-inspection-payment-flow.md`):

- после выбора у исполнителя 24 часа (`executor_deadline_at`, таймер
  `DeadlineCountdown`) — осмотреть или «Отказаться» (`POST /orders/{id}/decline`);
  отказ или просрочка возвращают заказ к остальным откликам, отклик становится
  `declined`/`expired`;
- `report_ready`: заказчик видит сумму, реквизиты (`payout`) и сводку
  (`report_summary`, только количества), но не вердикт и не отчёт → «Я оплатил»
  (`/payment/sent`) → исполнитель «Оплату получил» (`/payment/confirm`) →
  `completed`, отчёт открыт. С `payment_sent` отчёт править нельзя (403);
- спор — `/dispute` с причиной, разбирает поддержка (пока вручную на бекенде);
- реквизиты (карта или телефон+банк СБП) спрашивает форма отклика при первом
  отклике на осмотр (`RespondSheet`, `requiresPayout`), дальше — профиль
  («Реквизиты для выплат», `PATCH /me/payout`).

**Выход из подбора.** Исполнитель отказывается кнопкой «Отказаться от
подбора» (`POST /orders/{id}/decline`, только по `can_release`): заказ уходит в
ленту, готовые отчёты остаются у заказчика. Подбор без новостей сервер
предупреждает (`selection_close_soon`, в карточке — «Закроется …» по
`closes_at`) и закрывает сам (`closed`, `selection_closed`, причина —
`close_reason`); при удалении аккаунта заказчика — тоже.

**Активные устройства** (профиль → «Активные устройства»,
`SessionsScreen`): `GET /me/sessions`, выход на другом устройстве
(`DELETE /me/sessions/{id}`) и «Выйти на всех других». Имя телефона уходит при
входе (`device_name`, `device_info_plus`); сессия без входа 90 дней истекает
на сервере сама.

**Оплата через платформу** (схема — в бекенде, `docs/plan-placement-payment.md`):
пакет отчётов по VIN и комиссия за размещение разового осмотра (на сервере
`INSPECTION_PLACEMENT_FEE`; 0 — бесплатно). Провайдера приложение не знает:
платёж приходит с `checkout`, и `PaymentFlow` действует по `method`:

- `sdk` — форма SDK ЮKassa (`yookassa_payments_flutter`, `YooKassaSdk`):
  ключ SDK, магазин и способы — с сервера, в сборке ничего не вшито. Токен
  формы уходит на `POST /payments/{id}/token`, платёж создаёт сервер; если он
  вернул `confirmation_url` — подтверждение тем же SDK (3-D Secure, SberPay, СБП);
- `redirect` — страница оплаты во встроенном браузере (Custom Tabs), затем
  возврат в приложение (песочница `fake` на dev);
- `paid` — уже оплачено (заглушка `instant`); незнакомый способ — «обновите
  приложение».

Итог — всегда с сервера (`GET /payments/{id}`), колбэку SDK не верим. Убил
Android процесс посреди оплаты — итог не теряется: сервер узнаёт его вебхуком,
экраны показывают новый статус при следующем чтении. Комиссия за размещение:
цена — из `GET /config`, заказ ждёт оплаты в `awaitingPlacement` («Оплатить
размещение» в карточке, `POST /orders/{id}/placement-payment`), деньги
удерживаются до отчёта и возвращаются при отмене. Дата осмотра — не дальше
`maxInspectionDaysAhead` (10) дней.

`asking_price` — цена, которую просит продавец; `price` — согласованный гонорар
исполнителя из принятого отклика. Путать их нельзя, на `price` завязаны карточка
и лента.

**Два инварианта, которые легко сломать:**

1. **Статус детали вычисляется, а не хранится.** Единственная правда —
   `InspectionPanel.condition` (A/B/C/D), `PanelStatus` выводится из неё. Стор
   **никогда** не пересчитывает статус локально: мутация возвращает с сервера
   целиком обновлённую деталь, стор подменяет её в списке.
2. **Детали адресуются стабильным кодом, а не id.** В API это
   `/inspections/{inspection}/panels/{panel}`, где `{panel}` — `front_bumper`,
   `hood`, … Этот код и лежит в `InspectionPanel.id`.

Enum'ы в Dart — ручные зеркала PHP-энамов на бекенде. Меняете один — меняйте оба.

**Отзывы и рейтинг.** После завершения заказа заказчик ставит исполнителю 1–5
звёзд (`Review`, один отзыв на заказ). При оценке 1–2 текст обязателен (от 10
символов), правка — 24 часа, срок берётся из `editable_until` с сервера.
`UserSummary` несёт сводку исполнителя: `rating` (`null` — «Новый
исполнитель»), `reviewsCount`, `completedOrdersCount`; её рисует
`ExecutorStats` (`.resp-stats` из `order-types.html`). Свою сводку
исполнитель видит в профиле: `/me` отдаёт те же поля в `CurrentUser`, профиль
перечитывает их при каждом открытии (`AuthService.refreshUser()`), тап по
строке рейтинга открывает «Отзывы обо мне». Как и статус детали,
рейтинг и `Order.canReview` **локально не пересчитываются**: отправка отзыва
возвращает заказ целиком, экран и стор подменяют его. Ключей `review` и
`can_review` нет в `/orders/assigned` и `/orders/available` — там они читаются
как «нет».

## Чат с поддержкой

Пункт «Написать в чат» в шторке поддержки (`support_sheet.dart`) у вошедшего
открывает `SupportChatScreen`, у гостя ведёт в Telegram, как и раньше: бекенд
пускает в чат только с токеном. Шторку зовут экраны без `AuthService` (вопрос о
намерении, FAQ, оплата), поэтому сессию она берёт из `SupportChatScope.maybeOf()`.
Без scope (виджет-тесты) шторка ведёт себя как у гостя.

- Эндпоинты:
  - `POST /support/conversation` — свой чат, заводится при первом вызове;
  - `GET /conversations/{id}/messages` с `after_id` / `before_id`;
  - `POST …/messages` — multipart `body` + `photos[]`, до 5 фото и 4000 символов;
  - `POST …/read`.
- **Realtime нет.** `ChatStore` опрашивает `after_id` раз в 4 с, пока экран
  открыт, и ставит опрос на паузу, когда приложение уходит в фон. Сообщения
  сливаются по id, поэтому ответ на отправку и опрос не дают дублей.
- **Фото чата приватные**: `Image.network` только с `ChatRepository.imageHeaders`
  (Bearer). Сервер строит `url` от своего `APP_URL`, поэтому клиент берёт из него
  только путь и подставляет `ApiConfig.origin` (`chatAttachmentUrl()`).
- В `sender.role` приходит `me`, `system` или роль из `ChatRole`; у поддержки имя
  всегда «Поддержка».
- Ответы операторов приходят из Telegram (мост на бекенде). Локально ответ можно
  сымитировать через tinker: `Conversation::find(id)->post($staff, 'текст')`, где
  `$staff` — пользователь после `setStaff(true, …)`.

## Уведомления

Лента событий заказа: новый отклик, выбор исполнителя, отчёт готов, оплата,
спор и т. д. (полный список типов — README бекенда, «Уведомления»). Чат в ленту
не попадает — у него свой бейдж.

- Эндпоинты: `GET /notifications` (по 20, курсор `meta.next_cursor`,
  `meta.unread_count`), `GET /notifications/unread-count`,
  `POST /notifications/{id}/read`, `POST /notifications/read-all`.
- **Колокольчик** (`NotificationBell`) — в шапке «Моих заказов», «Взятых
  заказов» и «Заказов рядом», слева от профиля. Бейдж — `NotificationUnread`:
  тот же опрос, что у поддержки (`PolledUnread`, раз в минуту и при возврате в
  приложение). Колокольчик виден, только когда есть `NotificationScope`
  (`MaterialApp.builder`), поэтому в виджет-тестах отдельных экранов его нет.
- **Прочитано — по тапу** или кнопкой «Прочитать все». Прочитанность и число
  только с сервера: `NotificationStore` подменяет уведомление ответом и
  передаёт число в бейдж (`PolledUnread.report`).
- **Тап открывает заказ** через `openOrderScreen()` (`order_routes.dart`, тот же
  выбор экрана, что у «Моих заказов»). Роль — из `viewer_role`, у старых
  уведомлений без него — из типа (`NotificationType.defaultViewerIsCustomer`).
  `response_rejected` заказ не открывает: отклонённому исполнителю сервер его
  уже не покажет.
- `NotificationType` — зеркало `App\Enums\NotificationType`; неизвестный
  этой сборке тип читается как `unknown` и показывается без особой иконки.

### Пуши

Firebase Cloud Messaging, проект `bitnebit-c70ca`; у dev и prod свои
приложения (`com.bitnebit.dev` / `com.bitnebit.app`). Конфиг сгенерирован
`flutterfire configure` для каждого flavor-а: `lib/firebase_options_{dev,prod}.dart`,
`android/app/src/{dev,prod}/google-services.json`, `firebase.json` — секретов
в них нет. Повторно: `flutterfire configure --project=bitnebit-c70ca
--platforms=android --android-package-name=com.bitnebit.dev
--out=lib/firebase_options_dev.dart
--android-out=android/app/src/dev/google-services.json` (и так же для prod).

- **Два сервиса, выбор по телефону** — `AutoPushMessaging` на каждом запуске:
  RuStore (`RuStorePushMessaging`, пакет `flutter_rustore_push`), если у сборки
  есть проект RuStore, а RuStore установлен и доступен; иначе Firebase
  (`FirebasePushMessaging`). Токен уходит на сервер с `provider`
  (`PushProvider` — зеркало `App\Push\PushProvider`), сервер шлёт через тот же
  сервис. Сменился сервис — новый токен сессии заменяет прежний на сервере,
  дублей нет. iOS — только Firebase.
- **RuStore** — ID проекта (RuStore Консоль → Push-уведомления → Проекты) в
  `BuildConfig.RUSTORE_PUSH_PROJECT_ID` у flavor-а (`android/app/build.gradle.kts`).
  Проект привязан к пакету и SHA-256 ключа подписи, поэтому он есть только у
  prod (релизный ключ — `android/key.properties`); у dev пусто — там только
  Firebase. SDK инициализирует `BitNeBitApplication` (не мета-строка
  `project_id`: пустая сломала бы dev), Dart спрашивает о проекте через канал
  `bitnebit/push` в `MainActivity`. Версия `ru.rustore.sdk:pushclient` в
  `build.gradle.kts` — та же, что у плагина. Пушам RuStore нужен установленный
  RuStore с входом в аккаунт и разрешением на работу в фоне.
- **`PushService`** (`lib/push/`) — один на приложение, создаётся в `main()`.
  Сервис пушей — только через `PushMessaging` (в тестах фейк). Сбой
  инициализации пуши выключает, приложение живёт.
- **Регистрация** — на каждую новую сессию: системный запрос разрешения (один
  раз за запуск, сразу после входа) и `POST /me/devices`; обновление токена
  — повторно. Выход отдельно не шлём: сервер стирает устройство вместе с
  токеном сессии.
- **Открытое приложение** — FCM пуш не показывает: `PushService` обновляет
  бейдж и показывает его через `flutter_local_notifications`
  (`LocalNotifications`, каналы `orders`, `new_orders`, `chat` — их же заводит
  и для RuStore). Ответ поддержки при открытом чате (`SupportUnread.chatOpen`)
  не показывается. SDK RuStore показывает пуш сам и в открытом приложении —
  `RuStorePushMessaging.show()` пустой, иначе задвоится; ответ поддержки при
  открытом чате RuStore всё же покажет.
- **Тап** → `PushTarget` (`lib/models/push_target.dart`) → `_RootGate._openPush`:
  заказ — `openOrderScreen()` поверх текущего экрана и «прочитано» по
  `notification_id`; `response_rejected` — лента; поддержка — `pushSupportChat()`.
  Тап, которым приложение запустили, корень забирает `takePendingTap()` после
  `restore()`. Гостю тап ничего не открывает.
- Значок в строке состояния — `res/drawable-*/ic_notification.png`, белый
  силуэт логотипа (`design/icons/icons/source/car-transparent.png` по
  альфа-каналу, 24dp с полями по 2dp). Подключён в манифесте
  (`default_notification_icon` у Firebase и RuStore) и в
  `LocalNotifications.init()`.
- Классический FCM-токен (`getToken`, помечен deprecated в firebase_messaging
  17 в пользу FID): бекенд шлёт по `message.token`.

## Навигация

Роутера нет, всё через `Navigator.push`. Корень — `IntentScreen` с вопросом «Что
вас сюда привело?» (вошедшему — «Куда перейти?», без строк про регистрацию).
Выбранный на нём раздел — «дом» — кладётся поверх, профиль и разделы из профиля
— ещё выше, поэтому «назад» ведёт вниз по цепочке и с вопроса закрывает
приложение:

```
вопрос → дом («Мои заказы» | «Заказы рядом») → профиль → другой раздел
```

Правила стека — только в `SectionNav` (`lib/navigation/section_nav.dart`):
профиль, уже лежащий в стеке, не кладётся второй раз — к нему возвращаются;
раздел из профиля, совпадающий с домом, — возврат к дому. Копий нет, глубина не
больше четырёх. Раздел, открытый из профиля, делит стор профиля.

Выбор на вопросе запоминает `LastSection` (защищённое хранилище, стирается при
выходе): вошедшему при запуске дом открывается сразу, без анимации, и вопрос
виден только по «назад». Раздел, открытый из профиля, дом не меняет.

```
IntentScreen (корень)
  ├─(«Ищу автомобиль»)──────> [PhoneLoginScreen ─>] MyOrdersScreen ─> OrderDetailScreen ─> InspectionOverviewScreen ─> PanelDetailScreen
  │                                                   │                                      └─> StartInspectionScreen
  │                                                   │                                      └─> InspectionSummaryScreen (когда все детали оценены)
  │                                                   ├─> InspectionOrderDetailScreen (разовый осмотр)
  │                                                   │     (обе детали заказа) ─> showReviewSheet | ExecutorReviewsScreen (тап по рейтингу)
  │                                                   ├─> showOrderKindSheet ─> NewOrderScreen | NewInspectionScreen
  │                                                   ├─(колокольчик)─> NotificationsScreen ─> экран заказа по тапу
  │                                                   └─(иконка профиля)─> ProfileScreen ─> VerificationScreen ─> QuizScreen
  ├─(«Беру заказы на подбор»)> [PhoneLoginScreen ─>] NearbyOrdersScreen
  │   (AvailableOrdersScreen — карта, вход спрятан: карта декоративная)
  └─(«Просто посмотрю»)─────> PublicFeedScreen ─> PublicOrderScreen
                                └─(«Разместить заказ»)─> showOrderKindSheet ─> [вход] ─> форма заказа ─> MyOrdersScreen
```

Витрина открыта всем — и гостю, и вошедшему. «Мои заказы» и «Заказы рядом»
требуют токен, поэтому гостя туда ведут через `PhoneLoginScreen`. Профиль
открывается иконкой в шапке «Моих заказов» и «Заказов рядом» — это
единственный путь к взятым заказам.

Номер телефона меняется в профиле строкой «Номер телефона» —
`ChangePhoneSheet`: `POST /me/phone/request` → код на новый номер →
`POST /me/phone/verify`, ответ подменяет `auth.user`. Поле номера, маска и
отсчёт общие с экраном входа (`widgets/phone_input.dart`). Сервер после смены
отзывает остальные токены — другие устройства получат 401 и уйдут на вход.

## Макеты

`design/` — статичные HTML-макеты, **источник правды по дизайну**. Экраны, цвета
(`lib/theme/app_colors.dart`) и шрифты перенесены оттуда; схема кузова в
`lib/widgets/car_schematic.dart` — это пути из макета один в один. Прежде чем
придумывать вёрстку, откройте макет: `design/README.md` объясняет, какой файл за
что отвечает и что из него ещё не реализовано.

## Известные ограничения

Что из этого и в каком порядке доделывать — в `docs/backlog.md` репозитория
бекенда (общий список бекенда и приложения).

- **Оплата формой SDK ЮKassa не проверена вживую.** Нужны ключ мобильного
  SDK и включённые менеджером ЮKassa платежи токеном; без них проверен только
  путь страницы оплаты (`PAYMENT_GATEWAY=fake` на dev) и SDK — подделкой в
  тестах. Для 3-D Secure карт некоторых банков SDK требует корневой
  сертификат Минцифры (Russian Trusted Root CA) в network security config —
  ещё не добавлен. Схема возврата из банка — `ym_app_scheme` у флейворов
  (`bitnebit`, `bitnebitdev`); возврат со страницы оплаты по
  `PAYMENT_RETURN_URL` не зарегистрирован — вкладку закрывают, и приложение
  перечитывает платёж.
- **iOS-сборка не проверена.** Ключи камеры, галереи и микрофона в `Info.plist`,
  iOS 15.5 и `ios/Podfile` настроены, но ни разу не собирались: Mac для этого
  не было. Первая сборка — `flutter build ios --flavor dev` на Mac.
- **Голосовая заметка не перекодируется и не нормализуется.** Пишется на
  устройстве (`record`, AAC в `.m4a`, моно 64 кбит/с, до 5 минут) и уходит как
  есть; длительность считает клиент по секундомеру. Форма волны в плеере
  (`widgets/audio_note.dart`) — декоративная, от кода детали: сервер её не отдаёт.
- **Протухшая сессия разбирается целиком на клиенте.** Любой 401 на запрос с
  токеном стирает сессию (`AuthService.expireSession`), корень показывает «Сессия
  истекла» и открывает вход, а после входа возвращает в тот же раздел. При
  запуске `restore()` стирает токен тоже только на 401: без сети, по таймауту
  (10 с) и на 5xx приложение стартует вошедшим без профиля, разделы показывают
  «Нет связи» и «Повторить», а профиль догружает `ApiClient` перед первым
  удачным запросом (`AuthService.ensureUser`). `retry_after` из `ApiException` читает только
  `phone_login_screen.dart`.
- **Чат с поддержкой.** Непрочитанные (`unread_count` из
  `GET /conversations`) показывает бейдж на «Поддержке», в шторке, в профиле и
  на иконке профиля в разделах. Счётчик (`SupportUnread`) опрашивает сервер раз
  в минуту и при возврате в приложение; в фоне об ответе сообщает пуш (только
  Android). Гостю чат недоступен — только Telegram.
- **Верификацию исполнителя пройти нельзя.** Гейт на `NearbyOrdersScreen` гасит
  кнопки «Откликнуться»; сервер проверяет её при отклике, только если на нём
  включён `EXECUTOR_VERIFICATION_REQUIRED` (по умолчанию выключен). Шаги
  «Личность» и «Опыт» уходят на проверку, но модерации на бекенде нет.
- **Карты нет.** Экран «Показать на карте» (`AvailableOrdersScreen`) собран, но
  вход в него из ленты спрятан: карта там декоративная (`city_map.dart`), а не
  настоящая. Вернуть — п. 30 бэклога бекенда (`docs/backlog.md`).
- **Фото осмотра — по подписанным ссылкам.** `photos[].url` — относительный
  адрес с подписью, живёт до часа; токен не нужен, `Image.network(url)` хватает.
  Ссылку из старого ответа после истечения не переиспользовать — перезапросить
  осмотр.
- **Пуши — только Android.** На iOS Firebase не настроен (нет Mac и
  APNs-ключа): `PushService` ловит ошибку инициализации и выключается, остаётся
  опрос бейджей.
- **Об отзыве напоминают только список и карточка заказа.** Пуша об этом нет: осмотр
  завершает исполнитель, и заказчик узнаёт об этом по строке «Оценить
  исполнителя» в «Завершённых».
- **Контакты поддержки — заглушки.** В шторке (`lib/widgets/support_sheet.dart`)
  вошедшему «Написать в чат» открывает `SupportChatScreen`, гостю — Telegram.
  Телефон и ник в `lib/config/support_config.dart` — заглушки из макета.
