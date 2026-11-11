import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/order_page.dart';
import '../widgets/api_error.dart';

/// Вкладка «Завершённые»: заказы страницами (сервер отдаёт по 20, от
/// последнего закрытого). Первая страница — при открытии вкладки и по
/// потягиванию, следующие — подвалом списка. Ответ, обогнанный более новым
/// запросом (перечитали первую страницу, пока шла вторая), отбрасываем.
class PagedOrders extends ChangeNotifier {
  PagedOrders(this._fetch);

  final Future<OrderPage> Function(int page) _fetch;

  List<Order> _items = const [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _moreError;
  int _generation = 0;
  int _version = 0;

  List<Order> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;

  /// Первая страница ещё не загружалась (вкладку не открывали).
  bool get isLoaded => _page > 0;

  /// Ошибка первой страницы и подгрузки следующей.
  String? get error => _error;
  String? get moreError => _moreError;

  /// Растёт с каждой принятой страницей — ключ подвала подгрузки.
  int get version => _version;

  /// Первая страница заново (открыли вкладку, потянули вниз). Уже
  /// загруженный список ошибка не стирает.
  Future<void> load() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    _moreError = null;
    notifyListeners();
    try {
      final page = await _fetch(1);
      if (generation != _generation) return;
      _items = page.items;
      _accept(page, 1);
    } catch (e) {
      if (generation == _generation) _error = apiErrorText(e);
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Следующая страница — подвалом списка.
  Future<void> loadMore() async {
    if (!_hasMore || _loading || _loadingMore) return;
    final generation = _generation;
    _loadingMore = true;
    _moreError = null;
    notifyListeners();
    try {
      final page = await _fetch(_page + 1);
      if (generation != _generation) return;
      // закрытые заказы сдвигают страницы — повтор с прошлой отбрасываем
      final seen = {for (final o in _items) o.id};
      _items = [..._items, ...page.items.where((o) => seen.add(o.id))];
      _accept(page, _page + 1);
    } catch (e) {
      if (generation == _generation) _moreError = apiErrorText(e);
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Заказ изменился (действие на экране заказа) — подменить, если он здесь.
  void replace(Order order) {
    final index = _items.indexWhere((o) => o.id == order.id);
    if (index == -1) return;
    _items = [..._items]..[index] = order;
    notifyListeners();
  }

  void _accept(OrderPage page, int number) {
    _page = number;
    _hasMore = page.hasMore;
    _version++;
  }
}
