import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/city_repository.dart';
import '../models/nearby_filter.dart';
import '../models/order.dart';
import '../models/order_kind.dart';
import '../theme/app_colors.dart';
import 'app_ui.dart';
import 'city_picker_sheet.dart';

/// Шторка фильтров «Заказов рядом» — открывается кнопкой с ползунками в
/// шапке. Варианты городов и марок берёт из загруженных [orders].
/// [countFor] считает, сколько заказов останется при фильтре, — для кнопки
/// «Показать N заказов». [cities] добавляет чип «Другой город…» с поиском
/// по справочнику. Возвращает новый фильтр или null, если закрыли.
Future<NearbyFilter?> showNearbyFilterSheet(
  BuildContext context, {
  required NearbyFilter current,
  required List<Order> orders,
  required int Function(NearbyFilter) countFor,
  CityRepository? cities,
}) {
  return showModalBottomSheet<NearbyFilter>(
    context: context,
    backgroundColor: context.colors.bg0,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _NearbyFilterSheet(
      initial: current,
      orders: orders,
      countFor: countFor,
      cities: cities,
    ),
  );
}

class _NearbyFilterSheet extends StatefulWidget {
  const _NearbyFilterSheet({
    required this.initial,
    required this.orders,
    required this.countFor,
    required this.cities,
  });

  final NearbyFilter initial;
  final List<Order> orders;
  final int Function(NearbyFilter) countFor;
  final CityRepository? cities;

  @override
  State<_NearbyFilterSheet> createState() => _NearbyFilterSheetState();
}

class _NearbyFilterSheetState extends State<_NearbyFilterSheet> {
  late NearbyFilter _filter = widget.initial;
  late final _priceController = TextEditingController(
    text: widget.initial.minPrice?.toString() ?? '',
  );

  @override
  void initState() {
    super.initState();
    _priceController.addListener(() {
      final price = int.tryParse(_priceController.text);
      if (price != _filter.minPrice) {
        _update(_filter.copyWith(minPrice: () => price));
      }
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _update(NearbyFilter next) => setState(() => _filter = next);

  void _reset() {
    _priceController.clear();
    // сортировка — не фильтр, сброс её не трогает
    _update(NearbyFilter(sort: _filter.sort));
  }

  Future<void> _pickCities() async {
    final next = await showCityPickerSheet(
      context,
      cities: widget.cities!,
      selected: _filter.cities,
    );
    if (next != null && mounted) _update(_filter.copyWith(cities: next));
  }

  Set<String> _toggle(Set<String> set, String value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};

  @override
  Widget build(BuildContext context) {
    // сохранённый город может отсутствовать в текущей выдаче — всё равно
    // показываем его, иначе снять такой фильтр было бы нечем
    final cities = {...cityOptions(widget.orders), ..._filter.cities}.toList()
      ..sort();
    final brands = {...brandOptions(widget.orders), ..._filter.brands}.toList()
      ..sort();
    final count = widget.countFor(_filter);
    final work = context.colors.modeWork;

    Widget chips(List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Wrap(spacing: 6, runSpacing: 6, children: children),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .sheet-handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 14),
                decoration: BoxDecoration(
                  color: context.colors.bg3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Text(
                'Фильтры',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.colors.text1,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHead('Вид заказа'),
                    chips([
                      AppChip(
                        label: 'Все',
                        on: _filter.kind == null,
                        activeColor: work,
                        onTap: () =>
                            _update(_filter.copyWith(kind: () => null)),
                      ),
                      for (final kind in OrderKind.values)
                        AppChip(
                          label: kind.isInspection ? 'Осмотр' : 'Подбор',
                          on: _filter.kind == kind,
                          activeColor: work,
                          onTap: () =>
                              _update(_filter.copyWith(kind: () => kind)),
                        ),
                    ]),

                    // без справочника выбирать из одного города незачем
                    if (cities.length > 1 || widget.cities != null) ...[
                      const SectionHead('Город'),
                      chips([
                        for (final city in cities)
                          AppChip(
                            label: city,
                            on: _filter.cities.contains(city),
                            activeColor: work,
                            onTap: () => _update(
                              _filter.copyWith(
                                cities: _toggle(_filter.cities, city),
                              ),
                            ),
                          ),
                        if (widget.cities != null)
                          AppChip(
                            label: 'Другой город…',
                            on: false,
                            activeColor: work,
                            onTap: _pickCities,
                          ),
                      ]),
                    ],

                    const SectionHead('Когда', extra: 'только осмотр'),
                    chips([
                      for (final when in NearbyWhen.values)
                        AppChip(
                          label: when.label,
                          on: _filter.when == when,
                          activeColor: work,
                          onTap: () => _update(_filter.copyWith(when: when)),
                        ),
                    ]),

                    const SectionHead('Оплата', extra: 'только осмотр'),
                    FieldBoxInput(
                      label: '',
                      controller: _priceController,
                      hint: 'от',
                      unit: '₽',
                      mono: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 8),

                    if (brands.length > 1) ...[
                      const SectionHead('Марка'),
                      chips([
                        for (final brand in brands)
                          AppChip(
                            label: brand,
                            on: _filter.brands.contains(brand),
                            activeColor: work,
                            onTap: () => _update(
                              _filter.copyWith(
                                brands: _toggle(_filter.brands, brand),
                              ),
                            ),
                          ),
                      ]),
                    ],

                    const SectionHead('Сортировка'),
                    chips([
                      for (final sort in NearbySort.values)
                        AppChip(
                          label: sort.label,
                          on: _filter.sort == sort,
                          activeColor: work,
                          onTap: () => _update(_filter.copyWith(sort: sort)),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
            BottomCta(
              children: [
                CtaPrimary(
                  label: count == 0
                      ? 'Ничего не найдено'
                      : 'Показать ${ordersCount(count)}',
                  onPressed: count == 0
                      ? null
                      : () => Navigator.of(context).pop(_filter),
                ),
                CtaGhost(
                  label: 'Сбросить',
                  onPressed: _filter.isEmpty ? null : _reset,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «1 заказ», «3 заказа», «12 заказов».
String ordersCount(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'заказ'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? 'заказа'
      : 'заказов';
  return '$n $word';
}
