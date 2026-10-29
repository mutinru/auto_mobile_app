import 'package:flutter/material.dart';

import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/car_picker_sheet.dart';
import '../widgets/city_picker_sheet.dart';

/// Экран 03 макета — «новый заказ · что искать».
const _requirementOptions = [
  'Без ДТП',
  '1–2 владельца',
  'Автомат',
  'Не такси',
  'Сервисная книжка',
];

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key, required this.store});

  final OrderStore store;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _mileageController = TextEditingController();
  final _commentController = TextEditingController();

  RangeValues _budget = const RangeValues(1800000, 2400000);
  /// Пусто, пока не определили по геопозиции или не выбрали в листе.
  Set<String> _cities = {};

  /// Пользователь уже менял города — автоопределение их не перетирает.
  bool _citiesTouched = false;
  final Set<String> _requirements = {'Без ДТП'};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _detectCity();
  }

  Future<void> _detectCity() async {
    final city = await widget.store.locator?.detect();
    if (city == null || !mounted || _citiesTouched) return;
    setState(() => _cities = {city.name});
  }

  Future<void> _pickCities() async {
    final next = await showCityPickerSheet(
      context,
      cities: widget.store.cities,
      selected: _cities,
      locator: widget.store.locator,
    );
    if (next == null) return;
    setState(() {
      _cities = next;
      _citiesTouched = true;
    });
  }

  void _removeCity(String city) {
    setState(() {
      _cities = {..._cities}..remove(city);
      _citiesTouched = true;
    });
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String get _carLabel {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    if (brand.isEmpty && model.isEmpty) return 'Выбрать марку и модель';
    return [brand, model].where((s) => s.isNotEmpty).join(' ');
  }

  Future<void> _pickCar() async {
    final choice = await showCarPickerSheet(
      context,
      catalog: widget.store.catalog,
      initialBrand: _brandController.text,
      initialModel: _modelController.text,
    );
    if (choice == null) return;
    setState(() {
      _brandController.text = choice.brand;
      _modelController.text = choice.model;
    });
  }

  Future<void> _submit() async {
    if (_brandController.text.trim().isEmpty || _modelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите марку и модель')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final order = await widget.store.createOrder(
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        yearFrom: int.tryParse(_yearController.text),
        mileageTo: int.tryParse(_mileageController.text.replaceAll(' ', '')),
        budgetMin: _budget.start.round(),
        budgetMax: _budget.end.round(),
        cities: _cities.toList(),
        requirements: _requirements.toList(),
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      // созданный заказ — результатом: витрина по нему открывает «Мои заказы»
      if (mounted) Navigator.of(context).pop(order);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать заказ: ${apiErrorText(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // В макете здесь «шаг 1 из 2» и кнопка «Далее · выбрать
            // подборщика», но шаг 2 не нарисован: подборщик выбирается
            // позже, из откликов в карточке заказа. Поэтому надстрочника
            // нет, а кнопка названа по тому, что реально делает.
            DetailHead(
              title: 'Что искать',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                // .scroll-body { padding: 4px 22px 18px }
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                children: [
                  const SectionHead('Автомобиль'),
                  FieldBox(
                    label: 'Марка и модель',
                    value: _carLabel,
                    placeholder: _brandController.text.trim().isEmpty,
                    onTap: _pickCar,
                    trailing: Icon(
                      Icons.keyboard_arrow_down,
                      size: 15,
                      color: context.colors.text3,
                    ),
                  ),
                  // .field-pair — две колонки
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: FieldBoxInput(
                          label: 'Год от',
                          controller: _yearController,
                          hint: '2018',
                          mono: true,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FieldBoxInput(
                          label: 'Пробег до',
                          controller: _mileageController,
                          hint: '120 000',
                          mono: true,
                          unit: 'км',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  const SectionHead('Бюджет', extra: 'с учётом торга'),
                  // .budget-val
                  Text(
                    '${money(_budget.start.round())} — ${money(_budget.end.round())} ₽',
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.36,
                      color: context.colors.text1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // .slider — 4px дорожка, зелёная заливка, белые ручки 16px
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      activeTrackColor: context.colors.statusDone,
                      inactiveTrackColor: context.colors.bg1,
                      thumbColor: context.colors.text1,
                      overlayColor: context.colors.statusDone.withValues(alpha: 0.12),
                      // в макете дорожка гладкая — деления не показываем
                      activeTickMarkColor: Colors.transparent,
                      inactiveTickMarkColor: Colors.transparent,
                      rangeThumbShape: const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      trackShape: const RectangularSliderTrackShape(),
                      showValueIndicator: ShowValueIndicator.never,
                    ),
                    child: RangeSlider(
                      values: _budget,
                      // 300 тыс. — 5 млн шагом по 100 тыс.: типичный бюджет
                      // ложится на середину дорожки, как в макете
                      min: 300000,
                      max: 5000000,
                      divisions: 47,
                      onChanged: (v) => setState(() => _budget = v),
                    ),
                  ),

                  const SizedBox(height: 22),
                  const SectionHead('Город поиска'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // выбранные — тап снимает; остальное в листе
                      for (final c in _cities)
                        AppChip(label: '$c  ×', on: true, onTap: () => _removeCity(c)),
                      AppChip(
                        label: _cities.isEmpty ? '+ Выбрать город' : '+ Ещё город',
                        on: false,
                        onTap: _pickCities,
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  SectionHead('Важно', extra: 'выбрано ${_requirements.length}'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in _requirementOptions)
                        AppChip(
                          label: r,
                          on: _requirements.contains(r),
                          onTap: () => setState(() => _requirements.contains(r)
                              ? _requirements.remove(r)
                              : _requirements.add(r)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  const SectionHead('Комментарий'),
                  FieldBoxInput(
                    label: '',
                    controller: _commentController,
                    hint: 'Пожелания к цвету, комплектации, срокам…',
                    maxLines: 3,
                    minHeight: 64,
                  ),
                ],
              ),
            ),
            BottomCta(
              children: [
                CtaPrimary(
                  label: 'Разместить заказ',
                  loading: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
