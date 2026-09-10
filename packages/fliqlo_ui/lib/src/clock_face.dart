import 'dart:math' as math;

import 'package:fliqlo_core/fliqlo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'digit_glyph_atlas.dart';
import 'flip_digit.dart';
import 'theme.dart';

/// Full flip-clock face: digits, optional seconds, AM/PM, dim overlay.
class ClockFace extends StatefulWidget {
  const ClockFace({
    super.key,
    required this.snapshot,
    required this.settings,
  });

  final ClockSnapshot snapshot;
  final FliqloSettings settings;

  @override
  State<ClockFace> createState() => _ClockFaceState();
}

class _ClockFaceState extends State<ClockFace> {
  final DigitGlyphAtlas _atlas = DigitGlyphAtlas();
  Size? _pendingDigitSize;
  double? _pendingDpr;
  bool _ensureScheduled = false;

  @override
  void dispose() {
    _atlas.dispose();
    super.dispose();
  }

  void _scheduleAtlasEnsure(Size digitSize, double dpr) {
    if (_atlas.matches(digitSize, dpr)) return;
    _pendingDigitSize = digitSize;
    _pendingDpr = dpr;
    if (_ensureScheduled) return;
    _ensureScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _ensureScheduled = false;
      if (!mounted) return;
      final size = _pendingDigitSize;
      final ratio = _pendingDpr;
      if (size == null || ratio == null) return;
      _atlas.ensure(digitSize: size, dpr: ratio);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final showSeconds = widget.settings.showSeconds;
        final amPm = widget.snapshot.amPmLabel;

        final digitCount = showSeconds ? 6 : 4;
        final colonCount = showSeconds ? 2 : 1;
        final pairGaps = showSeconds ? 3 : 2;
        // Relative widths: digit=1, gap=0.12, colon=0.36
        final widthUnits =
            digitCount * 1.0 + pairGaps * 0.12 + colonCount * 0.36;

        // At scale=1.0, fill the binding axis (width or height) with a thin margin.
        // Scale is applied to digit metrics (not Transform.scale) so each
        // RepaintBoundary stays a stable, independently cached layer.
        const edgePad = 0.02;
        final scale = widget.settings.scale.clamp(0.5, 1.0);
        final availW = maxWidth * (1 - edgePad * 2);
        final availH = maxHeight * (1 - edgePad * 2);
        const digitAspect = 0.72; // width / height
        final heightFromWidth = availW / (widthUnits * digitAspect);
        final digitHeight = math.min(availH, heightFromWidth) * scale;
        final digitWidth = digitHeight * digitAspect;
        final gap = digitWidth * 0.12;
        final colonWidth = digitWidth * 0.36;
        final digitSize = Size(digitWidth, digitHeight);
        final dpr = MediaQuery.devicePixelRatioOf(context);

        _scheduleAtlasEnsure(digitSize, dpr);

        return ListenableBuilder(
          listenable: _atlas,
          builder: (context, _) {
            Widget digit(int value, {String? amPmOverlay, bool isPm = false}) {
              return RepaintBoundary(
                child: SizedBox(
                  width: digitWidth,
                  height: digitHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FlipDigit(
                        digit: value,
                        showFlaps: widget.settings.showFlaps,
                        atlas: _atlas,
                      ),
                      if (amPmOverlay != null)
                        CustomPaint(
                          painter: _AmPmPainter(
                            label: amPmOverlay,
                            isPm: isPm,
                            atlas: _atlas,
                            atlasGeneration: _atlas.generation,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }

            Widget colon() {
              return RepaintBoundary(
                child: SizedBox(
                  width: colonWidth,
                  height: digitHeight,
                  child: CustomPaint(
                    painter: _ColonPainter(sizeFactor: digitHeight),
                  ),
                ),
              );
            }

            final row = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                digit(
                  widget.snapshot.hourTens,
                  amPmOverlay: amPm,
                  isPm: widget.snapshot.isPm,
                ),
                SizedBox(width: gap),
                digit(widget.snapshot.hourOnes),
                colon(),
                digit(widget.snapshot.minuteTens),
                SizedBox(width: gap),
                digit(widget.snapshot.minuteOnes),
                if (showSeconds) ...[
                  colon(),
                  digit(widget.snapshot.secondTens),
                  SizedBox(width: gap),
                  digit(widget.snapshot.secondOnes),
                ],
              ],
            );

            return ColoredBox(
              color: FliqloTheme.background,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: row),
                  if (widget.settings.dim > 0)
                    IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: widget.settings.dim,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Draws AM/PM in the corner of the hour-tens flap (Gluqlo-style), above the digit.
class _AmPmPainter extends CustomPainter {
  _AmPmPainter({
    required this.label,
    required this.isPm,
    required this.atlas,
    required this.atlasGeneration,
  });

  final String label;
  final bool isPm;
  final DigitGlyphAtlas atlas;
  final int atlasGeneration;

  @override
  void paint(Canvas canvas, Size size) {
    atlas.paintAmPm(canvas, size, label: label, isPm: isPm);
  }

  @override
  bool shouldRepaint(covariant _AmPmPainter oldDelegate) =>
      oldDelegate.label != label ||
      oldDelegate.isPm != isPm ||
      oldDelegate.atlasGeneration != atlasGeneration;
}

class _ColonPainter extends CustomPainter {
  _ColonPainter({required this.sizeFactor});

  final double sizeFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = FliqloTheme.digitForeground;
    final r = sizeFactor * 0.035;
    final cx = size.width / 2;
    canvas.drawCircle(Offset(cx, size.height * 0.38), r, paint);
    canvas.drawCircle(Offset(cx, size.height * 0.62), r, paint);
  }

  @override
  bool shouldRepaint(covariant _ColonPainter oldDelegate) =>
      oldDelegate.sizeFactor != sizeFactor;
}
