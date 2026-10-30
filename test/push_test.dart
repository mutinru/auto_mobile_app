import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_chat_repository.dart';
import 'package:auto_podbor_mobile/data/mock_device_repository.dart';
import 'package:auto_podbor_mobile/data/mock_notification_repository.dart';
import 'package:auto_podbor_mobile/models/notification_type.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/push_target.dart';
import 'package:auto_podbor_mobile/push/push_messaging.dart';
import 'package:auto_podbor_mobile/push/push_service.dart';
import 'package:auto_podbor_mobile/state/notification_unread.dart';
import 'package:auto_podbor_mobile/state/support_unread.dart';

/// Firebase в тестах не поднять — PushService ходит через этот фейк.
class FakePushMessaging implements PushMessaging {
  bool failInit = false;
  String? token = 'fcm-1';
  PushMessage? launchedBy;
  int permissionRequests = 0;
  final shown = <PushMessage>[];

  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final taps = StreamController<PushMessage>.broadcast();

  @override
  Future<void> init() async {
    if (failInit) throw StateError('нет Play Services');
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<PushMessage> get onForeground => foreground.stream;

  @override
  Stream<PushMessage> get onTap => taps.stream;

  @override
  Future<PushMessage?> initialTap() async => launchedBy;

  @override
  Future<void> show(PushMessage message) async => shown.add(message);
}

const orderPush = PushMessage(
  title: 'Новый отклик',
  body: 'Иван предлагает 12 000 ₽',
  data: {
    'type': 'response_received',
    'notification_id': 'n-1',
    'order_id': '5',
    'order_kind': 'inspection',
    'viewer_role': 'customer',
  },
);

const supportPush = PushMessage(
  title: 'Поддержка',
  body: 'Сейчас посмотрим',
  data: {'type': 'chat_message', 'conversation_id': '3', 'conversation_type': 'support'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushTarget', () {
    test('пуш о заказе — заказ, вид, роль и запись ленты', () {
      final target = PushTarget.fromData(orderPush.data) as OrderTarget;
      expect(target.orderId, 5);
      expect(target.orderKind, OrderKind.inspection);
      expect(target.viewerIsCustomer, isTrue);
      expect(target.notificationId, 'n-1');
      expect(target.opensOrder, isTrue);
    });

    test('без viewer_role роль из типа; отклонённый отклик заказ не открывает', () {
      final target = PushTarget.fromData({'type': 'response_rejected', 'order_id': '7'}) as OrderTarget;
      expect(target.type, NotificationType.responseRejected);
      expect(target.viewerIsCustomer, isFalse);
      expect(target.opensOrder, isFalse);
    });

    test('чат поддержки и непонятные пуши', () {
      expect(PushTarget.fromData(supportPush.data), isA<SupportChatTarget>());
      expect(PushTarget.fromData({'type': 'chat_message', 'conversation_type': 'order'}), isNull);
      expect(PushTarget.fromData({'type': 'from_the_future', 'order_id': '1'}), isNull);
      expect(PushTarget.fromData({'type': 'report_ready'}), isNull);
      expect(PushTarget.fromData(const {}), isNull);
    });
  });

  group('PushService', () {
    late AuthService auth;
    late MockDeviceRepository devices;
    late FakePushMessaging messaging;

    setUp(() {
      auth = AuthService();
      devices = MockDeviceRepository();
      messaging = FakePushMessaging();
    });

    PushService service({NotificationUnread? notifications, SupportUnread? support}) => PushService(
      auth: auth,
      devices: devices,
      messaging: messaging,
      notifications: notifications,
      support: support,
    );

    test('Firebase не поднялся — пуши выключены, приложение живёт', () async {
      messaging.failInit = true;
      final push = service();
      await push.start();
      auth.debugSetToken('t');
      await pumpEventQueue();
      expect(push.enabled, isFalse);
      expect(devices.registered, isEmpty);
    });

    test('устройство регистрируется на каждую новую сессию, разрешение — один раз', () async {
      final push = service();
      await push.start();
      expect(devices.registered, isEmpty, reason: 'гостю не регистрируем');

      auth.debugSetToken('session-1');
      await pumpEventQueue();
      auth.debugSetToken('session-1'); // тот же вход — повторно не шлём
      await pumpEventQueue();
      expect(devices.registered, ['fcm-1']);

      messaging.refresh.add('fcm-2');
      await pumpEventQueue();
      expect(devices.registered, ['fcm-1', 'fcm-2']);

      auth.expireSession();
      auth.debugSetToken('session-2');
      await pumpEventQueue();
      expect(devices.registered, ['fcm-1', 'fcm-2', 'fcm-1']);
      expect(messaging.permissionRequests, 1);
      push.dispose();
    });

    test('сбой регистрации повторится на следующем изменении сессии', () async {
      devices.fail = true;
      final push = service();
      await push.start();
      auth.debugSetToken('session-1');
      await pumpEventQueue();
      expect(devices.registered, isEmpty);

      devices.fail = false;
      auth.debugSetToken('session-1');
      await pumpEventQueue();
      expect(devices.registered, ['fcm-1']);
      push.dispose();
    });

    test('в открытом приложении — показать и обновить бейдж; ответ при открытом чате — нет', () async {
      auth.debugSetToken('t');
      final feed = MockNotificationRepository();
      final notifications = NotificationUnread(auth, feed);
      final support = SupportUnread(auth, MockChatRepository());
      final push = service(notifications: notifications, support: support);
      await push.start();

      messaging.foreground.add(orderPush);
      messaging.foreground.add(supportPush);
      await pumpEventQueue();
      expect(messaging.shown, [orderPush, supportPush]);

      support.chatOpen = true;
      messaging.foreground.add(supportPush);
      await pumpEventQueue();
      expect(messaging.shown, hasLength(2), reason: 'чат открыт — ответ и так на экране');

      push.dispose();
      notifications.dispose();
      support.dispose();
    });

    test('тап — в поток taps; пуш запуска — забирается один раз', () async {
      messaging.launchedBy = supportPush;
      final push = service();
      final taps = <PushTarget>[];
      push.taps.listen(taps.add);
      await push.start();

      expect(push.takePendingTap(), isA<SupportChatTarget>());
      expect(push.takePendingTap(), isNull);

      messaging.taps.add(orderPush);
      messaging.taps.add(const PushMessage(data: {'type': 'unknown'}));
      await pumpEventQueue();
      expect(taps, hasLength(1));
      expect((taps.single as OrderTarget).orderId, 5);
      push.dispose();
    });
  });
}
