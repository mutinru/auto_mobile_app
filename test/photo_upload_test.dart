import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/photo_upload.dart';
import 'package:auto_podbor_mobile/models/car.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';

/// Сжатие снимка перед отправкой: ускоряет, но не условие отправки. В
/// тестах нативного плагина нет — это и есть «сжатие не удалось».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late String shot;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('photo_upload_test');
    shot = '${dir.path}/shot.jpg';
    File(shot).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('сжатие не удалось — уходит исходный снимок', () async {
    expect(await compressForUpload(shot), shot);
  });

  test('отправка получает путь, исходник остаётся на месте', () async {
    final sent = await withUploadCopy(shot, (path) async => path);

    expect(sent, shot);
    expect(File(shot).existsSync(), isTrue);
  });

  test('превью фото таблички и приборки разбираются у машины', () {
    final json = {
      'id': 1,
      'brand': 'Kia',
      'model': 'Rio',
      'year': 2019,
      'vin_masked': '··· 100111',
      'vin_photo_url': '/api/media/vin-photos/1?signature=a',
      'vin_photo_thumb_url': '/api/media/vin-photos/1/thumb?signature=b',
      'odometer_photo_url': '/api/media/odometer-photos/1?signature=c',
      'odometer_photo_thumb_url':
          '/api/media/odometer-photos/1/thumb?signature=d',
    };

    final car = Car.fromJson(json);
    expect(car.vinPhotoThumbUrl, endsWith('/vin-photos/1/thumb?signature=b'));
    expect(
      car.odometerPhotoThumbUrl,
      endsWith('/odometer-photos/1/thumb?signature=d'),
    );

    final orderCar = OrderCar.fromJson(json);
    expect(
      orderCar.vinPhotoThumbUrl,
      endsWith('/vin-photos/1/thumb?signature=b'),
    );
    expect(
      orderCar.odometerPhotoThumbUrl,
      endsWith('/odometer-photos/1/thumb?signature=d'),
    );
  });
}
