import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Строка настроек профиля: иконка, подпись, справа — контрол или стрелка.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
    this.labelColor,
  });

  final IconData icon;
  final String label;

  /// null — обычный текст; «Выйти» — цветом дефекта, как в макете.
  final Color? labelColor;
  final Widget trailing;
  final VoidCallback? onTap;

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
          onTap: onTap,
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
                  child: Icon(icon, size: 17, color: c.text1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: labelColor == null
                          ? c.text1
                          : c.textFor(labelColor!),
                    ),
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Стрелка справа у строки, ведущей на другой экран или шторку.
class SettingsChevron extends StatelessWidget {
  const SettingsChevron({super.key});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_right, size: 18, color: context.colors.text3);
}

/// Значение справа (номер, реквизиты) и стрелка.
class SettingsValue extends StatelessWidget {
  const SettingsValue(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: TextStyle(fontSize: 12, color: context.colors.text2)),
        const SizedBox(width: 4),
        const SettingsChevron(),
      ],
    );
  }
}
