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
  paymentDue,
  // заказ ждал решения и отменён сервером, комиссия за размещение вернулась
  orderAutoCancelled,
  // подбор: исполнитель отметил покупку — «Вы купили машину?»
  purchaseReported,
  // подбор не закрыт через 7 и 14 дней после вердикта
  purchaseReminder,
  // подбор: срок выбора исполнителя истекает через сутки
  pickDeadlineSoon,
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
  paymentConfirmDue,
  // заказчик ответил «нет» на сообщение о покупке
  purchaseReportDeclined,
  // заказчик выбрал другую купленную машину
  purchaseChanged,
  // обеим сторонам
  disputeOpened,
  disputeResolved,
  // ожидающей стороне — через сутки молчания другой
  disputeAvailable,
  // подбор без новостей скоро закроется сам
  selectionCloseSoon,
  // подбор закрыт без покупки (без новостей или заказчик удалил аккаунт)
  selectionClosed,
  // плательщику: чек об оплате зарегистрирован / аннулирован после возврата
  receiptIssued,
  receiptCancelled,
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
  'payment_due': NotificationType.paymentDue,
  'order_auto_cancelled': NotificationType.orderAutoCancelled,
  'payment_confirm_due': NotificationType.paymentConfirmDue,
  'dispute_available': NotificationType.disputeAvailable,
  'purchase_reported': NotificationType.purchaseReported,
  'purchase_reminder': NotificationType.purchaseReminder,
  'pick_deadline_soon': NotificationType.pickDeadlineSoon,
  'purchase_report_declined': NotificationType.purchaseReportDeclined,
  'purchase_changed': NotificationType.purchaseChanged,
  'selection_close_soon': NotificationType.selectionCloseSoon,
  'selection_closed': NotificationType.selectionClosed,
  'receipt_issued': NotificationType.receiptIssued,
  'receipt_cancelled': NotificationType.receiptCancelled,
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
    NotificationType.reviewReceived ||
    NotificationType.paymentConfirmDue ||
    NotificationType.purchaseReportDeclined ||
    NotificationType.purchaseChanged => false,
    _ => true,
  };

  /// Чек об оплате — тап открывает «Платежи и чеки», а не заказ.
  bool get opensPayments =>
      this == NotificationType.receiptIssued ||
      this == NotificationType.receiptCancelled;

  /// Открывается ли заказ по тапу. Отклонённый и сорвавший срок исполнитель
  /// заказ уже не видит (сервер ответит 403) — такое уведомление только
  /// читается. Перенесённый заказ снова в ленте — его открываем.
  bool get opensOrder =>
      this != NotificationType.responseRejected &&
      this != NotificationType.deadlineMissed;
}
