import 'package:fliqlo_ui/fliqlo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'clock_screen.dart';
import 'platform_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PlatformShell.initialize();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const OpenFliqloApp());
}

class OpenFliqloApp extends StatelessWidget {
  const OpenFliqloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Fliqlo',
      debugShowCheckedModeBanner: false,
      theme: FliqloTheme.material(),
      home: const ClockScreen(),
    );
  }
}
