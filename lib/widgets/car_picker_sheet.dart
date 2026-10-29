import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/car_catalog_repository.dart';
import '../models/car_catalog.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';

/// Что выбрано в листе: строки, которые уходят в заказ как brand/model.
class CarChoice {
  const CarChoice(this.brand, this.model);

  final String brand;
  final String model;
}

/// Лист «Марка и модель»: сначала марка, потом модель из справочника.
/// Справочник — только подсказка: на каждом шаге можно вписать своё,
/// а без сети лист сразу предлагает ручной ввод. Макета под лист нет —
/// собран из тех же кирпичей, что лист смены имени.
///
/// Если [initialBrand] есть в справочнике, лист открывается сразу на её
/// моделях. null — лист закрыли без выбора.
Future<CarChoice?> showCarPickerSheet(
  BuildContext context, {
  required CarCatalogRepository catalog,
  String initialBrand = '',
  String initialModel = '',
}) {
  return showModalBottomSheet<CarChoice>(
    context: context,
    backgroundColor: context.colors.bg0,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _CarPickerSheet(
      catalog: catalog,
      initialBrand: initialBrand.trim(),
      initialModel: initialModel.trim(),
    ),
  );
}

enum _Step { make, model, manual }

class _CarPickerSheet extends StatefulWidget {
  const _CarPickerSheet({
    required this.catalog,
    required this.initialBrand,
    required this.initialModel,
  });

  final CarCatalogRepository catalog;
  final String initialBrand;
  final String initialModel;

  @override
  State<_CarPickerSheet> createState() => _CarPickerSheetState();
}

class _CarPickerSheetState extends State<_CarPickerSheet> {
  final _search = TextEditingController();
  late final _manualBrand = TextEditingController(text: widget.initialBrand);
  late final _manualModel = TextEditingController(text: widget.initialModel);

  _Step _step = _Step.make;
  CarMake? _make;
  List<CarMake>? _makes;
  List<CarModel>? _models;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _manualBrand.addListener(() => setState(() {}));
    _manualModel.addListener(() => setState(() {}));
    _loadMakes(openInitial: true);
  }

  @override
  void dispose() {
    _search.dispose();
    _manualBrand.dispose();
    _manualModel.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim();

  Future<void> _loadMakes({bool openInitial = false}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final makes = await widget.catalog.fetchMakes();
      if (!mounted) return;
      setState(() => _makes = makes);
      if (openInitial && widget.initialBrand.isNotEmpty) {
        final initial = widget.initialBrand.toLowerCase();
        final match = makes.where((m) => m.name.toLowerCase() == initial).firstOrNull;
        if (match != null) await _openMake(match);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMake(CarMake make) async {
    setState(() {
      _make = make;
      _models = null;
      _step = _Step.model;
      _loading = true;
      _failed = false;
    });
    _search.clear();
    try {
      final models = await widget.catalog.fetchModels(make.id);
      if (mounted && _make == make) setState(() => _models = models);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() {
    _search.clear();
    setState(() {
      _step = _Step.make;
      _make = null;
      _models = null;
      // марки могли не загрузиться — тогда «назад» заодно повторяет запрос
      _failed = _makes == null;
    });
    if (_makes == null) _loadMakes();
  }

  /// Ручной ввод: марку и модель подставляем из того, что уже известно.
  void _manual({String? brand, String? model}) {
    if (brand != null) _manualBrand.text = brand;
    if (model != null) _manualModel.text = model;
    _search.clear();
    setState(() => _step = _Step.manual);
  }

  void _done(String brand, String model) {
    Navigator.of(context).pop(CarChoice(brand.trim(), model.trim()));
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
              _header(),
              const SizedBox(height: 14),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final title = switch (_step) {
      _Step.make => 'Марка',
      _Step.model => _make!.name,
      _Step.manual => 'Марка и модель',
    };
    final showBack = _step != _Step.make;

    return Row(
      children: [
        if (showBack) ...[
          SquareIconButton(
            icon: Icons.arrow_back,
            onTap: _step == _Step.model || _make == null ? _back : () => _openMake(_make!),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.34,
              color: context.colors.text1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_step == _Step.manual) return _manualForm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldBoxInput(
          label: '',
          controller: _search,
          hint: _step == _Step.make ? 'Поиск марки' : 'Поиск модели',
        ),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _list() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_failed) return _error();

    final q = _query;
    final rows = <Widget>[
      _manualRow(),
    ];

    if (_step == _Step.make) {
      final makes = _makes ?? const <CarMake>[];
      if (q.isEmpty) {
        final popular = makes.where((m) => m.popular).toList();
        if (popular.isNotEmpty) {
          rows.add(const _Gap());
          rows.add(const SectionHead('Популярные'));
          rows.addAll(popular.map(_makeRow));
        }
        final all = [...makes]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        rows.add(const _Gap());
        rows.add(const SectionHead('Все марки'));
        rows.addAll(all.map(_makeRow));
      } else {
        rows.addAll(makes.where((m) => m.matches(q)).map(_makeRow));
      }
    } else {
      final models = (_models ?? const <CarModel>[]).where((m) => m.matches(q));
      rows.addAll(models.map(_modelRow));
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: rows,
    );
  }

  /// Первая строка списка: своё значение, если в справочнике нет нужного.
  Widget _manualRow() {
    final q = _query;
    final label = q.isEmpty ? 'Нет в списке — ввести вручную' : 'Указать «$q»';

    void onTap() {
      if (_step == _Step.make) {
        _manual(brand: q.isEmpty ? null : q, model: '');
      } else if (q.isNotEmpty) {
        _done(_make!.name, q);
      } else {
        _manual(brand: _make!.name, model: '');
      }
    }

    return _Row(
      title: label,
      leading: Icon(Icons.edit_outlined, size: 16, color: context.colors.statusDone),
      accent: true,
      onTap: onTap,
    );
  }

  Widget _makeRow(CarMake make) => _Row(title: make.name, onTap: () => _openMake(make));

  Widget _modelRow(CarModel model) => _Row(
        title: model.name,
        trailing: model.years,
        onTap: () => _done(_make!.name, model.name),
      );

  Widget _error() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Не удалось загрузить список',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.colors.text2),
        ),
        const SizedBox(height: 14),
        CtaFlat(
          label: 'Повторить',
          onPressed: () => _step == _Step.model ? _openMake(_make!) : _loadMakes(),
        ),
        CtaGhost(
          label: 'Ввести вручную',
          onPressed: () => _manual(brand: _make?.name),
        ),
      ],
    );
  }

  Widget _manualForm() {
    final canSave = _manualBrand.text.trim().isNotEmpty && _manualModel.text.trim().isNotEmpty;

    return ListView(
      children: [
        FieldBoxInput(label: 'Марка', controller: _manualBrand, hint: 'Toyota', maxLength: 100),
        FieldBoxInput(
          label: 'Модель',
          controller: _manualModel,
          hint: 'Camry',
          maxLength: 100,
          autofocus: true,
        ),
        const SizedBox(height: 6),
        CtaPrimary(
          label: 'Готово',
          onPressed: canSave ? () => _done(_manualBrand.text, _manualModel.text) : null,
        ),
      ],
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 18);
}

/// Строка списка: название слева, годы выпуска справа серым моно.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.onTap,
    this.trailing,
    this.leading,
    this.accent = false,
  });

  final String title;
  final String? trailing;
  final Widget? leading;
  final bool accent;
  final VoidCallback onTap;

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
                    ? context.text.fieldValue.copyWith(color: context.colors.statusDone)
                    : context.text.fieldValue,
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: 12,
                  color: context.colors.text3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
