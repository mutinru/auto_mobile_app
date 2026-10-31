/// Тип уведомления ленты — зеркалит App\Enums\NotificationType на бекенде.
/// [unknown] — тип, о котором эта сборка ещё не знает: показываем текст
/// с сервера без особой иконки.
enum NotificationType {
  // заказчику
  responseReceived,
  executorReleased,
  reportReady,
  reportOpened,
  inspectionDatePassed,
  candidateInspected,
  // исполнителю
  executorAssigned,
  responseRejected,
  deadlineSoon,
  deadlineMissed,
  orderRescheduled,
  paymentSent,
  orderCompleted,
  orderCancelled,
  reviewReceived,
  // обеим сторонам
  disputeOpened,
  disputeResolved,
  unknown,
}

const _apiValues = {
  'response_received': NotificationType.responseReceived,
  'executor_released': NotificationType.executorReleased,
  'report_ready': NotificationType.reportReady,
  'report_opened': NotificationType.reportOpened,
  'inspection_date_passed': NotificationType.inspectionDatePassed,
  'candidate_inspected': NotificationType.candidateInspected,
  'executor_assigned': NotificationType.executorAssigned,
  'response_rejected': NotificationType.responseRejected,
  'deadline_soon': NotificationType.deadlineSoon,
  'deadline_missed': NotificationType.deadlineMissed,
  'order_rescheduled': NotificationType.orderRescheduled,
  'payment_sent': NotificationType.paymentSent,
  'order_completed': NotificationType.orderCompleted,
  'order_cancelled': NotificationType.orderCancelled,
  'review_received': NotificationType.reviewReceived,
  'dispute_opened': NotificationType.disputeOpened,
  'dispute_resolved': NotificationType.disputeResolved,
};

NotificationType notificationTypeFromApi(String? value) =>
    _apiValues[value] ?? NotificationType.unknown;

extension NotificationTypeX on NotificationType {
  /// Кому приходит тип, если сервер не прислал viewer_role (уведомления,
  /// созданные до этого поля). Спор приходит обеим сторонам — берём
  /// заказчика: его экран покажет только то, что ему видно.
  bool get defaultViewerIsCustomer => switch (this) {
        NotificationType.executorAssigned ||
        NotificationType.responseRejected ||
        NotificationType.deadlineSoon ||
        NotificationType.deadlineMissed ||
        NotificationType.orderRescheduled ||
        NotificationType.paymentSent ||
        NotificationType.orderCompleted ||
        NotificationType.orderCancelled ||
        NotificationType.reviewReceived =>
          false,
        _ => true,
      };

  /// Открывается ли заказ по тапу. Отклонённый и сорвавший срок исполнитель
  /// заказ уже не видит (сервер ответит 403) — такое уведомление только
  /// читается. Перенесённый заказ снова в ленте — его открываем.
  bool get opensOrder =>
      this != NotificationType.responseRejected && this != NotificationType.deadlineMissed;
}
