import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/support_sheet.dart';

/// «Частые вопросы» из шторки поддержки. Тексты статичные — на бекенде
/// под них ничего нет; ответы описывают то, что приложение умеет сейчас.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _items = [
    (
      'Как работает подбор?',
      'Вы описываете, какую машину ищете: марку, бюджет, год, пробег. '
          'Подборщики откликаются со своей ценой, вы выбираете одного. Он '
          'ищет варианты, едет на осмотры и присылает отчёт по каждой машине.',
    ),
    (
      'Чем разовый осмотр отличается от подбора?',
      'Осмотр — когда машина уже найдена. Вы присылаете объявление, '
          'специалист приезжает по адресу, проверяет кузов по 13 деталям и '
          'присылает отчёт с вердиктом: «можно брать», «с оговорками» или '
          '«не рекомендую».',
    ),
    (
      'Сколько это стоит?',
      'Цену предлагает исполнитель в отклике. Вы видите все отклики и '
          'выбираете сами — цена фиксируется, когда вы принимаете отклик.',
    ),
    (
      'Как происходит оплата?',
      'Через приложение оплата пока не проходит — о ней вы договариваетесь '
          'с исполнителем напрямую.',
    ),
    (
      'Какие гарантии?',
      'Исполнители проходят проверку: документы и тест на знание осмотра. '
          'Отчёт по каждой детали хранится в заказе — с фото и найденными '
          'дефектами, к нему всегда можно вернуться.',
    ),
    (
      'Можно ли пользоваться без регистрации?',
      'Смотреть витрину заказов и писать в поддержку можно без входа. '
          'Чтобы разместить заказ или откликнуться на него, войдите по номеру '
          'телефона.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              eyebrow: 'Поддержка',
              title: 'Частые вопросы',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                children: [
                  for (final (q, a) in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      // Material, а не Container с цветом: ExpansionTile рисует
                      // нажатие на ближайшем Material
                      child: Material(
                        color: c.bg1,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: c.line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Theme(
                          // у ExpansionTile свои рамки сверху и снизу — прячем
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              14,
                              0,
                              14,
                              14,
                            ),
                            iconColor: c.text2,
                            collapsedIconColor: c.text3,
                            title: Text(
                              q,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: c.text1,
                              ),
                            ),
                            expandedAlignment: Alignment.centerLeft,
                            children: [
                              Text(
                                a,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: c.text2,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  CtaFlat(
                    label: 'Не нашли ответ? Напишите нам',
                    onPressed: () => showSupportSheet(context),
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
