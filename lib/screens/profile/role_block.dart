import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// .role-block — карточка возможности аккаунта.
class RoleBlock extends StatelessWidget {
  const RoleBlock({
    super.key,
    required this.active,
    required this.icon,
    required this.name,
    required this.state,
    required this.actionLabel,
    required this.onAction,
    this.dashed = false,
    this.description,
    this.actionPrimary = false,
    this.statsWidgets,
    this.stateExtra,
    this.secondaryLabel,
    this.onSecondary,
  });

  final bool active;
  final bool dashed;
  final IconData icon;
  final String name;
  final String state;
  final String? description;
  final String actionLabel;
  final bool actionPrimary;
  final VoidCallback onAction;
  final List<Widget>? statsWidgets;

  /// Под строкой состояния — например, свой рейтинг исполнителя.
  final Widget? stateExtra;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: active
            ? context.colors.statusDone.withValues(alpha: 0.05)
            : context.colors.bg1,
        border: Border.all(
          color: active
              ? context.colors.statusDone.withValues(alpha: 0.45)
              : context.colors.line,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .rb-top
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active
                      ? context.colors.statusDone
                      : context.colors.bg3,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: active
                      ? context.colors.modeBuyInk
                      : context.colors.text2,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        color: context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.text2,
                      ),
                    ),
                    if (stateExtra != null) ...[
                      const SizedBox(height: 3),
                      stateExtra!,
                    ],
                  ],
                ),
              ),
            ],
          ),
          // .rb-body
          const SizedBox(height: 12),
          Container(height: 1, color: context.colors.line),
          const SizedBox(height: 12),
          if (statsWidgets != null) ...[
            // Wrap, а не Row: у исполнителя пять плашек, на узком
            // экране последняя переносится, а не вылезает за край
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: statsWidgets!,
            ),
            const SizedBox(height: 12),
          ],
          if (description != null) ...[
            Text(
              description!,
              style: TextStyle(
                fontSize: 11.5,
                color: context.colors.text2,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: actionPrimary
                    ? context.colors.statusDone
                    : context.colors.bg3,
                foregroundColor: actionPrimary
                    ? context.colors.modeBuyInk
                    : context.colors.text1,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                elevation: 0,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSecondary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.statusDone,
                  foregroundColor: context.colors.modeBuyInk,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  secondaryLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// .rb-stats > div
class RoleStat extends StatelessWidget {
  const RoleStat(this.value, this.caption, {super.key});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppTheme.monoFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.32,
            color: context.colors.text1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: TextStyle(fontSize: 10, color: context.colors.text3),
        ),
      ],
    );
  }
}
