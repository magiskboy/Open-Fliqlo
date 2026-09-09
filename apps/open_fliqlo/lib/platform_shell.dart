import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop window + mobile keep-awake helpers.
abstract final class PlatformShell {
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isWindows;
  }

  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<void> initialize() async {
    if (isDesktop) {
      await windowManager.ensureInitialized();
      const options = WindowOptions(
        backgroundColor: Color(0xFF000000),
        skipTaskbar: false,
        title: 'Open Fliqlo',
        titleBarStyle: TitleBarStyle.hidden,
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setPreventClose(false);
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setFullScreen(true);
      });
    }
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
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    }
  }

  static Future<void> enterImmersive() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}
