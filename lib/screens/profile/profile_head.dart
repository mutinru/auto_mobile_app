import 'package:flutter/material.dart';

import '../../data/profile_repository.dart';
import '../../models/current_user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/avatar_editor.dart';
import '../../widgets/edit_name_sheet.dart';

/// .prof-head — шапка профиля: тап по аватару — фото профиля, по остальной
/// шапке — смена имени. Без профиля (офлайн-старт) — прочерк и без нажатий.
class ProfileHead extends StatelessWidget {
  const ProfileHead({super.key, required this.user, required this.profile});

  final CurrentUser? user;
  final ProfileRepository profile;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: user == null
          ? null
          : () => showEditNameSheet(
              context,
              initial: user.name,
              onSave: profile.updateName,
            ),
      child: Row(
        children: [
          if (user == null)
            Avatar(initialsOf('—'), size: 54)
          else
            AvatarEditor(
              name: user.name,
              url: user.avatarUrl,
              onUpload: profile.uploadAvatar,
              onDelete: profile.deleteAvatar,
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user?.name ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.36,
                          color: context.colors.text1,
                        ),
                      ),
                    ),
                    if (user != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: context.colors.text3,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    user?.email ?? '',
                    if (user?.registeredLabel.isNotEmpty ?? false)
                      user!.registeredLabel,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 12, color: context.colors.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
