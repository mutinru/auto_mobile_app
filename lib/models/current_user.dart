/// Текущий пользователь (GET /api/me).
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.name,
    required this.email,
    this.registeredAt,
  });

  final int id;
  final String name;
  final String email;
  final DateTime? registeredAt;

  /// «с марта 2026» — вторая строка в шапке профиля.
  String get registeredLabel {
    final d = registeredAt;
    if (d == null) return '';
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return 'с ${months[d.month - 1]} ${d.year}';
  }

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        registeredAt: json['registered_at'] != null
            ? DateTime.tryParse(json['registered_at'] as String)
            : null,
      );
}
