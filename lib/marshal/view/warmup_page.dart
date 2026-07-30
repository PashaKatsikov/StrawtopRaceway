import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/assets.dart';
import '../../data/audio_service.dart';
import '../../data/game_state.dart';
import '../../data/image_bank.dart';
import '../../screens/main_menu.dart';
import '../../theme/app_theme.dart';
import '../stint_plan.dart';
import '../stint_types.dart';
import 'board_page.dart';
import 'dark_page.dart';
import 'ping_page.dart';

/// Loading screen and hand-off point. Looks exactly like the game's own
/// loading screen (same artwork, bar and labels) while it pre-warms the game
/// assets and walks the plan, then hands off to the game or the board view.
class WarmupPage extends StatefulWidget {
  const WarmupPage({super.key, required this.plan});

  final StintPlan plan;

  @override
  State<WarmupPage> createState() => _WarmupPageState();
}

class _WarmupPageState extends State<WarmupPage> {
  static const Duration _frameGap = Duration(milliseconds: 16);
  static const int _dotPeriodMs = 420;
  static const int _floorMs = 840;
  static const double _idleStep = 0.008;
  static const double _finalStep = 0.04;
  static const double _idleCeiling = 0.9;

  Timer? _ticker;
  StintExit? _exit;
  double _fill = 0;
  int _dots = 0;
  int _dotClock = 0;
  bool _assetsWarm = false;
  bool _planKnown = false;
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    // This screen may be shown in either orientation.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmAssets();
      _askPlan();
    });
    _ticker = Timer.periodic(_frameGap, _frame);
  }

  Future<void> _warmAssets() async {
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
    final spent = DateTime.now().difference(started).inMilliseconds;
    if (spent < _floorMs) {
      await Future<void>.delayed(Duration(milliseconds: _floorMs - spent));
    }
    _assetsWarm = true;
  }

  Future<void> _askPlan() async {
    try {
      _exit = await widget.plan.decide();
    } catch (_) {
      _exit = const GarageExit();
    }
    _planKnown = true;
  }

  void _frame(Timer ticker) {
    _dotClock += _frameGap.inMilliseconds;
    if (_dotClock >= _dotPeriodMs) {
      _dotClock = 0;
      _dots = (_dots + 1) % 4;
    }

    final settled = _assetsWarm && _planKnown;
    _fill = math.min(
      settled ? 1.0 : _idleCeiling,
      _fill + (settled ? _finalStep : _idleStep),
    );

    if (!mounted) return;
    setState(() {});

    if (_fill >= 1.0 && !_handedOff) {
      _handedOff = true;
      ticker.cancel();
      _handOff();
    }
  }

  Future<void> _handOff() async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    switch (_exit ?? const GarageExit()) {
      case GarageExit():
        await _toGarage();
      case DarkExit():
        _toDark();
      case BoardExit(:final url, :final fromCold):
        await _toBoard(url, fromCold);
    }
  }

  Future<void> _toGarage() async {
    // The game is landscape-only — same hand-off the original loader did.
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, _) =>
            FadeTransition(opacity: animation, child: const MainMenu()),
      ),
    );
  }

  void _toDark() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DarkPage(
          watch: widget.plan.watch,
          again: (_) => WarmupPage(plan: widget.plan),
        ),
      ),
    );
  }

  Future<void> _toBoard(String url, bool fromCold) async {
    final plan = widget.plan;
    Widget board(BuildContext _) => BoardPage(
      url: url,
      fromCold: fromCold,
      locker: plan.locker,
      watch: plan.watch,
      desk: plan.ping,
      wire: plan.wire,
    );

    final offerPing =
        plan.locker.mayOfferPing && await plan.ping.mayAskConsent();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: offerPing
            ? (_) => PingPage(
                locker: plan.locker,
                desk: plan.ping,
                next: board,
              )
            : board,
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tall = MediaQuery.of(context).orientation == Orientation.portrait;
    final percent = (_fill * 100).round().clamp(0, 100);
    final dots = '.' * _dots;

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            tall ? A.loadingV : A.loadingH,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.bgGradient),
            ),
          ),
          tall ? _tallOverlay(percent, dots) : _wideOverlay(percent, dots),
        ],
      ),
    );
  }

  Widget _tallOverlay(int percent, String dots) {
    final width = MediaQuery.of(context).size.width;
    return Align(
      alignment: const Alignment(0, 0.72),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _caption(28, dots),
            const SizedBox(height: 16),
            _FillBar(fill: _fill, width: width * 0.8, height: 26),
            const SizedBox(height: 12),
            _readout(percent, 22),
          ],
        ),
      ),
    );
  }

  Widget _wideOverlay(int percent, String dots) {
    final width = MediaQuery.of(context).size.width;
    return Align(
      alignment: const Alignment(0, 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _caption(22, dots),
          const SizedBox(height: 10),
          _FillBar(fill: _fill, width: width * 0.42, height: 18),
          const SizedBox(height: 8),
          _readout(percent, 18),
        ],
      ),
    );
  }

  /// The invisible full-width copy keeps the label from shifting as the dots
  /// come and go.
  Widget _caption(double size, String dots) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Opacity(
          opacity: 0,
          child: StrokeText('Loading...', style: AppText.title(size)),
        ),
        StrokeText('Loading$dots', style: AppText.title(size)),
      ],
    );
  }

  Widget _readout(int percent, double size) => StrokeText(
    '$percent%',
    strokeWidth: 3.5,
    style: AppText.title(size, color: AppColors.yellow),
  );
}

/// Left-to-right bar with the game's candy gradient and shine.
class _FillBar extends StatelessWidget {
  const _FillBar({
    required this.fill,
    required this.width,
    required this.height,
  });

  final double fill;
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
        boxShadow: <BoxShadow>[
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
            widthFactor: fill.clamp(0.0, 1.0),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[AppColors.yellow, AppColors.red],
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.45,
                  widthFactor: 1,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
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
