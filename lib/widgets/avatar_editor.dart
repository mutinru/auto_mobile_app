import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import 'api_error.dart';
import 'app_sheet.dart';
import 'app_ui.dart';

/// Выбрать снимок и вырезать из него квадрат; null — пользователь передумал.
/// [accent] — цвет активных элементов обрезки (по умолчанию у uCrop оранжевый).
typedef PickSquarePhoto =
    Future<String?> Function(ImageSource source, Color accent);

/// Снимок из галереи или с камеры → нативная обрезка квадратом (uCrop /
/// TOCropViewController). На сервер уходит JPEG до 1024 px — десятки КБ;
/// сервер всё равно режет центр и пережимает в 512×512.
Future<String?> pickSquarePhoto(ImageSource source, Color accent) async {
  final picked = await ImagePicker().pickImage(source: source);
  if (picked == null) return null;
  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    maxWidth: 1024,
    maxHeight: 1024,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 85,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Фото профиля',
        activeControlsWidgetColor: accent,
        lockAspectRatio: true,
        initAspectRatio: CropAspectRatioPreset.square,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
        hideBottomControls: false,
      ),
      IOSUiSettings(
        title: 'Фото профиля',
        aspectRatioLockEnabled: true,
        aspectRatioPickerButtonHidden: true,
        resetAspectRatioEnabled: false,
        doneButtonTitle: 'Готово',
        cancelButtonTitle: 'Отмена',
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
    ],
  );
  return cropped?.path;
}

enum _AvatarAction { gallery, camera, delete }

/// Аватар в шапке профиля: тап — шторка «Фото профиля» (галерея, камера,
/// удалить). Пока фото уходит на сервер — крутилка поверх. Новый URL
/// приходит профилем от сервера — его рисует родитель через [url].
class AvatarEditor extends StatefulWidget {
  const AvatarEditor({
    super.key,
    required this.name,
    required this.url,
    required this.onUpload,
    required this.onDelete,
    this.pick = pickSquarePhoto,
    this.size = 54,
  });

  final String name;
  final String? url;
  final Future<void> Function(String path) onUpload;
  final Future<void> Function() onDelete;

  /// Выбор и обрезка снаружи — тестам: плагинов камеры и обрезки там нет.
  final PickSquarePhoto pick;
  final double size;

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  bool _busy = false;

  Future<void> _edit() async {
    final action = await showAppSheet<_AvatarAction>(
      context,
      (context) => _AvatarSheet(hasPhoto: widget.url != null),
    );
    if (action == null || !mounted) return;

    Future<void> Function() run;
    if (action == _AvatarAction.delete) {
      run = widget.onDelete;
    } else {
      final path = await widget.pick(
        action == _AvatarAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        context.colors.statusDone,
      );
      if (path == null || !mounted) return;
      run = () => widget.onUpload(path);
    }

    setState(() => _busy = true);
    try {
      await run();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: _busy ? null : _edit,
      child: SizedBox(
        width: widget.size + 4,
        height: widget.size + 4,
        child: Stack(
          children: [
            Avatar(
              initialsOf(widget.name),
              size: widget.size,
              url: widget.url,
            ),
            if (_busy)
              Positioned(
                left: 0,
                top: 0,
                width: widget.size,
                height: widget.size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.backdrop,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            // значок «камера» — что аватар можно сменить
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: c.bg1,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.line),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 13,
                  color: c.text1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarSheet extends StatelessWidget {
  const _AvatarSheet({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(
      IconData icon,
      String label,
      _AvatarAction action, {
      Color? color,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? c.text1),
      title: Text(label, style: TextStyle(color: color ?? c.text1)),
      onTap: () => Navigator.of(context).pop(action),
    );

    return SheetFrame(
      title: 'Фото профиля',
      subtitle: 'Видят заказчики и исполнители',
      children: [
        item(
          Icons.photo_library_outlined,
          'Выбрать из галереи',
          _AvatarAction.gallery,
        ),
        item(
          Icons.photo_camera_outlined,
          'Сделать фото',
          _AvatarAction.camera,
        ),
        if (hasPhoto)
          item(
            Icons.delete_outline,
            'Удалить фото',
            _AvatarAction.delete,
            color: c.defectText,
          ),
      ],
    );
  }
}
