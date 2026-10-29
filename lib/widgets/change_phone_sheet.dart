import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_exception.dart';
import '../data/auth_service.dart';
import '../models/code_channel.dart';
import '../theme/app_colors.dart';
import 'api_error.dart';
import 'app_ui.dart';
import 'phone_input.dart';

/// Лист смены номера из профиля: номер → код на него → номер сменён. Макета
/// нет — шаги и отсчёт те же, что на экране входа (PhoneLoginScreen).
/// Запросы передаются снаружи (в приложении это
/// AuthService.requestPhoneChange/confirmPhoneChange), чтобы лист можно было
/// проверить без сети.
Future<void> showChangePhoneSheet(
  BuildContext context, {
  String? currentPhone,
  required Future<PhoneCodeSent> Function(String phone) onRequest,
  required Future<void> Function(String phone, String code) onConfirm,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.colors.bg0,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _ChangePhoneSheet(
      currentPhone: currentPhone,
      onRequest: onRequest,
      onConfirm: onConfirm,
    ),
  );
  if (changed == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Номер изменён')),
    );
  }
}

class _ChangePhoneSheet extends StatefulWidget {
  const _ChangePhoneSheet({
    required this.currentPhone,
    required this.onRequest,
    required this.onConfirm,
  });

  final String? currentPhone;
  final Future<PhoneCodeSent> Function(String phone) onRequest;
  final Future<void> Function(String phone, String code) onConfirm;

  @override
  State<_ChangePhoneSheet> createState() => _ChangePhoneSheetState();
}

class _ChangePhoneSheetState extends State<_ChangePhoneSheet> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  CodeChannel? _channel;

  /// Пауза до повторного запроса — по номеру, как на экране входа: другой
  /// номер после «Изменить номер» паузы не наследует.
  int _resendLeft = 0;
  String? _cooldownPhone;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() => _error = null));
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _phoneDigits => _phoneController.text.replaceAll(RegExp(r'\D'), '');

  /// Полный номер и не текущий — иначе сервер всё равно ответит 422.
  bool get _canRequest => _phoneDigits.length == 10 && '+7$_phoneDigits' != widget.currentPhone;

  Duration? get _cooldownLeft =>
      _resendLeft > 0 && _cooldownPhone == _phoneDigits ? Duration(seconds: _resendLeft) : null;

  void _startCooldown(int seconds) {
    if (seconds <= 0) return;
    _resendLeft = seconds;
    _cooldownPhone = _phoneDigits;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _resendLeft--);
      if (_resendLeft <= 0) timer.cancel();
    });
  }

  /// 422 сервер пишет по-русски («Номер уже привязан к другому аккаунту»),
  /// 429 с retry_after сразу запускает отсчёт.
  void _fail(Object e) {
    if (!mounted) return;
    setState(() {
      _error = apiErrorText(e);
      if (e is ApiException && e.statusCode == 429 && e.retryAfter != null) {
        _startCooldown(e.retryAfter!);
      }
    });
  }

  Future<void> _requestCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sent = await widget.onRequest(_phoneController.text);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _channel = sent.channel;
        _startCooldown(sent.resendIn);
        // в local бекенд ничего не отправляет и отдаёт код — подставляем сами
        if (sent.devCode != null) _codeController.text = sent.devCode!;
      });
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm(_phoneController.text, _codeController.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // лист не закрываем: код можно перепроверить или запросить заново
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cooldown = _cooldownLeft;
    final current = widget.currentPhone;
    return Padding(
      // лист поднимается над клавиатурой
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
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
                color: context.colors.bg3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Новый номер',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.34,
              color: context.colors.text1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            current == null
                ? 'По нему вы будете входить в приложение'
                : 'Сейчас — ${formatPhone(current)}. После смены входите по новому номеру, '
                    'на других устройствах войдите заново',
            style: TextStyle(fontSize: 12, color: context.colors.text2, height: 1.4),
          ),
          const SizedBox(height: 14),
          PhoneField(controller: _phoneController, enabled: !_codeSent, autofocus: true),
          const SizedBox(height: 8),
          Text(
            _codeSent
                ? 'Отправили код на +7 ${_phoneController.text}. ${codeChannelHint(_channel)}'
                : codeChannelHint(null),
            style: TextStyle(fontSize: 12, color: context.colors.text2, height: 1.4),
          ),
          if (_codeSent) ...[
            const SizedBox(height: 12),
            FieldBoxInput(
              label: 'Код',
              controller: _codeController,
              hint: '0000',
              mono: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(fontSize: 12, color: context.colors.statusDefect),
            ),
          ],
          const SizedBox(height: 12),
          CtaPrimary(
            label: _codeSent
                ? 'Сменить номер'
                : cooldown == null
                    ? 'Получить код'
                    : 'Получить код через ${formatCountdown(cooldown)}',
            loading: _busy,
            onPressed: _codeSent
                ? (_codeController.text.length == 4 ? _confirm : null)
                : (cooldown == null && _canRequest ? _requestCode : null),
          ),
          if (_codeSent) ...[
            CtaGhost(
              label: cooldown == null
                  ? 'Запросить код снова'
                  : 'Запросить код снова через ${formatCountdown(cooldown)}',
              onPressed: cooldown == null && !_busy ? _requestCode : null,
            ),
            CtaGhost(
              label: 'Изменить номер',
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _codeSent = false;
                        _error = null;
                        _codeController.clear();
                      }),
            ),
          ],
        ],
      ),
    );
  }
}
