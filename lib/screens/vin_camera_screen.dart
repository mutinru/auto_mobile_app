import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/vin_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/vin_frame.dart';

/// Снимок таблички: путь к полному кадру (уходит на сервер как
/// доказательство) и рамка в долях кадра — распознаётся только она.
/// [frame] == null — сняли системной камерой, рамки не было.
class VinShot {
  const VinShot({required this.path, this.frame});

  final String path;
  final Rect? frame;
}

/// Открывает камеру с рамкой; null — закрыли без снимка.
Future<VinShot?> openVinCamera(BuildContext context, VinKind kind) =>
    Navigator.of(context).push<VinShot>(
      MaterialPageRoute(builder: (_) => VinCameraScreen(kind: kind)),
    );

/// Своя камера для таблички VIN: кадр на весь экран, узкая рамка под строку
/// номера, фонарик и фокус по тапу. На шильдике на раме рядом с VIN много
/// других надписей — распознаём только рамку, иначе ML Kit читает всё
/// подряд. Камера создаётся здесь, при открытии экрана: в виджет-тестах
/// плагина нет, а другие экраны его не трогают.
class VinCameraScreen extends StatefulWidget {
  const VinCameraScreen({super.key, required this.kind});

  final VinKind kind;

  @override
  State<VinCameraScreen> createState() => _VinCameraScreenState();
}

class _VinCameraScreenState extends State<VinCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;
  bool _busy = false;
  bool _torch = false;

  /// Вспышки нет (эмулятор, часть планшетов) — кнопку фонарика прячем
  /// после первой неудачной попытки.
  bool _hasTorch = true;

  /// Куда тапнули для фокуса — короткая отметка на превью.
  Offset? _focusMark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  /// Камеру держат одно приложение за раз: свернули — отдаём, вернулись —
  /// поднимаем заново (так требует плагин).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive && camera != null) {
      _camera = null;
      _torch = false;
      camera.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed &&
        _camera == null &&
        _error == null) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', null);
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await camera.initialize();
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await camera.setFlashMode(FlashMode.off);
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.code.contains('AccessDenied')
            ? 'Нет доступа к камере — разрешите его в настройках телефона'
            : 'Камера недоступна',
      );
    }
  }

  /// Превью в портретной ориентации: плагин отдаёт размер сенсора лёжа.
  Size? get _preview {
    final size = _camera?.value.previewSize;
    if (size == null) return null;
    return Size(
      size.shortestSide,
      size.longestSide,
    );
  }

  /// Рамка на экране: почти во всю ширину, по высоте — под одну строку.
  /// Номер кузова короче VIN — рамка чуть выше.
  Rect _frameRect(Size viewport) {
    final width = viewport.width * 0.88;
    final height = width / (widget.kind == VinKind.vin ? 5 : 3.5);
    return Rect.fromCenter(
      center: Offset(viewport.width / 2, viewport.height * 0.42),
      width: width,
      height: height,
    );
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      await camera.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      setState(() => _torch = !_torch);
    } on CameraException {
      setState(() => _hasTorch = false);
    }
  }

  Future<void> _focus(Offset point, Size viewport) async {
    final camera = _camera;
    final preview = _preview;
    if (camera == null || preview == null) return;
    setState(() => _focusMark = point);
    final target = pointInImage(
      preview: preview,
      viewport: viewport,
      point: point,
    );
    try {
      await camera.setFocusPoint(target);
      await camera.setExposurePoint(target);
    } on CameraException {
      // фокус по точке умеют не все камеры — снимаем с автофокусом
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted && _focusMark == point) setState(() => _focusMark = null);
  }

  Future<void> _shoot(Size viewport) async {
    final camera = _camera;
    final preview = _preview;
    if (camera == null || preview == null || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await camera.takePicture();
      if (_torch) await camera.setFlashMode(FlashMode.off);
      if (!mounted) return;
      Navigator.of(context).pop(
        VinShot(
          path: file.path,
          frame: frameInImage(
            preview: preview,
            viewport: viewport,
            frameOnScreen: _frameRect(viewport),
          ),
        ),
      );
    } on CameraException {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось снять — попробуйте ещё')),
      );
    }
  }

  /// Своя камера не поднялась — снимаем системной, как раньше, без рамки:
  /// съёмка таблички не должна становиться тупиком.
  Future<void> _systemCamera() async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
    );
    if (shot == null || !mounted) return;
    Navigator.of(context).pop(VinShot(path: shot.path));
  }

  @override
  Widget build(BuildContext context) {
    // кадр камеры тёмный в любой теме, как видоискатель VinScanner
    return Theme(
      data: AppTheme.dark,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.colors.bg0,
          body: _error != null ? _errorView(context) : _cameraView(context),
        ),
      ),
    );
  }

  Widget _cameraView(BuildContext context) {
    final camera = _camera;
    final preview = _preview;
    final what = widget.kind == VinKind.vin ? 'VIN' : 'номер кузова';
    return LayoutBuilder(
      builder: (context, box) {
        final viewport = box.biggest;
        final frame = _frameRect(viewport);
        return Stack(
          children: [
            if (camera != null && preview != null)
              Positioned.fill(
                child: GestureDetector(
                  onTapUp: (d) => _focus(d.localPosition, viewport),
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: preview.width,
                        height: preview.height,
                        child: CameraPreview(camera),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(child: CircularProgressIndicator()),
            // затемнение вокруг рамки и уголки — не ловят тапы
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FramePainter(
                    frame: frame,
                    shade: context.colors.backdrop,
                    corner: context.colors.statusDone,
                  ),
                ),
              ),
            ),
            if (_focusMark != null)
              Positioned(
                left: _focusMark!.dx - 28,
                top: _focusMark!.dy - 28,
                child: IgnorePointer(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.statusDone,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 24,
              right: 24,
              bottom: viewport.height - frame.top + 14,
              child: Text(
                'Наведите рамку на $what',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.text1,
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: frame.bottom + 14,
              child: Text(
                'Только строка номера — остальные надписи оставьте за рамкой',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: context.colors.text2),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _RoundButton(
                    icon: Icons.close,
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        // Center — иначе SizedBox растянет круглую кнопку
                        child: _hasTorch && camera != null
                            ? Center(
                                heightFactor: 1,
                                child: _RoundButton(
                                  icon: _torch
                                      ? Icons.flashlight_on
                                      : Icons.flashlight_off_outlined,
                                  tooltip: _torch
                                      ? 'Выключить фонарик'
                                      : 'Включить фонарик',
                                  active: _torch,
                                  onPressed: _toggleTorch,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 28),
                      _Shutter(
                        busy: _busy,
                        onPressed: camera == null
                            ? null
                            : () => _shoot(viewport),
                      ),
                      const SizedBox(width: 28 + 72),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _errorView(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: _RoundButton(
                icon: Icons.close,
                tooltip: 'Закрыть',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.no_photography_outlined,
              size: 40,
              color: context.colors.text2,
            ),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: context.colors.text1),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _systemCamera,
              child: const Text('Снять системной камерой'),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Затемнение вокруг рамки и зелёные уголки, как у видоискателя VinScanner.
class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.frame,
    required this.shade,
    required this.corner,
  });

  final Rect frame;
  final Color shade;
  final Color corner;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(frame, const Radius.circular(10));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(hole),
      Paint()..color = shade,
    );
    final pen = Paint()
      ..color = corner
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const arm = 22.0;
    final l = frame.left, t = frame.top, r = frame.right, b = frame.bottom;
    for (final (x, y, dx, dy) in [
      (l, t, 1.0, 1.0),
      (r, t, -1.0, 1.0),
      (l, b, 1.0, -1.0),
      (r, b, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + arm * dx, y), pen);
      canvas.drawLine(Offset(x, y), Offset(x, y + arm * dy), pen);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.shade != shade || old.corner != corner;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 24,
      style: IconButton.styleFrom(
        fixedSize: const Size(52, 52),
        backgroundColor: active ? context.colors.knob : context.colors.backdrop,
        foregroundColor: active ? context.colors.knobInk : context.colors.text1,
      ),
      icon: Icon(icon),
    );
  }
}

/// Кнопка спуска: белое кольцо; пока сохраняем снимок — индикатор.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Снять',
      child: GestureDetector(
        onTap: busy ? null : onPressed,
        child: Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.knob, width: 4),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onPressed == null
                  ? context.colors.text3
                  : context.colors.knob,
            ),
            child: busy
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: context.colors.knobInk,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
