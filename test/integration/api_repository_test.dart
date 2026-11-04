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
// Осмотр не угадывается по номеру, а находится так же, как в приложении:
// взятые заказы исполнителя → кандидат подбора с незакрытым осмотром.
// Голосовую заметку тест кладёт на деталь без неё и удаляет.
// Тест возвращает деталь в исходное состояние — повторный прогон без
// пересидирования тоже зелёный.
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:auto_podbor_mobile/config/api_config.dart';
import 'package:auto_podbor_mobile/data/api_client.dart';
import 'package:auto_podbor_mobile/data/api_inspection_repository.dart';
import 'package:auto_podbor_mobile/data/api_order_repository.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/models/inspection_panel.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
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
    await auth.login('inspector@autopodbor.local', 'password');
    expect(auth.isAuthenticated, isTrue);
    final client = ApiClient(auth);

    // RichDemoSeeder: подбор Camry «на осмотре», третий кандидат осмотрен
    // наполовину и исхода не имеет — его исполнитель ещё может править
    final assigned = await ApiOrderRepository(client).fetchAssignedOrders();
    OrderCar? candidate;
    for (final order in assigned) {
      if (order.isInspection || order.status != OrderStatus.inspecting) {
        continue;
      }
      for (final car in order.cars) {
        if (car.inspectionId != null && car.inspectionOutcome == null) {
          candidate = car;
        }
      }
    }
    if (candidate == null) {
      fail(
        'Нет подбора с открытым осмотром у Максима — засидируйте базу: '
        'docker compose exec app php artisan migrate:fresh --seed',
      );
    }

    final repo = ApiInspectionRepository(
      client,
      inspectionId: candidate.inspectionId!,
    );

    final snapshot = await repo.fetchInspection();
    expect(snapshot.car.brand, 'Toyota');
    expect(snapshot.car.model, 'Camry');
    expect(snapshot.panels, hasLength(13));
    // точное число зависит от того, что правили в dev-базе после сида
    int assessed(Iterable<InspectionPanel> panels) =>
        panels.where((p) => p.status != PanelStatus.none).length;
    final assessedBefore = assessed(snapshot.panels);
    expect(assessedBefore, greaterThan(0));

    final catalog = await repo.fetchDefectCatalog();
    expect(catalog, hasLength(6));

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
      final withDefect = await repo.toggleDefect(panel.id, defect.id);
      expect(withDefect.defects, contains(defect.label));

      final withoutDefect = await repo.toggleDefect(panel.id, defect.id);
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

/// Валидный PNG 1×1 — сервер проверяет, что это изображение.
const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
