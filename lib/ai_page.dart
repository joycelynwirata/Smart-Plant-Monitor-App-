import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AIPage extends StatefulWidget {
  final String soil;
  final String light;
  final String name;
  final String type;
  final String profile;

  const AIPage({
    super.key,
    required this.soil,
    required this.light,
    required this.name,
    required this.type,
    required this.profile,
  });

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  String aiResponse = "Tap below to analyze your plant";

  Future<String> getGeminiAdvice() async {
   

    final response = await http.post(
      Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey",
      ),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": """
You are a plant monitoring system inside an automated watering app.

Rules:
- No greetings
- No markdown or symbols
- a paragraph long
- friendly tone
- Be direct and natural
- Do NOT give generic advice
- Always tailor insights specifically to the plant type

The watering is already handled automatically by the system. Do NOT tell the user to water the plant.

Focus on:
- Whether current conditions match what THIS plant needs
- Light suitability
- Soil behavior
- Any mismatch between plant needs and environment

Plant name: ${widget.name}
Plant type: ${widget.type}
Plant profile: ${widget.profile}

Sensor data:
- Soil moisture: ${widget.soil} (higher = drier)
- Light level: ${widget.light} lux

Give specific insights for this exact plant type (e.g., lily, cactus, etc.), not general plants.
"""
              }
            ]
          }
        ]
      }),
    );

    print(response.body);

    final data = jsonDecode(response.body);
    return data["candidates"][0]["content"]["parts"][0]["text"];
  }

  Future<void> fetchAdvice() async {
    setState(() {
      aiResponse = "Analyzing...";
    });

    try {
      final result = await getGeminiAdvice();

      setState(() {
        aiResponse = result;
      });
    } catch (e) {
      setState(() {
        aiResponse = "Error getting AI response";
      });
    }
  }

  @override

  Widget _sensorCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value == "--" ? "N/A" : value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Plant Doctor 🌱",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.eco, color: Colors.green),
                  ),

                  const SizedBox(width: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text("Type: ${widget.type}"),
                      Text("Preset: ${widget.profile}"),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _sensorCard(
                    title: "Soil Moisture",
                    value: widget.soil,
                    icon: Icons.water_drop,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _sensorCard(
                    title: "Light Level",
                    value: widget.light,
                    icon: Icons.wb_sunny,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                aiResponse,
                style: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: fetchAdvice,
              icon: const Icon(Icons.smart_toy),
              label: const Text("Analyze with AI"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}