import 'package:flutter/material.dart';
import 'services/plant_advice_service.dart';

class AIPage extends StatefulWidget {
  final String soil;
  final String light;
  final String name;
  final String type;
  final String profile;
  final PlantAdviceService? adviceService;

  const AIPage({
    super.key,
    required this.soil,
    required this.light,
    required this.name,
    required this.type,
    required this.profile,
    this.adviceService,
  });

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  String aiResponse = "Tap below to analyze your plant";

  bool _loading = false;

  Future<String> getGeminiAdvice() =>
      (widget.adviceService ?? PlantAdviceService()).getAdvice(
        messages: [
          {
            'role': 'user',
            'text':
                'Analyze this plant: ${widget.name}. '
                'Type: ${widget.type}. Profile: ${widget.profile}. '
                'Soil tension: ${widget.soil} cb (higher means drier). '
                'Light: ${widget.light} lux. Give one specific paragraph. '
                'Watering is automated; do not tell the user to water it.',
          },
        ],
      );

  Future<void> fetchAdvice() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      aiResponse = "Analyzing...";
    });

    try {
      final result = await getGeminiAdvice();

      if (!mounted) return;
      setState(() {
        aiResponse = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        aiResponse = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            value == "--" ? "N/A" : value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Plant Doctor 🌱",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                      color: Colors.green.withValues(alpha: 0.1),
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
              child: Text(aiResponse, style: const TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _loading ? null : fetchAdvice,
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
