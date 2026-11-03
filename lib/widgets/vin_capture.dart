import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/vin_kind.dart';
import '../theme/app_colors.dart';
import 'app_ui.dart';
import 'vin_scanner.dart';

/// Состояние блока VIN: что снято, какого вида, где фото таблички и
/// ошибка поля. Экран держит контроллер и в конце берёт [validate].
class VinCaptureController extends ChangeNotifier {
  VinKind _kind = VinKind.vin;
  VinKind get kind => _kind;

  final text = TextEditingController();

  String? _photoPath;
  String? get photoPath => _photoPath;

  bool _scanning = false;
  bool get scanning => _scanning;

  String? _error;
  String? get error => _error;

  String get value => text.text.trim().toUpperCase();

  VinCaptureController() {
    // поправили значение — ошибка поля уходит
    text.addListener(() {
      if (_error != null) {
        _error = null;
        notifyListeners();
      }
    });
  }

  void setKind(VinKind kind) {
    if (kind == _kind) return;
    _kind = kind;
    _error = null;
    notifyListeners();
  }

  void setPhoto(String path) {
    _photoPath = path;
    _error = null;
    notifyListeners();
  }

  /// Ошибка с сервера (422 по `vin`, `vin_kind`, `vin_photo`).
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _setScanning(bool value) {
    _scanning = value;
    notifyListeners();
  }

  /// Готовый VIN или null — тогда ошибка уже стоит у поля.
  CapturedVin? validate() {
    final v = value;
    final problem = v.isEmpty
        ? (_kind == VinKind.vin ? 'Укажите VIN' : 'Укажите номер кузова')
        : _kind.problem(v);
    final error =
        problem ?? (_photoPath == null ? 'Сфотографируйте табличку' : null);
    if (error != null) {
      setError(error);
      return null;
    }
    return CapturedVin(value: v, kind: _kind, photoPath: _photoPath!);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}

/// Блок «VIN» начала осмотра — и в подборе, и в разовом осмотре.
/// Исполнитель фотографирует табличку: снимок уходит на сервер как
/// доказательство, текст распознаётся на устройстве (ML Kit, офлайн).
/// Не распознался — правит руками, но снимок обязателен всё равно.
class VinCapture extends StatelessWidget {
  const VinCapture({super.key, required this.controller});

  final VinCaptureController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.text]),
      builder: (context, _) {
        final c = controller;
        final value = c.value;
        final ok = value.isNotEmpty && c.kind.problem(value) == null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHead(
              c.kind.label,
              extra: ok && c.photoPath != null ? 'снят' : 'нужен снимок',
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final k in VinKind.values)
                  AppChip(
                    label: k.label,
                    on: c.kind == k,
                    onTap: () => c.setKind(k),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            VinScanner(
              vin: c.scanning
                  ? 'распознаём…'
                  : (value.isEmpty ? 'нажмите, чтобы снять табличку' : value),
              onTap: c.scanning ? null : () => _tapped(context),
              error: c.error != null,
            ),
            if (c.photoPath != null)
              CapturedPhotoRow(
                path: c.photoPath!,
                label: 'Фото таблички сохранено',
              ),
            FieldError(c.error),
          ],
        );
      },
    );
  }

  /// Тап по видоискателю: снять табличку или поправить текст руками.
  Future<void> _tapped(BuildContext context) async {
    final scan = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.colors.bg0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_camera_outlined,
                color: context.colors.text2,
              ),
              title: Text(
                'Сфотографировать табличку',
                style: TextStyle(color: context.colors.text1),
              ),
              subtitle: Text(
                'Снимок обязателен — он попадёт в отчёт',
                style: TextStyle(color: context.colors.text3, fontSize: 11.5),
              ),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              leading: Icon(
                Icons.keyboard_alt_outlined,
                color: context.colors.text2,
              ),
              title: Text(
                'Ввести вручную',
                style: TextStyle(color: context.colors.text1),
              ),
              onTap: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (scan == null || !context.mounted) return;
    if (scan) {
      await _scan(context);
    } else {
      await _edit(context);
    }
  }

  /// Снимок + распознавание. VIN надёжнее номера кузова: найденный VIN
  /// переключает вид сам, номер кузова ищем, только если выбран он.
  Future<void> _scan(BuildContext context) async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
    );
    if (shot == null || !context.mounted) return;

    controller.setPhoto(shot.path);
    controller._setScanning(true);
    String? found;
    final text = await recognizeText(shot.path);
    controller._setScanning(false);
    if (text != null) {
      final vin = extractVin(text);
      if (vin != null) {
        controller.setKind(VinKind.vin);
        found = vin;
      } else if (controller.kind == VinKind.bodyNumber) {
        found = extractBodyNumber(text);
      }
    }
    if (!context.mounted) return;
    if (found != null) {
      controller.text.text = found;
      return;
    }
    // сбой распознавания — не запроса: свой текст, не apiErrorText
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${controller.kind.label} не распознан — введите вручную, '
          'снимок сохранён',
        ),
      ),
    );
    await _edit(context);
  }

  Future<void> _edit(BuildContext context) async {
    final kind = controller.kind;
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
            SectionHead(
              kind.label,
              extra: kind == VinKind.vin ? '17 символов' : 'как на табличке',
            ),
            FieldBoxInput(
              label: '',
              controller: controller.text,
              hint: kind == VinKind.vin ? 'XW8ZZZ61ZKG0KX24P' : 'GX110-6012345',
              mono: true,
              inputFormatters: [
                kind == VinKind.vin
                    ? const VinFormatter()
                    : const BodyNumberFormatter(),
              ],
            ),
            const SizedBox(height: 6),
            CtaPrimary(
              label: 'Готово',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Текст со снимка — ML Kit на устройстве, офлайн. null — не удалось
/// распознать: снимок остаётся, текст вводят руками.
Future<String?> recognizeText(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return result.text;
  } catch (_) {
    return null;
  } finally {
    await recognizer.close();
  }
}

/// VIN или номер кузова с камеры — без сохранения снимка (поле заказчика).
/// null — отказались от съёмки или ничего не нашли.
Future<String?> scanVinOrBodyNumber() async {
  final shot = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 2000,
  );
  if (shot == null) return null;
  final text = await recognizeText(shot.path);
  if (text == null) return null;
  return extractVin(text) ?? extractBodyNumber(text);
}

/// Снятое фото (табличка, одометр) — миниатюра и отметка «сохранено».
class CapturedPhotoRow extends StatelessWidget {
  const CapturedPhotoRow({super.key, required this.path, required this.label});

  final String path;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(path),
              width: 44,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 44,
                height: 32,
                color: context.colors.bg2,
                child: Icon(
                  Icons.image_outlined,
                  size: 16,
                  color: context.colors.text3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.check_circle, size: 14, color: context.colors.statusDone),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.colors.text2),
          ),
        ],
      ),
    );
  }
}
