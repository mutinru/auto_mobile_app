// Проверяет ApiInspectionRepository (тот же код, что использует
// приложение) против живого бекенда. В обычный `flutter test` не входит:
// тег integration пропускается (dart_test.yaml). Запускать отдельно:
//
//   docker compose up -d
//   docker compose exec app php artisan migrate:fresh --seed
//   flutter test --run-skipped -t integration
//
// Тест правит осмотр, поэтому с flavor prod отказывается работать: боевые
// данные он трогать не должен. Без флага ApiConfig и так берёт dev.
//
// Вход — по телефону, как в приложении: локальный бекенд отдаёт код прямо
// в ответе (dev_code, нужны APP_ENV=local и SMS_EXPOSE_CODE=true). Каждый
// прогон тратит код: между прогонами — пауза SMS_RESEND_COOLDOWN (120 с), а
// суточный лимит на номер в dev снимает SMS_DAILY_PER_PHONE=0.
//
// Осмотр не угадывается по номеру, а находится так же, как в приложении:
// взятые заказы исполнителя → первый кандидат подбора с идущим осмотром.
// Содержимое сида (марка, число пунктов и дефектов) тест не зашивает —
// сверяет ответы API между собой.
// Голосовую заметку и фото тест кладёт на деталь и удаляет, оценку и дефект
// возвращает — повторный прогон без пересидирования тоже зелёный.
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:auto_podbor_mobile/config/api_config.dart';
import 'package:auto_podbor_mobile/data/api_client.dart';
import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/api_inspection_repository.dart';
import 'package:auto_podbor_mobile/data/api_order_repository.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/models/inspection_panel.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/panel_condition.dart';
import 'package:auto_podbor_mobile/models/panel_status.dart';

void main() {
  test('login, fetch and mutate an inspection through the real API', () async {
    if (!ApiConfig.isDev) {
      fail(
        'Тест правит данные — только против локального бекенда: '
        'запускайте без --flavor prod (сейчас ${ApiConfig.baseUrl})',
      );
    }

    // в тесте нет платформенного хранилища — токен держим в памяти
    FlutterSecureStorage.setMockInitialValues({});
    final auth = AuthService();
    await _signIn(auth, _executorPhone);
    expect(auth.isAuthenticated, isTrue);
    final client = ApiClient(auth);

    // RichDemoSeeder: у Максима есть подборы «на осмотре» с идущим осмотром
    // кандидата — его исполнитель ещё может править. Берём первого такого.
    // Отсутствие исхода не годится: отправленный отчёт без исхода заморожен
    final assigned = await ApiOrderRepository(client).fetchAssignedOrders();
    final candidate = assigned
        .where((o) => !o.isInspection && o.status == OrderStatus.inspecting)
        .expand((o) => o.cars)
        .where(
          (c) => c.inspectionId != null && c.inspectionStatus == 'in_progress',
        )
        .firstOrNull;
    if (candidate == null) {
      fail(
        'Нет подбора с идущим осмотром у Максима — засидируйте базу: '
        'docker compose exec app php artisan migrate:fresh --seed',
      );
    }

    // библиотека осмотров — только чтение: разбор ответа и правило «машины
    // из этого подбора не предлагаются» (содержимое сида не зашиваем)
    final selection = assigned.firstWhere(
      (o) => !o.isInspection && o.status == OrderStatus.inspecting,
    );
    final library = await ApiOrderRepository(
      client,
    ).fetchInspectionLibrary(selection.id);
    expect(library.days, greaterThan(0));
    final inOrder = selection.cars.map((c) => c.id).toSet();
    for (final item in library.items) {
      expect(inOrder.contains(item.car.id), isFalse);
      expect(item.completedAt, isNotNull);
      expect(item.verdict, isNotNull);
    }

    final repo = ApiInspectionRepository(
      client,
      inspectionId: candidate.inspectionId!,
    );

    // осмотр — того самого кандидата, а пункты адресуются уникальным кодом
    final snapshot = await repo.fetchInspection();
    expect(snapshot.car.brand, candidate.brand);
    expect(snapshot.car.model, candidate.model);
    expect(snapshot.panels, isNotEmpty);
    expect(
      snapshot.panels.map((p) => p.id).toSet(),
      hasLength(snapshot.panels.length),
    );
    // точное число зависит от того, что правили в dev-базе после сида
    int assessed(Iterable<InspectionPanel> panels) =>
        panels.where((p) => p.status != PanelStatus.none).length;
    final assessedBefore = assessed(snapshot.panels);
    expect(assessedBefore, greaterThan(0));

    final catalog = await repo.fetchDefectCatalog();
    expect(catalog, isNotEmpty);

    // правим уже оценённую деталь и возвращаем её оценку — число оценённых
    // не меняется от прогона к прогону
    final panel = snapshot.panels.firstWhere((p) => p.condition != null);
    final original = panel.condition!;
    final target = original == PanelCondition.needsRepair
        ? PanelCondition.good
        : PanelCondition.needsRepair;

    try {
      final updated = await repo.updateCondition(panel.id, target);
      expect(updated.condition, target);
      expect(updated.status, target.impliedStatus);

      // дефект, которого на детали нет, — включаем и сразу выключаем
      final defect = catalog.firstWhere(
        (d) => !panel.defects.contains(d.label),
      );
      final withDefect = await repo.setDefect(panel.id, defect.id, on: true);
      expect(withDefect.defects, contains(defect.label));
      // повтор (ответ потерялся) — дефект остаётся, а не снимается
      final again = await repo.setDefect(panel.id, defect.id, on: true);
      expect(again.defects.where((d) => d == defect.label), hasLength(1));

      final withoutDefect = await repo.setDefect(
        panel.id,
        defect.id,
        on: false,
      );
      expect(withoutDefect.defects, isNot(contains(defect.label)));
    } finally {
      await repo.updateCondition(panel.id, original);
    }

    // осмотр вернулся к исходному виду — следующий прогон увидит то же самое
    final after = await repo.fetchInspection();
    expect(assessed(after.panels), assessedBefore);
    final restored = after.panels.firstWhere((p) => p.id == panel.id);
    expect(restored.condition, original);
    expect(restored.defects, panel.defects);

    // голосовая заметка на детали без неё: загрузить, послушать без токена
    // (ссылка подписанная), удалить. m4a с ftyp isom — как пишет Android.
    final silent = after.panels.firstWhere((p) => p.audioNoteSeconds == null);
    final file =
        File(
          '${Directory.systemTemp.createTempSync('audio_note').path}/note.m4a',
        )..writeAsBytesSync([
          0,
          0,
          0,
          24,
          ...'ftypisom'.codeUnits,
          0,
          0,
          0,
          0,
          ...'isommp42'.codeUnits,
          0,
          0,
          0,
          16,
          ...'mdat'.codeUnits,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
        ]);
    try {
      final withNote = await repo.uploadAudioNote(silent.id, file.path, 3);
      expect(withNote.audioNoteSeconds, 3);
      final audio = await http.get(Uri.parse(withNote.audioNoteUrl!));
      expect(audio.statusCode, 200);

      final withoutNote = await repo.deleteAudioNote(silent.id);
      expect(withoutNote.audioNoteSeconds, isNull);
      expect(withoutNote.audioNoteUrl, isNull);
    } finally {
      final left = (await repo.fetchInspection()).panels.firstWhere(
        (p) => p.id == silent.id,
      );
      if (left.audioNoteSeconds != null) await repo.deleteAudioNote(silent.id);
      file.parent.deleteSync(recursive: true);
    }

    // фото детали (QA №26): загрузить PNG 1×1, открыть без токена по
    // подписанной ссылке, удалить по id — число снимков как было
    final roomy = after.panels.firstWhere((p) => p.photoCount < 5);
    final png = File(
      '${Directory.systemTemp.createTempSync('panel_photo').path}/p.png',
    )..writeAsBytesSync(base64Decode(_onePixelPng));
    int? uploadedId;
    try {
      final withPhoto = await repo.uploadPhoto(roomy.id, png.path);
      expect(withPhoto.photoCount, roomy.photoCount + 1);
      final uploaded = withPhoto.photos.last;
      uploadedId = uploaded.id;
      expect((await http.get(Uri.parse(uploaded.url))).statusCode, 200);

      final withoutPhoto = await repo.deletePhoto(uploaded.id);
      uploadedId = null;
      expect(withoutPhoto.photoCount, roomy.photoCount);
      expect(
        withoutPhoto.photos.map((ph) => ph.id),
        isNot(contains(uploaded.id)),
      );
    } finally {
      if (uploadedId != null) await repo.deletePhoto(uploadedId);
      png.parent.deleteSync(recursive: true);
    }
  });
}

/// Исполнитель из RichDemoSeeder (Максим К.).
const _executorPhone = '+79000000001';

/// Вход по коду из ответа сервера (dev_code) — так же, как экран входа в
/// dev-сборке. Без dev_code или при лимите — понятная ошибка, а не 401 ниже.
Future<void> _signIn(AuthService auth, String phone) async {
  final PhoneCodeSent sent;
  try {
    sent = await auth.requestPhoneCode(phone);
  } on ApiException catch (e) {
    fail(
      'Код входа не выдан (${e.statusCode}): ${e.message}\n'
      'Пауза между кодами — SMS_RESEND_COOLDOWN; суточный лимит на номер в '
      'dev снимает SMS_DAILY_PER_PHONE=0.',
    );
  }
  final code = sent.devCode;
  if (code == null) {
    fail(
      'Сервер не вернул dev_code — нужен локальный бекенд с APP_ENV=local '
      'и SMS_EXPOSE_CODE=true.',
    );
  }
  await auth.verifyPhoneCode(phone, code);
}

/// Валидный PNG 1×1 — сервер проверяет, что это изображение.
const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
