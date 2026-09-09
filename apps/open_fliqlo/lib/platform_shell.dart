import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'launch_mode.dart';

/// Desktop window + mobile keep-awake helpers.
abstract final class PlatformShell {
  static LaunchMode _mode = LaunchMode.normal;
  static const MethodChannel _channel =
      MethodChannel('com.openfliqlo.app/platform');

  static LaunchMode get mode => _mode;

  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isWindows;
  }

  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<void> initialize(LaunchMode mode) async {
    _mode = mode;
    if (!isDesktop) return;

    await windowManager.ensureInitialized();

    if (mode == LaunchMode.preview) {
      const options = WindowOptions(
        size: Size(320, 200),
        center: true,
        backgroundColor: Color(0xFF000000),
        skipTaskbar: true,
        title: 'Open Fliqlo Preview',
        titleBarStyle: TitleBarStyle.hidden,
        alwaysOnTop: true,
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setAsFrameless();
        await windowManager.show();
        await windowManager.focus();
      });
      return;
    }

    final skipTaskbar = mode == LaunchMode.screensaver;
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        backgroundColor: const Color(0xFF000000),
        skipTaskbar: skipTaskbar,
        title: 'Open Fliqlo',
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.setPreventClose(false);
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setFullScreen(true);
      },
    );
  }

  static Future<void> enableKeepAwake() async {
    try {
      if (isMobile || isDesktop) {
        await WakelockPlus.enable();
      }
    } catch (_) {
      // Plugins may be unavailable in tests / unsupported hosts.
    }
  }

  static Future<void> disableKeepAwake() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  static Future<void> toggleFullscreen() async {
    if (!isDesktop) return;
    if (_mode.exitOnInput) return;
    final full = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!full);
    if (full) {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    } else {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
  }

  static Future<void> exitFullscreen() async {
    if (!isDesktop) return;
    if (_mode.exitOnInput) {
      requestExit();
      return;
    }
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    }
  }

  static Future<void> enterImmersive() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Lock to landscape when [forceLandscape] is true; otherwise allow all.
  /// No-op on desktop / web.
  static Future<void> applyPreferredOrientations({
    required bool forceLandscape,
  }) async {
    if (!isMobile) return;
    try {
      if (forceLandscape) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } catch (_) {
      // SystemChrome may be unavailable in tests.
    }
  }

  /// Quit the process (screensaver / preview) or finish Android activity/dream.
  static void requestExit() {
    if (kIsWeb) return;
    if (isDesktop) {
      exit(0);
    }
    if (Platform.isAndroid) {
      Future<void>(() async {
        try {
          await _channel.invokeMethod<void>('finish');
        } catch (_) {
          SystemNavigator.pop();
        }
      });
      return;
    }
    SystemNavigator.pop();
  }
}
