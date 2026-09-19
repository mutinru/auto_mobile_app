class Car {
  const Car({
    required this.brand,
    required this.model,
    required this.year,
    required this.vinMasked,
    required this.mileageKm,
  });

  final String brand;
  final String model;
  final int year;

  /// Замаскированный VIN для отображения в шапке ("··· KX24P").
  final String vinMasked;
  final int mileageKm;

  String get title => '$brand $model $year';

  String get mileageLabel {
    final s = mileageKm.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} км';
  }

  factory Car.fromJson(Map<String, dynamic> json) => Car(
        brand: json['brand'] as String,
        model: json['model'] as String,
        year: json['year'] as int,
        vinMasked: json['vin_masked'] as String,
        mileageKm: json['mileage_km'] as int,
      );
}
