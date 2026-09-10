import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Pre-rasterized digit (0–9) and AM/PM glyphs for the current digit cell size.
///
/// Glyph identity is fixed for the app lifetime; only [ensure] size / DPR
/// invalidates the cache. Paint paths draw [ui.Image] tiles — no per-frame
/// [TextPainter.layout].
class DigitGlyphAtlas extends ChangeNotifier {
  static const double _sizeEpsilon = 0.5;
  static const double _amPmPad = 8;

  Size? _logicalSize;
  double? _dpr;
  final List<ui.Image?> _digits = List<ui.Image?>.filled(10, null);
  ui.Image? _am;
  ui.Image? _pm;
  int _generation = 0;
  int _buildToken = 0;
  bool _disposed = false;

  /// Bumps when raster tiles are replaced; painters use this in [shouldRepaint].
  int get generation => _generation;

  bool get isReady =>
      _logicalSize != null &&
      _dpr != null &&
      _digits.every((image) => image != null);

  bool matches(Size digitSize, double dpr) {
    final cached = _logicalSize;
    if (cached == null || _dpr != dpr) return false;
    return (cached.width - digitSize.width).abs() < _sizeEpsilon &&
        (cached.height - digitSize.height).abs() < _sizeEpsilon &&
        isReady;
  }

  /// Builds or rebuilds raster tiles for [digitSize] at [dpr]. No-op if ready.
  Future<void> ensure({
    required Size digitSize,
    required double dpr,
  }) async {
    if (_disposed) return;
    if (digitSize.width < 1 || digitSize.height < 1 || dpr <= 0) return;
    if (matches(digitSize, dpr)) return;

    final token = ++_buildToken;
    final digits = <ui.Image>[];
    try {
      for (var i = 0; i < 10; i++) {
        digits.add(await _rasterizeDigit(i, digitSize, dpr));
        if (_disposed || token != _buildToken) {
          for (final image in digits) {
            image.dispose();
          }
          return;
        }
      }
      final am = await _rasterizeAmPm('AM', digitSize.height, dpr);
      if (_disposed || token != _buildToken) {
        for (final image in digits) {
          image.dispose();
        }
        am.dispose();
        return;
      }
      final pm = await _rasterizeAmPm('PM', digitSize.height, dpr);
      if (_disposed || token != _buildToken) {
        for (final image in digits) {
          image.dispose();
        }
        am.dispose();
        pm.dispose();
        return;
      }

      _disposeImages();
      for (var i = 0; i < 10; i++) {
        _digits[i] = digits[i];
      }
      _am = am;
      _pm = pm;
      _logicalSize = digitSize;
      _dpr = dpr;
      _generation++;
      notifyListeners();
    } catch (error, stack) {
      for (final image in digits) {
        image.dispose();
      }
      assert(() {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'fliqlo_ui',
            context: ErrorDescription('while building DigitGlyphAtlas'),
          ),
        );
        return true;
      }());
    }
  }

  /// Draws digit [digit] (0–9) centered in [size]. Falls back to [TextPainter].
  void paintDigit(Canvas canvas, Size size, int digit) {
    final image = digit >= 0 && digit <= 9 ? _digits[digit] : null;
    final dpr = _dpr;
    if (image == null || dpr == null) {
      paintDigitFallback(canvas, size, digit);
      return;
    }
    _drawImage(canvas, image, Offset.zero & size);
  }

  /// Draws AM/PM in the Gluqlo corner position. Falls back to [TextPainter].
  void paintAmPm(
    Canvas canvas,
    Size size, {
    required String label,
    required bool isPm,
  }) {
    final image = label == 'PM' ? _pm : _am;
    final dpr = _dpr;
    if (image == null || dpr == null) {
      paintAmPmFallback(canvas, size, label: label, isPm: isPm);
      return;
    }

    final logicalW = image.width / dpr;
    final logicalH = image.height / dpr;
    final textHeight = logicalH - 2 * _amPmPad;
    final dx = size.height * 0.07 - _amPmPad;
    final dy = isPm
        ? size.height - size.height * 0.10 - textHeight - _amPmPad
        : size.height * 0.10 - _amPmPad;
    _drawImage(canvas, image, Rect.fromLTWH(dx, dy, logicalW, logicalH));
  }

  @override
  void dispose() {
    _disposed = true;
    _buildToken++;
    _disposeImages();
    super.dispose();
  }

  void _disposeImages() {
    for (var i = 0; i < _digits.length; i++) {
      _digits[i]?.dispose();
      _digits[i] = null;
    }
    _am?.dispose();
    _am = null;
    _pm?.dispose();
    _pm = null;
    _logicalSize = null;
    _dpr = null;
  }

  static void _drawImage(Canvas canvas, ui.Image image, Rect dst) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  static Future<ui.Image> _rasterizeDigit(
    int digit,
    Size digitSize,
    double dpr,
  ) async {
    final pxW = (digitSize.width * dpr).round().clamp(1, 8192);
    final pxH = (digitSize.height * dpr).round().clamp(1, 8192);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    paintDigitFallback(canvas, digitSize, digit);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(pxW, pxH);
    } finally {
      picture.dispose();
    }
  }

  static Future<ui.Image> _rasterizeAmPm(
    String label,
    double digitHeight,
    double dpr,
  ) async {
    final painter = _amPmTextPainter(label, digitHeight)..layout();
    final logicalW = painter.width + 2 * _amPmPad;
    final logicalH = painter.height + 2 * _amPmPad;
    final pxW = (logicalW * dpr).round().clamp(1, 8192);
    final pxH = (logicalH * dpr).round().clamp(1, 8192);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    painter.paint(canvas, const Offset(_amPmPad, _amPmPad));
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(pxW, pxH);
    } finally {
      picture.dispose();
    }
  }

  /// [TextPainter] path used before tiles are ready and by painters without an atlas.
  static void paintDigitFallback(Canvas canvas, Size size, int digit) {
    final text = TextPainter(
      text: TextSpan(
        text: '$digit',
        style: TextStyle(
          color: FliqloTheme.digitForeground,
          fontSize: size.height * 0.70,
          fontWeight: FontWeight.w400,
          height: 1,
          fontFamily: FliqloTheme.digitFontFamily,
          package: FliqloTheme.digitFontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(
        (size.width - text.width) / 2,
        (size.height - text.height) / 2,
      ),
    );
  }

  /// [TextPainter] AM/PM path used before tiles are ready.
  static void paintAmPmFallback(
    Canvas canvas,
    Size size, {
    required String label,
    required bool isPm,
  }) {
    final text = _amPmTextPainter(label, size.height)..layout();
    final dx = size.height * 0.07;
    final dy = size.height * 0.10;
    text.paint(
      canvas,
      Offset(dx, isPm ? size.height - dy - text.height : dy),
    );
  }

  static TextPainter _amPmTextPainter(String label, double digitHeight) {
    return TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: FliqloTheme.digitForeground,
          fontSize: digitHeight * 0.11,
          fontWeight: FontWeight.w400,
          height: 1,
          fontFamily: FliqloTheme.digitFontFamily,
          package: FliqloTheme.digitFontPackage,
          shadows: const [
            Shadow(
              color: Color(0xFF000000),
              blurRadius: 2,
              offset: Offset(0, 0),
            ),
            Shadow(
              color: Color(0xFF000000),
              blurRadius: 4,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
  }
}
