import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/verification_repository.dart';
import '../models/order_status.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/support_sheet.dart';
import '../widgets/theme_switch.dart';
import 'verification_screen.dart';
import 'my_orders_screen.dart';

/// Экран 03 из car-marketplace-experiment.html — «профиль · две роли».
/// Точка входа после логина: аккаунт один, роли не выбираются, доступ к
/// выполнению заказов открывается верификацией — если сервер её требует.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    required this.store,
    required this.verification,
    required this.onMyOrders,
    required this.onNearbyOrders,
  });

  final AuthService auth;
  final OrderStore store;
  final VerificationRepository verification;

  /// Переход в разделы. Они подменяют профиль, а не ложатся поверх —
  /// навигацией разделов управляет main.dart.
  final VoidCallback onMyOrders;
  final VoidCallback onNearbyOrders;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  VerificationSummary? _verification;

  @override
  void initState() {
    super.initState();
    widget.store.loadMyOrders();
    widget.store.loadAssignedOrders();
    _loadVerification();
  }

  /// Ошибку глотаем: без сводки считаем верификацию необязательной и пункт
  /// про неё не показываем — сервер всё равно проверит отклик сам.
  Future<void> _loadVerification() async {
    try {
      final summary = await widget.verification.fetchSummary();
      if (mounted) setState(() => _verification = summary);
    } catch (_) {
      // молча
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.auth, widget.store]),
      builder: (context, _) {
        final user = widget.auth.user;
        final orders = widget.store.myOrders;
        final assigned = widget.store.assignedOrders;
        final verificationRequired = _verification?.required ?? false;
        final active = orders
            .where(
              (o) =>
                  o.status != OrderStatus.completed &&
                  o.status != OrderStatus.cancelled,
            )
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
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.36,
                                    color: context.colors.text1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    user?.email ?? '',
                                    if (user?.registeredLabel.isNotEmpty ??
                                        false)
                                      user!.registeredLabel,
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.text2,
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
                        onAction: widget.onMyOrders,
                        statsWidgets: [
                          _Stat('${orders.length}', 'заказов'),
                          _Stat('$active', 'в работе'),
                        ],
                      ),
                      if (verificationRequired)
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
                          onAction: widget.onNearbyOrders,
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
                        )
                      else
                        // верификация выключена на сервере — откликаться
                        // можно сразу, пункт про неё не показываем
                        _RoleBlock(
                          active: true,
                          icon: Icons.check,
                          name: 'Выполнять заказы',
                          state: assigned.isEmpty
                              ? 'Можно откликаться на заказы'
                              : 'Взятых заказов: ${assigned.length}',
                          actionLabel: 'Смотреть заказы рядом',
                          onAction: widget.onNearbyOrders,
                          statsWidgets: assigned.isEmpty
                              ? null
                              : [_Stat('${assigned.length}', 'взято')],
                          secondaryLabel: assigned.isEmpty
                              ? null
                              : 'Взятые заказы',
                          onSecondary: assigned.isEmpty
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MyOrdersScreen(
                                      store: widget.store,
                                      auth: widget.auth,
                                      asExecutor: true,
                                    ),
                                  ),
                                ),
                        ),

                      // те же тема и поддержка, что на стартовом экране, —
                      // чтобы не возвращаться к нему ради них
                      const SizedBox(height: 22),
                      const SectionHead('Приложение'),
                      const _SettingsRow(
                        icon: Icons.contrast,
                        label: 'Тема',
                        trailing: ThemeSwitch(),
                      ),
                      _SettingsRow(
                        icon: Icons.headset_mic_outlined,
                        label: 'Поддержка',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const OnlineDot(),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: context.colors.text3,
                            ),
                          ],
                        ),
                        onTap: () => showSupportSheet(context),
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
              color: context.colors.statusInfo,
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
            ? context.colors.statusDone.withValues(alpha: 0.05)
            : context.colors.bg1,
        border: Border.all(
          color: active
              ? context.colors.statusDone.withValues(alpha: 0.45)
              : context.colors.line,
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
                  color: active
                      ? context.colors.statusDone
                      : context.colors.bg3,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: active
                      ? context.colors.modeBuyInk
                      : context.colors.text2,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        color: context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // .rb-body
          const SizedBox(height: 12),
          Container(height: 1, color: context.colors.line),
          const SizedBox(height: 12),
          if (statsWidgets != null) ...[
            Row(
              children: [
                for (final w in statsWidgets!) ...[
                  w,
                  const SizedBox(width: 18),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (description != null) ...[
            Text(
              description!,
              style: TextStyle(
                fontSize: 11.5,
                color: context.colors.text2,
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
                backgroundColor: actionPrimary
                    ? context.colors.statusDone
                    : context.colors.bg3,
                foregroundColor: actionPrimary
                    ? context.colors.modeBuyInk
                    : context.colors.text1,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                elevation: 0,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
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
                  backgroundColor: context.colors.statusDone,
                  foregroundColor: context.colors.modeBuyInk,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  secondaryLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
          style: TextStyle(
            fontFamily: AppTheme.monoFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.32,
            color: context.colors.text1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: TextStyle(fontSize: 10, color: context.colors.text3),
        ),
      ],
    );
  }
}

/// Строка настроек: иконка, подпись, справа — контрол или стрелка.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.bg1,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.line),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.bg3,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: c.text1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: c.text1,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
