import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../state/order_store.dart';
import 'assigned_inspection_screen.dart';
import 'inspection_order_detail_screen.dart';
import 'order_detail_screen.dart';

/// Открыть заказ нужным экраном — из списка заказов и из ленты уведомлений.
/// У осмотра своя деталь (кадр 04): деталь подбора собрана под бюджет,
/// города и список кандидатов. Исполнителю осмотр открывается отдельным
/// экраном — там старт осмотра и вердикт, а не отклики.
Future<void> openOrderScreen(
  BuildContext context, {
  required OrderStore store,
  required AuthService? auth,
  required int orderId,
  required bool isInspection,
  required bool asExecutor,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => isInspection && asExecutor
          ? AssignedInspectionScreen(store: store, orderId: orderId, auth: auth)
          : isInspection
          ? InspectionOrderDetailScreen(
              store: store,
              orderId: orderId,
              viewerIsCustomer: !asExecutor,
              auth: auth,
            )
          : OrderDetailScreen(
              store: store,
              orderId: orderId,
              viewerIsCustomer: !asExecutor,
              auth: auth,
            ),
    ),
  );
}
