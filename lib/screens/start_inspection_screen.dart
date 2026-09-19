import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../data/order_repository.dart';
import '../models/inspection_type.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/vin_scanner.dart';

/// Экран 05 макета — «новый осмотр · автомобиль».
/// Заводит кандидата в рамках заказа и стартует по нему осмотр.
class StartInspectionScreen extends StatefulWidget {
  const StartInspectionScreen({
    super.key,
    required this.repository,
    required this.order,
  });

  final OrderRepository repository;
  final Order order;

  @override
  State<StartInspectionScreen> createState() => _StartInspectionScreenState();
}

class _StartInspectionScreenState extends State<StartInspectionScreen> {
  late final _brandController = TextEditingController(text: widget.order.brand);
  late final _modelController = TextEditingController(text: widget.order.model);
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();
  final _mileageController = TextEditingController();

  final _vinController = TextEditingController();
  bool _scanning = false;
  InspectionType _type = InspectionType.full;
  bool _submitting = false;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _mileageController.dispose();
    _vinController.dispose();
    super.dispose();
  }

  /// Тап по видоискателю: снять VIN камерой или ввести руками.
  Future<void> _vinTapped() async {
    final scan = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bg0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.text2),
              title: const Text('Сфотографировать VIN',
                  style: TextStyle(color: AppColors.text1)),
              subtitle: const Text('Наведите на табличку или стекло',
                  style: TextStyle(color: AppColors.text3, fontSize: 11.5)),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.keyboard_alt_outlined,
                  color: AppColors.text2),
              title: const Text('Ввести вручную',
                  style: TextStyle(color: AppColors.text1)),
              onTap: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (scan == null) return;
    if (scan) {
      await _scanVin();
    } else {
      await _editVin();
    }
  }

  /// Снимок + распознавание текста на устройстве (офлайн, ML Kit).
  Future<void> _scanVin() async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
    );
    if (shot == null || !mounted) return;

    setState(() => _scanning = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(shot.path));
      final vin = _extractVin(result.text);
      if (!mounted) return;
      if (vin == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('VIN не распознан — введите вручную')),
        );
        await _editVin();
      } else {
        setState(() => _vinController.text = vin);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось распознать: $e')),
        );
      }
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Ищем в распознанном тексте цепочку из 17 допустимых для VIN знаков.
  /// I, O и Q в VIN не встречаются — это отсеивает ложные срабатывания
  /// на обычных словах.
  static String? _extractVin(String text) {
    final cleaned = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final match = RegExp(r'[A-HJ-NPR-Z0-9]{17}').firstMatch(cleaned);
    return match?.group(0);
  }

  Future<void> _editVin() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg0,
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
            const SectionHead('VIN', extra: '17 символов'),
            FieldBoxInput(
              label: '',
              controller: _vinController,
              hint: 'XW8ZZZ61ZKG0KX24P',
              mono: true,
              inputFormatters: const [VinFormatter()],
            ),
            const SizedBox(height: 6),
            CtaPrimary(label: 'Готово', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _start() async {
    final vin = _vinController.text.trim().toUpperCase();
    if (vin.length != 17) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VIN должен быть из 17 символов')),
      );
      return;
    }
    final mileage = int.tryParse(_mileageController.text.replaceAll(' ', ''));
    if (mileage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите пробег')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final car = await widget.repository.addCar(
        widget.order.id,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        year: int.tryParse(_yearController.text) ?? DateTime.now().year,
        vin: vin,
        licensePlate: _plateController.text.trim().isEmpty
            ? null
            : _plateController.text.trim(),
        mileageKm: mileage,
      );
      await widget.repository.startInspection(widget.order.id, car.id, type: _type);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось начать осмотр: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vin = _vinController.text.trim().toUpperCase();

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
                  SectionHead('VIN', extra: vin.length == 17 ? 'распознан' : 'нужен ввод'),
                  VinScanner(
                    vin: _scanning
                        ? 'распознаём…'
                        : (vin.isEmpty ? 'нажмите, чтобы снять или ввести' : vin),
                    onTap: _scanning ? null : _vinTapped,
                  ),

                  const SizedBox(height: 22),
                  const SectionHead('Данные', extra: 'из заказа'),
                  FieldBox(
                    label: 'Марка и модель',
                    value: '${_brandController.text} ${_modelController.text}'.trim(),
                    trailing: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 15,
                      color: AppColors.text3,
                    ),
                    onTap: () {},
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
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FieldBoxInput(
                          label: 'Пробег',
                          controller: _mileageController,
                          hint: '127 450',
                          mono: true,
                          unit: 'км',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  FieldBoxInput(
                    label: 'Год выпуска',
                    controller: _yearController,
                    hint: '${widget.order.yearFrom ?? 2019}',
                    mono: true,
                    keyboardType: TextInputType.number,
                  ),
                  // «Клиент» из макета не нужен: осмотр всегда идёт внутри
                  // заказа, заказчик уже известен
                  FieldBox(
                    label: 'Клиент',
                    value: widget.order.customer.name,
                  ),

                  const SizedBox(height: 22),
                  const SectionHead('Тип осмотра'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in InspectionType.values)
                        AppChip(
                          label: t.label,
                          on: _type == t,
                          onTap: () => setState(() => _type = t),
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
                CtaGhost(label: 'Сохранить как черновик', onPressed: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
