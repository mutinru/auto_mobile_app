import 'package:flutter/material.dart';

import '../models/inspection_panel.dart';
import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/car_schematic.dart';
import '../widgets/progress_summary.dart';
import 'inspection_summary_screen.dart';
import 'panel_detail_screen.dart';
import 'panel_list_view.dart';

/// Экраны 06 и 07 макета — «схема» и «список» под одним переключателем.
class InspectionOverviewScreen extends StatefulWidget {
  const InspectionOverviewScreen({
    super.key,
    required this.store,
    this.onSendReport,
  });

  final InspectionStore store;

  /// Пробрасывается в [InspectionSummaryScreen] — см. там.
  final VoidCallback? onSendReport;

  @override
  State<InspectionOverviewScreen> createState() =>
      _InspectionOverviewScreenState();
}

class _InspectionOverviewScreenState extends State<InspectionOverviewScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.store.load();
  }

  Future<void> _openPanel(String panelId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PanelDetailScreen(store: widget.store, panelId: panelId),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        if (store.isLoading || store.car == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final car = store.car!;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // .head — иконка авто, название, VIN и пробег
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: context.colors.bg1,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.directions_car_filled_outlined,
                          size: 20,
                          color: context.colors.text2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              car.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.15,
                                color: context.colors.text1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'VIN ${car.vinMasked} · ${car.mileageLabel}',
                              style: TextStyle(
                                fontFamily: AppTheme.monoFamily,
                                fontSize: 11,
                                color: context.colors.text3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SquareIconButton(
                        icon: _tab == 0 ? Icons.more_vert : Icons.tune,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                AppToggle(
                  labels: const ['Схема', 'Список'],
                  activeIndex: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                Expanded(
                  child: _tab == 0
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                          child: CarSchematic(
                            statuses: {
                              for (final p in store.panels) p.id: p.status,
                            },
                            onTapPanel: _openPanel,
                          ),
                        )
                      : PanelListView(
                          panels: store.panels,
                          onTap: (InspectionPanel p) => _openPanel(p.id),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: ProgressSummary(panels: store.panels),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                  child: SizedBox(
                    width: double.infinity,
                    // .cta-btn — приглушённая кнопка, пока осмотр не завершён
                    child: OutlinedButton(
                      onPressed: store.remainingCount == 0
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => InspectionSummaryScreen(
                                  store: store,
                                  onSendReport: widget.onSendReport,
                                ),
                              ),
                            )
                          : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: context.colors.bg1,
                        side: BorderSide(color: context.colors.line),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Сформировать отчёт',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: store.remainingCount == 0
                                  ? context.colors.text1
                                  : context.colors.text3,
                            ),
                          ),
                          Text(
                            store.remainingCount == 0
                                ? 'готово'
                                : 'осталось ${store.remainingCount}',
                            style: TextStyle(
                              fontFamily: AppTheme.monoFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.colors.text3,
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
