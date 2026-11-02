import 'dart:async';

import 'package:flutter/material.dart';

import '../data/address_repository.dart';
import '../theme/app_colors.dart';
import 'app_ui.dart';

/// Поле «Адрес» осмотра с подсказками под ним. Подсказки только помогают:
/// без [addresses], без сети или с исчерпанным лимитом DaData это обычное
/// текстовое поле. Выбор подсказки отдаёт точку в [onPoint]; правка текста
/// после выбора её сбрасывает (onPoint(null)) — точка больше не про этот адрес.
///
/// [cityId] — fias_id города из справочника: подсказки только в его пределах.
class AddressField extends StatefulWidget {
  const AddressField({
    super.key,
    required this.controller,
    required this.onPoint,
    this.addresses,
    this.cityId,
  });

  final TextEditingController controller;
  final AddressRepository? addresses;
  final String? cityId;
  final ValueChanged<AddressPoint?> onPoint;

  @override
  State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
  /// Пауза после последней буквы, прежде чем идти в сеть: у DaData суточный лимит.
  static const _debounce = Duration(milliseconds: 400);

  /// Короче — подсказки бессмысленны, сервер отклонит запрос.
  static const _minQuery = 3;

  Timer? _timer;
  List<AddressSuggestion> _suggestions = const [];

  /// Текст выбранной подсказки: пока поле совпадает с ним, точка актуальна.
  String? _picked;

  /// Последний отправленный запрос — ответ на старый отбрасываем.
  String _requested = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(AddressField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    // подсказки другого города уже не к месту
    if (old.cityId != widget.cityId && _suggestions.isNotEmpty) {
      setState(() => _suggestions = const []);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final text = widget.controller.text.trim();
    if (text == _picked) return;
    if (_picked != null) {
      _picked = null;
      widget.onPoint(null);
    }
    _timer?.cancel();
    if (widget.addresses == null) return;
    if (text.length < _minQuery) {
      _requested = '';
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    _timer = Timer(_debounce, () => _load(text));
  }

  Future<void> _load(String query) async {
    _requested = query;
    final results = await widget.addresses!.suggest(
      query,
      cityId: widget.cityId,
    );
    if (!mounted || query != _requested) return;
    setState(() => _suggestions = results);
  }

  Future<void> _select(AddressSuggestion s) async {
    _timer?.cancel();
    _requested = '';
    _picked = s.value;
    widget.controller.text = s.value;
    widget.controller.selection = TextSelection.collapsed(
      offset: s.value.length,
    );
    setState(() => _suggestions = const []);
    FocusScope.of(context).unfocus();

    final point = await widget.addresses!.resolve(s);
    // пока искали точку, адрес могли поправить — тогда она не про него
    if (!mounted || _picked != s.value) return;
    widget.onPoint(point);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldBoxInput(
          label: 'Адрес',
          controller: widget.controller,
          hint: 'Улица, дом',
          maxLength: 255,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: context.colors.bg1,
              border: Border.all(color: context.colors.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (final (i, s) in _suggestions.indexed)
                  InkWell(
                    onTap: () => _select(s),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : Border(
                                top: BorderSide(color: context.colors.line),
                              ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: context.colors.text3,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.value,
                              style: context.text.fieldValue,
                            ),
                          ),
                        ],
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
