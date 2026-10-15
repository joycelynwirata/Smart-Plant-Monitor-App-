import 'package:cloud_firestore/cloud_firestore.dart';

/// Keeps Firestore history paths and reading conversion out of the dashboard.
class PlantHistoryService {
  PlantHistoryService({required this.uid});
  final String uid;

  CollectionReference<Map<String, dynamic>> _history(
    String plantId,
    String collection,
  ) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('plants')
      .doc(plantId)
      .collection(collection);

  Stream<List<double>> watchSoil(String plantId) =>
      _watchValues(plantId, 'history', 'soilMoisture');
  Stream<List<double>> watchLight(String plantId) =>
      _watchValues(plantId, 'lightHistory', 'light');

  Stream<List<double>> _watchValues(
    String plantId,
    String collection,
    String field,
  ) => _history(plantId, collection)
      .orderBy('timestamp', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => doc.data()[field])
            .whereType<num>()
            .where((value) => value.isFinite)
            .map((value) => value.toDouble())
            .toList()
            .reversed
            .toList(),
      );

  Future<void> recordSoil(String plantId, double value) =>
      _record(plantId, 'history', {'soilMoisture': value});
  Future<void> recordLight(String plantId, double value) =>
      _record(plantId, 'lightHistory', {'light': value});
  Future<void> recordWater(String plantId, String state) =>
      _record(plantId, 'waterEvents', {'state': state});

  Future<void> _record(
    String plantId,
    String collection,
    Map<String, dynamic> data,
  ) async {
    await _history(
      plantId,
      collection,
    ).add({...data, 'timestamp': FieldValue.serverTimestamp()});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchLatestWaterEvent(
    String plantId,
  ) => _history(
    plantId,
    'waterEvents',
  ).orderBy('timestamp', descending: true).limit(1).snapshots();
}
