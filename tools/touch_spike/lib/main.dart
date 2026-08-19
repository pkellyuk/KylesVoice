import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'log.dart';
import 'screens/capture_screen.dart';

Future<void> main() async {
  Log.enter('main');

  WidgetsFlutterBinding.ensureInitialized();

  // Landscape and fullscreen: the target device is a tablet held landscape, and
  // system bars would otherwise eat capture area and intercept edge touches,
  // which is exactly where mis-hits are most interesting.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  Log.step('main', 'orientation locked to landscape, immersive mode enabled');

  runApp(const TouchSpikeApp());

  Log.exit('main', 'app started');
}

/// Touch-geometry logger for the Kyle's Voice palm-mode spike.
///
/// This is a throwaway diagnostic, not a product. Its only job is to answer
/// one question on real hardware: does the device report contact geometry that
/// varies meaningfully between a fingertip point and an open-palm slap?
class TouchSpikeApp extends StatelessWidget {
  const TouchSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Touch Spike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4FC3F7),
          brightness: Brightness.dark,
        ),
      ),
      home: const CaptureScreen(),
    );
  }
}
