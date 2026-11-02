import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/city_repository.dart';
import '../models/nearby_filter.dart';
import '../models/order_kind.dart';
import '../theme/app_colors.dart';
import 'app_ui.dart';
import 'city_picker_sheet.dart';

/// Шторка фильтров «Заказов рядом» — открывается кнопкой с ползунками в
/// шапке. Варианты городов и марок — [cityOptions] и [brandOptions]
/// (фасеты сервера по всем свободным). [countFor] спрашивает у сервера,
/// сколько заказов покажет фильтр, — для кнопки «Показать N заказов».
/// [cities] добавляет чип «Другой город…» с поиском по справочнику.
/// Возвращает новый фильтр или null, если закрыли.
Future<NearbyFilter?> showNearbyFilterSheet(
  BuildContext context, {
  required NearbyFilter current,
  required List<String> cityOptions,
  required List<String> brandOptions,
  required Future<int> Function(NearbyFilter) countFor,
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
      cityOptions: cityOptions,
      brandOptions: brandOptions,
      countFor: countFor,
      cities: cities,
    ),
  );
}

class _NearbyFilterSheet extends StatefulWidget {
  const _NearbyFilterSheet({
    required this.initial,
    required this.cityOptions,
    required this.brandOptions,
    required this.countFor,
    required this.cities,
  });

  final NearbyFilter initial;
  final List<String> cityOptions;
  final List<String> brandOptions;
  final Future<int> Function(NearbyFilter) countFor;
  final CityRepository? cities;

  @override
  State<_NearbyFilterSheet> createState() => _NearbyFilterSheetState();
}

class _NearbyFilterSheetState extends State<_NearbyFilterSheet> {
  late NearbyFilter _filter = widget.initial;
  late final _priceController = TextEditingController(
    text: widget.initial.minPrice?.toString() ?? '',
  );

  /// Сколько заказов покажет фильтр; null — ещё не знаем или сервер не
  /// ответил (тогда кнопка без числа, но не заблокирована).
  int? _count;
  bool _counting = true;
  Timer? _countDelay;

  /// Номер запроса счётчика: поздний ответ на старый фильтр не нужен.
  int _countRequest = 0;

  /// Сортировка на число не влияет — по ней счётчик не переспрашиваем.
  String get _countKey => _filter.copyWith(sort: NearbySort.newest).toQuery();
  late String _countedKey;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(() {
      final price = int.tryParse(_priceController.text);
      if (price != _filter.minPrice) {
        _update(_filter.copyWith(minPrice: () => price));
      }
    });
    _countedKey = _countKey;
    _recount();
  }

  @override
  void dispose() {
    _countDelay?.cancel();
    _priceController.dispose();
    super.dispose();
  }

  void _update(NearbyFilter next) {
    setState(() => _filter = next);
    if (_countKey == _countedKey) return;
    _countedKey = _countKey;
    // цена меняется на каждый символ — спрашиваем, когда ввод затих
    setState(() => _counting = true);
    _countDelay?.cancel();
    _countDelay = Timer(const Duration(milliseconds: 300), _recount);
  }

  Future<void> _recount() async {
    final request = ++_countRequest;
    int? count;
    try {
      count = await widget.countFor(_filter);
    } catch (_) {
      // счётчик — подсказка: без него кнопка просто без числа
    }
    if (!mounted || request != _countRequest) return;
    setState(() {
      _count = count;
      _counting = false;
    });
  }

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
    final cities = {...widget.cityOptions, ..._filter.cities}.toList()..sort();
    final brands = {...widget.brandOptions, ..._filter.brands}.toList()..sort();
    final count = _count;
    // ноль блокирует кнопку, только когда он про текущий фильтр
    final nothing = count == 0 && !_counting;
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
                  label: nothing
                      ? 'Ничего не найдено'
                      : count == null || count == 0
                      ? 'Показать заказы'
                      : 'Показать ${ordersCount(count)}',
                  onPressed: nothing
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
