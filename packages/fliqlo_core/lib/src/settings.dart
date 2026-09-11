/// How digit pairs are arranged on the clock face.
enum ClockLayout {
  /// Classic Fliqlo row: HH : MM (: SS).
  horizontal,

  /// Stacked pairs: hours above minutes (optional seconds row below).
  vertical,
}

/// User-configurable display options for Open Fliqlo.
class FliqloSettings {
  const FliqloSettings({
    this.use24Hour = true,
    this.showSeconds = false,
    this.dim = 0.0,
    this.scale = 1.0,
    this.showFlaps = true,
    this.forceLandscape = false,
    this.layout = ClockLayout.horizontal,
    this.enableFlipSound = false,
  });

  final bool use24Hour;
  final bool showSeconds;

  /// Black overlay opacity from 0.0 to 0.8.
  final double dim;

  /// Clock face scale from 0.5 to 1.0.
  final double scale;

  /// Whether to draw the horizontal flap hinge.
  final bool showFlaps;

  /// Lock the app to landscape orientations (mobile).
  final bool forceLandscape;

  /// Horizontal row vs vertical stacked digit pairs.
  final ClockLayout layout;

  /// Play a short click when a digit flips (interactive app only).
  final bool enableFlipSound;

  FliqloSettings copyWith({
    bool? use24Hour,
    bool? showSeconds,
    double? dim,
    double? scale,
    bool? showFlaps,
    bool? forceLandscape,
    ClockLayout? layout,
    bool? enableFlipSound,
  }) {
    return FliqloSettings(
      use24Hour: use24Hour ?? this.use24Hour,
      showSeconds: showSeconds ?? this.showSeconds,
      dim: dim ?? this.dim,
      scale: scale ?? this.scale,
      showFlaps: showFlaps ?? this.showFlaps,
      forceLandscape: forceLandscape ?? this.forceLandscape,
      layout: layout ?? this.layout,
      enableFlipSound: enableFlipSound ?? this.enableFlipSound,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FliqloSettings &&
        other.use24Hour == use24Hour &&
        other.showSeconds == showSeconds &&
        other.dim == dim &&
        other.scale == scale &&
        other.showFlaps == showFlaps &&
        other.forceLandscape == forceLandscape &&
        other.layout == layout &&
        other.enableFlipSound == enableFlipSound;
  }

  @override
  int get hashCode => Object.hash(
        use24Hour,
        showSeconds,
        dim,
        scale,
        showFlaps,
        forceLandscape,
        layout,
        enableFlipSound,
      );
}
