/// Совпадает с App\Enums\OrderResponseStatus на бекенде.
/// declined и expired — исполнитель отказался от разового осмотра или
/// пропустил 24 часа: на этот заказ его больше не выбрать.
enum OrderResponseStatus { pending, accepted, rejected, declined, expired }

extension OrderResponseStatusX on OrderResponseStatus {
  String get label => switch (this) {
        OrderResponseStatus.pending => 'ждёт решения',
        OrderResponseStatus.accepted => 'принят',
        OrderResponseStatus.rejected => 'отклонён',
        OrderResponseStatus.declined => 'отказался',
        OrderResponseStatus.expired => 'не успел',
      };
}

OrderResponseStatus orderResponseStatusFromApi(String value) => switch (value) {
      'accepted' => OrderResponseStatus.accepted,
      'rejected' => OrderResponseStatus.rejected,
      'declined' => OrderResponseStatus.declined,
      'expired' => OrderResponseStatus.expired,
      _ => OrderResponseStatus.pending,
    };
