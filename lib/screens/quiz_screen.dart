import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../data/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

/// Экран 05 из car-marketplace-experiment.html — «тест на дефекты».
///
/// Механизм рабочий: вопросы приходят с сервера, ответы проверяются там же
/// (правильные варианты клиенту не отдаются), результат пишется в шаг
/// верификации. Но БАНК ВОПРОСОВ НЕ НАПОЛНЕН — в нём один вопрос из макета
/// вместо пятнадцати, поэтому тест нельзя сдать: порог 12 верных.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> _questions = const [];
  final Map<int, int> _answers = {};
  int _index = 0;
  int _threshold = 12;
  int _expected = 15;
  bool _bankReady = false;
  bool _loading = true;
  String? _error;
  String? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/quiz/questions'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.auth.token}',
        },
      );
      if (!mounted) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['available'] == false) {
        setState(() {
          _error = body['message'] as String?;
          _loading = false;
        });
        return;
      }
      setState(() {
        _questions =
            (body['data'] as List).cast<Map<String, dynamic>>();
        _threshold = body['threshold'] as int? ?? 12;
        _expected = body['expected_count'] as int? ?? 15;
        _bankReady = body['bank_ready'] as bool? ?? false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/quiz/submit'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.auth.token}',
      },
      body: jsonEncode({
        'answers': _answers.entries
            .map((e) => {'question_id': e.key, 'option_index': e.value})
            .toList(),
      }),
    );
    if (!mounted) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    setState(() {
      _result = 'Верных ${body['score']} из $_threshold необходимых — '
          '${(body['passed'] as bool) ? 'тест пройден' : 'не пройден'}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final correctSoFar = _answers.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: 'Тест на дефекты',
              eyebrow: 'шаг 3 из 4',
              onBack: () => Navigator.of(context).pop(),
              trailing: _questions.isEmpty
                  ? null
                  : DetailPos('${_index + 1}/${_questions.length}'),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.text3,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      : _body(correctSoFar),
            ),
            if (_error == null && !_loading)
              BottomCta(
                children: [
                  CtaPrimary(
                    label: _index < _questions.length - 1
                        ? 'Следующий вопрос'
                        : 'Завершить тест',
                    trailingIcon: _index < _questions.length - 1
                        ? Icons.arrow_forward
                        : null,
                    onPressed: _answers.containsKey(
                            _questions[_index]['id'] as int)
                        ? () {
                            if (_index < _questions.length - 1) {
                              setState(() => _index++);
                            } else {
                              _submit();
                            }
                          }
                        : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(int answered) {
    final q = _questions[_index];
    final options = (q['options'] as List).cast<String>();
    final selected = _answers[q['id'] as int];

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
      children: [
        // .quiz-q
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.bg1,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ВОПРОС ${_index + 1} ИЗ ${_questions.length}',
                style: AppText.sectionTitle,
              ),
              const SizedBox(height: 8),
              Text(
                q['text'] as String,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  letterSpacing: -0.15,
                  color: AppColors.text1,
                ),
              ),
              // .quiz-photo — фотографии к вопросам ещё не загружены
              if (q['photo_url'] != null) ...[
                const SizedBox(height: 12),
                Container(
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5A6470), Color(0xFF2C3138)],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 22),
        for (var i = 0; i < options.length; i++)
          _Answer(
            letter: String.fromCharCode(65 + i),
            text: options[i],
            selected: selected == i,
            onTap: () => setState(() => _answers[q['id'] as int] = i),
          ),

        // .quiz-foot
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'отвечено: $answered из ${_questions.length}',
              style: AppText.sectionExtra,
            ),
            Text('порог $_threshold / $_expected', style: AppText.sectionExtra),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _questions.isEmpty ? 0 : answered / _questions.length,
            minHeight: 3,
            backgroundColor: AppColors.bg1,
            valueColor: const AlwaysStoppedAnimation(AppColors.statusInfo),
          ),
        ),

        if (_result != null) ...[
          const SizedBox(height: 16),
          Text(
            _result!,
            style: const TextStyle(fontSize: 12.5, color: AppColors.text1),
          ),
        ],

        const SizedBox(height: 22),
        // честно про состояние банка вопросов
        if (!_bankReady)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.statusProgress.withValues(alpha: 0.07),
              border: Border.all(
                color: AppColors.statusProgress.withValues(alpha: 0.25),
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  size: 15,
                  color: AppColors.statusProgress,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'В банке ${_questions.length} вопрос(ов) вместо $_expected — '
                    'тест пока нельзя сдать, порог $_threshold верных.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.text2,
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

/// .answer
class _Answer extends StatelessWidget {
  const _Answer({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.statusInfo.withValues(alpha: 0.09)
              : AppColors.bg1,
          border: Border.all(
            color: selected ? AppColors.statusInfo : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            // .answer-key
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.statusInfo : AppColors.bg3,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF04121F) : AppColors.text3,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13.5, color: AppColors.text1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
