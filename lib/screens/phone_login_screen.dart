import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_exception.dart';
import '../data/auth_service.dart';
import '../models/code_channel.dart';
import '../theme/app_colors.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/phone_input.dart';

export '../widgets/phone_input.dart' show formatCountdown;

/// Экран 01 макета — «авторизация» по номеру телефона.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({
    super.key,
    required this.auth,
    required this.onLoggedIn,
    this.onBrowse,
  });

  final AuthService auth;
  final VoidCallback onLoggedIn;

  /// «Посмотреть заказы без входа» — назад на витрину.
  final VoidCallback? onBrowse;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  CodeChannel? _channel;

  /// Пауза до повторного запроса кода. Сервер считает её по номеру, поэтому
  /// помним номер: другой номер после «Изменить номер» паузы не наследует.
  int _resendLeft = 0;
  String? _cooldownPhone;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // правка номера во время паузы: кнопка сразу показывает, действует ли она
    _phoneController.addListener(() {
      if (_resendLeft > 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _phoneDigits => _phoneController.text.replaceAll(RegExp(r'\D'), '');

  /// Сколько ещё ждать для введённого номера; null — можно запрашивать.
  Duration? get _cooldownLeft =>
      _resendLeft > 0 && _cooldownPhone == _phoneDigits ? Duration(seconds: _resendLeft) : null;

  /// Счётчик секунд, а не отметка времени: так отсчёт идёт и в виджет-тестах
  /// с подменённым временем. Погрешность в доли секунды здесь не важна.
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

  /// Ошибка запроса: 429 с retry_after сразу запускает отсчёт на кнопке.
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
      final sent = await widget.auth.requestPhoneCode(_phoneController.text);
      if (!mounted) return;
      final devCode = sent.devCode;
      setState(() {
        _codeSent = true;
        _channel = sent.channel;
        _startCooldown(sent.resendIn);
        // в local бекенд ничего не отправляет и отдаёт код — подставляем сами
        if (devCode != null) _codeController.text = devCode;
      });
      if (devCode != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Код не отправлялся (режим разработки), подставлен автоматически')),
        );
      }
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.verifyPhoneCode(_phoneController.text, _codeController.text);
      widget.onLoggedIn();
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cooldown = _cooldownLeft;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // .auth-body { padding: 0 24px }
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // .brand-mark
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: context.colors.statusDone,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.directions_car_filled_outlined,
                    size: 28,
                    color: context.colors.modeBuyInk,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Подбор авто',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.75,
                    color: context.colors.text1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Один аккаунт на всё: заказывайте подбор и берите чужие '
                  'заказы, когда захотите.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.colors.text2,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),

                // .auth-proof — соцдоказательство из макета.
                // Аватарки декоративные: списка исполнителей публично нет.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    color: context.colors.bg1,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 24,
                        child: Stack(
                          children: const [
                            Positioned(left: 0, child: Avatar('МК', size: 24)),
                            Positioned(left: 16, child: Avatar('ИВ', size: 24)),
                            Positioned(left: 32, child: Avatar('ДП', size: 24)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Заказчики и подборщики в одном сервисе',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.colors.text2,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                Text('НОМЕР ТЕЛЕФОНА', style: context.text.fieldLabel),
                const SizedBox(height: 6),
                // .phone-input
                PhoneField(controller: _phoneController, enabled: !_codeSent),

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
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: context.colors.statusDefect,
                      fontSize: 12,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                CtaPrimary(
                  label: _codeSent
                      ? 'Войти'
                      : cooldown == null
                          ? 'Получить код'
                          : 'Получить код через ${formatCountdown(cooldown)}',
                  loading: _busy,
                  onPressed: _codeSent ? _verify : (cooldown == null ? _requestCode : null),
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
                    onPressed: () => setState(() {
                      _codeSent = false;
                      _codeController.clear();
                    }),
                  ),
                ] else if (widget.onBrowse != null)
                  CtaGhost(
                    label: 'Посмотреть заказы без входа',
                    onPressed: widget.onBrowse,
                  ),

                // .auth-note
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: context.colors.text3,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Заказать подбор можно сразу после входа. '),
                            TextSpan(
                              text: 'Брать заказы',
                              style: TextStyle(
                                color: context.colors.text1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: ' пока тоже можно без проверок.'),
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

                const SizedBox(height: 14),
                Text(
                  'Продолжая, вы соглашаетесь с условиями сервиса '
                  'и политикой конфиденциальности',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.colors.text3,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

