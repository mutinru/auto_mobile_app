import 'package:flutter/material.dart';

import '../data/session_repository.dart';
import '../models/session.dart';
import '../theme/app_colors.dart';
import '../util/ru_date.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/confirm_sheet.dart';

/// «Активные устройства»: где пользователь вошёл, и выход на чужом
/// устройстве. Это устройство — первым и без кнопки: выход с него —
/// «Выйти» в профиле. Сессия истекает сама через 90 дней без запросов.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, required this.repository});

  final SessionRepository repository;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<Session>? _sessions;
  String? _error;
  bool _loading = false;

  /// Идёт выход на устройстве (id) или на всех других (-1).
  int? _revoking;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await widget.repository.fetchSessions();
      if (!mounted) return;
      // это устройство — первым, остальные — в порядке сервера (свежие сверху)
      setState(
        () => _sessions = [
          ...sessions.where((s) => s.current),
          ...sessions.where((s) => !s.current),
        ],
      );
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(Session session) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Выйти на «${session.title}»?',
      text:
          'На этом устройстве придётся войти заново по коду, пуши туда '
          'больше не придут.',
      confirmLabel: 'Выйти',
    );
    if (!ok || !mounted) return;
    await _run(session.id, () => widget.repository.revoke(session.id));
  }

  Future<void> _revokeOthers() async {
    final ok = await showConfirmSheet(
      context,
      title: 'Выйти на всех других устройствах?',
      text: 'Останется только это устройство.',
      confirmLabel: 'Выйти',
    );
    if (!ok || !mounted) return;
    await _run(-1, widget.repository.revokeOthers);
  }

  Future<void> _run(int target, Future<void> Function() action) async {
    setState(() => _revoking = target);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _revoking = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    final others = sessions?.where((s) => !s.current).toList() ?? const [];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: 'Активные устройства',
              eyebrow: 'аккаунт',
              onBack: backIfCanPop(context),
            ),
            Expanded(child: _body(sessions)),
            if (others.isNotEmpty)
              BottomCta(
                children: [
                  CtaGhost(
                    label: 'Выйти на всех других',
                    onPressed: _revoking == null ? _revokeOthers : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(List<Session>? sessions) {
    final c = context.colors;
    if (sessions == null) {
      if (_error != null && !_loading) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Не удалось загрузить устройства',
                style: TextStyle(fontSize: 14, color: c.text1),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: c.text3),
              ),
              const SizedBox(height: 10),
              CtaGhost(label: 'Повторить', onPressed: _load),
            ],
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          for (final session in sessions)
            _SessionTile(
              session: session,
              busy: _revoking == session.id,
              onRevoke: session.current || _revoking != null
                  ? null
                  : () => _revoke(session),
            ),
          const SizedBox(height: 6),
          Text(
            'Сессия без входа 90 дней завершается сама.',
            style: TextStyle(fontSize: 11.5, color: c.text3),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.busy,
    required this.onRevoke,
  });

  final Session session;
  final bool busy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lastUsed = session.lastUsedAt;
    final subtitle = session.current
        ? 'Это устройство'
        : (lastUsed == null
              ? 'ещё не заходили'
              : 'заходили ${momentLabel(lastUsed)}');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: c.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Icon(
            session.platform == 'ios'
                ? Icons.phone_iphone
                : Icons.phone_android,
            size: 20,
            color: c.text2,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.text1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: session.current ? c.statusDone : c.text3,
                  ),
                ),
              ],
            ),
          ),
          if (!session.current)
            busy
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: onRevoke,
                    child: Text(
                      'Выйти',
                      style: TextStyle(color: c.defectText),
                    ),
                  ),
        ],
      ),
    );
  }
}
