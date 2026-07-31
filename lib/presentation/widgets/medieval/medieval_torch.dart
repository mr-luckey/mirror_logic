import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Metal wall torch with a live flame sitting in the cup.
///
/// The flame is drawn, not an image: particle tongues that rise, flicker and
/// die so the home-screen lamps feel lit rather than stickered.
class MedievalTorch extends StatelessWidget {
  const MedievalTorch({
    super.key,
    this.width = 56,
    this.height = 96,
    this.flip = false,
  });

  final double width;
  final double height;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    final torch = SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/medieval/torch_base_cut.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => Image.asset(
                'assets/images/medieval/torch_cut.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          // The sprite's top ~40% is transparent and the bowl rim sits at
          // x 0.56..0.99, y 0.41 of the box. Anchor the flame to those
          // measured bounds so it burns inside the cup, not above it.
          Positioned(
            left: width * 0.565,
            right: width * 0.01,
            top: height * 0.03,
            height: height * 0.43,
            child: const _TorchFlame(),
          ),
        ],
      ),
    );

    if (flip) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: torch,
      );
    }
    return torch;
  }
}

class _TorchFlame extends StatefulWidget {
  const _TorchFlame();

  @override
  State<_TorchFlame> createState() => _TorchFlameState();
}

class _TorchFlameState extends State<_TorchFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Boundaried: the flame runs every frame for as long as the menu is up,
    // and without this it would drag the crest, title and buttons along with
    // it on each tick.
    return RepaintBoundary(
      child: CustomPaint(
        painter: _FlamePainter(clock: _tick),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.clock}) : super(repaint: clock);

  final Animation<double> clock;

  double get time => clock.value * math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    // The base sits low in the box so the flame roots inside the bowl.
    final baseY = size.height * 0.95;
    final rng = math.Random(7);

    // Firelight spilling onto the bracket and the wall behind it.
    canvas.drawCircle(
      Offset(cx, baseY - size.height * 0.06),
      size.width * 0.95,
      Paint()
        ..color = const Color(0xFFFF7A18).withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    canvas.drawCircle(
      Offset(cx, baseY - size.height * 0.10),
      size.width * 0.5,
      Paint()
        ..color = const Color(0xFFFFB43C).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Layered tongues: outer orange, mid yellow, core white-hot. Each one is
    // a bit shorter and narrower, which is what gives fire its depth.
    _tongue(
      canvas,
      cx: cx,
      baseY: baseY,
      height: size.height * 0.9,
      width: size.width * 0.78,
      color: const Color(0xFFD8400A),
      wobble: 0.0,
      time: time,
      alpha: 0.85,
    );
    _tongue(
      canvas,
      cx: cx,
      baseY: baseY,
      height: size.height * 0.74,
      width: size.width * 0.56,
      color: const Color(0xFFF97A10),
      wobble: 1.1,
      time: time,
      alpha: 0.92,
    );
    _tongue(
      canvas,
      cx: cx,
      baseY: baseY,
      height: size.height * 0.55,
      width: size.width * 0.4,
      color: const Color(0xFFFFC02A),
      wobble: 2.3,
      time: time,
      alpha: 0.95,
    );
    _tongue(
      canvas,
      cx: cx,
      baseY: baseY,
      height: size.height * 0.34,
      width: size.width * 0.22,
      color: const Color(0xFFFFF6D0),
      wobble: 3.4,
      time: time,
      alpha: 0.9,
    );

    // Hot pool where the flame meets the fuel, so it does not look like it is
    // hovering above the cup.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, baseY - size.height * 0.02),
        width: size.width * 0.7,
        height: size.height * 0.1,
      ),
      Paint()
        ..color = const Color(0xFFFFD98A).withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Rising embers — the detail that sells "real fire" at a glance.
    for (var i = 0; i < 9; i++) {
      final phase = (time * (0.7 + i * 0.09) + i * 0.9) % (math.pi * 2);
      final life = (math.sin(phase) + 1) * 0.5;
      if (life < 0.12) continue;
      final x =
          cx + math.sin(phase * 2.1 + i) * size.width * 0.26 * (0.4 + life);
      final y = baseY - size.height * (0.2 + life * 0.95);
      final r = 0.7 + rng.nextDouble() * 1.5 * (1 - life);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFEE88),
            const Color(0xFFFF4400),
            life,
          )!
              .withValues(alpha: 0.9 * (1 - life * 0.7)),
      );
    }
  }

  static void _tongue(
    Canvas canvas, {
    required double cx,
    required double baseY,
    required double height,
    required double width,
    required Color color,
    required double wobble,
    required double time,
    required double alpha,
  }) {
    final tipSway = math.sin(time * 2.4 + wobble) * width * 0.18;
    final midSway = math.sin(time * 3.1 + wobble + 1.2) * width * 0.12;
    final breath = 1.0 + 0.06 * math.sin(time * 5.2 + wobble);

    final path = Path()
      ..moveTo(cx - width * 0.5 * breath, baseY)
      ..quadraticBezierTo(
        cx - width * 0.55 + midSway,
        baseY - height * 0.45,
        cx + tipSway,
        baseY - height,
      )
      ..quadraticBezierTo(
        cx + width * 0.55 + midSway,
        baseY - height * 0.45,
        cx + width * 0.5 * breath,
        baseY,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  /// The clock drives repaints; nothing else about the flame ever changes.
  @override
  bool shouldRepaint(covariant _FlamePainter oldDelegate) => false;
}
