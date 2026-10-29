/// Роль в разговоре — зеркалит App\Enums\ChatRole на бекенде.
/// requester — обратившийся в поддержку, customer/executor — стороны
/// заказа, support — оператор. В sender.role сообщения сервер отдаёт ещё
/// me и system — их разбирает ChatMessage.fromJson, в энам они не входят.
enum ChatRole { requester, customer, executor, support }

ChatRole chatRoleFromApi(String? value) => switch (value) {
      'customer' => ChatRole.customer,
      'executor' => ChatRole.executor,
      'support' => ChatRole.support,
      _ => ChatRole.requester,
    };
