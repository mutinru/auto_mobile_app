import 'package:flutter/material.dart';

import '../data/api_exception.dart';
import '../data/car_catalog_repository.dart';
import '../data/order_repository.dart';
import '../models/inspection_type.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../util/car_input.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/car_picker_sheet.dart';
import '../widgets/odometer_capture.dart';
import '../widgets/phone_input.dart';
import '../widgets/seller_phone_sheet.dart';
import '../widgets/vin_capture.dart';

/// Экран 05 макета — «новый осмотр · автомобиль».
/// Заводит кандидата подбора: сервер создаёт машину вместе с осмотром.
/// Закрывается с созданной машиной ([OrderCar.inspectionId] уже есть) —
/// карточка заказа сразу открывает осмотр.
class StartInspectionScreen extends StatefulWidget {
  const StartInspectionScreen({
    super.key,
    required this.repository,
    required this.catalog,
    required this.order,
    this.vin,
    this.odometer,
  });

  final OrderRepository repository;
  final CarCatalogRepository catalog;
  final Order order;

  /// Блок VIN снаружи — тестам, чтобы подложить снимок без камеры.
  @visibleForTesting
  final VinCaptureController? vin;

  /// Блок пробега снаружи — по той же причине.
  @visibleForTesting
  final OdometerCaptureController? odometer;

  @override
  State<StartInspectionScreen> createState() => _StartInspectionScreenState();
}

class _StartInspectionScreenState extends State<StartInspectionScreen> {
  late final _brandController = TextEditingController(text: widget.order.brand);
  late final _modelController = TextEditingController(text: widget.order.model);
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();
  final _sellerController = TextEditingController();

  late final _vin = widget.vin ?? VinCaptureController();
  late final _odometer = widget.odometer ?? OdometerCaptureController();
  bool _submitting = false;

  /// Ошибки по полям — ключи как у бекенда (`OrderCarController::store`),
  /// чтобы 422 сервера легли на те же поля.
  Map<String, String> _errors = {};

  /// Поля, у которых экран умеет показать ошибку; прочие — строкой.
  /// Ошибки VIN (`vin`, `vin_kind`, `vin_photo`) уходят в блок VIN,
  /// пробега (`mileage_km`, `odometer_photo`) — в блок одометра.
  static const _fieldKeys = {
    'brand',
    'model',
    'year',
    'license_plate',
    'seller_phone',
  };

  @override
  void initState() {
    super.initState();
    // поправили поле — его ошибка уходит, остальные остаются
    void clearOnEdit(TextEditingController c, List<String> keys) =>
        c.addListener(() {
          if (keys.any(_errors.containsKey)) {
            setState(
              () =>
                  _errors = {..._errors}
                    ..removeWhere((k, _) => keys.contains(k)),
            );
          }
        });
    clearOnEdit(_brandController, ['brand', 'model']);
    clearOnEdit(_modelController, ['brand', 'model']);
    clearOnEdit(_yearController, ['year']);
    clearOnEdit(_plateController, ['license_plate']);
    clearOnEdit(_sellerController, ['seller_phone']);
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _sellerController.dispose();
    if (widget.vin == null) _vin.dispose();
    if (widget.odometer == null) _odometer.dispose();
    super.dispose();
  }

  /// Кандидат может отличаться от заказа: искали Camry, а с заказчиком
  /// договорились смотреть RAV4. По умолчанию — марка и модель заказа.
  Future<void> _pickCar() async {
    final choice = await showCarPickerSheet(
      context,
      catalog: widget.catalog,
      initialBrand: _brandController.text,
      initialModel: _modelController.text,
    );
    if (choice == null) return;
    setState(() {
      _brandController.text = choice.brand;
      _modelController.text = choice.model;
    });
  }

  Future<void> _start() async {
    final vin = _vin.validate();
    final odometer = _odometer.validate();
    // год не подставляем молча: машина в отчёте должна быть с настоящим годом
    final year = int.tryParse(_yearController.text);

    // все ошибки разом — исполнитель видит сразу всё, что не заполнено
    final errors = <String, String>{
      if (_brandController.text.trim().isEmpty ||
          _modelController.text.trim().isEmpty)
        'brand': 'Выберите марку и модель',
      if (year == null)
        'year': 'Укажите год выпуска'
      else if (yearProblem(year) != null)
        'year': yearProblem(year)!,
      'seller_phone': ?sellerPhoneProblem(_sellerController.text),
    };
    setState(() => _errors = errors);
    if (errors.isNotEmpty || vin == null || odometer == null) return;

    setState(() => _submitting = true);
    try {
      final car = await widget.repository.addCar(
        widget.order.id,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        year: year!,
        vin: vin,
        licensePlate: _plateController.text.trim().isEmpty
            ? null
            : _plateController.text.trim(),
        odometer: odometer,
        sellerPhone: phoneFromMask(_sellerController.text),
      );
      if (mounted) Navigator.of(context).pop(car);
    } on ApiException catch (e) {
      // 422 по полям (машина уже в подборе и т. п.) — к своим полям,
      // остальное строкой
      final errors = e.fieldErrors;
      final vinError =
          errors['vin'] ?? errors['vin_photo'] ?? errors['vin_kind'];
      final fields = {
        for (final f in errors.entries)
          if (_fieldKeys.contains(f.key)) f.key: f.value,
      };
      final odometerError = errors['mileage_km'] ?? errors['odometer_photo'];
      if (vinError != null) _vin.setError(vinError);
      if (odometerError != null) _odometer.setError(odometerError);
      if (mounted && fields.isNotEmpty) {
        setState(() => _errors = fields);
      } else if (mounted && vinError == null && odometerError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorText(e))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось начать осмотр: ${apiErrorText(e)}'),
          ),
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
              title: 'Автомобиль',
              eyebrow: 'новый осмотр',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                children: [
                  VinCapture(controller: _vin),
                  const SizedBox(height: 22),
                  OdometerCapture(controller: _odometer),

                  const SizedBox(height: 22),
                  const SectionHead('Данные', extra: 'из заказа'),
                  FieldBox(
                    label: 'Марка и модель',
                    value: '${_brandController.text} ${_modelController.text}'
                        .trim(),
                    trailing: Icon(
                      Icons.keyboard_arrow_down,
                      size: 15,
                      color: context.colors.text3,
                    ),
                    onTap: _pickCar,
                    error: _errors['brand'] ?? _errors['model'],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: FieldBoxInput(
                          label: 'Госномер',
                          controller: _plateController,
                          hint: 'А432ВС',
                          mono: true,
                          optional: true,
                          error: _errors['license_plate'],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FieldBoxInput(
                          label: 'Год выпуска',
                          controller: _yearController,
                          hint: '${widget.order.yearFrom ?? 2019}',
                          mono: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: digitsOnly,
                          maxLength: 4,
                          error: _errors['year'],
                        ),
                      ),
                    ],
                  ),
                  // «Клиент» из макета не нужен: осмотр всегда идёт внутри
                  // заказа, заказчик уже известен
                  FieldBox(
                    label: 'Клиент',
                    value: widget.order.customer.name,
                  ),

                  const SizedBox(height: 22),
                  // заметка подборщика: заказчику сервер номер не отдаёт
                  const SectionHead('Продавец', extra: 'только для вас'),
                  PhoneField(controller: _sellerController),
                  FieldError(_errors['seller_phone']),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(sellerPhoneNote, style: context.text.fieldNote),
                  ),

                  const SizedBox(height: 22),
                  const SectionHead('Тип осмотра'),
                  // Пока доступен только полный: бекенд при любом типе создаёт
                  // одни и те же 17 пунктов. Остальные чипы видны, но не
                  // выбираются — до настоящей реализации.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in InspectionType.values)
                        AppChip(
                          label: t.label,
                          on: t == InspectionType.full,
                          enabled: t == InspectionType.full,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            BottomCta(
              children: [
                CtaPrimary(
                  label: 'Начать осмотр',
                  trailingIcon: Icons.arrow_forward,
                  loading: _submitting,
                  onPressed: _start,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
