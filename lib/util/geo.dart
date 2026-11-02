import 'dart:math' as math;

const _earthRadiusKm = 6371.0;

/// Расстояние по большому кругу (гаверсинус), как CityCatalogController
/// на бекенде.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double deg) => deg * math.pi / 180;
  final a =
      math.pow(math.sin(rad(lat2 - lat1) / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(rad(lon2 - lon1) / 2), 2);
  return 2 * _earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
}

/// «8 км», ближе километра — «< 1 км»: чужим исполнителям точка осмотра
/// приходит огрублённой до ~1 км, точнее показывать нечестно.
String distanceLabel(double km) => km < 1 ? '< 1 км' : '${km.round()} км';
