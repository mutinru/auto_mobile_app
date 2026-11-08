import 'inspection_panel.dart' show mediaUrl;

class Car {
  const Car({
    required this.brand,
    required this.model,
    required this.year,
    required this.vinMasked,
    this.vinPhotoUrl,
    this.vinPhotoThumbUrl,
    this.mileageKm,
    this.customerMileageKm,
    this.mileageMismatch = false,
    this.odometerPhotoUrl,
    this.odometerPhotoThumbUrl,
  });

  final String brand;
  final String model;
  final int year;

  /// Замаскированный VIN для отображения в шапке ("··· KX24P").
  final String vinMasked;

  /// Фото таблички VIN — подписанная ссылка, Bearer не нужен.
  final String? vinPhotoUrl;

  /// Превью таблички — подложка просмотра, пока грузится полный кадр.
  final String? vinPhotoThumbUrl;

  /// Пробег по одометру — снял исполнитель; null у старых осмотров.
  final int? mileageKm;

  /// Пробег со слов продавца (указал заказчик разового осмотра).
  final int? customerMileageKm;

  /// Одометр и слова продавца расходятся заметно — порог считает сервер.
  final bool mileageMismatch;

  /// Фото приборки — подписанная ссылка, Bearer не нужен.
  final String? odometerPhotoUrl;

  /// Превью приборки — подложка просмотра, пока грузится полный кадр.
  final String? odometerPhotoThumbUrl;

  String get title => '$brand $model $year';

  /// «127 450 км» или null без пробега.
  String? get mileageLabel => kmLabel(mileageKm);

  factory Car.fromJson(Map<String, dynamic> json) => Car(
    brand: json['brand'] as String,
    model: json['model'] as String,
    year: json['year'] as int,
    vinMasked: json['vin_masked'] as String,
    vinPhotoUrl: mediaUrl(json['vin_photo_url'] as String?),
    vinPhotoThumbUrl: mediaUrl(json['vin_photo_thumb_url'] as String?),
    mileageKm: json['mileage_km'] as int?,
    customerMileageKm: json['customer_mileage_km'] as int?,
    mileageMismatch: json['mileage_mismatch'] as bool? ?? false,
    odometerPhotoUrl: mediaUrl(json['odometer_photo_url'] as String?),
    odometerPhotoThumbUrl: mediaUrl(
      json['odometer_photo_thumb_url'] as String?,
    ),
  );
}

/// «127 450 км» или null без пробега.
String? kmLabel(int? km) {
  if (km == null) return null;
  final s = km.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${buf.toString()} км';
}
