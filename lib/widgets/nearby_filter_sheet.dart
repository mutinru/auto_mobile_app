import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/location_service.dart';
import '../state/city_locator.dart';
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
/// [cities] добавляет чип «Другой город…» с поиском по справочнику,
/// [locator] — строку «Определить по геопозиции» в нём (QA 2026-11-05 №9):
/// свой город возвращается, не сбрасывая остальные фильтры.
/// [locateCity] — спросить город по GPS: ответ может прийти, пока шторка
/// открыта, а не определился — заметка с причиной и «Повторить»;
/// [autoCity] — его можно подставить (пользователь город не выбирал). «Сбросить» закрывает шторку и зовёт [onReset] — что такое
/// умолчание, знает экран.
/// Возвращает новый фильтр или null, если закрыли.
Future<NearbyFilter?> showNearbyFilterSheet(
  BuildContext context, {
  required NearbyFilter current,
  required List<String> cityOptions,
  required List<String> brandOptions,
  required Future<int> Function(NearbyFilter) countFor,
  required VoidCallback onReset,
  CityRepository? cities,
  CityLocator? locator,
  Future<Set<String>> Function()? locateCity,
  bool autoCity = false,
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
      locator: locator,
      locateCity: locateCity,
      autoCity: autoCity,
      onReset: onReset,
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
    required this.locator,
    required this.locateCity,
    required this.autoCity,
    required this.onReset,
  });

  final NearbyFilter initial;
  final List<String> cityOptions;
  final List<String> brandOptions;
  final Future<int> Function(NearbyFilter) countFor;
  final CityRepository? cities;
  final CityLocator? locator;

  final Future<Set<String>> Function()? locateCity;
  final bool autoCity;
  final VoidCallback onReset;

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
    _awaitGpsCity();
  }

  /// Город по GPS, пока не пришёл, — «определяем…» у заголовка «Город».
  bool _locating = false;

  /// Известный город по GPS — подпись «по геопозиции».
  Set<String> _gps = const {};

  /// GPS спросили, а город не определился — заметка с причиной.
  bool _gpsFailed = false;
  LocationProblem? _gpsProblem;

  /// Город по GPS приходит в открытую шторку: подставляем его, если
  /// пользователь сам город не выбирал — ни раньше, ни уже в шторке.
  /// Не определился — почему (выключена геолокация, нет доступа), чтобы
  /// заметка сказала, что сделать.
  Future<void> _awaitGpsCity() async {
    final locate = widget.locateCity;
    if (locate == null) return;
    setState(() {
      _locating = true;
      _gpsFailed = false;
      _gpsProblem = null;
    });
    var gps = const <String>{};
    try {
      gps = await locate();
    } catch (_) {
      // без GPS шторка работает как обычно
    }
    LocationProblem? problem;
    if (gps.isEmpty) {
      try {
        problem = await widget.locator?.problem();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      _gps = gps;
      _gpsFailed = gps.isEmpty;
      _gpsProblem = problem;
    });
    if (gps.isEmpty || !widget.autoCity) return;
    if (!setEquals(_filter.cities, widget.initial.cities)) return;
    if (!setEquals(_filter.cities, gps)) {
      _update(_filter.copyWith(cities: gps));
    }
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

  /// «Сбросить» работает всегда и закрывает шторку: сброс делает экран.
  void _reset() {
    Navigator.of(context).pop();
    widget.onReset();
  }

  Future<void> _pickCities() async {
    final next = await showCityPickerSheet(
      context,
      cities: widget.cities!,
      selected: _filter.cities,
      locator: widget.locator,
    );
    if (next != null && mounted) _update(_filter.copyWith(cities: next));
  }

  /// Город по GPS не определился: причина и что сделать — включить
  /// геолокацию, открыть настройки или просто повторить (повтор и
  /// спросит разрешение, если его ещё не давали).
  Widget _gpsNote() {
    final problem = _gpsProblem;
    final (text, action) = switch (problem) {
      LocationProblem.serviceOff => (
        'Геолокация на телефоне выключена — город не определить',
        'Включить',
      ),
      LocationProblem.deniedForever => (
        'Приложению запрещён доступ к геопозиции',
        'Открыть настройки',
      ),
      LocationProblem.denied => (
        'Без доступа к геопозиции город не определить',
        'Разрешить',
      ),
      null => ('Не удалось определить город по геопозиции', 'Повторить'),
    };
    final settings =
        problem == LocationProblem.serviceOff ||
        problem == LocationProblem.deniedForever;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: context.text.fieldNote)),
          const SizedBox(width: 8),
          TextButton(
            onPressed: settings
                ? () => widget.locator?.openSettings(problem!)
                : _awaitGpsCity,
            child: Text(action),
          ),
        ],
      ),
    );
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
                      SectionHead(
                        'Город',
                        extra: _locating
                            ? 'определяем…'
                            : _gps.isNotEmpty && setEquals(_filter.cities, _gps)
                            ? 'по геопозиции'
                            : _gpsFailed && widget.autoCity
                            ? 'не определён'
                            : null,
                      ),
                      // свой город не выбран, а GPS не помог — сказать почему
                      if (_gpsFailed &&
                          widget.autoCity &&
                          _filter.cities.isEmpty)
                        _gpsNote(),
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
                // пустой результат — тоже результат: фильтр «осмотры в
                // Казани» ставят и заранее, вместе с подпиской на пуши
                CtaPrimary(
                  label: count == null || _counting
                      ? 'Показать заказы'
                      : 'Показать ${ordersCount(count)}',
                  onPressed: () => Navigator.of(context).pop(_filter),
                ),
                CtaGhost(
                  label: 'Сбросить',
                  onPressed: _reset,
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
