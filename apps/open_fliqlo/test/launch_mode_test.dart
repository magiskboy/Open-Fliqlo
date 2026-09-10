import 'package:flutter_test/flutter_test.dart';
import 'package:open_fliqlo/launch_mode.dart';

void main() {
  group('LaunchModeParser', () {
    test('defaults to normal', () {
      expect(LaunchModeParser.fromArgs([]), LaunchMode.normal);
    });

    test('parses screensaver', () {
      expect(
        LaunchModeParser.fromArgs(['--screensaver']),
        LaunchMode.screensaver,
      );
    });

    test('parses lockscreen', () {
      expect(
        LaunchModeParser.fromArgs(['--lockscreen']),
        LaunchMode.lockscreen,
      );
    });

    test('parses configure and preview', () {
      expect(
        LaunchModeParser.fromArgs(['--configure']),
        LaunchMode.configure,
      );
      expect(LaunchModeParser.fromArgs(['--preview']), LaunchMode.preview);
    });

    test('last matching flag wins', () {
      expect(
        LaunchModeParser.fromArgs(['--screensaver', '--configure']),
        LaunchMode.configure,
      );
    });

    test('fromName', () {
      expect(LaunchModeParser.fromName('screensaver'), LaunchMode.screensaver);
      expect(LaunchModeParser.fromName('lockscreen'), LaunchMode.lockscreen);
      expect(LaunchModeParser.fromName('unknown'), LaunchMode.normal);
    });
  });

  group('LaunchModeX', () {
    test('exitOnInput for screensaver and preview only', () {
      expect(LaunchMode.screensaver.exitOnInput, isTrue);
      expect(LaunchMode.preview.exitOnInput, isTrue);
      expect(LaunchMode.lockscreen.exitOnInput, isFalse);
      expect(LaunchMode.normal.exitOnInput, isFalse);
      expect(LaunchMode.lockscreen.isScreensaverLike, isTrue);
      expect(LaunchMode.configure.allowInteractiveGestures, isFalse);
      expect(LaunchMode.normal.allowInteractiveGestures, isTrue);
      expect(LaunchMode.configure.openSettingsOnLaunch, isTrue);
    });
  });
}
