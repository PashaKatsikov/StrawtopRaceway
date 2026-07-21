import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/assets.dart';
import '../data/audio_service.dart';
import '../data/game_state.dart';
import '../data/image_bank.dart';
import '../theme/app_theme.dart';
import 'main_menu.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0;
  bool _assetsReady = false;
  bool _navigated = false;
  Timer? _timer;
  int _dots = 0;
  int _dotAccum = 0;

  @override
  void initState() {
    super.initState();
    // The loading screen may be shown in either orientation.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
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
    // Guarantee a minimum on-screen time so the bar animation reads nicely,
    // while never exceeding the 10s budget.
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    if (elapsed < 900) {
      await Future.delayed(Duration(milliseconds: 900 - elapsed));
    }
    _assetsReady = true;
  }

  void _tick(Timer t) {
    // Cycle the "..." roughly 3x per second.
    _dotAccum += 16;
    if (_dotAccum >= 350) {
      _dotAccum = 0;
      _dots = (_dots + 1) % 4;
    }

    // Hold near 90% until real work finishes, then race to 100% and launch.
    final target = _assetsReady ? 1.0 : 0.9;
    final step = _assetsReady ? 0.035 : 0.0075;
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
    // Give the 100% state a brief moment on screen.
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    // The game itself is strictly landscape.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, a, _) => FadeTransition(
          opacity: a,
          child: const MainMenu(),
        ),
      ),
    );
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
            errorBuilder: (_, _, _) =>
                const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.bgGradient)),
          ),
          isPortrait
              ? _portraitOverlay(percent, dots)
              : _landscapeOverlay(percent, dots),
        ],
      ),
    );
  }

  // Portrait: bar sits in the lower third, "Loading" above, percent below.
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

  // Landscape: smaller bar pinned to the bottom, label + percent centered.
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
    // Keep width stable so the text doesn't jitter as dots change.
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

/// Left-to-right filling progress bar with a candy gradient and shine.
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
