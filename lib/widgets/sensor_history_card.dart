import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/plant_profile.dart';
import 'metric_stat.dart';

enum SensorKind { soil, light }

/// Soil and light share one chart, tooltip, loading state, and metric layout.
class SensorHistoryCard extends StatelessWidget {
  const SensorHistoryCard({
    super.key,
    required this.history,
    required this.kind,
    required this.profile,
    required this.profileName,
  });

  final Stream<List<double>> history;
  final SensorKind kind;
  final PlantProfile profile;
  final String profileName;

  bool get _isSoil => kind == SensorKind.soil;

  String _status(double value) {
    if (!_isSoil) {
      if (value < profile.minLight) return 'Low';
      if (value <= profile.maxLight) return 'Adequate';
      return 'Ideal';
    }
    if (value > profile.dryThreshold) return 'Very Dry';
    if (value > profile.dryThreshold - 20) return 'Dry';
    if (value > profile.dryThreshold - 40) return 'Optimal';
    return 'Wet';
  }

  String _trend(double change) {
    if (change == 0) return 'Stable';
    if (_isSoil) return change > 0 ? '↑ Drying' : '↓ Moistening';
    return change > 0 ? '↑ Increasing' : '↓ Decreasing';
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<double>>(
    stream: history,
    builder: (context, snapshot) {
      final values = snapshot.data ?? [];
      final color = _isSoil ? Colors.green : Colors.orange;
      final unit = _isSoil ? 'cb' : 'lx';
      final name = _isSoil ? 'soil' : 'light';
      if (snapshot.hasError || values.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              snapshot.hasError
                  ? 'Unable to load $name data'
                  : 'No $name data yet',
            ),
          ),
        );
      }
      final current = values.last;
      final change = values.length > 1
          ? current - values[values.length - 2]
          : 0.0;
      final spots = List.generate(
        values.length,
        (index) => FlSpot(index.toDouble(), values[index]),
      );
      final bar = LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: _isSoil ? 2.5 : 2.2,
        dotData: FlDotData(
          show: true,
          checkToShowDot: (spot, _) => spot.x == values.length - 1,
          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
            radius: 5,
            color: color,
            strokeWidth: 2,
            strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isSoil ? 'Soil Intelligence' : 'Light Intensity',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _isSoil ? '$profileName moisture profile' : 'Light over time',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: _isSoil ? 8 : 10),
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: _isSoil
                        ? 220
                        : values.reduce((a, b) => a > b ? a : b) + 500,
                    clipData: FlClipData.none(),
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [bar],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: false,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => color,
                        tooltipRoundedRadius: 10,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) => spots
                            .map(
                              (spot) => LineTooltipItem(
                                '${spot.y.toInt()} $unit',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    showingTooltipIndicators: [
                      ShowingTooltipIndicators([
                        LineBarSpot(bar, 0, spots.last),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MetricStat('Current', '${current.toInt()} $unit'),
                MetricStat('Trend', _trend(change)),
                MetricStat('Status', _status(current)),
              ],
            ),
          ],
        ),
      );
    },
  );
}
