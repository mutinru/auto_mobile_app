import '../config/api_config.dart';
import 'chat_role.dart';

/// Фото в сообщении. Файл приватный: грузить только с заголовками
/// ChatRepository.imageHeaders, без токена сервер отдаёт 401.
class ChatAttachment {
  const ChatAttachment({required this.id, required this.url, this.width, this.height});

  final int id;
  final String url;
  final int? width;
  final int? height;

  /// Соотношение сторон для заглушки до загрузки; без размеров — квадрат.
  double get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : 1;

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
        id: json['id'] as int,
        url: chatAttachmentUrl(json['url'] as String),
        width: json['width'] as int?,
        height: json['height'] as int?,
      );
}

/// Сервер строит адрес от своего APP_URL (на dev — localhost:8083, а
/// эмулятору нужен 10.0.2.2). Берём только путь и подставляем свой хост.
String chatAttachmentUrl(String url) {
  final uri = Uri.parse(url);
  return '${ApiConfig.origin}${uri.path}';
}

/// Сообщение чата (MessageResource на бекенде) глазами текущего
/// пользователя: sender.role = me — моё, system — системное, иначе роль.
class ChatMessage {
  const ChatMessage({
    required this.id,
    this.body,
    this.attachments = const [],
    this.isMine = false,
    this.isSystem = false,
    this.senderRole,
    this.senderName,
    required this.createdAt,
  });

  final int id;
  final String? body;
  final List<ChatAttachment> attachments;
  final bool isMine;
  final bool isSystem;

  /// null у своих и системных сообщений.
  final ChatRole? senderRole;

  /// У поддержки всегда «Поддержка» — имён операторов сервер не отдаёт.
  final String? senderName;
  final DateTime createdAt;

  bool get isFromSupport => senderRole == ChatRole.support;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>? ?? const {};
    final role = sender['role'] as String?;
    return ChatMessage(
      id: json['id'] as int,
      body: json['body'] as String?,
      attachments: [
        for (final a in json['attachments'] as List? ?? const [])
          ChatAttachment.fromJson(a as Map<String, dynamic>),
      ],
      isMine: role == 'me',
      isSystem: role == 'system',
      senderRole: role == 'me' || role == 'system' ? null : chatRoleFromApi(role),
      senderName: sender['name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
