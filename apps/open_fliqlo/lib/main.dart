import 'package:fliqlo_ui/fliqlo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'clock_screen.dart';
import 'launch_mode.dart';
import 'platform_shell.dart';

/// Global launch mode set in [main] before [runApp].
LaunchMode appLaunchMode = LaunchMode.normal;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  appLaunchMode = LaunchModeParser.fromArgs(args);

  // Android Dream / configure can pass mode via dartEntrypointArguments.
  // When args are empty, also check --dart-define LAUNCH_MODE.
  const defineMode = String.fromEnvironment('LAUNCH_MODE');
  if (args.isEmpty && defineMode.isNotEmpty) {
    appLaunchMode = LaunchModeParser.fromName(defineMode);
  }

  await PlatformShell.initialize(appLaunchMode);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(OpenFliqloApp(mode: appLaunchMode));
}

class OpenFliqloApp extends StatelessWidget {
  const OpenFliqloApp({super.key, this.mode = LaunchMode.normal});

  final LaunchMode mode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Fliqlo',
      debugShowCheckedModeBanner: false,
      theme: FliqloTheme.material(),
      builder: (context, child) {
        if (mode.isScreensaverLike) {
          return MouseRegion(
            cursor: SystemMouseCursors.none,
            child: child ?? const SizedBox.shrink(),
          );
        }
        return child ?? const SizedBox.shrink();
      },
      home: ClockScreen(mode: mode),
    );
  }
}
