import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/time_slot.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/ru_date.dart';
import '../widgets/app_ui.dart';

/// Кадр 03 макета order-types.html — «новый осмотр». Вместо бюджета и
/// городов поиска: ссылка или VIN, адрес, дата и цена заказчика.
///
/// [basedOn] заполняет адрес, время и цену из прошлого осмотра — это
/// «Осмотреть другую машину» из кадра 05; машина всегда новая.
class NewInspectionScreen extends StatefulWidget {
  const NewInspectionScreen({super.key, required this.store, this.basedOn});

  final OrderStore store;
  final Order? basedOn;

  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  final _listingController = TextEditingController();
  final _vinController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _mileageController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  late DateTime _date;
  late TimeSlot _slot;
  TimeOfDay? _exactTime;
  late int _price;
  bool _submitting = false;

  /// Шаг цены из макета (.price-step).
  static const _priceStep = 500;

  @override
  void initState() {
    super.initState();
    final based = widget.basedOn;
    _date = DateTime.now().add(const Duration(days: 1));
    _slot = based?.timeSlot ?? TimeSlot.day;
    _price = based?.askingPrice ?? 3500;
    if (based != null) {
      _addressController.text = based.address ?? '';
      _phoneController.text = based.sellerPhone ?? '';
      if (based.timeSlot == TimeSlot.exact && based.inspectTime != null) {
        final parts = based.inspectTime!.split(':');
        _exactTime = TimeOfDay(
          hour: int.tryParse(parts.first) ?? 12,
          minute: int.tryParse(parts.last) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _listingController.dispose();
    _vinController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _carLabel {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    if (brand.isEmpty && model.isEmpty) return 'Выбрать марку и модель';
    return [brand, model].where((s) => s.isNotEmpty).join(' ');
  }

  Future<void> _pickCar() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.bg0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHead('Марка и модель'),
            FieldBoxInput(label: 'Марка', controller: _brandController, hint: 'BMW'),
            FieldBoxInput(label: 'Модель', controller: _modelController, hint: 'X3'),
            const SizedBox(height: 6),
            CtaPrimary(label: 'Готово', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
    setState(() {});
  }

  /// Три ближайших дня чипами, всё остальное — через календарь.
  List<DateTime> get _dateOptions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [today, today.add(const Duration(days: 1)), today.add(const Duration(days: 2))];
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _exactTime ?? const TimeOfDay(hour: 16, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _exactTime = picked;
        _slot = TimeSlot.exact;
      });
    }
  }

  String get _exactTimeLabel {
    final t = _exactTime;
    if (t == null) return TimeSlot.exact.label;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    final year = int.tryParse(_yearController.text.trim());
    final mileage = int.tryParse(_mileageController.text.replaceAll(' ', ''));
    final address = _addressController.text.trim();
    final vin = _vinController.text.trim();

    final problem = switch (null) {
      _ when brand.isEmpty || model.isEmpty => 'Укажите марку и модель',
      _ when year == null => 'Укажите год',
      _ when mileage == null => 'Укажите пробег',
      _ when address.isEmpty => 'Укажите адрес осмотра',
      _ when vin.isNotEmpty && vin.length != 17 => 'VIN — ровно 17 символов',
      _ => null,
    };
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    setState(() => _submitting = true);
    try {
      final order = await widget.store.createInspectionOrder(
        brand: brand,
        model: model,
        year: year!,
        mileageKm: mileage!,
        address: address,
        inspectOn: _date,
        timeSlot: _slot,
        askingPrice: _price,
        inspectTime: _slot == TimeSlot.exact ? _exactTimeLabel : null,
        vin: vin.isEmpty ? null : vin,
        listingUrl: _listingController.text.trim(),
        sellerPhone: _phoneController.text.trim(),
      );
      // созданный заказ — результатом: витрина по нему открывает «Мои заказы»
      if (mounted) Navigator.of(context).pop(order);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось разместить осмотр: $e')),
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
            DetailHead(
              title: 'Что осмотреть',
              eyebrow: 'осмотр',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                children: [
                  FieldBoxInput(
                    label: 'Ссылка на объявление',
                    controller: _listingController,
                    hint: 'auto.ru/cars/used/sale/…',
                    mono: true,
                  ),
                  // .or — разделитель «или»
                  const _OrDivider(),
                  FieldBoxInput(
                    label: 'VIN',
                    controller: _vinController,
                    hint: '17 символов',
                    mono: true,
                    inputFormatters: const [VinFormatter()],
                  ),

                  const SizedBox(height: 22),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: FieldBoxInput(
                          label: 'Год',
                          controller: _yearController,
                          hint: '2017',
                          mono: true,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FieldBoxInput(
                          label: 'Пробег',
                          controller: _mileageController,
                          hint: '112 000',
                          mono: true,
                          unit: 'км',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  const SectionHead('Где и когда'),
                  FieldBoxInput(
                    label: '',
                    controller: _addressController,
                    hint: 'Город, улица, дом',
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final option in _dateOptions)
                        AppChip(
                          label: shortDate(option),
                          on: _sameDay(_date, option),
                          activeColor: context.colors.statusDone,
                          onTap: () => setState(() => _date = option),
                        ),
                      AppChip(
                        label: _dateOptions.any((d) => _sameDay(_date, d))
                            ? 'Другая дата'
                            : shortDate(_date),
                        on: !_dateOptions.any((d) => _sameDay(_date, d)),
                        activeColor: context.colors.statusDone,
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final slot in TimeSlot.values)
                        AppChip(
                          label: slot == TimeSlot.exact ? _exactTimeLabel : slot.label,
                          on: _slot == slot,
                          activeColor: context.colors.statusDone,
                          onTap: () => slot == TimeSlot.exact
                              ? _pickTime()
                              : setState(() => _slot = slot),
                        ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  const SectionHead('Продавец', extra: 'увидит только выбранный'),
                  FieldBoxInput(
                    label: '',
                    controller: _phoneController,
                    hint: '+7 · телефон продавца',
                    mono: true,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 12),
                  const SectionHead('Ваша цена'),
                  _PriceBox(
                    value: _price,
                    onMinus: _price > _priceStep
                        ? () => setState(() => _price -= _priceStep)
                        : null,
                    onPlus: () => setState(() => _price += _priceStep),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Исполнители видят вашу цену и могут предложить свою. Выбираете вы.',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.text3,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            BottomCta(
              children: [
                CtaPrimary(
                  label: 'Разместить осмотр',
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

/// .or — «или» между ссылкой и VIN.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: context.colors.line, height: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'или',
              style: TextStyle(fontSize: 10.5, color: context.colors.text3),
            ),
          ),
          Expanded(child: Divider(color: context.colors.line, height: 1)),
        ],
      ),
    );
  }
}

/// .price-box — цена заказчика с шагом ±500 ₽.
class _PriceBox extends StatelessWidget {
  const _PriceBox({required this.value, required this.onMinus, required this.onPlus});

  final int value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${money(value)} ₽',
              style: TextStyle(
                fontFamily: AppTheme.monoFamily,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.66,
                color: context.colors.text1,
              ),
            ),
          ),
          _PriceStep(icon: Icons.remove, onTap: onMinus),
          const SizedBox(width: 6),
          _PriceStep(icon: Icons.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class _PriceStep extends StatelessWidget {
  const _PriceStep({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: context.colors.bg3,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap == null ? context.colors.text3 : context.colors.text1,
        ),
      ),
    );
  }
}
