import 'dart:async';
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
    this.onDigitFlip,
  });

  final ClockSnapshot snapshot;
  final FliqloSettings settings;

  /// Fired (debounced) when one or more digits start a flip animation.
  final VoidCallback? onDigitFlip;

  @override
  State<ClockFace> createState() => _ClockFaceState();
}

class _ClockFaceState extends State<ClockFace> {
  final DigitGlyphAtlas _atlas = DigitGlyphAtlas();
  Size? _pendingDigitSize;
  double? _pendingDpr;
  bool _ensureScheduled = false;
  Timer? _flipSoundDebounce;

  /// Coalesce multi-digit flips (e.g. 9:59→10:00) into one callback.
  static const Duration _flipSoundDebounceWindow = Duration(milliseconds: 40);

  @override
  void dispose() {
    _flipSoundDebounce?.cancel();
    _atlas.dispose();
    super.dispose();
  }

  void _notifyDigitFlip() {
    if (widget.onDigitFlip == null) return;
    _flipSoundDebounce?.cancel();
    _flipSoundDebounce = Timer(_flipSoundDebounceWindow, () {
      widget.onDigitFlip?.call();
    });
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

  /// Digit metrics that fill [availW]×[availH] for [layout] at [scale].
  static ({double digitWidth, double digitHeight, double gap, double colonWidth})
      _metrics({
    required double availW,
    required double availH,
    required double scale,
    required ClockLayout layout,
    required bool showSeconds,
  }) {
    const digitAspect = 0.72; // width / height
    const pairGapFactor = 0.12;
    const colonFactor = 0.36;

    late final double digitHeight;
    if (layout == ClockLayout.horizontal) {
      final digitCount = showSeconds ? 6 : 4;
      final colonCount = showSeconds ? 2 : 1;
      final pairGaps = showSeconds ? 3 : 2;
      final widthUnits =
          digitCount * 1.0 + pairGaps * pairGapFactor + colonCount * colonFactor;
      final heightFromWidth = availW / (widthUnits * digitAspect);
      digitHeight = math.min(availH, heightFromWidth) * scale;
    } else {
      final rows = showSeconds ? 3 : 2;
      // Two digits + one intra-pair gap per row.
      const widthUnits = 2.0 + pairGapFactor;
      // Row gap matches horizontal pair gap (in digit-width units).
      final heightUnits =
          rows + (rows - 1) * (digitAspect * pairGapFactor);
      final fromWidth = availW / (widthUnits * digitAspect);
      final fromHeight = availH / heightUnits;
      digitHeight = math.min(fromWidth, fromHeight) * scale;
    }

    final digitWidth = digitHeight * digitAspect;
    final gap = digitWidth * pairGapFactor;
    final colonWidth = digitWidth * colonFactor;
    return (
      digitWidth: digitWidth,
      digitHeight: digitHeight,
      gap: gap,
      colonWidth: colonWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final showSeconds = widget.settings.showSeconds;
        final amPm = widget.snapshot.amPmLabel;
        final layout = widget.settings.layout;

        // At scale=1.0, fill the binding axis with a thin margin.
        // Scale is applied to digit metrics (not Transform.scale) so each
        // RepaintBoundary stays a stable, independently cached layer.
        const edgePad = 0.02;
        final scale = widget.settings.scale.clamp(0.5, 1.0);
        final availW = maxWidth * (1 - edgePad * 2);
        final availH = maxHeight * (1 - edgePad * 2);
        final m = _metrics(
          availW: availW,
          availH: availH,
          scale: scale,
          layout: layout,
          showSeconds: showSeconds,
        );
        final digitWidth = m.digitWidth;
        final digitHeight = m.digitHeight;
        final gap = m.gap;
        final colonWidth = m.colonWidth;
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
                        onFlip: widget.onDigitFlip == null
                            ? null
                            : _notifyDigitFlip,
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

            Widget pair(
              int tens,
              int ones, {
              String? amPmOverlay,
              bool isPm = false,
            }) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  digit(tens, amPmOverlay: amPmOverlay, isPm: isPm),
                  SizedBox(width: gap),
                  digit(ones),
                ],
              );
            }

            final Widget face;
            if (layout == ClockLayout.vertical) {
              face = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pair(
                    widget.snapshot.hourTens,
                    widget.snapshot.hourOnes,
                    amPmOverlay: amPm,
                    isPm: widget.snapshot.isPm,
                  ),
                  SizedBox(height: gap),
                  pair(widget.snapshot.minuteTens, widget.snapshot.minuteOnes),
                  if (showSeconds) ...[
                    SizedBox(height: gap),
                    pair(
                      widget.snapshot.secondTens,
                      widget.snapshot.secondOnes,
                    ),
                  ],
                ],
              );
            } else {
              face = Row(
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
            }

            return ColoredBox(
              color: FliqloTheme.background,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: face),
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
