import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../data/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../data/api_exception.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/score_ring.dart';
import 'quiz_screen.dart';

/// Экран 04 из car-marketplace-experiment.html — «верификация исполнителя».
///
/// Отображение полностью живое (GET /api/verification), но завершить
/// верификацию сейчас нельзя: шаг «Личность» требует ручной модерации,
/// а «Тест на дефекты» — банка вопросов. Ни того, ни другого пока нет.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Прямой http мимо ApiClient — 401 разбираем сами, иначе протухшая
  /// сессия станет тупиком.
  ApiException _failure(http.Response response) {
    if (response.statusCode == 401) widget.auth.expireSession();
    return ApiException(response.statusCode, response.body);
  }

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/verification'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.auth.token}',
        },
      );
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _error = apiErrorText(_failure(response));
          _loading = false;
        });
        return;
      }
      setState(() {
        _data = (jsonDecode(response.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorText(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final passed = data?['passed'] as int? ?? 0;
    final total = data?['total'] as int? ?? 4;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: 'Верификация',
              eyebrow: 'доступ к заказам',
              onBack: () => Navigator.of(context).pop(),
              trailing: data == null ? null : DetailPos('$passed / $total'),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            'Не удалось загрузить: $_error',
                            style: TextStyle(
                              color: context.colors.text3,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : _body(data!, passed, total),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Map<String, dynamic> data, int passed, int total) {
    final steps = (data['steps'] as List).cast<Map<String, dynamic>>();
    final levels = (data['levels'] as List).cast<Map<String, dynamic>>();
    final percent = total == 0 ? 0 : (passed * 100 / total).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
      children: [
        // .verif-hero
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: context.colors.bg1,
            border: Border.all(color: context.colors.line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ScoreRing(percent: percent, color: context.colors.statusInfo),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: context.colors.text1,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passed == total
                          ? 'Верификация пройдена'
                          : 'Осталось шагов: ${total - passed}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        color: context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'После проверки вы получите доступ к заказам '
                      'и значок «Верифицирован» в профиле.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.text2,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),
        const SectionHead('Шаги проверки'),
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            step: steps[i],
            index: i + 1,
            onTap: steps[i]['key'] == 'test'
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(auth: widget.auth),
                      ),
                    )
                : null,
          ),

        const SizedBox(height: 22),
        const SectionHead('Уровни доступа', extra: 'растут с опытом'),
        Row(
          children: [
            for (final l in levels) ...[
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 7),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
                  decoration: BoxDecoration(
                    color: (l['reached'] as bool)
                        ? context.colors.statusDone.withValues(alpha: 0.07)
                        : context.colors.bg1,
                    border: Border.all(
                      color: (l['reached'] as bool)
                          ? context.colors.statusDone
                          : context.colors.line,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        l['name'] as String,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.colors.text1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l['caption'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: context.colors.text3,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 22),
        // .note-box — честно про то, что поток не замкнут
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.colors.statusInfo.withValues(alpha: 0.07),
            border: Border.all(color: context.colors.statusInfo.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 15, color: context.colors.statusInfo),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Проверка документов и тест пока не запущены — брать '
                  'заказы можно без верификации.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.colors.text2,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// .step
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.index, this.onTap});

  final Map<String, dynamic> step;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = step['status'] as String? ?? 'pending';
    final passedStep = status == 'passed';
    final inReview = status == 'in_review';

    final (markColor, markFg) = switch (status) {
      'passed' => (context.colors.statusDone, context.colors.modeBuyInk),
      'in_review' => (
          context.colors.statusProgress.withValues(alpha: 0.16),
          context.colors.statusProgress
        ),
      _ => (context.colors.bg3, context.colors.text3),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: inReview
            ? context.colors.statusInfo.withValues(alpha: 0.05)
            : context.colors.bg1,
        border: Border.all(
          color: inReview
              ? context.colors.statusInfo.withValues(alpha: 0.5)
              : context.colors.line,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .step-mark
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: markColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: passedStep
                ? Icon(Icons.check, size: 11, color: markFg)
                : Text(
                    '$index',
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: markFg,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step['name'] as String,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step['description'] as String,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.colors.text2,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  switch (status) {
                    'passed' => 'ПРОЙДЕНО',
                    'in_review' => 'НА ПРОВЕРКЕ',
                    'failed' => 'НЕ ПРОЙДЕНО',
                    _ => 'НЕ НАЧАТО',
                  },
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: switch (status) {
                      'passed' => context.colors.statusDone,
                      'in_review' => context.colors.statusProgress,
                      'failed' => context.colors.statusDefect,
                      _ => context.colors.text3,
                    },
                  ),
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
