import 'dart:async';

import 'package:flutter/material.dart';

import '../models/car_catalog.dart';
import '../models/order.dart';
import '../models/time_slot.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/listing_url.dart';
import '../util/ru_date.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/car_picker_sheet.dart';

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

  /// Подсказка по ссылке: догадка сервера и адрес, к которому она относится.
  /// Отклонённые ✕ адреса больше не предлагаем.
  ListingGuess? _guess;
  String? _guessUrl;
  final _dismissedUrls = <String>{};
  Timer? _guessDebounce;

  /// Пустое поле — строка «Подставим марку…»; не-ссылка — предупреждение.
  bool _listingEmpty = true;
  bool _listingInvalid = false;

  /// Шаг цены из макета (.price-step).
  static const _priceStep = 500;

  @override
  void initState() {
    super.initState();
    _listingController.addListener(_onListingChanged);
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
    _guessDebounce?.cancel();
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

  /// Спрашиваем сервер, когда ввод замер на полсекунды: вставка ссылки —
  /// одно событие, а печать руками не должна слать запрос на каждую букву.
  void _onListingChanged() {
    final url = _listingController.text.trim();
    if (url == _guessUrl) return;
    _guessDebounce?.cancel();
    if (_guess != null || _listingInvalid || _listingEmpty != url.isEmpty) {
      setState(() {
        _guess = null;
        _listingInvalid = false;
        _listingEmpty = url.isEmpty;
      });
    }
    _guessUrl = url;
    if (url.isEmpty) return;
    // и предупреждение, и подсказка — после паузы, а не на каждую букву
    _guessDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (normalizeListingUrl(url) == null) {
        setState(() => _listingInvalid = true);
      } else if (!_dismissedUrls.contains(url)) {
        _guessFor(url);
      }
    });
  }

  Future<void> _guessFor(String url) async {
    ListingGuess? guess;
    try {
      guess = await widget.store.catalog.guessFromListing(url);
    } catch (_) {
      // подсказка необязательна: без сети просто не показываем её
      return;
    }
    // пока ждали ответ, ссылку могли поменять — догадка уже не про неё
    if (!mounted || url != _guessUrl) return;
    setState(() => _guess = guess);
  }

  /// Догадка уже в полях — предлагать нечего.
  bool _guessApplied(ListingGuess g) =>
      _brandController.text.trim() == g.make.name &&
      (g.model == null || _modelController.text.trim() == g.model!.name) &&
      (g.year == null || _yearController.text.trim() == '${g.year}');

  void _applyGuess(ListingGuess g) {
    setState(() {
      if (_brandController.text.trim() != g.make.name) _modelController.clear();
      _brandController.text = g.make.name;
      if (g.model != null) _modelController.text = g.model!.name;
      if (g.year != null) _yearController.text = '${g.year}';
      _guess = null;
    });
  }

  void _dismissGuess() {
    setState(() {
      if (_guessUrl != null) _dismissedUrls.add(_guessUrl!);
      _guess = null;
    });
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
    final listing = _listingController.text.trim();

    final problem = switch (null) {
      _ when brand.isEmpty || model.isEmpty => 'Укажите марку и модель',
      _ when year == null => 'Укажите год',
      _ when mileage == null => 'Укажите пробег',
      _ when address.isEmpty => 'Укажите адрес осмотра',
      _ when vin.isNotEmpty && vin.length != 17 => 'VIN — ровно 17 символов',
      _ when listing.isNotEmpty && normalizeListingUrl(listing) == null =>
        'Похоже, это не ссылка на объявление',
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
        listingUrl: listing,
        sellerPhone: _phoneController.text.trim(),
      );
      // созданный заказ — результатом: витрина по нему открывает «Мои заказы»
      if (mounted) Navigator.of(context).pop(order);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось разместить осмотр: ${apiErrorText(e)}')),
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
                    hint: 'Ссылка с Авито, Авто.ру или Дрома',
                    mono: true,
                  ),
                  if (_listingInvalid)
                    _FieldNote('Похоже, это не ссылка', error: true)
                  else if (_listingEmpty)
                    const _FieldNote('Подставим марку, модель и год'),
                  if (_guess case final guess? when !_guessApplied(guess))
                    _ListingGuessCard(
                      guess: guess,
                      replace: _brandController.text.trim().isNotEmpty,
                      onApply: () => _applyGuess(guess),
                      onDismiss: _dismissGuess,
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

/// .field-hint — строка под полем: подсказка или (error) предупреждение.
class _FieldNote extends StatelessWidget {
  const _FieldNote(this.text, {this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // поле уже отступает на 10 снизу — подтягиваем строку к нему
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Transform.translate(
        offset: const Offset(0, -4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            height: 1.45,
            color: error ? context.colors.statusDefect : context.colors.text3,
          ),
        ),
      ),
    );
  }
}

/// .guess — «Похоже, это Toyota Camry, 2019» под полем ссылки: поля
/// заполняются только по кнопке.
class _ListingGuessCard extends StatelessWidget {
  const _ListingGuessCard({
    required this.guess,
    required this.replace,
    required this.onApply,
    required this.onDismiss,
  });

  final ListingGuess guess;

  /// Поля уже заполнены чем-то другим — кнопка «Заменить», а не «Заполнить».
  final bool replace;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.statusDone.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 16, color: context.colors.statusDone),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Похоже, это ',
                style: TextStyle(fontSize: 13, color: context.colors.text2),
                children: [
                  TextSpan(
                    text: guess.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.colors.text1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: onApply,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.statusDone,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              replace ? 'Заменить' : 'Заполнить',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Не то',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 16, color: context.colors.text3),
          ),
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
