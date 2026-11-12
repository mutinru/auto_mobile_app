import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';

import 'support/stores.dart';

/// Экран, который грузит списки при открытии — как профиль и разделы.
class _Loader extends StatefulWidget {
  const _Loader(this.store, this.load);

  final OrderStore store;
  final void Function(OrderStore) load;

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  @override
  void initState() {
    super.initState();
    widget.load(widget.store);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Стор общий на сессию (ревью №41): новый экран грузит списки в
/// `initState`, пока список под ним слушает тот же стор. Синхронное
/// уведомление посреди сборки кадра роняло приложение
/// («markNeedsBuild() called during build» при открытии профиля).
void main() {
  final loads = <String, void Function(OrderStore)>{
    'мои заказы': (s) => s.loadMyOrders(),
    'взятые заказы': (s) => s.loadAssignedOrders(),
    'заказы рядом': (s) => s.loadAvailableOrders(),
  };

  for (final MapEntry(key: name, value: load) in loads.entries) {
    testWidgets('$name: загрузка из initState при общем сторе', (
      tester,
    ) async {
      final store = mockStore(
        orders: MockOrderRepository(),
      );
      final open = ValueNotifier(false);
      var builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              // список, который уже на экране
              ListenableBuilder(
                listenable: store,
                builder: (_, _) {
                  builds++;
                  return const SizedBox();
                },
              ),
              // новый экран поверх — появляется в том же кадре
              ValueListenableBuilder(
                valueListenable: open,
                builder: (_, shown, _) =>
                    shown ? _Loader(store, load) : const SizedBox(),
              ),
            ],
          ),
        ),
      );
      final before = builds;

      open.value = true;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // список под экраном всё равно узнал о загрузке и её итоге
      expect(builds, greaterThan(before));
    });
  }
}
