import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';

/// .theme-switch из design/first-launch-screen.html: пилюля на два слота —
/// луна (тёмная) и солнце (светлая), под активным ездит бегунок.
/// Без [ThemeScope] выше по дереву не рисуется.
class ThemeSwitch extends StatelessWidget {
  const ThemeSwitch({super.key});

  static const _slotW = 32.0;
  static const _slotH = 28.0;

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final c = context.colors;
    final light = controller.isLight;

    return Semantics(
      button: true,
      label: light ? 'Включить тёмную тему' : 'Включить светлую тему',
      child: GestureDetector(
        onTap: controller.toggle,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: c.bg1,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: SizedBox(
            width: _slotW * 2,
            height: _slotH,
            child: Stack(
              children: [
                // .theme-knob
                AnimatedAlign(
                  duration: const Duration(milliseconds: 280),
                  curve: const Cubic(.4, .1, .2, 1),
                  alignment: light
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: _slotW,
                    height: _slotH,
                    decoration: BoxDecoration(
                      color: c.knob,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _slot(
                      Icons.dark_mode_outlined,
                      !light ? c.knobInk : c.text3,
                    ),
                    _slot(
                      Icons.light_mode_outlined,
                      light ? c.knobInk : c.text3,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slot(IconData icon, Color color) => SizedBox(
    width: _slotW,
    height: _slotH,
    child: Icon(icon, size: 15, color: color),
  );
}
