import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';
import '../models/panel_status.dart';
import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/audio_note.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/status_dot.dart';

/// Чем закончился экран детали — для схемы, которая его открыла.
enum PanelExit {
  /// «Завершить осмотр» на последней детали: схема покажет сводку или
  /// шторку «Осталось исправить», а не молча уведёт в недоделанную деталь.
  finish,
}

/// Экран 02 из макета: оценка одной детали (состояние, дефекты, фото, аудио).
class PanelDetailScreen extends StatefulWidget {
  const PanelDetailScreen({
    super.key,
    required this.store,
    required this.panelId,
    this.fixMode = false,
  });

  final InspectionStore store;
  final String panelId;

  /// Режим исправления: деталь открыта из «Осталось исправить» или сводки.
  /// Вместо «Дальше» по порядку — «Готово» обратно к списку, сверху плашка
  /// «чего не хватает», экран прокручен к этому блоку и подсвечивает его.
  final bool fixMode;

  @override
  State<PanelDetailScreen> createState() => _PanelDetailScreenState();
}

class _PanelDetailScreenState extends State<PanelDetailScreen> {
  late String _panelId = widget.panelId;

  /// Снимок, который сейчас уходит на сервер: плитка «+» показывает его
  /// под крутилкой, чтобы исполнитель сразу видел, что снял.
  String? _uploadingPath;
  bool get _uploading => _uploadingPath != null;

  final _conditionKey = GlobalKey();
  final _defectKey = GlobalKey();
  final _photoKey = GlobalKey();

  /// Короткая подсветка проблемного блока при входе в режим исправления.
  bool _highlight = false;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    if (widget.fixMode && !widget.store.readOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pointAtProblem());
    }
  }

  /// Прокрутить к первому блоку, которого не хватает, и мигнуть им.
  Future<void> _pointAtProblem() async {
    if (!mounted) return;
    final panel = widget.store.panelById(_panelId);
    final key = panel.condition == null
        ? _conditionKey
        : panel.needsDefect
        ? _defectKey
        : panel.needsPhoto
        ? _photoKey
        : null;
    final target = key?.currentContext;
    if (target == null) return;
    setState(() => _highlight = true);
    await Scrollable.ensureVisible(
      target,
      alignment: 0.3,
      duration: const Duration(milliseconds: 300),
    );
    if (!mounted) return;
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlight = false);
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  /// Снять камерой или взять из галереи и отправить на сервер.
  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
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
                'Снять камерой',
                style: TextStyle(color: context.colors.text1),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: context.colors.text2,
              ),
              title: Text(
                'Выбрать из галереи',
                style: TextStyle(color: context.colors.text1),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    // без пересжатия здесь: снимок сожмёт отправка (photo_upload.dart),
    // иначе JPEG пережимался бы дважды
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;

    setState(() => _uploadingPath = picked.path);
    try {
      await widget.store.uploadPhoto(_panelId, picked.path);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _uploadingPath = null);
    }
  }

  /// Мутации детали: ждём ответ сервера и показываем отказ (403 после
  /// «Я оплатил» заказчика, 422) — раньше Future терялся, плитка молча не
  /// подсвечивалась.
  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final panel = store.panelById(_panelId);
        final position = store.indexOf(_panelId) + 1;
        final next = store.nextAfter(_panelId);
        final fixing = widget.fixMode && !store.readOnly;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 20, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: context.colors.bg1,
                          foregroundColor: context.colors.text1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              panel.zone,
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                color: context.colors.text3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              panel.name,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                color: context.colors.text1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.bg1,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${position.toString().padLeft(2, '0')}/${store.totalCount}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: context.colors.text3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (fixing) _FixBanner(panel: panel),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      _SectionTitle('Состояние'),
                      if (fixing && panel.condition == null)
                        _Requirement(
                          'Выберите состояние',
                          key: _conditionKey,
                          highlight: _highlight,
                        ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.6,
                        children: [
                          for (final c in PanelCondition.values)
                            _ConditionTile(
                              condition: c,
                              selected: panel.condition == c,
                              onTap: store.readOnly
                                  ? null
                                  : () => _mutate(
                                      () => store.applyCondition(_panelId, c),
                                    ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SectionTitle('Дефекты'),
                          Text(
                            '${panel.defects.length} отмечен(о)',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.text3,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      if (panel.needsDefect && !store.readOnly)
                        _Requirement(
                          '«К ремонту» — отметьте дефект',
                          key: _defectKey,
                          highlight: _highlight,
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final d in store.defectLabelsFor(panel))
                            _DefectChip(
                              label: d,
                              on: panel.defects.contains(d),
                              onTap: store.readOnly
                                  ? null
                                  : () => _mutate(
                                      () => store.toggleDefect(_panelId, d),
                                    ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SectionTitle('Фото'),
                          Text(
                            '${panel.photoCount}/${InspectionPanel.maxPhotos}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.text3,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      if (panel.needsPhoto && !store.readOnly)
                        _Requirement(
                          'Нужно хотя бы одно фото',
                          key: _photoKey,
                          // дефект подсвечивается первым, фото — если он есть
                          highlight: _highlight && !panel.needsDefect,
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 72,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final (i, photo) in panel.photos.indexed)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  // на весь экран; исполнитель там же удаляет
                                  onTap: () => openPhotoGallery(
                                    context,
                                    [for (final p in panel.photos) p.url],
                                    thumbUrls: [
                                      for (final p in panel.photos) p.thumbUrl,
                                    ],
                                    initialIndex: i,
                                    onDelete: store.readOnly
                                        ? null
                                        : (index) => store.deletePhoto(
                                            panel.photos[index].id,
                                          ),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: context.colors.bg1,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Image.network(
                                      photo.thumbUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.broken_image_outlined,
                                        size: 20,
                                        color: context.colors.text3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (panel.photoCount < InspectionPanel.maxPhotos &&
                                !store.readOnly)
                              InkWell(
                                onTap: _uploading ? null : _addPhoto,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: context.colors.line,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _uploadingPath != null
                                      ? _UploadingTile(path: _uploadingPath!)
                                      : Icon(
                                          Icons.add,
                                          color: context.colors.text3,
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _SectionTitle('Голосовая заметка'),
                      const SizedBox(height: 12),
                      AudioNoteEditor(
                        key: ValueKey(_panelId),
                        seed: panel.id,
                        url: panel.audioNoteUrl,
                        seconds: panel.audioNoteSeconds,
                        readOnly: store.readOnly,
                        onRecorded: (path, seconds) => _mutate(
                          () => store.uploadAudioNote(_panelId, path, seconds),
                        ),
                        onDelete: () =>
                            _mutate(() => store.deleteAudioNote(_panelId)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: fixing
                        ? NextStepButton(
                            caption: switch (store.problems.length) {
                              0 => 'Всё заполнено',
                              final n => 'Осталось исправить · $n',
                            },
                            title: 'Готово',
                            onPressed: () => Navigator.of(context).pop(),
                          )
                        : NextStepButton(
                            caption: 'Дальше',
                            title: next?.name ?? 'Завершить осмотр',
                            onPressed: next == null
                                ? () => Navigator.of(
                                    context,
                                  ).pop(PanelExit.finish)
                                : () => setState(() => _panelId = next.id),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 1.2,
        color: context.colors.text3,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Подсказка, чего не хватает детали для отчёта. Не блокирует «Дальше»:
/// жёстко это проверит отправка отчёта (сервер, InspectionPanel::missing()).
class _Requirement extends StatelessWidget {
  const _Requirement(this.text, {super.key, this.highlight = false});
  final String text;

  /// Мигнуть при входе в режим исправления — см. [PanelDetailScreen.fixMode].
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(top: 6),
      padding: EdgeInsets.symmetric(
        horizontal: highlight ? 8 : 0,
        vertical: highlight ? 6 : 0,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? context.colors.statusProgress.withValues(alpha: 0.16)
            : context.colors.statusProgress.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 14,
            color: context.colors.progressText,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                color: context.colors.progressText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Плашка режима исправления: зачем исполнителя вернули на эту деталь.
/// Пропадает, как только сервер вернёт деталь без `missing`.
class _FixBanner extends StatelessWidget {
  const _FixBanner({required this.panel});

  final InspectionPanel panel;

  @override
  Widget build(BuildContext context) {
    final todo = panel.condition == null
        ? ['выберите состояние']
        : [
            if (panel.needsDefect) 'отметьте дефект',
            if (panel.needsPhoto) 'добавьте фото',
          ];
    if (todo.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: context.colors.statusProgress.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: context.colors.progressText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Чтобы отправить отчёт: ${todo.join(' и ')}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: context.colors.progressText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({
    required this.condition,
    required this.selected,
    required this.onTap,
  });

  final PanelCondition condition;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.statusDone.withValues(alpha: 0.08)
              : context.colors.bg1,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? context.colors.statusDone : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                StatusDot(color: condition.impliedStatus.color(context.colors)),
                const Spacer(),
                Text(
                  condition.grade,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: context.colors.text3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              condition.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected
                    ? context.colors.doneText
                    : context.colors.text1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefectChip extends StatelessWidget {
  const _DefectChip({
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on
              ? context.colors.statusProgress.withValues(alpha: 0.12)
              : context.colors.bg1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on
                ? context.colors.statusProgress.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: on ? context.colors.progressText : context.colors.text2,
          ),
        ),
      ),
    );
  }
}

/// Плитка снимка, который уходит на сервер: сам снимок под крутилкой.
class _UploadingTile extends StatelessWidget {
  const _UploadingTile({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.cover,
          // полный кадр камеры — не раскодируем его целиком ради плитки
          cacheWidth: (72 * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ],
    );
  }
}
