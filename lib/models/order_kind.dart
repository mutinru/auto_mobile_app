/// Вид заказа — зеркалит App\Enums\OrderKind на бекенде.
/// selection — подбор автомобиля, inspection — разовый осмотр
/// конкретной машины (design/order-types.html).
enum OrderKind { selection, inspection }

extension OrderKindX on OrderKind {
  String get label => switch (this) {
        OrderKind.selection => 'подбор',
        OrderKind.inspection => 'осмотр',
      };

  String get apiValue => switch (this) {
        OrderKind.selection => 'selection',
        OrderKind.inspection => 'inspection',
      };

  bool get isInspection => this == OrderKind.inspection;
}

OrderKind orderKindFromApi(String? value) =>
    value == 'inspection' ? OrderKind.inspection : OrderKind.selection;
