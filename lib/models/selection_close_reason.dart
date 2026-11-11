/// Почему подбор закрыт без покупки (статус closed) — зеркало
/// App\Enums\SelectionCloseReason на бекенде. [unknown] — причина, о
/// которой эта сборка не знает.
enum SelectionCloseReason { inactive, accountDeleted, unknown }

SelectionCloseReason? selectionCloseReasonFromApi(String? value) =>
    switch (value) {
      null => null,
      'inactive' => SelectionCloseReason.inactive,
      'account_deleted' => SelectionCloseReason.accountDeleted,
      _ => SelectionCloseReason.unknown,
    };

extension SelectionCloseReasonX on SelectionCloseReason {
  /// Подпись под статусом «закрыт без покупки».
  String get label => switch (this) {
    SelectionCloseReason.inactive => 'Два месяца не было новостей',
    SelectionCloseReason.accountDeleted => 'Заказчик удалил аккаунт',
    SelectionCloseReason.unknown => 'Подбор закрыт',
  };
}
