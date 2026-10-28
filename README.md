# auto_podbor_mobile

Мобильное приложение «БитНеБит» — маркетплейс подбора автомобиля. Заказчик
размещает заказ, исполнитель откликается, находит кандидатов и проводит осмотр
кузова по 13 деталям.

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

Для запуска dev-сборки на **реальном телефоне** в той же сети с компьютером
подставьте в `lib/config/api_config.dart` LAN-адрес машины с бекендом
(`http://192.168.1.5:8083/api`) вместо `10.0.2.2`/`localhost`.

### Демо-аккаунты

Вход — по телефону и коду из SMS. Отправка SMS не подключена: в окружении `local`
бекенд возвращает код прямо в ответе (`dev_code`).

| Кто | Телефон | Почта (для `POST /login`) |
| --- | --- | --- |
| Максим, исполнитель | `+79000000001` | `inspector@autopodbor.local` |
| Андрей, заказчик | `+79000000002` | `customer@autopodbor.local` |
| Ещё пять исполнителей | `+79000000003…7` | — |

Пароль у всех — `password`.

## Проверки

```bash
flutter analyze
flutter test                                    # 8 suites на мок-репозиториях, бекенд не нужен
flutter test test/vin_test.dart --plain-name 'обрезает до 17 знаков'
```

`test/integration/api_repository_test.dart` в обычный прогон **не входит**: ему
нужен живой засиданный бекенд, а ещё он завязан на конкретный id осмотра.
Запускайте его отдельно и осознанно.

Снимки экрана для проверки вёрстки кладите в `screenshots/`. Координаты тапов для
`adb shell input tap` — в пикселях устройства (1080×2400 на типовом эмуляторе), а
не в масштабе картинки, которую вы читаете обратно.

## Структура

```
lib/
  config/     ApiConfig — адрес бекенда, SupportConfig — контакты поддержки
  data/       репозитории (api_* и mock_*), ApiClient, AuthService
  models/     доменные модели и enum'ы, зеркала PHP-энамов
  state/      OrderStore, InspectionStore — ChangeNotifier
  screens/    экраны
  widgets/    переиспользуемые блоки макета
  theme/      палитры (тёмная и светлая), тема, ThemeController
design/       HTML-макеты — источник правды по дизайну, см. design/README.md
fonts/        Inter и JetBrains Mono, зашиты чтобы не зависеть от сети
```

Данные текут в одну сторону: **экран → стор → репозиторий → API**. У
`InspectionRepository`, `OrderRepository` и `VerificationRepository` по две
реализации — `api_*` (весь прод) и `mock_*` (только тесты).

`ApiClient` — тонкая обёртка над `http`, подставляет bearer-токен из
`AuthService`. Загрузка фото multipart'ом идёт мимо него и читает
`ApiClient.token` напрямую.

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
  несколько машин-кандидатов и осматривает их.
- `inspection` — разовый осмотр найденной машины: адрес, дата и слот времени,
  ссылка на объявление, телефон продавца. Машина создаётся вместе с заказом и
  всегда ровно одна, итог — вердикт осмотра.

Статусы: подбор `awaiting_executor → sourcing → inspecting → completed`, осмотр
`awaiting_executor → scheduled → inspecting → completed`; `cancelled` возможен
до завершения.

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

## Навигация

Роутера нет, всё через `Navigator.push`. Корень — `IntentScreen` с вопросом «Что
вас сюда привело?»; он показывается **при каждом запуске**, и гостю, и вошедшему,
выбор нигде не сохраняется. Всё остальное пушится поверх, поэтому «назад»
возвращает к вопросу, а не закрывает приложение.

```
IntentScreen (корень)
  ├─(«Ищу автомобиль»)──────> [PhoneLoginScreen ─>] MyOrdersScreen ─> OrderDetailScreen ─> InspectionOverviewScreen ─> PanelDetailScreen
  │                                                   │                                      └─> StartInspectionScreen
  │                                                   │                                      └─> InspectionSummaryScreen (когда все детали оценены)
  │                                                   ├─> InspectionOrderDetailScreen (разовый осмотр)
  │                                                   ├─> showOrderKindSheet ─> NewOrderScreen | NewInspectionScreen
  │                                                   └─(иконка профиля)─> ProfileScreen ─> VerificationScreen ─> QuizScreen
  ├─(«Беру заказы на подбор»)> [PhoneLoginScreen ─>] NearbyOrdersScreen ─> AvailableOrdersScreen (карта)
  └─(«Просто посмотрю»)─────> PublicFeedScreen ─> PublicOrderScreen
                                └─(«Разместить заказ»)─> showOrderKindSheet ─> [вход] ─> форма заказа ─> MyOrdersScreen
```

Витрина открыта всем — и гостю, и вошедшему. «Мои заказы» и «Заказы рядом»
требуют токен, поэтому гостя туда ведут через `PhoneLoginScreen`. Профиль
открывается только иконкой в шапке «Моих заказов» — это единственный путь к
взятым заказам.

## Макеты

`design/` — статичные HTML-макеты, **источник правды по дизайну**. Экраны, цвета
(`lib/theme/app_colors.dart`) и шрифты перенесены оттуда; схема кузова в
`lib/widgets/car_schematic.dart` — это пути из макета один в один. Прежде чем
придумывать вёрстку, откройте макет: `design/README.md` объясняет, какой файл за
что отвечает и что из него ещё не реализовано.

## Известные ограничения

- **iOS не запускается как есть**: в `ios/Runner/Info.plist` нет ни одного ключа
  `NS*UsageDescription`, поэтому `image_picker` (фото и скан VIN) роняет
  приложение при открытии галереи. Android объявляет только `CAMERA` и
  `INTERNET`.
- **Аудиозаметок нет.** В `pubspec.yaml` нет пакета записи звука, в манифесте нет
  `RECORD_AUDIO` — ручка `POST /audio-note` из приложения не вызывается.
- **Сторы виснут на ошибке.** Почти везде `_loading = true` снимается только при
  успехе, без `try/finally`: любой 401, 500 или офлайн оставляет экран на вечном
  спиннере. Исключение — `OrderStore.loadAvailableOrders()` и `loadMyOrders()`, у
  них есть `try/finally` и поля ошибки.
- **`ApiException` разбирается по типу ровно в одном экране** (`phone_login_screen.dart`),
  в остальных превращается в строку для SnackBar — 401, 403 и 500 неразличимы, и
  нет пути «токен протух → перелогиниться».
- **`ApiInspectionRepository` по умолчанию берёт `inspectionId = 1`** — вызов,
  забывший аргумент, молча работает с первым попавшимся осмотром в базе.
- **Верификация исполнителя декоративна.** Гейт на `NearbyOrdersScreen` гасит
  кнопки «Откликнуться», но он чисто клиентский: сам эндпоинт отклика
  верификацию не проверяет, а на экране карты отклик доступен всегда.
- **Осмотры на бекенде не защищены проверкой владельца** — любой авторизованный
  пользователь может прочитать и изменить чужой осмотр по id. Дыра известная, не
  закладывайтесь на то, что сервер прикроет.
- **Поддержка — без чата.** Шторка поддержки (`lib/widgets/support_sheet.dart`)
  ведёт в Telegram и на звонок; «Написать в чат» пока открывает тот же Telegram —
  на бекенде чата нет. Телефон и ник в `lib/config/support_config.dart` —
  заглушки из макета.
