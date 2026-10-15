import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_planter_app/ai_page.dart';
import 'package:smart_planter_app/services/plant_advice_service.dart';

void main() {
  testWidgets('Can leave AI page while advice is loading', (tester) async {
    final response = Completer<http.Response>();
    var requestCount = 0;
    final service = PlantAdviceService(
      client: MockClient((_) {
        requestCount++;
        return response.future;
      }),
      tokenProvider: () async => 'token',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AIPage(
            soil: '82',
            light: '1200',
            name: 'Lily',
            type: 'Lily',
            profile: 'Flowering',
            adviceService: service,
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Analyze with AI'));
    await tester.tap(find.text('Analyze with AI'));
    await tester.pump();
    expect(find.text('Analyzing...'), findsOneWidget);
    expect(requestCount, 1);
    final button = tester.widget<ElevatedButton>(
      find.byWidgetPredicate((widget) => widget is ElevatedButton),
    );
    expect(button.onPressed, isNull);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    response.complete(http.Response('{"advice":"More light."}', 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
