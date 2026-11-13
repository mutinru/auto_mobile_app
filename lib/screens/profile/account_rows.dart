import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/profile_repository.dart';
import '../../state/order_store.dart';
import '../../widgets/change_phone_sheet.dart';
import '../../widgets/payout_sheet.dart';
import '../../widgets/phone_input.dart';
import '../vin_report_screen.dart';
import 'settings_row.dart';

/// Данные аккаунта: номер телефона, реквизиты для выплат, купленные отчёты.
class ProfileAccountRows extends StatelessWidget {
  const ProfileAccountRows({
    super.key,
    required this.auth,
    required this.profile,
    required this.store,
  });

  final AuthService auth;
  final ProfileRepository profile;
  final OrderStore store;

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // телефон — логин, поэтому смена через код на новый номер
        SettingsRow(
          icon: Icons.phone_outlined,
          label: 'Номер телефона',
          trailing: SettingsValue(
            user?.phone != null ? formatPhone(user!.phone!) : 'не указан',
          ),
          onTap: user == null
              ? null
              : () => showChangePhoneSheet(
                  context,
                  currentPhone: user.phone,
                  onRequest: profile.requestPhoneChange,
                  onConfirm: profile.confirmPhoneChange,
                ),
        ),

        // разовый осмотр оплачивается напрямую исполнителю;
        // при первом отклике реквизиты спросит и форма отклика
        SettingsRow(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Реквизиты для выплат',
          trailing: SettingsValue(user?.payout?.shortLabel ?? 'не указаны'),
          onTap: () => showPayoutSheet(
            context,
            initial: user?.payout,
            onSave: profile.updatePayout,
          ),
        ),

        // готовые отчёты по VIN, купленные при заказе осмотра
        SettingsRow(
          icon: Icons.fact_check_outlined,
          label: 'Купленные отчёты',
          trailing: const SettingsChevron(),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  VinReportsScreen(repository: store.vinReports, auth: auth),
            ),
          ),
        ),
      ],
    );
  }
}
