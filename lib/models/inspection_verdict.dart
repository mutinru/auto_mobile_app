import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Итог разового осмотра — зеркалит App\Enums\InspectionVerdict.
enum InspectionVerdict { recommended, withReservations, notRecommended }

extension InspectionVerdictX on InspectionVerdict {
  String get label => switch (this) {
        InspectionVerdict.recommended => 'Можно брать',
        InspectionVerdict.withReservations => 'С оговорками',
        InspectionVerdict.notRecommended => 'Не рекомендую',
      };

  Color get color => switch (this) {
        InspectionVerdict.recommended => AppColors.statusDone,
        InspectionVerdict.withReservations => AppColors.statusProgress,
        InspectionVerdict.notRecommended => AppColors.statusDefect,
      };

  IconData get icon => switch (this) {
        InspectionVerdict.recommended => Icons.check,
        InspectionVerdict.withReservations => Icons.info_outline,
        InspectionVerdict.notRecommended => Icons.warning_amber_rounded,
      };

  String get apiValue => switch (this) {
        InspectionVerdict.recommended => 'recommended',
        InspectionVerdict.withReservations => 'with_reservations',
        InspectionVerdict.notRecommended => 'not_recommended',
      };
}

InspectionVerdict? inspectionVerdictFromApi(String? value) => switch (value) {
      'recommended' => InspectionVerdict.recommended,
      'with_reservations' => InspectionVerdict.withReservations,
      'not_recommended' => InspectionVerdict.notRecommended,
      _ => null,
    };
