import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/panel_condition.dart';
import '../models/panel_status.dart';
import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import '../widgets/status_dot.dart';

/// Экран 02 из макета: оценка одной детали (состояние, дефекты, фото, аудио).
class PanelDetailScreen extends StatefulWidget {
  const PanelDetailScreen({
    super.key,
    required this.store,
    required this.panelId,
  });

  final InspectionStore store;
  final String panelId;

  @override
  State<PanelDetailScreen> createState() => _PanelDetailScreenState();
}

class _PanelDetailScreenState extends State<PanelDetailScreen> {
  late String _panelId = widget.panelId;

  bool _uploading = false;

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
              leading: Icon(Icons.photo_camera_outlined,
                  color: context.colors.text2),
              title: Text('Снять камерой',
                  style: TextStyle(color: context.colors.text1)),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library_outlined, color: context.colors.text2),
              title: Text('Выбрать из галереи',
                  style: TextStyle(color: context.colors.text1)),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    // сжимаем на устройстве: бекенд принимает до 10 МБ, а снимки
    // современных камер легко больше
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await widget.store.uploadPhoto(_panelId, picked.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить фото: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
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
                            horizontal: 10, vertical: 6),
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
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      _SectionTitle('Состояние'),
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
                              onTap: () => store.applyCondition(_panelId, c),
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
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final d in store.defectLabels)
                            _DefectChip(
                              label: d,
                              on: panel.defects.contains(d),
                              onTap: () => store.toggleDefect(_panelId, d),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SectionTitle('Фото'),
                          Text(
                            '${panel.photoCount}/5',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.text3,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 72,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final url in panel.photoUrls)
                              Container(
                                width: 72,
                                height: 72,
                                margin: const EdgeInsets.only(right: 8),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: context.colors.bg1,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.broken_image_outlined,
                                    size: 20,
                                    color: context.colors.text3,
                                  ),
                                ),
                              ),
                            if (panel.photoCount < 5)
                              InkWell(
                                onTap: _uploading ? null : _addPhoto,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: context.colors.line,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _uploading
                                      ? const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
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
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.colors.bg1,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: context.colors.text1,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                color: context.colors.bg0,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 24,
                                child: panel.audioNoteSeconds == null
                                    ? Text(
                                        'нет записи',
                                        style: TextStyle(
                                          color: context.colors.text3,
                                          fontSize: 12,
                                        ),
                                      )
                                    : Row(
                                        children: List.generate(
                                          24,
                                          (i) => Expanded(
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(
                                                  horizontal: 1),
                                              height: 6 + (i % 5) * 4,
                                              color: i < 10
                                                  ? context.colors.text1
                                                  : context.colors.text3,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: next == null
                          ? () => Navigator.of(context).pop()
                          : () => setState(() => _panelId = next.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.statusDone,
                        foregroundColor: context.colors.modeBuyInk,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ДАЛЬШЕ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                next?.name ?? 'Завершить осмотр',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: context.colors.modeBuyInk,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward,
                              color: context.colors.statusDone,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
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

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({
    required this.condition,
    required this.selected,
    required this.onTap,
  });

  final PanelCondition condition;
  final bool selected;
  final VoidCallback onTap;

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
                color: selected ? context.colors.statusDone : context.colors.text1,
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
  final VoidCallback onTap;

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
            color: on ? context.colors.statusProgress : context.colors.text2,
          ),
        ),
      ),
    );
  }
}
