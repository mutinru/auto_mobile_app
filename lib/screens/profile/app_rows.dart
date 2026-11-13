import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/auth_service.dart';
import '../../data/session_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../data/legal_repository.dart';
import '../../models/legal_text.dart';
import '../legal_document_screen.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/support_sheet.dart';
import '../../widgets/theme_switch.dart';
import '../../widgets/unread_badge.dart';
import '../sessions_screen.dart';
import 'settings_row.dart';

/// Низ профиля: «Приложение» (тема, поддержка, документы) и сессия (устройства,
/// выход, удаление аккаунта). Подтверждения выхода и удаления — у экрана.
class ProfileAppRows extends StatelessWidget {
  const ProfileAppRows({
    super.key,
    required this.auth,
    required this.deleting,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  final AuthService auth;

  /// Идёт удаление аккаунта — строка со спиннером и не нажимается.
  final bool deleting;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // те же тема и поддержка, что на стартовом экране, —
        // чтобы не возвращаться к нему ради них
        const SizedBox(height: 22),
        const SectionHead('Приложение'),
        const _ThemeRow(),
        SettingsRow(
          icon: Icons.headset_mic_outlined,
          label: 'Поддержка',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SupportUnreadBuilder(
                builder: (context, count) => count > 0
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: UnreadBadge(
                          count,
                          borderColor: context.colors.bg1,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const OnlineDot(),
              const SizedBox(width: 8),
              const SettingsChevron(),
            ],
          ),
          onTap: () => showSupportSheet(context),
        ),
        SettingsRow(
          icon: Icons.description_outlined,
          label: 'Документы',
          trailing: const SettingsChevron(),
          onTap: () => _showLegalSheet(
            context,
            ApiLegalRepository(ApiClient(auth)),
          ),
        ),

        // .row[data-action=logout] из tab-bar-navigation.html
        const SizedBox(height: 22),
        // где вошли и выход на чужом устройстве (GET /me/sessions)
        SettingsRow(
          icon: Icons.devices_outlined,
          label: 'Активные устройства',
          trailing: const SettingsChevron(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionsScreen(
                repository: ApiSessionRepository(ApiClient(auth)),
              ),
            ),
          ),
        ),
        SettingsRow(
          icon: Icons.logout,
          label: 'Выйти',
          labelColor: context.colors.defectText,
          trailing: const SizedBox.shrink(),
          onTap: onLogout,
        ),
        SettingsRow(
          icon: Icons.person_remove_outlined,
          label: 'Удалить аккаунт',
          labelColor: context.colors.text3,
          trailing: deleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const SizedBox.shrink(),
          onTap: deleting ? null : onDeleteAccount,
        ),
      ],
    );
  }
}

/// Шторка со ссылками на соглашение, политику и согласие — те же, что на
/// экране входа; открываются своим экраном.
Future<void> _showLegalSheet(
  BuildContext context,
  LegalRepository repository,
) {
  final c = context.colors;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bg0,
    barrierColor: c.backdrop,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: c.line),
    ),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHead('Документы'),
            for (final doc in LegalDocument.values)
              SettingsRow(
                icon: Icons.description_outlined,
                label: doc.title,
                trailing: const SettingsChevron(),
                onTap: () {
                  // экран — поверх профиля, а не шторки
                  Navigator.of(sheet).pop();
                  openLegalDocument(context, repository, doc);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

/// Строка «Тема»: переключает вся строка, а не только капсула справа, и
/// диктор слышит один переключатель «Светлая тема», а не строку-кнопку с
/// отдельной кнопкой внутри (QA 2026-11-05 №13). Капсула ловит своё нажатие
/// сама — тот же toggle, двойного переключения нет.
class _ThemeRow extends StatelessWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.maybeOf(context);
    if (theme == null) return const SizedBox.shrink();
    return Semantics(
      toggled: theme.isLight,
      label: 'Светлая тема',
      child: SettingsRow(
        icon: Icons.contrast,
        label: 'Тема',
        onTap: theme.toggle,
        trailing: const ExcludeSemantics(child: ThemeSwitch()),
      ),
    );
  }
}
