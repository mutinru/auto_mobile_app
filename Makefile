.PHONY: run-dev run-prod build-apk-dev build-apk-prod build-appbundle-prod build-ios-dev build-ios-prod analyze test

FLAVOR_DEV=dev
FLAVOR_PROD=prod

# --- Запуск на эмуляторе/симуляторе ---

## Разработка: локальный бекенд (http://10.0.2.2:8083/api на Android)
run-dev:
	flutter run --flavor $(FLAVOR_DEV)

## Прод-сборка для проверки: https://bitnebit.com/api
run-prod:
	flutter run --flavor $(FLAVOR_PROD)

# --- Android ---

## Dev APK (com.bitnebit.dev)
build-apk-dev:
	flutter build apk --flavor $(FLAVOR_DEV)

## Prod APK (com.bitnebit.app) — для установки на телефон
build-apk-prod:
	flutter build apk --flavor $(FLAVOR_PROD)

## Prod AAB для Google Play
build-appbundle-prod:
	flutter build appbundle --flavor $(FLAVOR_PROD)

# --- iOS ---

## Требуют macOS + Xcode + настроенный signing
build-ios-dev:
	flutter build ios --flavor $(FLAVOR_DEV)

build-ios-prod:
	flutter build ios --flavor $(FLAVOR_PROD)

# --- Проверки ---

analyze:
	flutter analyze

test:
	flutter test
