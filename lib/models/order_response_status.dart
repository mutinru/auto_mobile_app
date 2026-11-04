/// Совпадает с App\Enums\OrderResponseStatus на бекенде.
/// declined — исполнитель отказался от разового осмотра: до переноса даты
/// его больше не выбрать. expired — сорвал день осмотра: на этот заказ он
/// больше не откликнется. outdated — заказчик перенёс осмотр, отклик был
/// под прежнюю дату: можно откликнуться снова.
enum OrderResponseStatus {
  pending,
  accepted,
  rejected,
  declined,
  expired,
  outdated,
}

extension OrderResponseStatusX on OrderResponseStatus {
  String get label => switch (this) {
    OrderResponseStatus.pending => 'ждёт решения',
    OrderResponseStatus.accepted => 'принят',
    OrderResponseStatus.rejected => 'отклонён',
    OrderResponseStatus.declined => 'отказался',
    OrderResponseStatus.expired => 'не успел',
    OrderResponseStatus.outdated => 'дата перенесена',
  };

  /// Отклик в игре: ждёт выбора или принят (`isActive()` на бекенде).
  bool get isActive =>
      this == OrderResponseStatus.pending ||
      this == OrderResponseStatus.accepted;

  /// С таким откликом можно откликнуться ещё раз (`allowsNewResponse()`).
  bool get allowsNewResponse => this == OrderResponseStatus.outdated;
}

OrderResponseStatus orderResponseStatusFromApi(String value) => switch (value) {
  'accepted' => OrderResponseStatus.accepted,
  'rejected' => OrderResponseStatus.rejected,
  'declined' => OrderResponseStatus.declined,
  'expired' => OrderResponseStatus.expired,
  'outdated' => OrderResponseStatus.outdated,
  _ => OrderResponseStatus.pending,
};
