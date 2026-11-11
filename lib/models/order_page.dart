import 'order.dart';

/// Страница завершённых заказов («Мои заказы» / «Взятые заказы» →
/// «Завершённые»): сервер отдаёт их по 20, от последнего закрытого.
class OrderPage {
  const OrderPage({required this.items, required this.hasMore});

  final List<Order> items;
  final bool hasMore;
}
