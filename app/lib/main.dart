import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'log.dart';
import 'screens/board_screen.dart';

Future<void> main() async {
  Log.enter('main');

  WidgetsFlutterBinding.ensureInitialized();

  // Landscape and fullscreen. System bars would otherwise take board area and
  // intercept touches near the edges, and an accidental swipe out of the app is
  // exactly the failure a non-verbal child cannot report or recover from.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  Log.step('main', 'landscape locked, immersive mode enabled');

  runApp(const KylesVoiceApp());

  Log.exit('main', 'app started');
}

/// Kyle's Voice: a free, open-source AAC picture-card app with speech output.
///
/// No advertising, no analytics, no accounts, no in-app purchases, and no
/// network dependency for anything on the communication path.
class KylesVoiceApp extends StatelessWidget {
  const KylesVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Kyle's Voice",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E1216),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4FA3D1),
          brightness: Brightness.dark,
        ),
      ),
      home: const BoardScreen(),
    );
  }
}
