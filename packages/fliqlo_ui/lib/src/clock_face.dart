import 'dart:math' as math;

import 'package:fliqlo_core/fliqlo_core.dart';
import 'package:flutter/material.dart';

import 'flip_digit.dart';
import 'theme.dart';

/// Full flip-clock face: digits, optional seconds, AM/PM, dim overlay.
class ClockFace extends StatelessWidget {
  const ClockFace({
    super.key,
    required this.snapshot,
    required this.settings,
  });

  final ClockSnapshot snapshot;
  final FliqloSettings settings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final showSeconds = settings.showSeconds;
        final amPm = snapshot.amPmLabel;

        final digitCount = showSeconds ? 6 : 4;
        final colonCount = showSeconds ? 2 : 1;
        final pairGaps = showSeconds ? 3 : 2;
        // Relative widths: digit=1, gap=0.12, colon=0.36
        final widthUnits =
            digitCount * 1.0 + pairGaps * 0.12 + colonCount * 0.36;

        // At scale=1.0, fill the binding axis (width or height) with a thin margin.
        const edgePad = 0.02;
        final availW = maxWidth * (1 - edgePad * 2);
        final availH = maxHeight * (1 - edgePad * 2);
        const digitAspect = 0.72; // width / height
        final heightFromWidth = availW / (widthUnits * digitAspect);
        final digitHeight = math.min(availH, heightFromWidth);
        final digitWidth = digitHeight * digitAspect;
        final gap = digitWidth * 0.12;
        final colonWidth = digitWidth * 0.36;

        Widget digit(int value, {String? amPmOverlay, bool isPm = false}) {
          return SizedBox(
            width: digitWidth,
            height: digitHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FlipDigit(
                  digit: value,
                  showFlaps: settings.showFlaps,
                ),
                if (amPmOverlay != null)
                  CustomPaint(
                    painter: _AmPmPainter(
                      label: amPmOverlay,
                      isPm: isPm,
                    ),
                  ),
              ],
            ),
          );
        }

        Widget colon() {
          return SizedBox(
            width: colonWidth,
            height: digitHeight,
            child: CustomPaint(
              painter: _ColonPainter(sizeFactor: digitHeight),
            ),
          );
        }

        final row = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            digit(
              snapshot.hourTens,
              amPmOverlay: amPm,
              isPm: snapshot.isPm,
            ),
            SizedBox(width: gap),
            digit(snapshot.hourOnes),
            colon(),
            digit(snapshot.minuteTens),
            SizedBox(width: gap),
            digit(snapshot.minuteOnes),
            if (showSeconds) ...[
              colon(),
              digit(snapshot.secondTens),
              SizedBox(width: gap),
              digit(snapshot.secondOnes),
            ],
          ],
        );

        return ColoredBox(
          color: FliqloTheme.background,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Transform.scale(
                  key: const ValueKey('clock-scale'),
                  scale: settings.scale.clamp(0.5, 1.0),
                  child: row,
                ),
              ),
              if (settings.dim > 0)
                IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: settings.dim),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Draws AM/PM in the corner of the hour-tens flap (Gluqlo-style), above the digit.
class _AmPmPainter extends CustomPainter {
  _AmPmPainter({required this.label, required this.isPm});

  final String label;
  final bool isPm;

  @override
  void paint(Canvas canvas, Size size) {
    final fontSize = size.height * 0.11;
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: FliqloTheme.digitForeground,
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          height: 1,
          fontFamily: FliqloTheme.digitFontFamily,
          package: FliqloTheme.digitFontPackage,
          shadows: const [
            Shadow(color: Color(0xFF000000), blurRadius: 2, offset: Offset(0, 0)),
            Shadow(color: Color(0xFF000000), blurRadius: 4, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = size.height * 0.07;
    final dy = size.height * 0.10;
    final offset = Offset(
      dx,
      isPm ? size.height - dy - text.height : dy,
    );
    text.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _AmPmPainter oldDelegate) =>
      oldDelegate.label != label || oldDelegate.isPm != isPm;
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
