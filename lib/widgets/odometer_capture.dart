import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/vin_kind.dart';
import '../theme/app_colors.dart';
import 'app_ui.dart';
import 'vin_capture.dart' show CapturedPhotoRow;

/// Состояние блока «Пробег по одометру»: цифры, фото приборки и ошибка.
/// Экран держит контроллер и в конце берёт [validate].
class OdometerCaptureController extends ChangeNotifier {
  final text = TextEditingController();

  String? _photoPath;
  String? get photoPath => _photoPath;

  String? _error;
  String? get error => _error;

  int? get km => int.tryParse(text.text.replaceAll(' ', ''));

  /// Ошибка — про сами цифры (нет их или они за потолком), а не про фото
  /// или отказ сервера: тогда она стоит у поля.
  bool get _kmWrong {
    final value = km;
    return value == null || mileageProblem(value) != null;
  }

  OdometerCaptureController() {
    // поправили цифры — ошибка блока уходит
    text.addListener(() {
      if (_error != null) {
        _error = null;
        notifyListeners();
      }
    });
  }

  void setPhoto(String path) {
    _photoPath = path;
    _error = null;
    notifyListeners();
  }

  /// Ошибка с сервера (422 по `mileage_km`, `odometer_photo`).
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Готовый пробег или null — тогда ошибка уже стоит у блока.
  CapturedOdometer? validate() {
    final value = km;
    final error = value == null
        ? 'Укажите пробег по одометру'
        : mileageProblem(value) ??
              (_photoPath == null ? 'Сфотографируйте одометр' : null);
    if (error != null) {
      setError(error);
      return null;
    }
    return CapturedOdometer(km: value!, photoPath: _photoPath!);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}

/// Блок «Пробег по одометру» начала осмотра — и в подборе, и в разовом.
/// Исполнитель вводит цифры с приборки и фотографирует её: снимок уходит
/// в отчёт как доказательство. Пробег заказчика сюда не подставляется —
/// иначе его перепишут, не глядя на приборку.
class OdometerCapture extends StatelessWidget {
  const OdometerCapture({super.key, required this.controller});

  final OdometerCaptureController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        // нет цифр или они за потолком — ошибка у поля, иначе (нет фото,
        // отказ сервера) — под блоком, а рамкой подсвечена кнопка фото
        final kmError = c._kmWrong ? c.error : null;
        final otherError = kmError == null ? c.error : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHead(
              'Пробег по одометру',
              extra: c.photoPath != null ? 'снят' : 'нужен снимок',
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FieldBoxInput(
                    label: '',
                    controller: c.text,
                    // не число: пример цифрами выглядит как введённое
                    hint: 'с приборки',
                    mono: true,
                    unit: 'км',
                    keyboardType: TextInputType.number,
                    inputFormatters: digitsOnly,
                    maxLength: 7,
                    error: kmError,
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: 'Сфотографировать одометр',
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _shoot,
                      icon: const Icon(Icons.photo_camera_outlined, size: 17),
                      label: Text(c.photoPath == null ? 'Фото' : 'Переснять'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.text1,
                        side: BorderSide(
                          color: otherError != null && c.photoPath == null
                              ? context.colors.statusDefect
                              : context.colors.line,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (c.photoPath != null)
              CapturedPhotoRow(
                path: c.photoPath!,
                label: 'Фото одометра сохранено',
              ),
            FieldError(otherError),
          ],
        );
      },
    );
  }

  Future<void> _shoot() async {
    // сжимает отправка (photo_upload.dart), не пикер
    final shot = await ImagePicker().pickImage(source: ImageSource.camera);
    if (shot != null) controller.setPhoto(shot.path);
  }
}
