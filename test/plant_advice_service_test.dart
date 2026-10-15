import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_planter_app/services/plant_advice_service.dart';

void main() {
  final messages = [
    {'role': 'user', 'text': 'How is my lily?'},
  ];

  test('Adds the user token and reads backend advice', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(jsonDecode(request.body)['messages'], messages);
      expect(request.url.host, endsWith('cloudfunctions.net'));
      return http.Response('{"advice":"More indirect light."}', 200);
    });
    final service = PlantAdviceService(
      client: client,
      tokenProvider: () async => 'test-token',
    );
    expect(await service.getAdvice(messages: messages), 'More indirect light.');
  });

  test('Does not send unauthenticated requests', () async {
    final service = PlantAdviceService(
      client: MockClient((_) async => fail('Request should not be sent')),
      tokenProvider: () async => null,
    );
    await expectLater(
      service.getAdvice(messages: messages),
      throwsA(isA<AdviceException>()),
    );
  });

  for (final status in [401, 429, 500, 503]) {
    test(
      'Handles HTTP $status without parsing an upstream error as advice',
      () async {
        final service = PlantAdviceService(
          client: MockClient((_) async => http.Response('not JSON', status)),
          tokenProvider: () async => 'token',
        );
        await expectLater(
          service.getAdvice(messages: messages),
          throwsA(isA<AdviceException>()),
        );
      },
    );
  }

  for (final body in ['not JSON', '{}', '{"advice":""}', '[]']) {
    test('Rejects empty or malformed advice: $body', () async {
      final service = PlantAdviceService(
        client: MockClient((_) async => http.Response(body, 200)),
        tokenProvider: () async => 'token',
      );
      await expectLater(
        service.getAdvice(messages: messages),
        throwsA(isA<AdviceException>()),
      );
    });
  }
}
