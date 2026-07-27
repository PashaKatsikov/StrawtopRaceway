import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/assets.dart';
import '../../data/audio_service.dart';
import '../../data/game_state.dart';
import '../../data/image_bank.dart';
import '../../theme/app_theme.dart';
import '../../screens/main_menu.dart';
import '../core/lane_models.dart';
import '../lane_router.dart';
import 'alert_optin.dart';
import 'offline_pit.dart';
import 'track_portal.dart';

/// Splash + routing point. Visually identical to the game's original loading
/// screen (same artwork, progress bar and labels) while it runs the pit
/// pipeline and pre-warms the game assets, then routes to the game (organic) or
/// the WebView (attributed).
class PitSplash extends StatefulWidget {
  const PitSplash({super.key, required this.router});

  final LaneRouter router;

  @override
  State<PitSplash> createState() => _PitSplashState();
}

class _PitSplashState extends State<PitSplash> {
  double _progress = 0;
  bool _assetsReady = false;
  bool _resolved = false;
  bool _navigated = false;
  LaneStop? _stop;
  Timer? _timer;
  int _dots = 0;
  int _dotAccum = 0;

  @override
  void initState() {
    super.initState();
    // The splash may be shown in either orientation.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepare();
      _resolveLane();
    });
    _timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  Future<void> _prepare() async {
    final started = DateTime.now();
    try {
      await GameState.instance.init();
      await AudioService.instance.init();
      await ImageBank.instance.load(A.effects);
      for (final asset in A.preload) {
        if (!mounted) return;
        try {
          await precacheImage(AssetImage(asset), context);
        } catch (_) {}
      }
    } catch (_) {}
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    if (elapsed < 900) {
      await Future.delayed(Duration(milliseconds: 900 - elapsed));
    }
    _assetsReady = true;
  }

  Future<void> _resolveLane() async {
    try {
      _stop = await widget.router.resolve(onProgress: (_) {});
    } catch (_) {
      _stop = const NativeStop();
    }
    _resolved = true;
  }

  void _tick(Timer t) {
    _dotAccum += 16;
    if (_dotAccum >= 350) {
      _dotAccum = 0;
      _dots = (_dots + 1) % 4;
    }

    final ready = _assetsReady && _resolved;
    final target = ready ? 1.0 : 0.9;
    final step = ready ? 0.035 : 0.0075;
    _progress = math.min(target, _progress + step);

    if (!mounted) return;
    setState(() {});

    if (_progress >= 1.0 && !_navigated) {
      _navigated = true;
      t.cancel();
      _launch();
    }
  }

  Future<void> _launch() async {
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    final stop = _stop ?? const NativeStop();
    switch (stop) {
      case NativeStop():
        await _openGame();
      case OfflineStop():
        _openOffline();
      case PortalStop():
        await _openPortal(stop);
    }
  }

  Future<void> _openGame() async {
    // The game is strictly landscape — matches the original loading handoff.
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, a, _) =>
            FadeTransition(opacity: a, child: const MainMenu()),
      ),
    );
  }

  void _openOffline() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflinePit(
          probe: widget.router.probe,
          retryBuilder: (_) => PitSplash(router: widget.router),
        ),
      ),
    );
  }

  Future<void> _openPortal(PortalStop stop) async {
    final router = widget.router;
    Widget portal(BuildContext _) => TrackPortal(
          url: stop.url,
          coldLaunch: stop.coldLaunch,
          vault: router.vault,
          probe: router.probe,
          pulse: router.pulse,
          agent: router.agent,
        );

    if (router.vault.shouldShowPushInvite &&
        await router.pulse.canOfferPermission()) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AlertOptin(
            vault: router.vault,
            pulse: router.pulse,
            nextBuilder: portal,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute<void>(builder: portal));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final percent = (_progress * 100).round().clamp(0, 100);
    final dots = '.' * _dots;

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            isPortrait ? A.loadingV : A.loadingH,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.bgGradient),
            ),
          ),
          isPortrait
              ? _portraitOverlay(percent, dots)
              : _landscapeOverlay(percent, dots),
        ],
      ),
    );
  }

  Widget _portraitOverlay(int percent, String dots) {
    final w = MediaQuery.of(context).size.width;
    return Align(
      alignment: const Alignment(0, 0.72),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _loadingLabel(28, dots),
            const SizedBox(height: 16),
            _ProgressBar(progress: _progress, width: w * 0.8, height: 26),
            const SizedBox(height: 12),
            _percentLabel(percent, 22),
          ],
        ),
      ),
    );
  }

  Widget _landscapeOverlay(int percent, String dots) {
    final w = MediaQuery.of(context).size.width;
    return Align(
      alignment: const Alignment(0, 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _loadingLabel(22, dots),
          const SizedBox(height: 10),
          _ProgressBar(progress: _progress, width: w * 0.42, height: 18),
          const SizedBox(height: 8),
          _percentLabel(percent, 18),
        ],
      ),
    );
  }

  Widget _loadingLabel(double size, String dots) {
    return SizedBox(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0,
            child: StrokeText('Loading...', style: AppText.title(size)),
          ),
          StrokeText('Loading$dots', style: AppText.title(size)),
        ],
      ),
    );
  }

  Widget _percentLabel(int percent, double size) {
    return StrokeText('$percent%',
        strokeWidth: 3.5,
        style: AppText.title(size, color: AppColors.yellow));
  }
}

/// Left-to-right filling progress bar with a candy gradient and shine —
/// identical to the game's original loading bar.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.width,
    required this.height,
  });

  final double progress;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.yellow, AppColors.red],
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.45,
                  widthFactor: 1,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
