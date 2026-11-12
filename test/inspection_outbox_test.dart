import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/api_client.dart';
import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/api_inspection_repository.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/inspection_cache.dart';
import 'package:auto_podbor_mobile/data/inspection_repository.dart';
import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/models/inspection_panel.dart';
import 'package:auto_podbor_mobile/models/panel_condition.dart';
import 'package:auto_podbor_mobile/models/panel_status.dart';
import 'package:auto_podbor_mobile/state/inspection_op.dart';
import 'package:auto_podbor_mobile/state/inspection_outbox.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';

/// Сервер осмотра, у которого можно выключить сеть и отказать действию.
class _Server extends MockInspectionRepository {
  _Server() : super.blank();

  bool offline = false;

  /// Отказ (422) на оценку — например, отчёт уже заморожен.
  bool rejectConditions = false;

  /// Фото сохраняется, но ответ теряется (тайм-аут) — один раз.
  bool loseNextPhotoResponse = false;

  final calls = <String>[];

  /// Осмотр отдаётся из копии (сети не было при открытии).
  bool fromCopy = false;

  @override
  Future<InspectionSnapshot> fetchInspection() async {
    final s = await super.fetchInspection();
    return (car: s.car, panels: s.panels, offline: fromCopy);
  }

  Future<void> _net(String call) async {
    if (offline) throw http.ClientException('no network');
    calls.add(call);
  }

  @override
  Future<InspectionPanel> updateCondition(
    String panelId,
    PanelCondition condition,
  ) async {
    await _net('condition $panelId ${condition.apiValue}');
    if (rejectConditions) {
      throw ApiException(422, '{"message":"Отчёт уже у заказчика"}');
    }
    return super.updateCondition(panelId, condition);
  }

  @override
  Future<InspectionPanel> setDefect(
    String panelId,
    int defectId, {
    required bool on,
  }) async {
    await _net('defect $panelId $defectId $on');
    return super.setDefect(panelId, defectId, on: on);
  }

  @override
  Future<InspectionPanel> uploadPhoto(
    String panelId,
    String filePath, {
    String? clientId,
    PhotoSource source = PhotoSource.camera,
    String? takenAt,
  }) async {
    await _net('photo $panelId');
    final panel = await super.uploadPhoto(
      panelId,
      filePath,
      clientId: clientId,
    );
    if (loseNextPhotoResponse) {
      loseNextPhotoResponse = false;
      throw TimeoutException('ответ потерялся');
    }
    return panel;
  }

  @override
  Future<InspectionPanel> deletePhoto(int photoId) async {
    await _net('delete photo $photoId');
    return super.deletePhoto(photoId);
  }
}

void main() {
  const fender = 'front_right_fender';
  const hood = 'hood';
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('outbox');
    // повтор по таймеру тестам не нужен — отправку зовём сами
    InspectionOutbox.retryDelay = (_) => const Duration(hours: 1);
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<InspectionOutboxes> registry(
    _Server server, {
    int user = 7,
  }) async {
    final r = InspectionOutboxes(
      repositoryFor: (_) => server,
      currentUser: () async => user,
      root: root,
    );
    await r.init();
    return r;
  }

  File photoFile(String name) =>
      File('${root.path}/$name.jpg')..writeAsBytesSync([1, 2, 3]);

  Future<InspectionStore> openStore(
    _Server server,
    InspectionOutbox outbox,
  ) async {
    final store = InspectionStore(server, outbox: outbox);
    await store.load();
    return store;
  }

  test(
    'без сети действия видны сразу и уходят по порядку, когда сеть есть',
    () async {
      final server = _Server();
      final outbox = (await registry(server)).forInspection(1);
      final store = await openStore(server, outbox);
      server.offline = true;

      await store.applyCondition(fender, PanelCondition.needsRepair);
      await store.uploadPhoto(fender, photoFile('a').path);
      await store.toggleDefect(fender, 'Вмятина');

      final panel = store.panelById(fender);
      expect(panel.status, PanelStatus.defect);
      expect(panel.photos.single.isPending, isTrue);
      expect(panel.defects, contains('Вмятина'));
      expect(panel.missing, isEmpty, reason: 'фото и дефект уже есть');
      expect(store.pendingCount, 3);
      expect(store.isWaitingForNetwork, isTrue);
      expect(store.canSendReport, isFalse);

      server.offline = false;
      await outbox.flush();

      expect(server.calls, [
        'condition $fender needs_repair',
        'photo $fender',
        'defect $fender 3 true',
      ]);
      expect(store.pendingCount, 0);
      final saved = store.panelById(fender);
      expect(saved.photos.single.isPending, isFalse);
      expect(saved.photos.single.id, greaterThan(0));
      expect(saved.defects, contains('Вмятина'));
    },
  );

  test(
    'повторы схлопываются: последняя оценка, последнее состояние дефекта',
    () async {
      final server = _Server();
      final outbox = (await registry(server)).forInspection(1);
      final store = await openStore(server, outbox);
      server.offline = true;

      await store.applyCondition(hood, PanelCondition.good);
      await store.applyCondition(hood, PanelCondition.satisfactory);
      await store.toggleDefect(fender, 'Вмятина');
      await store.toggleDefect(fender, 'Вмятина');

      expect(outbox.pending, hasLength(2));
      expect(store.panelById(hood).condition, PanelCondition.satisfactory);
      expect(store.panelById(hood).missing, {InspectionPanel.missingPhoto});
      expect(store.panelById(fender).defects, isNot(contains('Вмятина')));

      server.offline = false;
      await outbox.flush();
      expect(server.calls, [
        'condition $hood satisfactory',
        'defect $fender 3 false',
      ]);
    },
  );

  test('удаление неотправленного фото — без запроса, файл стёрт', () async {
    final server = _Server();
    final outbox = (await registry(server)).forInspection(1);
    final store = await openStore(server, outbox);
    server.offline = true;

    await store.uploadPhoto(fender, photoFile('b').path);
    final pending = store.panelById(fender).photos.single;
    expect(File(pending.localPath!).existsSync(), isTrue);

    await store.deletePhoto(fender, pending);

    expect(store.panelById(fender).photos, isEmpty);
    expect(store.pendingCount, 0);
    expect(File(pending.localPath!).existsSync(), isFalse);
    server.offline = false;
    await outbox.flush();
    expect(server.calls, isEmpty);
  });

  test(
    'потерянный ответ загрузки: повтор с тем же ключом не дублирует фото',
    () async {
      final server = _Server()..loseNextPhotoResponse = true;
      final outbox = (await registry(server)).forInspection(1);
      final store = await openStore(server, outbox);

      await store.uploadPhoto(fender, photoFile('c').path);
      expect(store.pendingCount, 1, reason: 'исход неизвестен — повторим');

      await outbox.flush();

      expect(server.calls, ['photo $fender', 'photo $fender']);
      expect(store.pendingCount, 0);
      expect(store.panelById(fender).photos, hasLength(1));
    },
  );

  test(
    'отказ сервера: действие снято, деталь перечитана, причина — снекбару',
    () async {
      final server = _Server()..rejectConditions = true;
      final outbox = (await registry(server)).forInspection(1);
      final store = await openStore(server, outbox);
      final messages = <String>[];
      store.rejections.listen(messages.add);

      await store.applyCondition(hood, PanelCondition.good);
      await pumpEventQueue();

      expect(store.pendingCount, 0);
      expect(store.panelById(hood).condition, isNull);
      expect(messages, ['Не сохранилось: Капот — Отчёт уже у заказчика']);
    },
  );

  test('очередь переживает перезапуск и уходит после входа', () async {
    final server = _Server();
    final store = await openStore(
      server,
      (await registry(server)).forInspection(1),
    );
    server.offline = true;
    await store.applyCondition(hood, PanelCondition.good);
    await store.uploadPhoto(hood, photoFile('d').path);

    // приложение убито; новый запуск — новый реестр с той же папкой
    server.offline = false;
    final after = await registry(server);
    await after.resumeAll();
    await after.forInspection(1).flush();

    expect(server.calls, ['condition $hood good', 'photo $hood']);
    expect(after.forInspection(1).pendingCount, 0);
    final queues = Directory('${root.path}/inspection_outbox');
    expect(
      queues.existsSync() ? queues.listSync() : const [],
      isEmpty,
      reason: 'долг погашен: ни очереди, ни её файлов',
    );
  });

  test('чужую очередь (вошёл другой) не отправляет', () async {
    final server = _Server();
    final store = await openStore(
      server,
      (await registry(server)).forInspection(1),
    );
    server.offline = true;
    await store.applyCondition(hood, PanelCondition.good);
    server.offline = false;

    final other = await registry(server, user: 99);
    await other.resumeAll();
    await other.forInspection(1).flush();

    expect(server.calls, isEmpty);
    expect(other.forInspection(1).state, OutboxState.paused);
    expect(other.forInspection(1).pendingCount, 1);
  });

  test(
    'открыт из копии: первый ответ сервера возвращает свежий осмотр',
    () async {
      final server = _Server()..fromCopy = true;
      final store = await openStore(
        server,
        (await registry(server)).forInspection(1),
      );
      expect(store.isOffline, isTrue);

      server.fromCopy = false;
      await store.applyCondition(hood, PanelCondition.good);
      await pumpEventQueue();

      expect(store.isOffline, isFalse);
    },
  );

  test('applyPending не трогает подтверждённые детали', () {
    final confirmed = [
      InspectionPanel(
        id: hood,
        name: 'Капот',
        zone: 'Перед',
        status: PanelStatus.none,
        missing: {InspectionPanel.missingCondition},
      ),
    ];
    final shown = applyPending(confirmed, const [
      SetConditionOp(
        id: 1,
        panelId: hood,
        condition: PanelCondition.needsRepair,
      ),
    ]);

    expect(shown.single.status, PanelStatus.defect);
    expect(shown.single.missing, {
      InspectionPanel.missingPhoto,
      InspectionPanel.missingDefect,
    });
    expect(confirmed.single.condition, isNull);
    expect(confirmed.single.missing, {InspectionPanel.missingCondition});
  });

  group('копия осмотра', () {
    setUp(() {
      InspectionCache.debugRoot = root;
      InspectionCache.debugReset();
    });
    tearDown(() {
      InspectionCache.debugRoot = null;
      InspectionCache.debugReset();
    });

    Map<String, dynamic> panelJson(String condition) => {
      'id': hood,
      'name': 'Капот',
      'zone': 'Перед',
      'status': 'ok',
      'condition': condition,
      'defects': <dynamic>[],
      'photo_count': 0,
      'photos': <dynamic>[],
      'missing': <dynamic>[],
    };

    final inspection = {
      'data': {
        'car': {
          'brand': 'Kia',
          'model': 'Rio',
          'year': 2020,
          'vin_masked': '··· 1234',
        },
        'panels': [panelJson('good')],
      },
    };

    AuthService auth() => AuthService()
      ..debugSetToken('t')
      ..debugSetUser(const CurrentUser(id: 7, name: 'И', email: 'i@e.ru'));

    Future<T> net<T>(Future<T> Function() body, {required bool online}) =>
        http.runWithClient(
          body,
          () => MockClient((r) async {
            if (!online) throw http.ClientException('no network');
            if (r.url.path.endsWith('/panels/$hood')) {
              return http.Response(
                jsonEncode({'data': panelJson('needs_repair')}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            return http.Response(
              jsonEncode(inspection),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );

    test(
      'без сети осмотр открывается из копии, ответы мутаций её правят',
      () async {
        final repo = ApiInspectionRepository(
          ApiClient(auth()),
          inspectionId: 5,
        );

        final fresh = await net(repo.fetchInspection, online: true);
        expect(fresh.offline, isFalse);

        await net(
          () => repo.updateCondition(hood, PanelCondition.needsRepair),
          online: true,
        );

        final cached = await net(repo.fetchInspection, online: false);
        expect(cached.offline, isTrue);
        expect(cached.car.model, 'Rio');
        expect(cached.panels.single.condition, PanelCondition.needsRepair);
      },
    );

    test('без сети и без копии — ошибка, как раньше', () async {
      final repo = ApiInspectionRepository(ApiClient(auth()), inspectionId: 6);

      await expectLater(
        net(repo.fetchInspection, online: false),
        throwsA(isA<http.ClientException>()),
      );
    });
  });
}
