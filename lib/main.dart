import 'dart:io' show Platform;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/audio_service.dart';
import 'marshal/flag_book.dart';
import 'marshal/link/beacon_call.dart';
import 'marshal/link/intake_feed.dart';
import 'marshal/link/locker.dart';
import 'marshal/link/net_watch.dart';
import 'marshal/link/ping_desk.dart';
import 'marshal/link/wire_client.dart';
import 'marshal/stint_plan.dart';
import 'marshal/trace.dart';
import 'marshal/view/warmup_page.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _pinChrome();

  final locker = Locker();
  final wire = WireClient();
  await Future.wait<void>(<Future<void>>[locker.open(), wire.prime()]);

  final pushLive = FlagBook.ready && await _ignitePush();

  final plan = StintPlan(
    locker: locker,
    watch: NetWatch(),
    intake: IntakeFeed(wire),
    beacon: BeaconCall(wire, locker),
    ping: PingDesk(locker, live: pushLive),
    wire: wire,
    armed: FlagBook.ready,
  );

  runApp(RacewayRoot(plan: plan));
}

/// Firebase and App Check are best-effort: the intake and the beacon still have
/// to run if either of them fails. Only notifications truly need Firebase.
Future<bool> _ignitePush() async {
  try {
    await Firebase.initializeApp();
  } catch (error) {
    gridNote(() => 'mrs:boot firebase unavailable: $error');
    return false;
  }
  try {
    await FirebaseAppCheck.instance.activate(
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (error) {
    gridNote(() => 'mrs:boot app check skipped: $error');
  }
  return true;
}

/// Hide the OS chrome so the game renders fullscreen.
void _pinChrome() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}

class RacewayRoot extends StatefulWidget {
  const RacewayRoot({super.key, required this.plan});

  final StintPlan plan;

  @override
  State<RacewayRoot> createState() => _RacewayRootState();
}

class _RacewayRootState extends State<RacewayRoot> with WidgetsBindingObserver {
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
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        AudioService.instance.onBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: FlagBook.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: WarmupPage(plan: widget.plan),
    );
  }
}
