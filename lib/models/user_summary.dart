/// Минимальное представление пользователя в контексте заказа
/// (UserResource на бекенде: id + name, без контактов).
class UserSummary {
  const UserSummary({required this.id, required this.name});

  final int id;
  final String name;

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as int,
        name: json['name'] as String,
      );
}
