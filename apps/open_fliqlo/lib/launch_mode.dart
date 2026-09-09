/// How the app was launched (CLI args / Android extras / Dream).
enum LaunchMode {
  /// Interactive flip-clock app.
  normal,

  /// OS screensaver: fullscreen, exit on input, no settings gestures.
  screensaver,

  /// Open settings sheet after load (Windows /c, Android dream settings).
  configure,

  /// Small preview window (Windows Screen Saver /p).
  preview,
}

/// Parses launch flags from argv and optional Android/Dart entrypoint args.
abstract final class LaunchModeParser {
  /// Returns the first matching mode; later flags win if multiple present.
  static LaunchMode fromArgs(List<String> args) {
    var mode = LaunchMode.normal;
    for (final raw in args) {
      final arg = raw.toLowerCase();
      if (arg == '--screensaver' || arg == '-screensaver') {
        mode = LaunchMode.screensaver;
      } else if (arg == '--configure' || arg == '-configure') {
        mode = LaunchMode.configure;
      } else if (arg == '--preview' || arg == '-preview') {
        mode = LaunchMode.preview;
      }
    }
    return mode;
  }

  static LaunchMode fromName(String? name) {
    switch (name?.toLowerCase()) {
      case 'screensaver':
        return LaunchMode.screensaver;
      case 'configure':
        return LaunchMode.configure;
      case 'preview':
        return LaunchMode.preview;
      default:
        return LaunchMode.normal;
    }
  }
}

extension LaunchModeX on LaunchMode {
  bool get isScreensaverLike =>
      this == LaunchMode.screensaver || this == LaunchMode.preview;

  bool get exitOnInput =>
      this == LaunchMode.screensaver || this == LaunchMode.preview;

  bool get allowInteractiveGestures => this == LaunchMode.normal;

  bool get openSettingsOnLaunch => this == LaunchMode.configure;
}
