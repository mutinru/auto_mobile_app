import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/api_inspection_repository.dart';
import '../data/auth_service.dart';
import '../data/vin_report_repository.dart';
import '../models/vin_report.dart';
import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/money.dart';
import '../util/ru_date.dart';
import '../util/ru_plural.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/inspection_order_parts.dart';
import 'inspection_report_screen.dart';

/// Купленный пакет готовых отчётов по VIN: осмотры с вердиктами, тап —
/// полный отчёт. [auth] нужен, чтобы открыть отчёт через API; без него
/// (в тестах) список только для чтения.
class VinReportScreen extends StatefulWidget {
  const VinReportScreen({
    super.key,
    required this.repository,
    required this.purchaseId,
    this.auth,
  });

  final VinReportRepository repository;
  final int purchaseId;
  final AuthService? auth;

  @override
  State<VinReportScreen> createState() => _VinReportScreenState();
}

class _VinReportScreenState extends State<VinReportScreen> {
  VinReportPurchase? _purchase;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final purchase = await widget.repository.fetchVinReportPurchase(
        widget.purchaseId,
      );
      if (mounted) setState(() => _purchase = purchase);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    }
  }

  void _open(VinReportPurchase purchase, VinReportItem item) {
    final auth = widget.auth;
    final id = item.inspectionId;
    if (auth == null || id == null) return;
    // стор — до маршрута: builder перезапускается при смене темы
    final store = InspectionStore(
      ApiInspectionRepository(ApiClient(auth), inspectionId: id),
      readOnly: true,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionReportScreen.purchased(
          store: store,
          title: purchase.carTitle ?? 'VIN ${purchase.vinMasked}',
          verdict: item.verdict,
          verdictComment: item.verdictComment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchase = _purchase;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: purchase?.carTitle ?? 'Отчёты по VIN',
              eyebrow: purchase == null
                  ? 'готовые отчёты'
                  : 'VIN ${purchase.vinMasked}',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(child: _body(purchase)),
          ],
        ),
      ),
    );
  }

  Widget _body(VinReportPurchase? purchase) {
    if (_error != null) {
      return _ErrorBlock(text: _error!, onRetry: _load);
    }
    if (purchase == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      children: [
        SectionHead(
          'Осмотры этой машины',
          extra: '${purchase.items.length}',
        ),
        for (final item in purchase.items)
          _ReportCard(
            item: item,
            onTap: widget.auth != null && item.inspectionId != null
                ? () => _open(purchase, item)
                : null,
          ),
        const SizedBox(height: 6),
        Text(
          'Отчёты сделали другие исполнители. Данные продавца и голосовые '
          'заметки в них скрыты.',
          style: TextStyle(fontSize: 11.5, color: context.colors.text3),
        ),
      ],
    );
  }
}

/// Один осмотр пакета: когда, где, пробег и вердикт.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.item, this.onTap});

  final VinReportItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final verdict = item.verdict;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      vinReportLine(item),
                      style: TextStyle(
                        fontFamily: AppTheme.monoFamily,
                        fontSize: 11.5,
                        color: context.colors.text2,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Text(
                      'Полный отчёт ›',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.doneText,
                      ),
                    ),
                ],
              ),
            ),
            if (verdict != null)
              InspectionVerdictBox(
                verdict: verdict,
                comment: item.verdictComment,
              ),
          ],
        ),
      ),
    );
  }
}

/// «20 октября · Москва · 112 000 км» — что известно об осмотре.
String vinReportLine(VinReportItem item) => [
  if (item.date case final d?) dayMonth(d),
  ?item.city,
  if (item.mileageKm case final km?) '${money(km)} км',
].join(' · ');

/// Купленные пакеты отчётов — вход из профиля.
class VinReportsScreen extends StatefulWidget {
  const VinReportsScreen({super.key, required this.repository, this.auth});

  final VinReportRepository repository;
  final AuthService? auth;

  @override
  State<VinReportsScreen> createState() => _VinReportsScreenState();
}

class _VinReportsScreenState extends State<VinReportsScreen> {
  List<VinReportPurchase>? _purchases;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await widget.repository.fetchVinReportPurchases();
      if (mounted) setState(() => _purchases = list);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchases = _purchases;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: 'Купленные отчёты',
              eyebrow: 'отчёты по VIN',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: _error != null
                  ? _ErrorBlock(text: _error!, onRetry: _load)
                  : purchases == null
                  ? const Center(child: CircularProgressIndicator())
                  : purchases.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Пока пусто. Укажите VIN при заказе осмотра — '
                          'если машину уже смотрели, отчёт можно купить.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.text3,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
                      children: [
                        for (final p in purchases)
                          _PurchaseRow(
                            purchase: p,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => VinReportScreen(
                                  repository: widget.repository,
                                  purchaseId: p.id,
                                  auth: widget.auth,
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
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({required this.purchase, required this.onTap});

  final VinReportPurchase purchase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = purchase.items.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.colors.bg1,
            border: Border.all(color: context.colors.line),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchase.carTitle ?? 'VIN ${purchase.vinMasked}',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'VIN ${purchase.vinMasked} · '
                      '$n ${plural(n, 'осмотр', 'осмотра', 'осмотров')}',
                      style: TextStyle(
                        fontFamily: AppTheme.monoFamily,
                        fontSize: 11,
                        color: context.colors.text3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.colors.text3),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.colors.text2),
          ),
          const SizedBox(height: 10),
          CtaGhost(label: 'Повторить', onPressed: onRetry),
        ],
      ),
    );
  }
}
