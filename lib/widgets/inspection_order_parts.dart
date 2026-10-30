import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/ru_date.dart';
import 'app_ui.dart';

/// Общие куски детали разового осмотра — у заказчика
/// ([InspectionOrderDetailScreen]) и у исполнителя ([AssignedInspectionScreen]).

/// .summary — дата, адрес, пробег и объявление, внизу цена. Подпись цены
/// разная: заказчику — «Ваша цена», исполнителю — «Ваш гонорар».
class InspectionOrderSummary extends StatelessWidget {
  const InspectionOrderSummary({
    super.key,
    required this.order,
    required this.priceLabel,
    required this.price,
  });

  final Order order;
  final String priceLabel;
  final int? price;

  @override
  Widget build(BuildContext context) {
    final listing = order.listingUrl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(
            icon: Icons.calendar_today_outlined,
            text: whenLabel(order.inspectOn, order.timeSlot, order.inspectTime),
            strong: true,
          ),
          // улицу сервер отдаёт только сторонам заказа — остальным город
          if (order.fullAddress ?? order.cities.firstOrNull case final place?)
            _SummaryRow(icon: Icons.location_on_outlined, text: place),
          if (order.mileageTo != null)
            _SummaryRow(
              icon: Icons.speed_outlined,
              text: '${money(order.mileageTo!)} км',
            ),
          if (listing != null && listing.isNotEmpty)
            order.listingHost == null
                // старый заказ с не-ссылкой — как раньше, просто текст
                ? _SummaryRow(icon: Icons.link, text: listing)
                : _ListingRow(
                    url: listing,
                    host: order.listingHost!,
                    site: order.listingSite,
                  )
          // ссылку сервер отдаёт только сторонам заказа — остальным площадка
          else if (order.hasListing)
            _LockedListingRow(site: order.listingSite),
          if (price != null) ...[
            const SizedBox(height: 11),
            Container(height: 1, color: context.colors.line),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Text(
                    priceLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.colors.text2,
                    ),
                  ),
                ),
                Text(
                  '${money(price!)} ₽',
                  style: TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// .summary-row
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.text,
    this.strong = false,
  });

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: context.colors.text3),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: strong ? context.colors.text1 : context.colors.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ссылка на объявление: «Объявление на Авито» для известной площадки,
/// для чужого сайта — домен и пометка «незнакомый сайт», чтобы было видно,
/// куда ведёт ссылка от незнакомого заказчика. Открывается во внешнем браузере.
class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.url, required this.host, this.site});

  final String url;
  final String host;
  final String? site;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12.5, height: 1.4, color: context.colors.text2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.link, size: 15, color: context.colors.text3),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                site != null
                    ? TextSpan(
                        text: 'Объявление на ',
                        children: [
                          TextSpan(
                            text: site,
                            style: TextStyle(
                              color: context.colors.text1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : TextSpan(
                        text: host,
                        style: TextStyle(color: context.colors.text1),
                        children: [
                          TextSpan(
                            text: ' · незнакомый сайт',
                            style: TextStyle(color: context.colors.statusProgress),
                          ),
                        ],
                      ),
                style: style,
              ),
            ),
            Icon(Icons.open_in_new, size: 14, color: context.colors.text3),
          ],
        ),
      ),
    );
  }
}

/// Объявление есть, но ссылку видят только заказчик и выбранный
/// исполнитель: через объявление можно выйти на продавца.
class _LockedListingRow extends StatelessWidget {
  const _LockedListingRow({this.site});

  final String? site;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.link, size: 15, color: context.colors.text3),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: site != null ? 'Объявление на ' : 'Объявление на другом сайте',
                children: [
                  if (site != null)
                    TextSpan(
                      text: site,
                      style: TextStyle(
                        color: context.colors.text1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  TextSpan(
                    text: ' · откроется после выбора',
                    style: TextStyle(color: context.colors.text3),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 12.5, height: 1.4, color: context.colors.text2),
            ),
          ),
          Icon(Icons.lock_outline, size: 14, color: context.colors.text3),
        ],
      ),
    );
  }
}

/// Вердикт с комментарием — то, ради чего заказ и делался.
class InspectionVerdictBox extends StatelessWidget {
  const InspectionVerdictBox({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final verdict = order.verdict!;
    final comment = order.cars.first.verdictComment;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(
          color: verdict.color(context.colors).withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: verdict.color(context.colors).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              verdict.icon,
              size: 15,
              color: verdict.color(context.colors),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verdict.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: verdict.color(context.colors),
                  ),
                ),
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    comment,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.colors.text2,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
