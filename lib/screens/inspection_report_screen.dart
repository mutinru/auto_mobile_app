import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/api_inspection_repository.dart';
import '../data/auth_service.dart';
import '../models/inspection_panel.dart';
import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/panel_condition.dart';
import '../models/panel_status.dart';
import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/audio_note.dart';
import '../widgets/inspection_schematic.dart';
import '../widgets/inspection_order_parts.dart';
import '../widgets/inspection_report_parts.dart';
import 'panel_list_view.dart';

/// Открыть полный отчёт по разовому осмотру. Стор — до маршрута:
/// builder перезапускается при смене темы.
Future<void> openInspectionReport(
  BuildContext context,
  AuthService auth,
  Order order,
) {
  final store = InspectionStore(
    ApiInspectionRepository(
      ApiClient(auth),
      inspectionId: order.cars.first.inspectionId!,
    ),
  );
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => InspectionReportScreen(store: store, order: order),
    ),
  );
}

/// Есть ли у заказа отчёт, который можно открыть: осмотр завершён
/// и у машины есть id осмотра.
bool hasInspectionReport(Order order) =>
    order.isInspection &&
    order.verdict != null &&
    order.cars.isNotEmpty &&
    order.cars.first.inspectionId != null;

/// Полный отчёт осмотра только для чтения — то, что видит заказчик:
/// вердикт, балл, схема, дефекты, оценка и фото каждой детали.
/// Ничего не меняет: ни оценок, ни дефектов, ни фото.
class InspectionReportScreen extends StatefulWidget {
  InspectionReportScreen({
    super.key,
    required this.store,
    required Order order,
  }) : title = order.carTitle,
       verdict = order.verdict,
       verdictComment = order.cars.firstOrNull?.verdictComment;

  /// Отчёт из купленного пакета по VIN: заказа у покупателя нет, вердикт
  /// пришёл с покупкой. Голосовых заметок сервер ему не отдаёт.
  const InspectionReportScreen.purchased({
    super.key,
    required this.store,
    required this.title,
    this.verdict,
    this.verdictComment,
  });

  final InspectionStore store;

  /// Машина — подпись над заголовком.
  final String title;
  final InspectionVerdict? verdict;
  final String? verdictComment;

  @override
  State<InspectionReportScreen> createState() => _InspectionReportScreenState();
}

class _InspectionReportScreenState extends State<InspectionReportScreen> {
  @override
  void initState() {
    super.initState();
    // ошибку стор держит в loadError — её и рисуем вместо спиннера
    widget.store.load();
  }

  void _openPanel(InspectionPanel panel) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.bg0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _PanelReportSheet(panel: panel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: 'Отчёт',
              eyebrow: widget.title,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.store,
                builder: (context, _) => _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final store = widget.store;
    final error = store.loadError;
    if (error != null && !store.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Не удалось загрузить отчёт',
              style: TextStyle(fontSize: 14, color: context.colors.text1),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: context.colors.text3),
            ),
            const SizedBox(height: 10),
            CtaGhost(label: 'Повторить', onPressed: store.load),
          ],
        ),
      );
    }

    if (store.isLoading || store.car == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final panels = store.panels;
    final defective = defectivePanels(panels);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      children: [
        if (widget.verdict case final verdict?) ...[
          const SectionHead('Итог осмотра'),
          InspectionVerdictBox(
            verdict: verdict,
            comment: widget.verdictComment,
          ),
          const SizedBox(height: 22),
        ],
        ReportScoreCard(panels: panels),
        const SizedBox(height: 12),
        ReportStats(panels: panels),
        if (store.car!.vinPhotoUrl case final url?) ...[
          const SizedBox(height: 22),
          const SectionHead('Табличка VIN', extra: 'сняли на осмотре'),
          VinPlateRow(vinMasked: store.car!.vinMasked, photoUrl: url),
        ],

        const SizedBox(height: 22),
        const SectionHead('Схема', extra: 'нажмите на пункт'),
        // схема 360×720: по высоте 380 — читается и не съедает экран
        SizedBox(
          height: 380,
          child: InspectionSchematic(
            panels: panels,
            onTapPanel: (id) => _openPanel(store.panelById(id)),
          ),
        ),

        const SizedBox(height: 22),
        const SectionHead('Найденные дефекты'),
        if (defective.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Дефекты не отмечены',
              style: TextStyle(fontSize: 12, color: context.colors.text3),
            ),
          )
        else
          for (final p in defective)
            ReportDefectItem(panel: p, onTap: () => _openPanel(p)),

        const SizedBox(height: 4),
        PanelListView(
          panels: panels,
          onTap: _openPanel,
          embedded: true,
          forCustomer: true,
        ),
      ],
    );
  }
}

/// Одна деталь в отчёте: оценка, отмеченные дефекты, фото и голосовая
/// заметка. Только чтение.
class _PanelReportSheet extends StatelessWidget {
  const _PanelReportSheet({required this.panel});

  final InspectionPanel panel;

  @override
  Widget build(BuildContext context) {
    final condition = panel.condition;
    final color = panel.status.color(context.colors);
    final audioUrl = panel.audioNoteUrl;
    final audioSeconds = panel.audioNoteSeconds;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              panel.zone.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: context.colors.text3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    panel.name,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: context.colors.text1,
                    ),
                  ),
                ),
                if (condition != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${condition.grade} · ${condition.label}',
                      style: TextStyle(
                        fontFamily: AppTheme.monoFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textFor(color),
                      ),
                    ),
                  )
                else
                  Text(
                    'Не оценена',
                    style: TextStyle(fontSize: 12, color: context.colors.text3),
                  ),
              ],
            ),

            const SizedBox(height: 20),
            const SectionHead('Дефекты'),
            if (panel.defects.isEmpty)
              Text(
                'Дефектов нет',
                style: TextStyle(fontSize: 12.5, color: context.colors.text2),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in panel.defects)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.statusDefect.withValues(
                          alpha: 0.10,
                        ),
                        border: Border.all(
                          color: context.colors.statusDefect.withValues(
                            alpha: 0.45,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.colors.text1,
                        ),
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 20),
            SectionHead('Фото', extra: '${panel.photoUrls.length}'),
            if (panel.photoUrls.isEmpty)
              Text(
                'Фото нет',
                style: TextStyle(fontSize: 12.5, color: context.colors.text2),
              )
            else
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final url in panel.photoUrls)
                      GestureDetector(
                        onTap: () => _openPhoto(context, url),
                        child: Container(
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
                      ),
                  ],
                ),
              ),
            if (audioUrl != null && audioSeconds != null) ...[
              const SizedBox(height: 20),
              SectionHead(
                'Голосовая заметка',
                extra: formatAudioTime(Duration(seconds: audioSeconds)),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                decoration: BoxDecoration(
                  color: context.colors.bg1,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AudioNotePlayer(
                  url: audioUrl,
                  seconds: audioSeconds,
                  seed: panel.id,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openPhoto(BuildContext context, String url) =>
      openPhotoViewer(context, url);
}
