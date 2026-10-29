import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'order_kind.dart';

/// Статус-машина заказа — совпадает с App\Enums\OrderStatus на бекенде.
/// scheduled бывает только у разового осмотра: исполнитель выбран,
/// выезд назначен, но осмотр ещё не начат.
///
/// Разовый осмотр после осмотра: reportReady (отчёт готов, заказчик его не
/// видит, пока не оплатит) → paymentSent (заказчик нажал «Я оплатил») →
/// completed (исполнитель подтвердил, отчёт открыт). Из reportReady и
/// paymentSent любая сторона открывает disputed.
enum OrderStatus {
  awaitingExecutor,
  sourcing,
  scheduled,
  inspecting,
  reportReady,
  paymentSent,
  disputed,
  completed,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  /// Подпись без учёта вида заказа — для экранов исполнителя,
  /// где всё и так про один заказ. Расхождения — в [labelFor].
  String get label => labelFor(OrderKind.selection);

  /// У подбора завершённый заказ — «выполнен», у осмотра — «отчёт
  /// получен»: «отчёт готов» теперь значит «готов, но ждёт оплаты».
  String labelFor(OrderKind kind) => switch (this) {
        OrderStatus.awaitingExecutor => 'ждёт исполнителя',
        OrderStatus.sourcing => 'идёт подбор',
        OrderStatus.scheduled => 'назначен',
        OrderStatus.inspecting => 'на осмотре',
        OrderStatus.reportReady => 'отчёт готов',
        OrderStatus.paymentSent => 'ждём подтверждения',
        OrderStatus.disputed => 'спор',
        OrderStatus.completed => kind.isInspection ? 'отчёт получен' : 'выполнен',
        OrderStatus.cancelled => 'отменён',
      };

  /// Завершён или отменён — во вкладку «Завершённые».
  bool get isFinished =>
      this == OrderStatus.completed || this == OrderStatus.cancelled;

  /// Отчёт готов, но заказчик его ещё не получил: идёт оплата или спор.
  bool get isAwaitingPayment =>
      this == OrderStatus.reportReady ||
      this == OrderStatus.paymentSent ||
      this == OrderStatus.disputed;

  Color color(AppColors c) => switch (this) {
        OrderStatus.awaitingExecutor => c.text2,
        OrderStatus.sourcing => c.statusProgress,
        OrderStatus.scheduled => c.text1,
        OrderStatus.inspecting => c.statusInfo,
        OrderStatus.reportReady => c.statusProgress,
        OrderStatus.paymentSent => c.statusProgress,
        OrderStatus.disputed => c.statusDefect,
        OrderStatus.completed => c.statusDone,
        OrderStatus.cancelled => c.text3,
      };

  /// Цвет для .pill. null → нейтральный вариант (.pill без модификатора,
  /// фон bg-3) — в макете так выглядит «ждёт исполнителя».
  Color? pillColor(AppColors c) => switch (this) {
        // .pill.planned в макете — тот же нейтральный фон, что и у
        // «ждёт исполнителя», но текст ярче
        OrderStatus.awaitingExecutor || OrderStatus.cancelled => null,
        _ => color(c),
      };
}

OrderStatus orderStatusFromApi(String value) => switch (value) {
      'sourcing' => OrderStatus.sourcing,
      'scheduled' => OrderStatus.scheduled,
      'inspecting' => OrderStatus.inspecting,
      'report_ready' => OrderStatus.reportReady,
      'payment_sent' => OrderStatus.paymentSent,
      'disputed' => OrderStatus.disputed,
      'completed' => OrderStatus.completed,
      'cancelled' => OrderStatus.cancelled,
      _ => OrderStatus.awaitingExecutor,
    };
