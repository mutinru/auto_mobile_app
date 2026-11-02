import 'package:flutter/material.dart';

import '../data/api_exception.dart';
import '../data/order_repository.dart';
import '../models/order.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/vin_capture.dart';

/// Разовый осмотр начинается с таблички: исполнитель снимает VIN (или
/// номер кузова) сам — то, что указал заказчик, сюда не подставляется,
/// иначе его не сверят с машиной. Снятый VIN заменяет VIN заказчика.
/// Возвращает id начатого осмотра.
class CarVinScreen extends StatefulWidget {
  const CarVinScreen({
    super.key,
    required this.repository,
    required this.order,
    this.vin,
  });

  final OrderRepository repository;
  final Order order;

  /// Блок VIN снаружи — тестам, чтобы подложить снимок без камеры.
  @visibleForTesting
  final VinCaptureController? vin;

  @override
  State<CarVinScreen> createState() => _CarVinScreenState();
}

class _CarVinScreenState extends State<CarVinScreen> {
  late final _vin = widget.vin ?? VinCaptureController();
  bool _submitting = false;

  @override
  void dispose() {
    if (widget.vin == null) _vin.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final vin = _vin.validate();
    if (vin == null) return;
    final car = widget.order.cars.first;

    setState(() => _submitting = true);
    try {
      final id = await widget.repository.startInspection(
        widget.order.id,
        car.id,
        vin: vin,
      );
      if (mounted) Navigator.of(context).pop(id);
    } on ApiException catch (e) {
      final errors = e.fieldErrors;
      final vinError =
          errors['vin'] ?? errors['vin_photo'] ?? errors['vin_kind'];
      if (vinError != null) {
        _vin.setError(vinError);
      } else if (mounted) {
        showApiError(context, e);
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.order.cars.first;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: 'Табличка VIN',
              eyebrow: 'начало осмотра',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                children: [
                  VinCapture(controller: _vin),
                  const SizedBox(height: 22),
                  const SectionHead('Автомобиль', extra: 'из заказа'),
                  FieldBox(label: 'Марка и модель', value: car.title),
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
