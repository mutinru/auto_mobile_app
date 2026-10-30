import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../models/notification_category.dart';
import '../theme/app_colors.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';

/// Настройки — шестерёнка в профиле. Пока один раздел: пуши по категориям
/// (PATCH /me/notifications). Глушится только пуш, лента пишется всегда.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Set<NotificationCategory> _muted = {...?widget.auth.user?.pushMuted};

  /// Переключатель меняется сразу, при ошибке — откат. Каждый запрос шлёт
  /// полный список заглушённых, а не разницу.
  Future<void> _toggle(NotificationCategory category, bool enabled) async {
    final before = _muted;
    final next = {..._muted};
    enabled ? next.remove(category) : next.add(category);
    setState(() => _muted = next);
    try {
      await widget.auth.updatePushMuted(next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _muted = before);
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: 'Настройки',
              eyebrow: 'аккаунт',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                children: [
                  const SectionHead('Push-уведомления'),
                  for (final category in NotificationCategory.values)
                    _CategoryRow(
                      category: category,
                      enabled: !_muted.contains(category),
                      onChanged: category.mutable
                          ? (value) => _toggle(category, value)
                          : null,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Выключенные уведомления не приходят на телефон, но '
                    'остаются в ленте уведомлений.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: c.text3),
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

/// Строка категории — в стиле строк настроек профиля, справа Switch.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.enabled,
    required this.onChanged,
  });

  final NotificationCategory category;
  final bool enabled;

  /// null — категория не выключается, Switch заблокирован во «вкл».
  final ValueChanged<bool>? onChanged;

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
          onTap: onChanged == null ? null : () => onChanged!(!enabled),
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
                  child: Icon(category.icon, size: 17, color: c.text1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: c.text1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.caption,
                        style: TextStyle(fontSize: 11.5, color: c.text2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: enabled,
                  onChanged: onChanged,
                  activeTrackColor: c.statusDone,
                  // дефолтная выключенная дорожка сливается с bg1 карточки
                  inactiveTrackColor: c.bg3,
                  inactiveThumbColor: c.text3,
                  trackOutlineColor: WidgetStatePropertyAll(c.line),
                  // заблокированный — с замком, чтобы не путать с обычным «вкл»
                  thumbIcon: onChanged == null
                      ? WidgetStatePropertyAll(Icon(Icons.lock, size: 14, color: c.text2))
                      : null,
                  thumbColor: onChanged == null ? WidgetStatePropertyAll(c.bg1) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
