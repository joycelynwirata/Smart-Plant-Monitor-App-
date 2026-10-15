import 'package:flutter_test/flutter_test.dart';
import 'package:smart_planter_app/services/realtime_sensor_service.dart';

void main() {
  test('Parses numeric hardware readings', () {
    expect(
      RealtimeSensorService.parseReading({
        'soilMoisture': '81.5',
        'light': 1200,
        'waterLevel': '1',
        'waterNow': true,
      }),
      {'soilMoisture': 81.5, 'light': 1200, 'waterLevel': 1},
    );
  });
  test(
    'Rejects incomplete and invalid readings instead of inventing zeros',
    () {
      for (final value in [
        null,
        [],
        'offline',
        {},
        {'soilMoisture': 'bad', 'light': 1200, 'waterLevel': 1},
        {'soilMoisture': double.nan, 'light': 1200, 'waterLevel': 1},
        {'soilMoisture': 80, 'light': -1, 'waterLevel': 1},
        {'soilMoisture': 80, 'light': 1200, 'waterLevel': 2},
      ]) {
        expect(RealtimeSensorService.parseReading(value), isNull);
      }
    },
  );
}
