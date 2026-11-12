.PHONY: run-dev run-prod build-apk-dev build-apk-prod build-appbundle-prod build-ios-dev build-ios-prod analyze test

FLAVOR_DEV=dev
FLAVOR_PROD=prod

# Номер сборки у build-* (versionCode / CFBundleVersion) — число коммитов:
# растёт с каждым коммитом, второй бандл с тем же номером Google Play не
# примет. Сервер сравнивает его с min_build (принудительное обновление). CI
# задаёт свой: make build-appbundle-prod BUILD_NUMBER=… У flutter run флага
# нет — там номер 1 из pubspec.yaml (prodRelease с ним Gradle не соберёт).
BUILD_NUMBER ?= $(shell git rev-list --count HEAD)
BUILD=--build-number=$(BUILD_NUMBER)

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
	flutter build apk --flavor $(FLAVOR_DEV) $(BUILD)

## Prod APK (com.bitnebit.app) — для установки на телефон
build-apk-prod:
	flutter build apk --flavor $(FLAVOR_PROD) $(BUILD)

## Prod AAB для Google Play
build-appbundle-prod:
	flutter build appbundle --flavor $(FLAVOR_PROD) $(BUILD)

# --- iOS ---

## Требуют macOS + Xcode + настроенный signing
build-ios-dev:
	flutter build ios --flavor $(FLAVOR_DEV) $(BUILD)

build-ios-prod:
	flutter build ios --flavor $(FLAVOR_PROD) $(BUILD)

# --- Проверки ---

analyze:
	flutter analyze

test:
	flutter test
