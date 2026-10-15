import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaterWave extends StatefulWidget {
  final Color color;
  final double level;

  const WaterWave({super.key, required this.color, required this.level});

  @override
  State<WaterWave> createState() => _WaterWaveState();
}

class _WaterWaveState extends State<WaterWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return ClipPath(
          clipper: _WaveClipper(_controller.value, widget.level),
          child: Container(color: widget.color),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _WaveClipper extends CustomClipper<Path> {
  final double value;
  final double level;

  _WaveClipper(this.value, this.level);

  @override
  Path getClip(Size size) {
    final path = Path();
    const waveHeight = 10.0;
    final baseHeight = size.height * (1 - level);

    path.lineTo(0, baseHeight);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        baseHeight +
            waveHeight *
                math.sin((i / size.width * 2 * math.pi) + value * 2 * math.pi),
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant _WaveClipper oldClipper) => true;
}
