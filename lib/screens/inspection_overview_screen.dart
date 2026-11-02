import 'package:flutter/material.dart';

import '../models/inspection_panel.dart';
import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/inspection_schematic.dart';
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
    this.sendLabel = 'Отправить отчёт клиенту',
  });

  final InspectionStore store;

  /// Подпись главной кнопки сводки — см. [InspectionSummaryScreen.sendLabel].
  final String sendLabel;

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

  /// Главная кнопка ведёт по осмотру: пока есть неоценённые пункты, она
  /// открывает первый из них (дальше по цепочке — «Дальше» в карточке),
  /// после — сводка и отчёт.
  Widget _primaryAction(InspectionStore store) {
    final next = store.firstUnrated;
    if (next != null) {
      return NextStepButton(
        caption: store.evaluatedCount == 0 ? 'Начать осмотр' : 'Продолжить',
        title: next.name,
        onPressed: () => _openPanel(next.id),
      );
    }
    return NextStepButton(
      caption: 'Осмотр завершён',
      title: 'Сформировать отчёт',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InspectionSummaryScreen(
            store: store,
            onSendReport: widget.onSendReport,
            sendLabel: widget.sendLabel,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        if (store.loadError != null && !store.isLoading) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Не удалось открыть осмотр',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      store.loadError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.text3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CtaGhost(
                      label: 'Повторить',
                      onPressed: store.load,
                    ),
                    CtaGhost(
                      label: 'Назад',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
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
                              [
                                'VIN ${car.vinMasked}',
                                ?car.mileageLabel,
                              ].join(' · '),
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
                // Подсказка только на схеме: в списке строки и так читаются как
                // кнопки. Исполнителю — пока ничего не оценено, заказчику — всегда.
                if (_tab == 0 && (store.readOnly || store.evaluatedCount == 0))
                  _SchematicHint(
                    // одна строка: «по порядку» и так говорит зелёная кнопка внизу
                    store.readOnly
                        ? 'Нажмите на деталь, чтобы посмотреть оценку'
                        : 'Нажмите на деталь или пункт сбоку',
                  ),
                Expanded(
                  child: _tab == 0
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                          child: InspectionSchematic(
                            panels: store.panels,
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
                if (store.readOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                    child: Text(
                      'Только просмотр — оценки ставит исполнитель',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.text3,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                    child: SizedBox(
                      width: double.infinity,
                      child: _primaryAction(store),
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

/// .schematic-hint — строка над схемой: что здесь можно нажать.
class _SchematicHint extends StatelessWidget {
  const _SchematicHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 14, color: context.colors.text3),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.colors.text3),
            ),
          ),
        ],
      ),
    );
  }
}
