import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/payment_repository.dart';
import '../models/payment.dart';
import '../theme/app_colors.dart';
import '../util/money.dart';
import '../util/ru_date.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/load_more.dart';

/// «Платежи»: оплаты пользователя с чеками — новые сверху, страницами с
/// сервера. Чек — ссылка на страницу ФНС, открывается в браузере; статус чека
/// ведёт сервер (зарегистрирован, оформляется, аннулирован после возврата).
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, required this.repository});

  final PaymentRepository repository;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final List<Payment> _payments = [];
  bool _loaded = false;
  bool _loading = false;
  bool _hasMore = false;
  int _page = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _page = 0;
    _payments.clear();
    _hasMore = false;
    await _loadNext();
  }

  Future<void> _loadNext() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.fetchPayments(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _payments.addAll(page.items);
        _hasMore = page.hasMore;
        _loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: 'Платежи и чеки',
              eyebrow: 'аккаунт',
              onBack: backIfCanPop(context),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final c = context.colors;
    if (!_loaded) {
      if (_error != null && !_loading) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Не удалось загрузить платежи',
                style: TextStyle(fontSize: 14, color: c.text1),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: c.text3),
              ),
              const SizedBox(height: 10),
              CtaGhost(label: 'Повторить', onPressed: _reload),
            ],
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          if (_payments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'Оплат пока не было',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.text3),
              ),
            ),
          for (final payment in _payments) _PaymentTile(payment: payment),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: _error != null
                    ? CtaGhost(label: 'Повторить', onPressed: _loadNext)
                    : LoadMore(onShown: _loadNext),
              ),
            ),
          if (_payments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Чек приходит после списания денег. Если деньги вернулись, '
              'чек аннулируется.',
              style: TextStyle(fontSize: 11.5, color: c.text3),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final Payment payment;

  String get _title =>
      payment.description ??
      switch (payment.purpose) {
        'vin_report' => 'Готовые отчёты по VIN',
        'selection_placement' => 'Размещение подбора',
        'inspection_placement' => 'Размещение осмотра',
        _ => 'Оплата',
      };

  /// Что с деньгами: удержаны, списаны или вернулись.
  String get _state => switch (payment.status) {
    _ when payment.isRefunded => 'вернули',
    PaymentStatus.authorized => 'удержано до выбора исполнителя или отчёта',
    PaymentStatus.paid => 'оплачено',
    _ => '',
  };

  Future<void> _openReceipt(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть чек')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final receipt = payment.receipt;
    final at = payment.paidAt ?? payment.createdAt;
    final url = receipt?.url;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _title,
                  style: TextStyle(fontSize: 14, color: c.text1),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${money(payment.amount)} ₽',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.text1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (at != null) momentLabel(at),
              if (_state.isNotEmpty) _state,
            ].join(' · '),
            style: TextStyle(fontSize: 12, color: c.text3),
          ),
          if (receipt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.receipt_long_outlined, size: 16, color: c.text2),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    switch (receipt.status) {
                      ReceiptStatus.registered => 'Чек об оплате',
                      ReceiptStatus.cancelled => 'Чек аннулирован',
                      ReceiptStatus.issuing => 'Чек оформляется',
                      ReceiptStatus.unknown => 'Чек',
                    },
                    style: TextStyle(fontSize: 12.5, color: c.text2),
                  ),
                ),
                if (url != null)
                  TextButton(
                    onPressed: () => _openReceipt(context, url),
                    child: const Text('Открыть'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
