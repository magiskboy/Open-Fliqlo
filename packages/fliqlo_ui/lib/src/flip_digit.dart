import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'digit_glyph_atlas.dart';
import 'theme.dart';

/// A single flip-clock digit with a hinged flap animation.
class FlipDigit extends StatefulWidget {
  const FlipDigit({
    super.key,
    required this.digit,
    this.showFlaps = true,
    this.duration = FliqloTheme.flipDuration,
    this.atlas,
  });

  /// Target digit (0–9).
  final int digit;
  final bool showFlaps;
  final Duration duration;

  /// Optional shared raster glyph cache; falls back to [TextPainter] if null.
  final DigitGlyphAtlas? atlas;

  @override
  State<FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<FlipDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _from;
  late int _to;

  @override
  void initState() {
    super.initState();
    _from = widget.digit;
    _to = widget.digit;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..value = 1;
  }

  @override
  void didUpdateWidget(covariant FlipDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.digit != oldWidget.digit) {
      _from = oldWidget.digit;
      _to = widget.digit;
      _controller.forward(from: 0);
    }
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return CustomPaint(
          painter: FlipDigitPainter(
            from: _from,
            to: _to,
            progress: t,
            showFlaps: widget.showFlaps,
            atlas: widget.atlas,
            atlasGeneration: widget.atlas?.generation ?? 0,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

/// Paints a split-flap digit. [progress] 0 = [from], 1 = [to].
class FlipDigitPainter extends CustomPainter {
  FlipDigitPainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.showFlaps,
    this.atlas,
    this.atlasGeneration = 0,
  });

  final int from;
  final int to;
  final double progress;
  final bool showFlaps;
  final DigitGlyphAtlas? atlas;
  final int atlasGeneration;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) * 0.1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = FliqloTheme.digitBackground);

    final half = size.height / 2;
    final topRect = Rect.fromLTWH(0, 0, size.width, half);
    final bottomRect = Rect.fromLTWH(0, half, size.width, half);

    if (progress >= 1 || from == to) {
      _paintDigit(canvas, size, to);
      if (showFlaps) _paintHinge(canvas, size);
      canvas.restore();
      return;
    }

    // Static: upper half of next digit, lower half of current digit.
    _paintClippedDigit(canvas, size, to, topRect);
    _paintClippedDigit(canvas, size, from, bottomRect);

    // Animated flap rotates around the horizontal hinge.
    final angle = progress * math.pi; // 0 → π
    if (angle <= math.pi / 2) {
      // First half: top flap of [from] swinging down.
      _paintFlap(
        canvas,
        size: size,
        digit: from,
        isTop: true,
        angle: angle,
      );
    } else {
      // Second half: bottom flap of [to] swinging into place.
      _paintFlap(
        canvas,
        size: size,
        digit: to,
        isTop: false,
        angle: angle - math.pi,
      );
    }

    if (showFlaps) _paintHinge(canvas, size);

    // Soft shadow under the moving flap.
    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.35 * math.sin(progress * math.pi)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, half - 4, size.width, half * 0.4));
    canvas.drawRect(Rect.fromLTWH(0, half - 2, size.width, half * 0.35), shadowPaint);

    canvas.restore();
  }

  void _paintHinge(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = FliqloTheme.hinge
      ..strokeWidth = math.max(1.5, size.height * 0.012);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  void _paintClippedDigit(Canvas canvas, Size size, int digit, Rect clip) {
    canvas.save();
    canvas.clipRect(clip);
    _paintDigit(canvas, size, digit);
    canvas.restore();
  }

  void _paintFlap(
    Canvas canvas, {
    required Size size,
    required int digit,
    required bool isTop,
    required double angle,
  }) {
    final half = size.height / 2;
    canvas.save();
    canvas.translate(size.width / 2, half);
    // Perspective-ish squash on X via scale based on cos(angle).
    final cosA = math.cos(angle);
    canvas.scale(1.0, cosA.abs().clamp(0.05, 1.0));

    if (isTop) {
      canvas.translate(-size.width / 2, -half);
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, half));
    } else {
      canvas.translate(-size.width / 2, 0);
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, half));
      canvas.translate(0, -half);
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = FliqloTheme.digitBackground,
    );
    _paintDigit(canvas, size, digit);
    canvas.restore();
  }

  void _paintDigit(Canvas canvas, Size size, int digit) {
    final cache = atlas;
    if (cache != null) {
      cache.paintDigit(canvas, size, digit);
      return;
    }
    DigitGlyphAtlas.paintDigitFallback(canvas, size, digit);
  }

  @override
  bool shouldRepaint(covariant FlipDigitPainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.progress != progress ||
        oldDelegate.showFlaps != showFlaps ||
        oldDelegate.atlas != atlas ||
        oldDelegate.atlasGeneration != atlasGeneration;
  }
}
