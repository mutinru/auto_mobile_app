import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../models/current_user.dart';
import '../../models/order_status.dart';
import '../../state/order_store.dart';
import '../../state/verification_status.dart';
import '../../theme/app_colors.dart';
import '../../util/ru_plural.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/executor_stats.dart';
import '../executor_reviews_screen.dart';
import '../my_orders_screen.dart';
import '../verification_screen.dart';
import 'role_block.dart';

/// «Ваши возможности»: аккаунт один, роли не выбираются. Заказывать подбор
/// можно сразу; выполнять заказы — сразу или после верификации, если её
/// требует сервер (`verification.summary.required`).
class ProfileRolesSection extends StatelessWidget {
  const ProfileRolesSection({
    super.key,
    required this.auth,
    required this.store,
    required this.verification,
    required this.onMyOrders,
    required this.onNearbyOrders,
  });

  final AuthService auth;
  final OrderStore store;
  final VerificationStatus verification;
  final VoidCallback onMyOrders;
  final VoidCallback onNearbyOrders;

  /// Плашки блока «Выполнять заказы»: рейтинг, отзывы, выполненные,
  /// взятые и сорванные. null — пока показывать нечего (новый исполнитель
  /// без заказов).
  List<Widget>? _executorStats(CurrentUser? me, int assigned) {
    final reviews = me?.reviewsCount ?? 0;
    final completed = me?.completedOrdersCount ?? 0;
    final missed = me?.missedOrdersCount ?? 0;
    if (reviews == 0 && completed == 0 && assigned == 0 && missed == 0) {
      return null;
    }
    return [
      RoleStat(me?.rating?.toStringAsFixed(1) ?? '—', 'рейтинг'),
      RoleStat('$reviews', plural(reviews, 'отзыв', 'отзыва', 'отзывов')),
      RoleStat('$completed', 'выполнено'),
      RoleStat('$assigned', 'взято'),
      // заказчики видят это число в откликах
      RoleStat('$missed', 'сорвано'),
    ];
  }

  /// «★ 4.8 · 12 отзывов · 30 заказов» под заголовком блока, как .prof-sub
  /// в car-marketplace-experiment.html; тап — отзывы обо мне.
  Widget? _ratingLine(BuildContext context, CurrentUser? me) {
    if (me == null || me.reviewsCount == 0) return null;
    return ExecutorStats(
      user: me.asSummary,
      onTap: () => openExecutorReviews(context, store.reviews, me.asSummary),
    );
  }

  void _openAssigned(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          MyOrdersScreen(store: store, auth: auth, asExecutor: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    final orders = store.myOrders;
    final assigned = store.assignedOrders;
    final verificationRequired = verification.summary?.required ?? false;
    final active = orders.where((o) => !o.status.isFinished).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _NoteBox(
          boldPart: 'роли не разделены',
          before: 'Аккаунт один — ',
          after:
              '. Вы можете заказывать подбор и одновременно выполнять чужие заказы.',
        ),
        const SizedBox(height: 22),
        const SectionHead('Ваши возможности'),
        RoleBlock(
          active: true,
          icon: Icons.check,
          name: 'Заказывать подбор',
          state: 'Доступно сразу · без проверок',
          actionLabel: 'Мои заказы',
          actionPrimary: true,
          onAction: onMyOrders,
          statsWidgets: [
            RoleStat('${orders.length}', 'заказов'),
            RoleStat('$active', 'в работе'),
          ],
        ),
        if (verificationRequired)
          RoleBlock(
            active: false,
            dashed: true,
            icon: Icons.lock_outline,
            name: 'Выполнять заказы',
            state: assigned.isEmpty
                ? 'Верификация появится позже'
                : 'Взятых заказов: ${assigned.length}',
            description:
                'Мы проверяем личность и умение находить дефекты — заказчики доверяют подборщику свои деньги.',
            actionLabel: 'Смотреть заказы рядом',
            onAction: onNearbyOrders,
            statsWidgets: _executorStats(user, assigned.length),
            stateExtra: _ratingLine(context, user),
            secondaryLabel: assigned.isEmpty
                ? 'Пройти верификацию'
                : 'Взятые заказы',
            onSecondary: () async {
              if (assigned.isNotEmpty) {
                _openAssigned(context);
                return;
              }
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VerificationScreen(auth: auth),
                ),
              );
              // могли пройти шаги верификации — перечитываем
              verification.refresh();
            },
          )
        else
          // верификация выключена на сервере — откликаться
          // можно сразу, пункт про неё не показываем
          RoleBlock(
            active: true,
            icon: Icons.check,
            name: 'Выполнять заказы',
            state: assigned.isEmpty
                ? 'Можно откликаться на заказы'
                : 'Взятых заказов: ${assigned.length}',
            actionLabel: 'Смотреть заказы рядом',
            onAction: onNearbyOrders,
            statsWidgets: _executorStats(user, assigned.length),
            stateExtra: _ratingLine(context, user),
            secondaryLabel: assigned.isEmpty ? null : 'Взятые заказы',
            onSecondary: assigned.isEmpty ? null : () => _openAssigned(context),
          ),
      ],
    );
  }
}

/// .note-box — синяя врезка с пояснением.
class _NoteBox extends StatelessWidget {
  const _NoteBox({
    required this.before,
    required this.boldPart,
    required this.after,
  });

  final String before;
  final String boldPart;
  final String after;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.statusInfo.withValues(alpha: 0.07),
        border: Border.all(
          color: context.colors.statusInfo.withValues(alpha: 0.25),
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline,
              size: 15,
              color: context.colors.infoText,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: before),
                  TextSpan(
                    text: boldPart,
                    style: TextStyle(
                      color: context.colors.text1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: after),
                ],
              ),
              style: TextStyle(
                fontSize: 11.5,
                color: context.colors.text2,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
