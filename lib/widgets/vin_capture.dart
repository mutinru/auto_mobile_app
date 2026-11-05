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

  /// Текст подставило распознавание, а исполнитель его ещё не открывал:
  /// ML Kit путает 0 и O, 8 и B — просим сверить с табличкой.
  bool _recognized = false;
  bool get needsCheck => _recognized && value.isNotEmpty;

  /// Зовётся после записи распознанного текста в [text].
  void markRecognized() {
    _recognized = true;
    notifyListeners();
  }

  /// Новый снимок ничего не дал — прежнее распознавание к нему не относится.
  void _forgetRecognition() {
    if (!_recognized) return;
    _recognized = false;
    notifyListeners();
  }

  /// Исполнитель открыл поле правки — значит, сверил.
  void markChecked() {
    if (!_recognized) return;
    _recognized = false;
    notifyListeners();
  }

  VinCaptureController() {
    // поправили значение — ошибка поля уходит
    text.addListener(() {
      if (_error != null) {
        _error = null;
        notifyListeners();
      }
    });
  }

  /// Исполнитель сам переключил вид: введённое под прежний вид не
  /// подходит — текст очищаем, фото оставляем (на нём может быть и то и то).
  void switchKind(VinKind kind) {
    if (kind == _kind) return;
    _recognized = false;
    text.clear();
    setKind(kind);
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

  /// Что не так с введённым текстом; null — годится. Распознавание могло
  /// отдать неполный VIN — тогда говорим, сколько знаков не хватает.
  String? textProblem() {
    final v = value;
    if (v.isEmpty) {
      return _kind == VinKind.vin ? 'Укажите VIN' : 'Укажите номер кузова';
    }
    if (_kind == VinKind.vin && v.length != 17) {
      return 'В VIN 17 символов, сейчас ${v.length} — сверьте с фото';
    }
    return _kind.problem(v);
  }

  /// Готовый VIN или null — тогда ошибка уже стоит у поля.
  CapturedVin? validate() {
    final problem = textProblem();
    final error =
        problem ?? (_photoPath == null ? 'Сфотографируйте табличку' : null);
    if (error != null) {
      setError(error);
      return null;
    }
    return CapturedVin(value: value, kind: _kind, photoPath: _photoPath!);
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
            VinScanner(
              vin: c.scanning
                  ? 'распознаём…'
                  : (value.isNotEmpty
                        ? value
                        : c.kind == VinKind.vin
                        ? 'нажмите, чтобы снять табличку'
                        : 'нажмите, чтобы снять номер кузова'),
              onTap: c.scanning ? null : () => _tapped(context),
              error: c.error != null,
            ),
            if (c.photoPath != null)
              CapturedPhotoRow(
                path: c.photoPath!,
                label: 'Фото таблички сохранено',
              ),
            if (c.needsCheck)
              _CheckHint(kind: c.kind, onFix: () => _edit(context)),
            _KindSwitch(controller: c),
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
  /// переключает вид сам, номер кузова ищем, только если выбран он. Что бы
  /// ни распозналось — даже часть VIN или ничего, — открываем шторку сверки
  /// со снимком: подтвердить номер исполнитель обязан сам.
  Future<void> _scan(BuildContext context) async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
    );
    if (shot == null || !context.mounted) return;

    controller.setPhoto(shot.path);
    controller._setScanning(true);
    String? found;
    var how = _Recognition.none;
    final text = await recognizeText(shot.path);
    controller._setScanning(false);
    if (text != null) {
      final vin = extractVin(text);
      if (vin != null) {
        controller.setKind(VinKind.vin);
        found = vin;
        how = _Recognition.exact;
      } else if (controller.kind == VinKind.bodyNumber) {
        found = extractBodyNumber(text);
        if (found != null) how = _Recognition.exact;
      } else {
        // неполный VIN тоже показываем: дописать проще, чем набрать
        found = guessVin(text);
        if (found != null) how = _Recognition.guess;
      }
    }
    if (!context.mounted) return;
    // в поле — только то, что дал этот снимок: номер с прошлого выглядел
    // бы распознанным с нового фото
    controller.text.text = found ?? '';
    if (found != null) {
      controller.markRecognized();
    } else {
      controller._forgetRecognition();
    }
    await _edit(context, recognized: how);
  }

  /// Шторка сверки: снимок таблички, поле и «Всё верно». Закрыта кнопкой —
  /// номер сверен; смахнули — распознанный номер остаётся с подсказкой
  /// «Проверьте VIN» под видоискателем.
  Future<void> _edit(BuildContext context, {_Recognition? recognized}) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.colors.bg0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _VinSheet(controller: controller, recognized: recognized),
    );
    if (confirmed == true) controller.markChecked();
  }
}

/// Чем закончилось распознавание снимка. Догадка ([guessVin]: неполный
/// номер или с заменой O→0) показывается как неуверенная — её
/// исполнитель обязан проверить по знаку.
enum _Recognition { exact, guess, none }

/// Содержимое шторки сверки VIN. Ошибку «Всё верно» держит у себя: пока
/// номер не годится, шторка не закрывается.
class _VinSheet extends StatefulWidget {
  const _VinSheet({required this.controller, this.recognized});

  final VinCaptureController controller;

  /// Исход распознавания сразу после снимка; null — шторку открыли руками
  /// («Исправить», «Ввести вручную»).
  final _Recognition? recognized;

  @override
  State<_VinSheet> createState() => _VinSheetState();
}

class _VinSheetState extends State<_VinSheet> {
  String? _error;

  /// Рекомендация под полем: как прошло распознавание. Считается один раз
  /// при открытии — пока исполнитель правит, текст не должен прыгать.
  late final String? _warning;
  late final String? _helper;

  /// Уверенно распознанный полный номер — клавиатуру не поднимаем, иначе
  /// она закроет снимок; догадку, неполный или пустой — сразу править.
  late final bool _confident;

  VinCaptureController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.text.addListener(_clearError);
    final complete = _c.value.isNotEmpty && _c.textProblem() == null;
    final how = widget.recognized;
    _confident =
        complete && how != _Recognition.guess && how != _Recognition.none;
    _warning = switch (how) {
      _Recognition.none => 'Не удалось распознать — введите по фото',
      _Recognition.guess when complete =>
        'Распознано неуверенно — проверьте каждый знак',
      _Recognition.guess => 'Распознано не всё — допишите по фото',
      _ => null,
    };
    _helper = _warning == null && _c.photoPath != null
        ? 'Сверьте с табличкой на фото'
        : null;
  }

  @override
  void dispose() {
    _c.text.removeListener(_clearError);
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  void _submit() {
    final problem = _c.textProblem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final kind = _c.kind;
    final photo = _c.photoPath;
    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHead(
              kind.label,
              extra: kind == VinKind.vin ? '17 символов' : 'как на табличке',
            ),
            if (photo != null) ...[
              _PlatePhoto(path: photo),
              const SizedBox(height: 10),
            ],
            FieldBoxInput(
              label: '',
              controller: _c.text,
              hint: kind == VinKind.vin
                  ? '17 знаков с таблички'
                  : 'например, GX110-6012345',
              mono: true,
              autofocus: !_confident,
              error: _error,
              warning: _warning,
              helper: _helper,
              inputFormatters: [
                kind == VinKind.vin
                    ? const VinFormatter()
                    : const BodyNumberFormatter(),
              ],
            ),
            const SizedBox(height: 6),
            CtaPrimary(
              label: photo != null ? 'Всё верно' : 'Готово',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Снимок таблички в шторке — щипком увеличивается, чтобы сверить знаки.
class _PlatePhoto extends StatelessWidget {
  const _PlatePhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 170,
        color: context.colors.bg2,
        child: InteractiveViewer(
          maxScale: 6,
          child: Center(
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_outlined,
                size: 28,
                color: context.colors.text3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Под распознанным VIN: просьба сверить с табличкой и прямой путь к
/// правке — без него исправить можно было, только догадавшись тапнуть
/// по видоискателю ещё раз.
class _CheckHint extends StatelessWidget {
  const _CheckHint({required this.kind, required this.onFix});

  final VinKind kind;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final what = kind == VinKind.vin ? 'VIN' : 'номер кузова';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 15,
            color: context.colors.progressText,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Проверьте $what по табличке — распознавание может ошибиться',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.progressText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onFix,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: context.colors.text1,
            ),
            child: const Text(
              'Исправить',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Номер кузова — исключение, а не равный выбор: без VIN бывают японские
/// праворульные и часть старых машин. Ссылка под видоискателем вместо
/// чипов, чтобы не казалось, что снимать надо и то и другое.
class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.controller});

  final VinCaptureController controller;

  @override
  Widget build(BuildContext context) {
    final toBody = controller.kind == VinKind.vin;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: () => controller.switchKind(
              toBody ? VinKind.bodyNumber : VinKind.vin,
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: context.colors.text1,
            ),
            child: Text(
              toBody ? 'Нет VIN? Указать номер кузова' : '← Вернуться к VIN',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          if (toBody)
            Text(
              'у японских праворульных и части старых машин',
              style: TextStyle(fontSize: 11.5, color: context.colors.text3),
            ),
        ],
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
