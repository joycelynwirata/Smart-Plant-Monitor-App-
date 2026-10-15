import 'dart:convert';
import 'package:http/http.dart' as http;

class PlantAlertService {
  Future<void> sendEmail({
    required String email,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': 'service_17wya8d',
        'template_id': 'template_xsbgmy8',
        'user_id': '3nNjUaWA2KyonwkpJ',
        'template_params': {'message': message, 'to_email': email},
      }),
    );
    if (response.statusCode >= 300) {
      throw StateError('Email delivery failed (${response.statusCode})');
    }
  }
}
