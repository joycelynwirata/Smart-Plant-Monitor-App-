import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_planter_app/models/plant_profile.dart';
import 'package:smart_planter_app/widgets/sensor_history_card.dart';

void main() {
  for (final kind in SensorKind.values) {
    testWidgets('${kind.name} card handles empty, single, and failed history', (
      tester,
    ) async {
      final readings = StreamController<List<double>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 360,
              child: SensorHistoryCard(
                history: readings.stream,
                kind: kind,
                profile: PlantProfile.tropical,
                profileName: 'Tropical',
              ),
            ),
          ),
        ),
      );
      expect(find.text('No ${kind.name} data yet'), findsOneWidget);

      final value = kind == SensorKind.soil ? 82.0 : 1250.0;
      final unit = kind == SensorKind.soil ? 'cb' : 'lx';
      readings.add([value]);
      await tester.pumpAndSettle();
      expect(find.text('${value.toInt()} $unit'), findsOneWidget);
      expect(find.text('Stable'), findsOneWidget);
      expect(tester.takeException(), isNull);

      readings.add([value - 10, value]);
      await tester.pumpAndSettle();
      expect(
        find.text(kind == SensorKind.soil ? '↑ Drying' : '↑ Increasing'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      readings.addError(StateError('Connection lost'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to load ${kind.name} data'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      readings.close();
      await tester.pump();
    });
  }
}
