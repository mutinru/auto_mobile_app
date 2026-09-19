import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/api_verification_repository.dart';
import '../data/auth_service.dart';
import '../models/order_status.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'nearby_orders_screen.dart';
import 'verification_screen.dart';
import 'my_orders_screen.dart';

/// Экран 03 из car-marketplace-experiment.html — «профиль · две роли».
/// Точка входа после логина: аккаунт один, роли не выбираются, доступ к
/// выполнению заказов открывается верификацией.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.auth, required this.store});

  final AuthService auth;
  final OrderStore store;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.loadMyOrders();
    widget.store.loadAssignedOrders();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.auth, widget.store]),
      builder: (context, _) {
        final user = widget.auth.user;
        final orders = widget.store.myOrders;
        final assigned = widget.store.assignedOrders;
        final active = orders
            .where((o) =>
                o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
            .length;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                DetailHead(
                  title: 'Профиль',
                  eyebrow: 'аккаунт',
                  // профиль открывается с витрины — без этого с него
                  // некуда вернуться
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).pop()
                      : null,
                  trailing: SquareIconButton(
                    icon: Icons.settings_outlined,
                    onTap: () {},
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                    children: [
                      // .prof-head
                      Row(
                        children: [
                          Avatar(initialsOf(user?.name ?? '—'), size: 54),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? '—',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.36,
                                    color: AppColors.text1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    user?.email ?? '',
                                    if (user?.registeredLabel.isNotEmpty ?? false)
                                      user!.registeredLabel,
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _NoteBox(
                        boldPart: 'роли не разделены',
                        before: 'Аккаунт один — ',
                        after:
                            '. Вы можете заказывать подбор и одновременно выполнять чужие заказы.',
                      ),

                      const SizedBox(height: 22),
                      const SectionHead('Ваши возможности'),
                      _RoleBlock(
                        active: true,
                        icon: Icons.check,
                        name: 'Заказывать подбор',
                        state: 'Доступно сразу · без проверок',
                        actionLabel: 'Мои заказы',
                        actionPrimary: true,
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MyOrdersScreen(
                              store: widget.store,
                              auth: widget.auth,
                              // открыты из профиля — иконка просто
                              // возвращает в него, а не плодит копию
                              onProfile: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                        statsWidgets: [
                          _Stat('${orders.length}', 'заказов'),
                          _Stat('$active', 'в работе'),
                        ],
                      ),
                      _RoleBlock(
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
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NearbyOrdersScreen(
                    store: widget.store,
                    verification: ApiVerificationRepository(ApiClient(widget.auth)),
                    auth: widget.auth,
                  ),
                          ),
                        ),
                        statsWidgets: assigned.isEmpty
                            ? null
                            : [_Stat('${assigned.length}', 'взято')],
                        secondaryLabel: assigned.isEmpty
                            ? 'Пройти верификацию'
                            : 'Взятые заказы',
                        onSecondary: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => assigned.isEmpty
                                ? VerificationScreen(auth: widget.auth)
                                : MyOrdersScreen(
                                    store: widget.store,
                                    auth: widget.auth,
                                    asExecutor: true,
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
      },
    );
  }
}

/// .note-box — синяя врезка с пояснением.
class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.before, required this.boldPart, required this.after});

  final String before;
  final String boldPart;
  final String after;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.statusInfo.withValues(alpha: 0.07),
        border: Border.all(color: AppColors.statusInfo.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, size: 15, color: AppColors.statusInfo),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: before),
                  TextSpan(
                    text: boldPart,
                    style: const TextStyle(
                      color: AppColors.text1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: after),
                ],
              ),
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.text2,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// .role-block — карточка возможности аккаунта.
class _RoleBlock extends StatelessWidget {
  const _RoleBlock({
    required this.active,
    required this.icon,
    required this.name,
    required this.state,
    required this.actionLabel,
    required this.onAction,
    this.dashed = false,
    this.description,
    this.actionPrimary = false,
    this.statsWidgets,
    this.secondaryLabel,
    this.onSecondary,
  });

  final bool active;
  final bool dashed;
  final IconData icon;
  final String name;
  final String state;
  final String? description;
  final String actionLabel;
  final bool actionPrimary;
  final VoidCallback onAction;
  final List<Widget>? statsWidgets;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: active
            ? AppColors.statusDone.withValues(alpha: 0.05)
            : AppColors.bg1,
        border: Border.all(
          color: active
              ? AppColors.statusDone.withValues(alpha: 0.45)
              : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .rb-top
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active ? AppColors.statusDone : AppColors.bg3,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: active ? const Color(0xFF07150E) : AppColors.text2,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        color: AppColors.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // .rb-body
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 12),
          if (statsWidgets != null) ...[
            Row(
              children: [
                for (final w in statsWidgets!) ...[w, const SizedBox(width: 18)],
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (description != null) ...[
            Text(
              description!,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.text2,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    actionPrimary ? AppColors.statusDone : AppColors.bg3,
                foregroundColor:
                    actionPrimary ? const Color(0xFF07150E) : AppColors.text1,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                elevation: 0,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSecondary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusDone,
                  foregroundColor: const Color(0xFF07150E),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  secondaryLabel!,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// .rb-stats > div
class _Stat extends StatelessWidget {
  const _Stat(this.value, this.caption);

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTheme.monoFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.32,
            color: AppColors.text1,
          ),
        ),
        const SizedBox(height: 2),
        Text(caption, style: const TextStyle(fontSize: 10, color: AppColors.text3)),
      ],
    );
  }
}
