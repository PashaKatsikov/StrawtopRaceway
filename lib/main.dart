import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/audio_service.dart';
import 'theme/app_theme.dart';
import 'screens/loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const StrawtopApp());
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
    // Pause all audio only when the app is truly minimised. IMPORTANT: do NOT
    // treat `inactive` as background – on many Android devices it fires during
    // ordinary in-app navigation / system prompts, which was pausing the music
    // on every screen change and it never came back.
    switch (state) {
      case AppLifecycleState.resumed:
        AudioService.instance.onForeground();
        break;
      case AppLifecycleState.inactive:
        // Transient (navigation, system prompt) – leave audio playing.
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
