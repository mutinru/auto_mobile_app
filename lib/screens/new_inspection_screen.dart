import 'dart:async';

import 'package:flutter/material.dart';

import '../data/address_repository.dart';
import '../models/car_catalog.dart';
import '../models/order.dart';
import '../models/time_slot.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../util/listing_url.dart';
import '../widgets/address_field.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/car_picker_sheet.dart';
import '../widgets/city_picker_sheet.dart';
import '../widgets/inspection_when_picker.dart';
import '../widgets/phone_input.dart';
import '../widgets/price_box.dart';

/// Кадр 03 макета order-types.html — «новый осмотр». Вместо бюджета и
/// городов поиска: ссылка или VIN, город и адрес, дата и цена заказчика.
///
/// [basedOn] заполняет город, адрес, время и цену из прошлого осмотра — это
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

  /// Город осмотра: по геопозиции, из прошлого осмотра или из листа.
  CityChoice? _city;

  /// Пользователь уже выбирал город — автоопределение его не перетирает.
  bool _cityTouched = false;

  /// Точка выбранной подсказки адреса; null — свой текст, сервер возьмёт
  /// центр города.
  AddressPoint? _point;

  late InspectionWhen _when;
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

  @override
  void initState() {
    super.initState();
    _listingController.addListener(_onListingChanged);
    final based = widget.basedOn;
    final now = DateTime.now();
    _when = InspectionWhen(
      date: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
      slot: based?.timeSlot ?? TimeSlot.day,
      exactTime: parseInspectTime(based?.inspectTime),
    );
    _price = based?.askingPrice ?? 3500;
    if (based != null) {
      // точку прошлого осмотра не переносим: у чужих она огрублена, а
      // адрес могут поправить — сервер возьмёт центр города
      if (based.cities.isNotEmpty) _city = CityChoice(based.cities.first);
      _addressController.text = based.address ?? '';
      _phoneController.text = _sellerDigits(based.sellerPhone ?? '');
    }
    if (_city == null) _detectCity();
  }

  Future<void> _detectCity() async {
    final city = await widget.store.locator?.detect();
    if (city == null || !mounted || _cityTouched) return;
    setState(() => _city = CityChoice(city.name, city: city));
  }

  Future<void> _pickCity() async {
    final choice = await showSingleCityPickerSheet(
      context,
      cities: widget.store.cities,
      selected: _city?.name,
      locator: widget.store.locator,
    );
    if (choice == null || !mounted) return;
    _cityTouched = true;
    // адрес из подсказки — про прежний город, свой текст оставляем;
    // точку сбросит само поле (onPoint(null))
    if (choice.name != _city?.name && _point != null) _addressController.clear();
    setState(() => _city = choice);
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

  /// «+79161234567» прежнего заказа → «916 123 45 67» для поля с маской.
  static String _sellerDigits(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
      digits = digits.substring(1);
    }
    return const PhoneMask()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: digits))
        .text;
  }

  Future<void> _submit() async {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    final year = int.tryParse(_yearController.text.trim());
    // пробег необязателен: это слова продавца, их и проверяет осмотр
    final mileageText = _mileageController.text.replaceAll(' ', '');
    final mileage = int.tryParse(mileageText);
    final address = _addressController.text.trim();
    final vin = _vinController.text.trim();
    final listing = _listingController.text.trim();
    // поле с маской «+7 | 900 123 45 67» — здесь 10 цифр без кода страны
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    final problem = switch (null) {
      _ when brand.isEmpty || model.isEmpty => 'Укажите марку и модель',
      _ when year == null => 'Укажите год',
      _ when yearProblem(year) != null => yearProblem(year),
      _ when mileageText.isNotEmpty && mileage == null => 'Пробег — числом, в км',
      _ when _city == null => 'Укажите город осмотра',
      _ when address.isEmpty => 'Укажите адрес осмотра',
      _ when vin.isNotEmpty && vin.length != 17 => 'VIN — ровно 17 символов',
      _ when listing.isNotEmpty && normalizeListingUrl(listing) == null =>
        'Похоже, это не ссылка на объявление',
      _ when phoneDigits.isNotEmpty && phoneDigits.length != 10 =>
        'Телефон продавца — 10 цифр после +7',
      _ when PriceBox.problem(_price) != null => PriceBox.problem(_price),
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
        mileageKm: mileage,
        city: _city!.name,
        cityId: _city!.city?.id,
        address: address,
        lat: _point?.lat,
        lon: _point?.lon,
        addressPrecision: _point?.precision,
        inspectOn: _when.date,
        timeSlot: _when.slot,
        askingPrice: _price,
        inspectTime: _when.inspectTime,
        vin: vin.isEmpty ? null : vin,
        listingUrl: listing,
        sellerPhone: phoneDigits.isEmpty ? null : '+7$phoneDigits',
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
                    maxLength: 500,
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
                          inputFormatters: digitsOnly,
                          maxLength: 4,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FieldBoxInput(
                          label: 'Пробег',
                          controller: _mileageController,
                          hint: '112000',
                          mono: true,
                          unit: 'км',
                          keyboardType: TextInputType.number,
                          inputFormatters: digitsOnly,
                          maxLength: 7,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  const SectionHead('Где и когда'),
                  FieldBox(
                    label: 'Город',
                    value: _city?.name ?? 'Выбрать город',
                    placeholder: _city == null,
                    onTap: _pickCity,
                    trailing: Icon(
                      Icons.keyboard_arrow_down,
                      size: 15,
                      color: context.colors.text3,
                    ),
                  ),
                  AddressField(
                    controller: _addressController,
                    addresses: widget.store.addresses,
                    cityId: _city?.city?.id,
                    onPoint: (point) => setState(() => _point = point),
                  ),
                  InspectionWhenPicker(
                    value: _when,
                    onChanged: (when) => setState(() => _when = when),
                  ),

                  const SizedBox(height: 22),
                  const SectionHead('Продавец', extra: 'увидит только выбранный'),
                  // та же маска, что на входе: «+7 | 900 123 45 67»
                  PhoneField(controller: _phoneController),

                  const SizedBox(height: 12),
                  const SectionHead('Ваша цена'),
                  PriceBox(value: _price, onChanged: (v) => setState(() => _price = v)),
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
