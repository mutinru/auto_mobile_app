import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_exception.dart';
import '../data/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

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

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final devCode = await widget.auth.requestPhoneCode(_phoneController.text);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        // доставки SMS нет: в local бекенд возвращает код, подставляем сами
        if (devCode != null) _codeController.text = devCode;
      });
      if (devCode != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SMS не отправляется, код из ответа: $devCode')),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Нет связи с сервером: $e');
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
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Нет связи с сервером: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.bg1,
                    border: Border.all(color: context.colors.line),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'RU +7',
                        style: TextStyle(fontSize: 13, color: context.colors.text2),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 20, color: context.colors.line),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !_codeSent,
                          inputFormatters: const [_PhoneMask()],
                          style: TextStyle(
                            fontFamily: AppTheme.monoFamily,
                            fontSize: 15,
                            letterSpacing: 0.6,
                            color: context.colors.text1,
                          ),
                          cursorColor: context.colors.statusDone,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 13),
                            border: InputBorder.none,
                            hintText: '000 000 00 00',
                            hintStyle: TextStyle(
                              fontFamily: AppTheme.monoFamily,
                              fontSize: 15,
                              color: context.colors.text3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_codeSent) ...[
                  const SizedBox(height: 12),
                  FieldBoxInput(
                    label: 'Код из SMS',
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
                  label: _codeSent ? 'Войти' : 'Получить код в SMS',
                  loading: _busy,
                  onPressed: _codeSent ? _verify : _requestCode,
                ),
                if (_codeSent)
                  CtaGhost(
                    label: 'Изменить номер',
                    onPressed: () => setState(() {
                      _codeSent = false;
                      _codeController.clear();
                    }),
                  )
                else if (widget.onBrowse != null)
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


/// Маска телефона: цифры складываются в «XXX XXX XX XX» прямо во время
/// ввода и обрезаются на десятой — больше в российский номер не влезает.
class _PhoneMask extends TextInputFormatter {
  const _PhoneMask();

  static const _groups = [3, 3, 2, 2];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 10 ? digits.substring(0, 10) : digits;

    // сколько цифр стоялослева от курсора — по ним вернём его на место
    final digitsBeforeCursor = newValue.text
        .substring(0, newValue.selection.baseOffset.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'\D'), '')
        .length;

    final buf = StringBuffer();
    var consumed = 0;
    var cursor = 0;
    for (final size in _groups) {
      if (consumed >= capped.length) break;
      if (consumed > 0) buf.write(' ');
      final end = (consumed + size).clamp(0, capped.length);
      buf.write(capped.substring(consumed, end));
      consumed = end;
      if (digitsBeforeCursor >= consumed) cursor = buf.length;
    }

    final text = buf.toString();
    final offset = digitsBeforeCursor >= capped.length ? text.length : cursor;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset.clamp(0, text.length)),
    );
  }
}
