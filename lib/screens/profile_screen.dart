import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/profile_repository.dart';
import '../state/order_store.dart';
import '../state/verification_status.dart';
import '../theme/app_colors.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import 'profile/account_rows.dart';
import 'profile/app_rows.dart';
import 'profile/profile_head.dart';
import 'profile/roles_section.dart';
import 'settings_screen.dart';

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
    required this.onDeleteAccount,
  });

  final AuthService auth;

  final OrderStore store;

  /// Статус верификации на всю сессию — общий с «Заказами рядом».
  final VerificationStatus verification;

  /// Переход в разделы. Они подменяют профиль, а не ложатся поверх —
  /// навигацией разделов управляет main.dart.
  final VoidCallback onMyOrders;
  final VoidCallback onNearbyOrders;

  /// Сессия уже стёрта — корень приложения возвращает к вопросу о намерении.
  final Future<void> Function() onLogout;

  /// Удалить аккаунт (DELETE /me). Ошибку — идут заказы, нет сети —
  /// пробрасывает: её показывает профиль, пользователь остаётся вошедшим.
  final Future<void> Function() onDeleteAccount;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _profile = ProfileRepository.of(widget.auth);

  /// Идёт удаление аккаунта — строка не нажимается второй раз.
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    widget.store.loadMyOrders();
    widget.store.loadAssignedOrders();
    // рейтинг мог измениться с прошлого входа
    widget.auth.refreshUser();
    // без сводки считаем верификацию необязательной и пункт про неё не
    // показываем — сервер всё равно проверит отклик сам
    widget.verification.ensureLoaded();
  }

  /// Подтверждение опасного действия: «Отмена» или [action] цветом дефекта.
  Future<bool> _confirm({
    required String title,
    required String text,
    required String action,
  }) async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.bg1,
        title: Text(title, style: TextStyle(color: c.text1, fontSize: 17)),
        content: Text(text, style: TextStyle(color: c.text2, fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Отмена', style: TextStyle(color: c.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              action,
              style: TextStyle(
                color: c.defectText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Выход — с подтверждением: строка стоит в конце списка, задеть её
  /// случайно при прокрутке легко.
  Future<void> _confirmLogout() async {
    final ok = await _confirm(
      title: 'Выйти из аккаунта?',
      text: 'Чтобы вернуться, понадобится код из Telegram или звонка.',
      action: 'Выйти',
    );
    if (ok) await widget.onLogout();
  }

  /// Удаление аккаунта — с подтверждением: оно необратимо. Google Play
  /// требует эту кнопку в приложении; что удаляется — решает сервер
  /// (AccountDeletion), текст диалога пересказывает его правило.
  Future<void> _confirmDeleteAccount() async {
    final ok = await _confirm(
      title: 'Удалить аккаунт?',
      text:
          'Имя, телефон, фото и реквизиты будут удалены без возможности '
          'восстановления. Завершённые заказы, отчёты и отзывы останутся '
          'без вашего имени. Открытые заказы без исполнителя отменятся.',
      action: 'Удалить',
    );
    if (!ok || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.onDeleteAccount();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _openSettings() {
    if (widget.auth.user == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          auth: widget.auth,
          cities: widget.store.cities,
          locator: widget.store.locator,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.auth,
        widget.store,
        widget.verification,
      ]),
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              DetailHead(
                title: 'Профиль',
                eyebrow: 'аккаунт',
                // профиль открывается с витрины — без этого с него
                // некуда вернуться
                onBack: backIfCanPop(context),
                trailing: SquareIconButton(
                  icon: Icons.settings_outlined,
                  onTap: _openSettings,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                  children: [
                    ProfileHead(user: widget.auth.user, profile: _profile),
                    const SizedBox(height: 14),
                    ProfileRolesSection(
                      auth: widget.auth,
                      store: widget.store,
                      verification: widget.verification,
                      onMyOrders: widget.onMyOrders,
                      onNearbyOrders: widget.onNearbyOrders,
                    ),
                    const SizedBox(height: 10),
                    ProfileAccountRows(
                      auth: widget.auth,
                      profile: _profile,
                      store: widget.store,
                    ),
                    ProfileAppRows(
                      auth: widget.auth,
                      deleting: _deleting,
                      onLogout: _confirmLogout,
                      onDeleteAccount: _confirmDeleteAccount,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
