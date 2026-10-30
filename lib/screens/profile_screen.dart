import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/verification_repository.dart';
import '../models/current_user.dart';
import '../models/order_status.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/ru_plural.dart';
import '../widgets/app_ui.dart';
import '../widgets/change_phone_sheet.dart';
import '../widgets/edit_name_sheet.dart';
import '../widgets/executor_stats.dart';
import '../widgets/payout_sheet.dart';
import '../widgets/phone_input.dart';
import '../widgets/support_sheet.dart';
import '../widgets/theme_switch.dart';
import '../widgets/unread_badge.dart';
import 'executor_reviews_screen.dart';
import 'settings_screen.dart';
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
    required this.onLogout,
  });

  final AuthService auth;
  final OrderStore store;
  final VerificationRepository verification;

  /// Переход в разделы. Они подменяют профиль, а не ложатся поверх —
  /// навигацией разделов управляет main.dart.
  final VoidCallback onMyOrders;
  final VoidCallback onNearbyOrders;

  /// Сессия уже стёрта — корень приложения возвращает к вопросу о намерении.
  final Future<void> Function() onLogout;

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
    // рейтинг мог измениться с прошлого входа
    widget.auth.refreshUser();
    _loadVerification();
  }

  /// Плашки блока «Выполнять заказы»: рейтинг, отзывы, выполненные и
  /// взятые. null — пока показывать нечего (новый исполнитель без заказов).
  List<Widget>? _executorStats(CurrentUser? me, int assigned) {
    final reviews = me?.reviewsCount ?? 0;
    final completed = me?.completedOrdersCount ?? 0;
    if (reviews == 0 && completed == 0 && assigned == 0) return null;
    return [
      _Stat(me?.rating?.toStringAsFixed(1) ?? '—', 'рейтинг'),
      _Stat('$reviews', plural(reviews, 'отзыв', 'отзыва', 'отзывов')),
      _Stat('$completed', 'выполнено'),
      _Stat('$assigned', 'взято'),
    ];
  }

  /// «★ 4.8 · 12 отзывов · 30 заказов» под заголовком блока, как .prof-sub
  /// в car-marketplace-experiment.html; тап — отзывы обо мне.
  Widget? _ratingLine(CurrentUser? me) {
    if (me == null || me.reviewsCount == 0) return null;
    return ExecutorStats(
      user: me.asSummary,
      onTap: () => openExecutorReviews(
        context,
        widget.store.repository,
        me.asSummary,
      ),
    );
  }

  /// Выход — с подтверждением: строка стоит в конце списка, задеть её
  /// случайно при прокрутке легко.
  Future<void> _confirmLogout() async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.bg1,
        title: Text('Выйти из аккаунта?', style: TextStyle(color: c.text1, fontSize: 17)),
        content: Text(
          'Чтобы вернуться, понадобится код из Telegram или звонка.',
          style: TextStyle(color: c.text2, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Отмена', style: TextStyle(color: c.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Выйти', style: TextStyle(color: c.statusDefect, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) await widget.onLogout();
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
            .where((o) => !o.status.isFinished)
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
                    onTap: () {
                      if (user == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(auth: widget.auth),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                    children: [
                      // .prof-head; тап по шапке — смена имени
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: user == null
                            ? null
                            : () => showEditNameSheet(
                                context,
                                initial: user.name,
                                onSave: widget.auth.updateName,
                              ),
                        child: Row(
                          children: [
                            Avatar(initialsOf(user?.name ?? '—'), size: 54),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user?.name ?? '—',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.36,
                                            color: context.colors.text1,
                                          ),
                                        ),
                                      ),
                                      if (user != null) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: context.colors.text3,
                                        ),
                                      ],
                                    ],
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
                          statsWidgets: _executorStats(user, assigned.length),
                          stateExtra: _ratingLine(user),
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
                          statsWidgets: _executorStats(user, assigned.length),
                          stateExtra: _ratingLine(user),
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

                      // телефон — логин, поэтому смена через код на новый номер
                      const SizedBox(height: 10),
                      _SettingsRow(
                        icon: Icons.phone_outlined,
                        label: 'Номер телефона',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user?.phone != null ? formatPhone(user!.phone!) : 'не указан',
                              style: TextStyle(fontSize: 12, color: context.colors.text2),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, size: 18, color: context.colors.text3),
                          ],
                        ),
                        onTap: user == null
                            ? null
                            : () => showChangePhoneSheet(
                                  context,
                                  currentPhone: user.phone,
                                  onRequest: widget.auth.requestPhoneChange,
                                  onConfirm: widget.auth.confirmPhoneChange,
                                ),
                      ),

                      // разовый осмотр оплачивается напрямую исполнителю;
                      // при первом отклике реквизиты спросит и форма отклика
                      _SettingsRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Реквизиты для выплат',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user?.payout?.shortLabel ?? 'не указаны',
                              style: TextStyle(fontSize: 12, color: context.colors.text2),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, size: 18, color: context.colors.text3),
                          ],
                        ),
                        onTap: () => showPayoutSheet(
                          context,
                          initial: user?.payout,
                          onSave: widget.auth.updatePayout,
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
                            SupportUnreadBuilder(
                              builder: (context, count) => count > 0
                                  ? Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: UnreadBadge(count, borderColor: context.colors.bg1),
                                    )
                                  : const SizedBox.shrink(),
                            ),
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

                      // .row[data-action=logout] из tab-bar-navigation.html
                      const SizedBox(height: 22),
                      _SettingsRow(
                        icon: Icons.logout,
                        label: 'Выйти',
                        labelColor: context.colors.statusDefect,
                        trailing: const SizedBox.shrink(),
                        onTap: _confirmLogout,
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
    this.stateExtra,
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

  /// Под строкой состояния — например, свой рейтинг исполнителя.
  final Widget? stateExtra;
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
                    if (stateExtra != null) ...[
                      const SizedBox(height: 3),
                      stateExtra!,
                    ],
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
            // Wrap, а не Row: у исполнителя четыре плашки, на узком
            // экране последняя переносится, а не вылезает за край
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: statsWidgets!,
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
    this.labelColor,
  });

  final IconData icon;
  final String label;

  /// null — обычный текст; «Выйти» — цветом дефекта, как в макете.
  final Color? labelColor;
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
                      color: labelColor ?? c.text1,
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
