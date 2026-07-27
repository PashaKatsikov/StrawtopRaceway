import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import 'data/audio_service.dart';
import 'theme/app_theme.dart';
import 'pitwall/config/track_config.dart';
import 'pitwall/infra/config_relay.dart';
import 'pitwall/infra/pit_agent.dart';
import 'pitwall/infra/pit_vault.dart';
import 'pitwall/infra/pulse_hub.dart';
import 'pitwall/infra/reach_probe.dart';
import 'pitwall/infra/track_attribution.dart';
import 'pitwall/lane_router.dart';
import 'pitwall/pages/pit_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureSystemChrome();

  final vault = PitVault();
  final agent = PitAgent();
  await Future.wait<void>(<Future<void>>[
    vault.initialize(),
    agent.warmUp(),
  ]);

  // Firebase + App Check are best-effort: attribution and the config POST must
  // still run if either fails. Only push (FCM) needs Firebase to be ready.
  var pushServicesReady = false;
  if (TrackConfig.grayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      pushServicesReady = true;
    } catch (error) {
      assert(() {
        debugPrint('[STW.BOOT] Firebase.initializeApp failed: $error');
        return true;
      }());
    }
    if (pushServicesReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (error) {
        assert(() {
          debugPrint('[STW.BOOT] AppCheck skipped: $error');
          return true;
        }());
      }
    }
  }

  final probe = ReachProbe();
  final pulse = PulseHub(vault, enabled: pushServicesReady);
  final attribution = TrackAttribution(agent);
  final router = LaneRouter(
    vault: vault,
    probe: probe,
    attribution: attribution,
    relay: ConfigRelay(agent, vault),
    pulse: pulse,
    agent: agent,
    runtimeEnabled: TrackConfig.grayCredentialsReady,
  );

  runApp(StrawtopApp(router: router));
}

/// Hide OS chrome so the game renders fullscreen (unchanged behaviour).
void _configureSystemChrome() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
}

class StrawtopApp extends StatefulWidget {
  const StrawtopApp({super.key, required this.router});

  final LaneRouter router;

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
    switch (state) {
      case AppLifecycleState.resumed:
        AudioService.instance.onForeground();
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
        break;
      case AppLifecycleState.inactive:
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
      home: PitSplash(router: widget.router),
    );
  }
}
