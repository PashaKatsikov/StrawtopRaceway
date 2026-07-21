import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../data/assets.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/image_bank.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'race_engine.dart';
import 'race_painter.dart';
import 'race_result_screen.dart';

class RaceScreen extends StatefulWidget {
  const RaceScreen({super.key, required this.level, this.eventBonus = false});
  final GameLevel level;
  final bool eventBonus;

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen>
    with SingleTickerProviderStateMixin {
  late final RaceEngine engine = RaceEngine(
    level: widget.level,
    eventBonus: widget.eventBonus,
    background: Catalog.locationById(widget.level.locationId).background,
  );
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _ready = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _prepare();
  }

  Future<void> _prepare() async {
    final skin = Catalog.topById(GameState.instance.equippedTop);
    await ImageBank.instance.loadAll([
      A.directRoad, A.finish, A.pencil, A.eraser, A.springboard,
      A.coin, A.star, A.powerUp, A.shieldBuff, A.beckonsBuff, A.iceBuff,
      A.effects, skin.asset, engine.background,
    ]);
    if (!mounted) return;
    engine.onSound = _onGameSound;
    engine.start();
    engine.addListener(_checkStatus);
    _ticker.start();
    AudioService.instance.playGameMusic();
    setState(() => _ready = true);
  }

  void _onGameSound(RaceSound s) {
    final a = AudioService.instance;
    switch (s) {
      case RaceSound.coin:
        a.coin();
        break;
      case RaceSound.star:
        a.star();
        break;
      case RaceSound.power:
        a.power();
        break;
      case RaceSound.hit:
        a.hit();
        break;
      case RaceSound.go:
        a.go();
        break;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    engine.update(dt);
  }

  void _checkStatus() {
    if (_handled) return;
    if (engine.status == RaceStatus.finished ||
        engine.status == RaceStatus.failed) {
      _handled = true;
      _ticker.stop();
      _finish();
    }
  }

  void _finish() {
    final finished = engine.status == RaceStatus.finished;
    if (finished) {
      AudioService.instance.win();
    } else {
      AudioService.instance.lose();
    }
    final stars = engine.computeStars();
    final reward = finished ? engine.coinReward() : engine.coins;
    GameState.instance.recordRace(
      levelId: widget.level.id,
      finished: finished,
      stars: stars,
      coinsCollected: reward,
      score: engine.computeScore(),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RaceResultScreen(
          level: widget.level,
          finished: finished,
          stars: stars,
          coins: reward,
          score: engine.computeScore(),
          eventBonus: widget.eventBonus,
        ),
      ),
    );
  }

  @override
  void dispose() {
    engine.removeListener(_checkStatus);
    _ticker.dispose();
    engine.dispose();
    // Hand music back to the menu track when leaving gameplay.
    AudioService.instance.playMenuMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.navyDeep,
        body: Center(child: CircularProgressIndicator(color: AppColors.yellow)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => engine.setTargetX(d.localPosition.dx),
        onPanUpdate: (d) => engine.setTargetX(d.localPosition.dx),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: RacePainter(engine),
                isComplex: true,
                willChange: true,
                size: Size.infinite,
              ),
            ),
            _hud(),
            _readyOverlay(),
            _pauseOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _hud() {
    return SafeArea(
      child: AnimatedBuilder(
        animation: engine,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            children: [
              // ── compact top bar ──────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left pill: energy + progress stacked
                  Expanded(child: _barPill()),
                  const SizedBox(width: 8),
                  _coinChip(),
                  const SizedBox(width: 6),
                  _pauseButton(),
                ],
              ),
              const Spacer(),
              _buffRow(),
            ],
          ),
        ),
      ),
    );
  }

  /// Reusable glassy pill decoration used across the HUD.
  BoxDecoration _glassPill({Color? accent}) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.ink.withValues(alpha: 0.62),
            AppColors.navy.withValues(alpha: 0.58),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: (accent ?? Colors.white).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (accent ?? Colors.black).withValues(alpha: 0.28),
            blurRadius: 12,
            spreadRadius: -3,
            offset: const Offset(0, 3),
          ),
        ],
      );

  /// Single glassy pill containing the two compact bars.
  Widget _barPill() {
    final energyColor =
        engine.energy < 30 ? AppColors.red : AppColors.green;
    final energyColorDark =
        engine.energy < 30 ? AppColors.redDark : AppColors.greenDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: _glassPill(
          accent: engine.energy < 30 ? AppColors.red : AppColors.green),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Energy row
          Row(
            children: [
              Image.asset(A.barSpinning, width: 16, height: 16),
              const SizedBox(width: 5),
              Expanded(child: _thinBar(
                value: (engine.energy / 100).clamp(0.0, 1.0),
                fill: LinearGradient(colors: [energyColor, energyColorDark]),
                h: 8,
              )),
              const SizedBox(width: 5),
              SizedBox(
                width: 28,
                child: Text(
                  '${engine.energy.round()}',
                  style: AppText.body(9,
                      weight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.85)),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Progress row
          Row(
            children: [
              const Icon(Icons.flag_rounded,
                  color: Colors.white60, size: 14),
              const SizedBox(width: 5),
              Expanded(child: _thinBar(
                value: engine.progress,
                fill: const LinearGradient(
                    colors: [AppColors.yellow, AppColors.yellowDark]),
                h: 6,
              )),
              const SizedBox(width: 5),
              SizedBox(
                width: 28,
                child: Text(
                  '${(engine.progress * 100).round()}%',
                  style: AppText.body(9,
                      weight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.85)),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thinBar({
    required double value,
    required Gradient fill,
    required double h,
  }) {
    final glowColor = (fill is LinearGradient && fill.colors.isNotEmpty)
        ? fill.colors.first
        : Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Stack(
        children: [
          Container(height: h, color: Colors.white.withValues(alpha: 0.12)),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: h,
              decoration: BoxDecoration(
                gradient: fill,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.55),
                    blurRadius: 6,
                    spreadRadius: -1,
                  ),
                ],
              ),
            ),
          ),
          // Glossy top highlight along the whole track.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: h * 0.45,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coinChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: _glassPill(accent: AppColors.yellow),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(A.coin, width: 18, height: 18),
          const SizedBox(width: 4),
          Text('${engine.coins}',
              style: AppText.body(13, weight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _pauseButton() {
    return GestureDetector(
      onTap: () => engine.pause(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.panelLight, AppColors.panel],
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.glassHi, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.pause_rounded, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buffRow() {
    final buffs = <Widget>[];
    if (engine.shieldActive) buffs.add(_buffIcon(A.shieldBuff, AppColors.blue));
    if (engine.boostActive) buffs.add(_buffIcon(A.powerUp, AppColors.yellow));
    if (engine.magnetActive) buffs.add(_buffIcon(A.beckonsBuff, AppColors.pink));
    if (buffs.isEmpty) return const SizedBox(height: 32);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: buffs,
    );
  }

  Widget _buffIcon(String asset, Color accent) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                accent.withValues(alpha: 0.5),
                AppColors.ink.withValues(alpha: 0.6),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.55),
                blurRadius: 12,
                spreadRadius: -1,
              ),
            ],
          ),
          child: Image.asset(asset, width: 26, height: 26),
        ),
      );

  Widget _readyOverlay() {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) {
        if (engine.status != RaceStatus.ready) return const SizedBox.shrink();
        final go = engine.readyCountdown <= 0;
        final label = go ? 'GO!' : '${engine.readyCountdown}';
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              radius: 0.9,
              colors: [Color(0x66000000), Color(0xB3000000)],
            ),
          ),
          alignment: Alignment.center,
          // Each value gets a fresh key so it pops in with a scale bounce.
          child: TweenAnimationBuilder<double>(
            key: ValueKey(label),
            tween: Tween(begin: 0.4, end: 1.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.elasticOut,
            builder: (_, v, child) =>
                Transform.scale(scale: v, child: child),
            child: GradientText(
              label,
              strokeWidth: 9,
              style: AppText.title(96),
              gradient:
                  go ? AppColors.greenGradient : AppColors.goldGradient,
            ),
          ),
        );
      },
    );
  }

  Widget _pauseOverlay() {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) {
        if (engine.status != RaceStatus.paused) return const SizedBox.shrink();
        // Frosted glass over the frozen game frame.
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
            alignment: Alignment.center,
            child: Panel(
              padding: const EdgeInsets.all(26),
              glow: AppColors.purple,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GradientText('PAUSED',
                      style: AppText.title(30),
                      gradient: AppColors.sunsetGradient,
                      strokeWidth: 5),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 220,
                    child: PulseGlow(
                      color: AppColors.green,
                      child: ChunkyButton(
                        label: 'RESUME',
                        icon: Icons.play_arrow_rounded,
                        onTap: () => engine.resume(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 220,
                    child: ChunkyButton(
                      label: 'QUIT',
                      gradient: AppColors.redGradient,
                      lip: AppColors.redDark,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
