import 'package:flutter/material.dart';

import '../../data/verification_repository.dart';
import '../../theme/app_colors.dart';

/// .gate — шлагбаум верификации. Клиентский; сервер проверяет её при
/// отклике, только если включён EXECUTOR_VERIFICATION_REQUIRED, а на
/// экране карты кнопка «Откликнуться» гейтом не гасится.
class VerificationGate extends StatelessWidget {
  const VerificationGate({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final VerificationSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = summary.progress;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(
          color: context.colors.modeWork.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.colors.modeWork.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 17,
                  color: context.colors.progressText,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Смотреть можно, откликаться — нет',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.14,
                        color: context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Нужна верификация: пройдено ${summary.passed} из '
                      '${summary.total} шагов · ~20 минут',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.text2,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          // .gate-prog
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: context.colors.bg0,
              valueColor: AlwaysStoppedAnimation(context.colors.modeWork),
            ),
          ),
          const SizedBox(height: 11),
          // .gate-btn
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.modeWork,
                foregroundColor: context.colors.modeWorkInk,
                disabledBackgroundColor: context.colors.bg3,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Стать исполнителем',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Статус верификации не загрузился: без него откликаться нельзя, но и
/// говорить «нужна верификация» верифицированному — неправда.
class VerificationRetry extends StatelessWidget {
  const VerificationRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: context.colors.text3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Не удалось проверить верификацию',
              style: TextStyle(fontSize: 12.5, color: context.colors.text2),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
