import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_planter_app/widgets/plant_chat.dart';

void main() {
  testWidgets('Chat retains its conversation when closed and reopened', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                right: 20,
                bottom: 20,
                child: PlantChat(sensorSummary: () => 'No readings yet.'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(find.text('Sprout Quick AI'), findsOneWidget);
    expect(find.textContaining("I'm Sprout"), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Sprout Quick AI'), findsNothing);
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(find.textContaining("I'm Sprout"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
