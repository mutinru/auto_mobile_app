import 'order.dart';

/// Вариант шторки «Заказов рядом» — город или марка и сколько свободных
/// заказов с ним (meta.facets сервера, по всем свободным без фильтров).
class Facet {
  const Facet(this.name, this.count);

  final String name;
  final int count;

  factory Facet.fromJson(Map<String, dynamic> json) =>
      Facet(json['name'] as String, (json['count'] as num).toInt());
}

/// Страница ленты свободных заказов.
class AvailablePage {
  const AvailablePage({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.total,
    required this.all,
    this.cityFacets,
    this.brandFacets,
  });

  final List<Order> items;
  final int page;
  final bool hasMore;

  /// Заказов под фильтром — на всех страницах.
  final int total;

  /// Свободных без фильтров — для «свободные · N» и «Все · N».
  final int all;

  /// Варианты шторки; сервер отдаёт их только с первой страницей.
  final List<Facet>? cityFacets;
  final List<Facet>? brandFacets;
}
