import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/city_repository.dart';
import '../data/location_service.dart';
import '../models/car_catalog.dart';
import '../models/city.dart';
import '../state/city_locator.dart';
import '../theme/app_colors.dart';
import 'app_ui.dart';

/// Лист «Город»: поиск по справочнику городов РФ, выбор нескольких,
/// «Вся Россия» и своё значение. Справочник — только подсказка: в заказ и
/// фильтр уходят строки-названия. Макета под лист нет — собран из тех же
/// кирпичей, что лист марки и модели.
///
/// [locator] добавляет строку «Определить по геопозиции». Возвращает новый
/// выбор или null, если лист закрыли без «Готово».
Future<Set<String>?> showCityPickerSheet(
  BuildContext context, {
  required CityRepository cities,
  required Set<String> selected,
  CityLocator? locator,
}) async {
  final result = await _showSheet(
    context,
    _CityPickerSheet(cities: cities, initial: selected, locator: locator),
  );
  return result as Set<String>?;
}

/// Выбранный город: [name] — всегда, [city] — когда он из справочника
/// (своё значение «Указать …» приходит без него).
class CityChoice {
  const CityChoice(this.name, {this.city});

  final String name;
  final City? city;
}

/// Тот же лист для одного города (разовый осмотр): без «Вся Россия» и
/// «Готово» — тап по строке сразу закрывает лист. null — закрыли без выбора.
Future<CityChoice?> showSingleCityPickerSheet(
  BuildContext context, {
  required CityRepository cities,
  String? selected,
  CityLocator? locator,
}) async {
  final result = await _showSheet(
    context,
    _CityPickerSheet(
      cities: cities,
      initial: {?selected},
      locator: locator,
      single: true,
    ),
  );
  return result as CityChoice?;
}

Future<Object?> _showSheet(BuildContext context, Widget sheet) {
  return showModalBottomSheet<Object>(
    context: context,
    backgroundColor: context.colors.bg0,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => sheet,
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({
    required this.cities,
    required this.initial,
    required this.locator,
    this.single = false,
  });

  final CityRepository cities;
  final Set<String> initial;
  final CityLocator? locator;

  /// Один город: тап по строке закрывает лист с [CityChoice].
  final bool single;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  /// Пауза после последней буквы, прежде чем идти в сеть.
  static const _debounce = Duration(milliseconds: 300);

  final _search = TextEditingController();
  late final Set<String> _selected = {...widget.initial};

  Timer? _timer;
  List<City>? _results;

  /// Запрос, на который пришли [_results]: ответ на старый запрос,
  /// обогнанный новым, отбрасываем.
  String _resultsFor = '';
  bool _loading = false;
  bool _failed = false;
  bool _locating = false;

  /// Геопозиция не дала города — заметка под строкой «Определить…».
  bool _locateFailed = false;
  LocationProblem? _locateProblem;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onQueryChanged);
    _load('');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim();

  void _onQueryChanged() {
    _timer?.cancel();
    final q = _query;
    if (q == _resultsFor && !_failed) {
      setState(() {});
      return;
    }
    _timer = Timer(_debounce, () => _load(q));
    setState(() {});
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await widget.cities.search(query);
      if (!mounted || query != _query) return;
      setState(() {
        _results = results;
        _resultsFor = query;
      });
    } catch (_) {
      if (mounted && query == _query) setState(() => _failed = true);
    } finally {
      if (mounted && query == _query) setState(() => _loading = false);
    }
  }

  /// Тап по строке: в режиме одного города — сразу выбор, иначе галочка.
  void _pick(String name, [City? city]) {
    if (widget.single) {
      Navigator.of(context).pop(CityChoice(name, city: city));
    } else {
      _toggle(name);
    }
  }

  /// «Вся Россия» исключает конкретные города, и наоборот.
  void _toggle(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else if (name == allRussia) {
        _selected
          ..clear()
          ..add(allRussia);
      } else {
        _selected
          ..remove(allRussia)
          ..add(name);
      }
    });
  }

  /// Неудача — заметкой в самой шторке: SnackBar лёг бы на экран под ней
  /// и не был бы виден (QA №20).
  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locateFailed = false;
      _locateProblem = null;
    });
    final locator = widget.locator!;
    final city = await locator.detect();
    final problem = city == null ? await locator.problem() : null;
    if (!mounted) return;
    setState(() {
      _locating = false;
      _locateFailed = city == null;
      _locateProblem = problem;
    });
    if (city == null) return;
    if (widget.single) {
      _pick(city.name, city);
    } else if (!_selected.contains(city.name)) {
      _toggle(city.name);
    }
  }

  Widget _locateNote() {
    final problem = _locateProblem;
    final (text, action) = switch (problem) {
      LocationProblem.serviceOff => (
        'Геолокация на телефоне выключена',
        'Включить',
      ),
      LocationProblem.deniedForever => (
        'Приложению запрещён доступ к геопозиции',
        'Открыть настройки',
      ),
      LocationProblem.denied => (
        'Без доступа к геопозиции город не определить — нажмите ещё раз '
            'и разрешите',
        null,
      ),
      null => (
        'Не удалось определить город. Попробуйте ещё раз или найдите его '
            'поиском',
        null,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 12, color: context.colors.defectText),
          ),
          if (action != null && problem != null) ...[
            const SizedBox(height: 6),
            CtaFlat(
              label: action,
              onPressed: () => widget.locator!.openSettings(problem),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // с открытой клавиатурой лист ужимается, чтобы не уехать под статус-бар
    final available =
        media.size.height - media.viewInsets.bottom - media.padding.top - 24;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: math.min(media.size.height * 0.85, available),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
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
                'Город',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.34,
                  color: context.colors.text1,
                ),
              ),
              const SizedBox(height: 14),
              if (_selected.isNotEmpty && !widget.single) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final name in _selected)
                      AppChip(
                        label: '$name  ×',
                        on: true,
                        onTap: () => _toggle(name),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              FieldBoxInput(
                label: '',
                controller: _search,
                hint: 'Поиск города',
              ),
              Expanded(child: _list()),
              if (!widget.single) ...[
                const SizedBox(height: 10),
                CtaPrimary(
                  label: _selected.isEmpty
                      ? 'Готово'
                      : 'Готово · ${_selected.length}',
                  onPressed: () => Navigator.of(context).pop(_selected),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _list() {
    final q = _query;
    final rows = <Widget>[
      if (q.isEmpty && widget.locator != null)
        _Row(
          title: _locating ? 'Определяем…' : 'Определить по геопозиции',
          leading: Icon(
            Icons.my_location,
            size: 16,
            color: context.colors.doneText,
          ),
          accent: true,
          onTap: _locating ? null : _locate,
        ),
      if (q.isEmpty && widget.locator != null && _locateFailed) _locateNote(),
      if (q.isEmpty && !widget.single)
        _Row(
          title: allRussia,
          checked: _selected.contains(allRussia),
          onTap: () => _toggle(allRussia),
        ),
    ];

    // своё значение — когда в справочнике нет точного совпадения
    final results = _results ?? const <City>[];
    final exact = results.any(
      (c) => normalizeSearch(c.name) == normalizeSearch(q),
    );
    if (q.isNotEmpty && !exact) {
      rows.add(
        _Row(
          title: 'Указать «$q»',
          leading: Icon(
            Icons.edit_outlined,
            size: 16,
            color: context.colors.doneText,
          ),
          accent: true,
          checked: _selected.contains(q),
          onTap: () => _pick(q),
        ),
      );
    }

    final stale = q != _resultsFor;
    if (_failed) {
      rows.add(_error());
    } else if (_loading && (_results == null || stale)) {
      rows.add(
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    } else if (!stale) {
      if (q.isEmpty) {
        rows.add(const SizedBox(height: 18));
        rows.add(const SectionHead('Крупные города'));
      } else if (results.isEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'В справочнике не нашлось',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.colors.text2),
            ),
          ),
        );
      }
      rows.addAll(
        results.map(
          (c) => _Row(
            title: c.name,
            trailing: c.region == c.name ? null : c.region,
            checked: _selected.contains(c.name),
            onTap: () => _pick(c.name, c),
          ),
        ),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: rows,
    );
  }

  Widget _error() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Не удалось загрузить список',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.colors.text2),
          ),
          const SizedBox(height: 14),
          CtaFlat(label: 'Повторить', onPressed: () => _load(_query)),
        ],
      ),
    );
  }
}

/// Строка списка: название слева, регион справа серым, галочка у выбранных.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.onTap,
    this.trailing,
    this.leading,
    this.accent = false,
    this.checked = false,
  });

  final String title;
  final String? trailing;
  final Widget? leading;
  final bool accent;
  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.line)),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Text(
                title,
                style: accent
                    ? context.text.fieldValue.copyWith(
                        color: context.colors.doneText,
                      )
                    : context.text.fieldValue,
              ),
            ),
            if (trailing != null)
              Flexible(
                child: Text(
                  trailing!,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: context.colors.text3),
                ),
              ),
            if (checked) ...[
              const SizedBox(width: 10),
              Icon(Icons.check, size: 18, color: context.colors.progressText),
            ],
          ],
        ),
      ),
    );
  }
}
