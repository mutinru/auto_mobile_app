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
///
/// awaitingDecision — осмотр: исполнитель сорвал день осмотра или день
/// прошёл без выбранного исполнителя; подбор: исполнитель отказался.
/// Заказчик размещает заказ заново (у осмотра — новая дата) или отменяет; в
/// ленте исполнителей его нет. Без решения несколько дней сервер отменяет
/// заказ сам (order_auto_cancelled).
///
/// awaitingPlacement — только при комиссии за размещение (осмотр и подбор):
/// заказ создан, но не опубликован, пока заказчик не оплатит.
///
/// closed — только у подбора: закрыт без покупки (сервер закрывает
/// брошенный подбор сам или при удалении аккаунта заказчика).
///
/// [unknown] — статус, о котором эта сборка не знает (сервер новее):
/// показываем «обновите приложение», а не притворяемся знакомым статусом.
enum OrderStatus {
  awaitingPlacement,
  awaitingExecutor,
  awaitingDecision,
  sourcing,
  scheduled,
  inspecting,
  reportReady,
  paymentSent,
  disputed,
  completed,
  closed,
  cancelled,
  unknown,
}

extension OrderStatusX on OrderStatus {
  /// Подпись без учёта вида заказа — для экранов исполнителя,
  /// где всё и так про один заказ. Расхождения — в [labelFor].
  String get label => labelFor(OrderKind.selection);

  /// У подбора завершённый заказ — «выполнен», у осмотра — «отчёт
  /// получен»: «отчёт готов» теперь значит «готов, но ждёт оплаты».
  String labelFor(OrderKind kind) => switch (this) {
    OrderStatus.awaitingPlacement => 'ждёт оплаты',
    OrderStatus.awaitingExecutor => 'ждёт исполнителя',
    OrderStatus.awaitingDecision => 'ждёт решения',
    OrderStatus.sourcing => 'идёт подбор',
    OrderStatus.scheduled => 'назначен',
    OrderStatus.inspecting => 'на осмотре',
    OrderStatus.reportReady => 'отчёт готов',
    OrderStatus.paymentSent => 'ждём подтверждения',
    OrderStatus.disputed => 'спор',
    OrderStatus.completed => kind.isInspection ? 'отчёт получен' : 'выполнен',
    OrderStatus.closed => 'закрыт без покупки',
    OrderStatus.cancelled => 'отменён',
    OrderStatus.unknown => 'обновите приложение',
  };

  /// Завершён, закрыт без покупки или отменён — во вкладку «Завершённые».
  bool get isFinished =>
      this == OrderStatus.completed ||
      this == OrderStatus.closed ||
      this == OrderStatus.cancelled;

  /// Отчёт готов, но заказчик его ещё не получил: идёт оплата или спор.
  bool get isAwaitingPayment =>
      this == OrderStatus.reportReady ||
      this == OrderStatus.paymentSent ||
      this == OrderStatus.disputed;

  Color color(AppColors c) => switch (this) {
    OrderStatus.awaitingPlacement => c.statusProgress,
    OrderStatus.awaitingExecutor => c.text2,
    OrderStatus.awaitingDecision => c.statusProgress,
    OrderStatus.sourcing => c.statusProgress,
    OrderStatus.scheduled => c.text1,
    OrderStatus.inspecting => c.statusInfo,
    OrderStatus.reportReady => c.statusProgress,
    OrderStatus.paymentSent => c.statusProgress,
    OrderStatus.disputed => c.statusDefect,
    OrderStatus.completed => c.statusDone,
    OrderStatus.closed => c.text3,
    OrderStatus.cancelled => c.text3,
    OrderStatus.unknown => c.text3,
  };

  /// Цвет для .pill. null → нейтральный вариант (.pill без модификатора,
  /// фон bg-3) — в макете так выглядит «ждёт исполнителя».
  Color? pillColor(AppColors c) => switch (this) {
    // .pill.planned в макете — тот же нейтральный фон, что и у
    // «ждёт исполнителя», но текст ярче
    OrderStatus.awaitingExecutor ||
    OrderStatus.closed ||
    OrderStatus.cancelled ||
    OrderStatus.unknown => null,
    _ => color(c),
  };
}

OrderStatus orderStatusFromApi(String value) => switch (value) {
  'awaiting_placement' => OrderStatus.awaitingPlacement,
  'awaiting_executor' => OrderStatus.awaitingExecutor,
  'awaiting_decision' => OrderStatus.awaitingDecision,
  'sourcing' => OrderStatus.sourcing,
  'scheduled' => OrderStatus.scheduled,
  'inspecting' => OrderStatus.inspecting,
  'report_ready' => OrderStatus.reportReady,
  'payment_sent' => OrderStatus.paymentSent,
  'disputed' => OrderStatus.disputed,
  'completed' => OrderStatus.completed,
  'closed' => OrderStatus.closed,
  'cancelled' => OrderStatus.cancelled,
  _ => OrderStatus.unknown,
};
