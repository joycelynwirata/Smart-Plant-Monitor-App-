import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AdviceException implements Exception {
  const AdviceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Calls the authenticated backend; Gemini credentials never enter the app.
class PlantAdviceService {
  PlantAdviceService({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
  }) : _client = client,
       _tokenProvider = tokenProvider ?? _currentToken;

  final http.Client? _client;
  final Future<String?> Function() _tokenProvider;
  static Future<String?> _currentToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  static const _endpoint = String.fromEnvironment(
    'PLANT_ADVICE_URL',
    defaultValue:
        'https://us-central1-smart-plant-595ab.cloudfunctions.net/getPlantAdvice',
  );

  Future<String> getAdvice({
    required List<Map<String, String>> messages,
  }) async {
    final token = await _tokenProvider();
    if (token == null) {
      throw const AdviceException('Please sign in to get plant advice.');
    }
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'messages': messages.length > 20
                  ? messages.sublist(messages.length - 20)
                  : messages,
            }),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        throw AdviceException(switch (response.statusCode) {
          401 => 'Your session expired. Please sign in again.',
          429 => 'Too many requests. Please try again in a minute.',
          503 => 'Plant advice is not configured yet. Please try again later.',
          _ => 'Plant advice is temporarily unavailable. Please try again.',
        });
      }
      final data = jsonDecode(response.body);
      final advice = data is Map ? data['advice'] : null;
      if (advice is! String || advice.trim().isEmpty) {
        throw const AdviceException(
          'No advice was returned. Please try again.',
        );
      }
      return advice.trim();
    } on TimeoutException {
      throw const AdviceException('The request timed out. Please try again.');
    } on FormatException {
      throw const AdviceException(
        'The advice service returned an invalid response.',
      );
    } on http.ClientException {
      throw const AdviceException(
        'Unable to connect. Check your internet connection.',
      );
    } finally {
      if (_client == null) client.close();
    }
  }
}
