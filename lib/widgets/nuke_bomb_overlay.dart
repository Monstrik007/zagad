import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

const _fireEmojis = ['🔥', '💥', '☄️', '🔥', '🔥'];

class NukeBombOverlay extends StatefulWidget {
  const NukeBombOverlay({
    super.key,
    required this.throwerName,
    required this.targetName,
  });

  final String throwerName;
  final String targetName;

  @override
  State<NukeBombOverlay> createState() => _NukeBombOverlayState();
}

class _NukeBombOverlayState extends State<NukeBombOverlay>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(seconds: 5);
  static const _particleCount = 48;

  late final AnimationController _controller;
  late final List<_FireParticle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..forward();
    _particles = List.generate(_particleCount, (_) => _FireParticle.random(_random));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return CustomPaint(
                painter: _FireRainPainter(
                  progress: t,
                  particles: _particles,
                ),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('☢️', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.throwerName} скинул ядерную бомбу на ${widget.targetName}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FireParticle {
  _FireParticle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.emoji,
    required this.size,
  });

  final double x;
  final double delay;
  final double speed;
  final String emoji;
  final double size;

  factory _FireParticle.random(Random random) {
    return _FireParticle(
      x: random.nextDouble(),
      delay: random.nextDouble() * 0.45,
      speed: 0.55 + random.nextDouble() * 0.9,
      emoji: _fireEmojis[random.nextInt(_fireEmojis.length)],
      size: 18 + random.nextDouble() * 22,
    );
  }
}

class _FireRainPainter extends CustomPainter {
  _FireRainPainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_FireParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final local = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final y = -p.size + (size.height + p.size * 2) * local * p.speed;
      final x = p.x * size.width;

      final tp = TextPainter(
        text: TextSpan(
          text: p.emoji,
          style: TextStyle(fontSize: p.size),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(x - tp.width / 2, y));
    }
  }

  @override
  bool shouldRepaint(covariant _FireRainPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
