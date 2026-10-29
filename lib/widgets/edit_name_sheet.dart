import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'api_error.dart';
import 'app_ui.dart';

/// Лист смены имени из шапки профиля. Макета под него нет — собран из
/// тех же кирпичей, что лист выбора вида заказа. Сохранение передаётся
/// снаружи (в приложении это AuthService.updateName), чтобы лист можно
/// было проверить без сети.
Future<void> showEditNameSheet(
  BuildContext context, {
  required String initial,
  required Future<void> Function(String name) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.bg0,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _EditNameSheet(initial: initial, onSave: onSave),
  );
}

class _EditNameSheet extends StatefulWidget {
  const _EditNameSheet({required this.initial, required this.onSave});

  final String initial;
  final Future<void> Function(String name) onSave;

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  /// Совпадает с max:255 в валидации бекенда.
  static const _maxLength = 255;

  late final _controller = TextEditingController(text: widget.initial);
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _trimmed => _controller.text.trim();

  bool get _canSave => _trimmed.isNotEmpty && _trimmed != widget.initial;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_trimmed);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // лист не закрываем, чтобы не потерять ввод; без сети apiErrorText
      // отдаст «Нет связи с сервером»
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            'Как вас зовут',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.34,
              color: context.colors.text1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Имя видят исполнители и заказчики',
            style: TextStyle(fontSize: 12, color: context.colors.text2),
          ),
          const SizedBox(height: 14),
          FieldBoxInput(
            label: 'Имя',
            controller: _controller,
            hint: 'Имя и фамилия',
            autofocus: true,
            maxLength: _maxLength,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.statusDefect,
                ),
              ),
            ),
          const SizedBox(height: 4),
          CtaPrimary(
            label: 'Сохранить',
            loading: _saving,
            onPressed: _canSave ? _save : null,
          ),
        ],
      ),
    );
  }
}
