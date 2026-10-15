import 'package:firebase_database/firebase_database.dart';

class RealtimeSensorService {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref(
    'liveData/plant1',
  );

  Future<void> requestWatering() async {
    await _ref.update({'waterNow': false});
    await Future.delayed(const Duration(milliseconds: 200));
    await _ref.update({'waterNow': true});
  }

  /// Invalid or incomplete readings stay unavailable instead of becoming zero.
  static Map<String, dynamic>? parseReading(Object? value) {
    if (value is! Map) return null;
    final result = <String, dynamic>{};
    for (final key in ['soilMoisture', 'light', 'waterLevel']) {
      final raw = value[key];
      final number = raw is num ? raw : num.tryParse(raw?.toString() ?? '');
      if (number == null || !number.isFinite || number < 0) return null;
      if (key == 'waterLevel' && number != 0 && number != 1) return null;
      result[key] = number;
    }
    return result;
  }

  Stream<Map<String, dynamic>?> getSensorData() =>
      _ref.onValue.map((event) => parseReading(event.snapshot.value));
}
