import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/support_config.dart';
import '../screens/faq_screen.dart';
import '../screens/support_chat_screen.dart';
import '../state/chat_store.dart';
import '../state/support_chat_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Шторка поддержки (design/first-launch-screen.html, .sheet). Доступна
/// ещё до входа: со стартового экрана и из профиля.
Future<void> showSupportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.bg0,
    barrierColor: context.colors.backdrop,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: context.colors.line),
    ),
    builder: (_) => const _SupportSheet(),
  );
}

class _SupportSheet extends StatelessWidget {
  const _SupportSheet();

  /// Открывает внешнее приложение. Шторку закрываем заранее, а сообщение
  /// об ошибке показываем на экране под ней — ScaffoldMessenger общий.
  Future<void> _open(BuildContext context, Uri uri, {String? notice}) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (notice != null) {
      messenger.showSnackBar(SnackBar(content: Text(notice)));
    }
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть — нет подходящего приложения'),
        ),
      );
    }
  }

  /// Чат в приложении — только с токеном: бекенд пускает в него вошедших.
  /// Стор создаём до маршрута, а не в builder (смена темы пересоздала бы его).
  void _openChat(BuildContext context, SupportChatScope scope) {
    final navigator = Navigator.of(context);
    navigator.pop();
    final store = ChatStore(scope.repository());
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => SupportChatScreen(store: store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scope = SupportChatScope.maybeOf(context);
    final canChat = scope != null && scope.auth.isAuthenticated;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .sheet-handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // .sheet-head
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Поддержка',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.36,
                            color: c.text1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const OnlineDot(),
                            const SizedBox(width: 6),
                            Text(
                              'Онлайн · отвечаем в среднем за 5 минут',
                              style: TextStyle(fontSize: 11.5, color: c.text2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // .sheet-close
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c.bg1,
                        border: Border.all(color: c.line),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.close, size: 15, color: c.text2),
                    ),
                  ),
                ],
              ),
            ),
            _SupportItem(
              primary: true,
              icon: Icons.chat_bubble_outline,
              name: 'Написать в чат',
              desc: canChat
                  ? 'Прямо в приложении, ответим здесь же'
                  : 'После входа — в приложении, пока откроем Telegram',
              // гостю чат недоступен — ведём в Telegram и честно об этом говорим
              onTap: canChat
                  ? () => _openChat(context, scope)
                  : () => _open(
                      context,
                      SupportConfig.telegramUri,
                      notice:
                          'Чат в приложении доступен после входа — пока откроем Telegram',
                    ),
            ),
            _SupportItem(
              icon: Icons.send_outlined,
              name: 'Telegram',
              desc: 'Ответим в мессенджере',
              onTap: () => _open(context, SupportConfig.telegramUri),
            ),
            _SupportItem(
              icon: Icons.phone_outlined,
              name: 'Позвонить',
              descSpan: TextSpan(
                children: [
                  TextSpan(
                    text: SupportConfig.phoneDisplay,
                    style: const TextStyle(fontFamily: AppTheme.monoFamily),
                  ),
                  TextSpan(text: ' · бесплатно, ${SupportConfig.phoneHours}'),
                ],
              ),
              onTap: () => _open(context, SupportConfig.phoneUri),
            ),
            _SupportItem(
              icon: Icons.help_outline,
              name: 'Частые вопросы',
              desc: 'Как работает подбор, оплата, гарантии',
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute<void>(builder: (_) => const FaqScreen()),
                );
              },
            ),
            if (!canChat) ...[
              const SizedBox(height: 2),
              Text(
                'Без аккаунта — Telegram или звонок.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: c.text3, height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// .sup-item — строка способа связи.
class _SupportItem extends StatelessWidget {
  const _SupportItem({
    required this.icon,
    required this.name,
    this.desc,
    this.descSpan,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String name;
  final String? desc;
  final InlineSpan? descSpan;
  final VoidCallback onTap;

  /// .sup-item.primary — выделенный синим первый пункт.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: primary ? c.infoSoft : c.bg1,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: primary ? c.statusInfo : c.line),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primary ? c.statusInfo : c.bg3,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: primary ? c.infoInk : c.text1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.135,
                          color: c.text1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        descSpan ?? TextSpan(text: desc),
                        style: TextStyle(
                          fontSize: 11,
                          color: c.text2,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: c.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// .support-dot — зелёная точка «на связи».
class OnlineDot extends StatelessWidget {
  const OnlineDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: context.colors.online,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// .support-btn — пилюля «Поддержка» в верхнем ряду стартового экрана.
class SupportButton extends StatelessWidget {
  const SupportButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.bg1,
      shape: StadiumBorder(side: BorderSide(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showSupportSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 12, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.headset_mic_outlined, size: 16, color: c.text2),
              const SizedBox(width: 7),
              Text(
                'Поддержка',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.125,
                  color: c.text1,
                ),
              ),
              const SizedBox(width: 7),
              const OnlineDot(),
            ],
          ),
        ),
      ),
    );
  }
}
