import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'order_kind.dart';

/// Статус-машина заказа — совпадает с App\Enums\OrderStatus на бекенде.
/// scheduled бывает только у разового осмотра: исполнитель выбран,
/// выезд назначен, но осмотр ещё не начат.
enum OrderStatus {
  awaitingExecutor,
  sourcing,
  scheduled,
  inspecting,
  completed,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  /// Подпись без учёта вида заказа — для экранов исполнителя,
  /// где всё и так про один заказ. Расхождения — в [labelFor].
  String get label => labelFor(OrderKind.selection);

  /// У подбора завершённый заказ — «выполнен», у осмотра — «отчёт готов»
  /// (order-types.html, кадр 05).
  String labelFor(OrderKind kind) => switch (this) {
        OrderStatus.awaitingExecutor => 'ждёт исполнителя',
        OrderStatus.sourcing => 'идёт подбор',
        OrderStatus.scheduled => 'назначен',
        OrderStatus.inspecting => 'на осмотре',
        OrderStatus.completed => kind.isInspection ? 'отчёт готов' : 'выполнен',
        OrderStatus.cancelled => 'отменён',
      };

  Color color(AppColors c) => switch (this) {
        OrderStatus.awaitingExecutor => c.text2,
        OrderStatus.sourcing => c.statusProgress,
        OrderStatus.scheduled => c.text1,
        OrderStatus.inspecting => c.statusInfo,
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
      'completed' => OrderStatus.completed,
      'cancelled' => OrderStatus.cancelled,
      _ => OrderStatus.awaitingExecutor,
    };
