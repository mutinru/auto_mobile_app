/// Что зритель может сделать с заказом прямо сейчас — ключи карты `actions`
/// в OrderResource (ревью №32). Ручное зеркало `App\Orders\OrderActions::KEYS`.
/// Кнопки действий заказа рисуются только по ним: правило считает сервер,
/// и меняется оно без новой сборки. Незнакомый ключ игнорируется.
enum OrderAction {
  acceptResponse('accept_response'),
  cancel('cancel'),
  repost('repost'),
  payPlacement('pay_placement'),
  complete('complete'),
  declinePurchaseReport('decline_purchase_report'),
  changePurchase('change_purchase'),
  markPaid('mark_paid'),
  dispute('dispute'),
  review('review'),
  addCandidate('add_candidate'),
  editSellerPhone('edit_seller_phone'),
  reportPurchase('report_purchase'),
  release('release'),
  startInspection('start_inspection'),
  finishInspection('finish_inspection'),
  confirmPayment('confirm_payment');

  const OrderAction(this.apiValue);

  final String apiValue;
}

/// Разрешённые действия из `actions` (`{"cancel": true, …}`): только true.
Set<OrderAction> orderActionsFromApi(Object? json) {
  if (json is! Map) return const {};
  return {
    for (final a in OrderAction.values)
      if (json[a.apiValue] == true) a,
  };
}

/// Кто смотрит заказ (`viewer_role`, ревью №31).
enum ViewerRole { customer, executor }

ViewerRole? viewerRoleFromApi(Object? value) => switch (value) {
  'customer' => ViewerRole.customer,
  'executor' => ViewerRole.executor,
  _ => null,
};
