/// Вид разговора — зеркалит App\Enums\ConversationType на бекенде.
/// support — постоянный чат с поддержкой, order — чат заказчика с
/// назначенным исполнителем (на бекенде пока не включён).
enum ConversationType { support, order }

ConversationType conversationTypeFromApi(String? value) =>
    value == 'order' ? ConversationType.order : ConversationType.support;
