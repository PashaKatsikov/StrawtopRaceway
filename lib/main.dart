import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/audio_service.dart';
import 'theme/app_theme.dart';
import 'screens/loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _configureSystemChrome();
  runApp(const StrawtopApp());
}

/// Hide OS chrome (status / navigation bar) so the game renders fullscreen.
///
/// * Android – `immersiveSticky` hides both the status bar and the nav-gesture
///   pill, and reveals them briefly on an edge swipe.
/// * iOS – the same call maps to hiding the status bar via
///   `setSystemUIOverlays([])`, and the `UIStatusBarHidden=true` /
///   `UIViewControllerBasedStatusBarAppearance=false` keys in `Info.plist`
///   make sure it stays hidden across scene transitions.
void _configureSystemChrome() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // A dark transparent status/nav bar so any tiny fringe during transitions
  // blends with the game's dark background.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
}

class StrawtopApp extends StatefulWidget {
  const StrawtopApp({super.key});

  @override
  State<StrawtopApp> createState() => _StrawtopAppState();
}

class _StrawtopAppState extends State<StrawtopApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause background music only when the app is genuinely minimised.
    //
    // Do NOT treat `inactive` as background – on both Android and iOS this
    // state fires during transient events (in-app navigation, control
    // centre pull-down, incoming call banner, system permission prompts).
    // Reacting to it caused music to pause on every screen change and never
    // resume.
    switch (state) {
      case AppLifecycleState.resumed:
        AudioService.instance.onForeground();
        // Re-assert immersive fullscreen after the OS restored us: on Android
        // the nav bar sometimes lingers, and on iOS returning from control
        // centre briefly re-shows the status bar.
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
        break;
      case AppLifecycleState.inactive:
        // Transient – leave audio playing.
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        AudioService.instance.onBackground();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Strawtop Raceway',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const LoadingScreen(),
    );
  }
}
