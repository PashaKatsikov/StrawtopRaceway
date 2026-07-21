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
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Energy + progress.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _energyBar(),
                        const SizedBox(height: 8),
                        _progressBar(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _coinChip(),
                  const SizedBox(width: 8),
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

  Widget _energyBar() {
    return Row(
      children: [
        Image.asset(A.barSpinning, width: 26, height: 26),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Stack(
              children: [
                Container(height: 16, color: AppColors.ink),
                FractionallySizedBox(
                  widthFactor: (engine.energy / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        engine.energy < 30 ? AppColors.red : AppColors.green,
                        engine.energy < 30 ? AppColors.redDark : AppColors.greenDark,
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _progressBar() {
    return Row(
      children: [
        const Icon(Icons.flag_rounded, color: Colors.white70, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: engine.progress,
              minHeight: 8,
              backgroundColor: Colors.black45,
              valueColor: const AlwaysStoppedAnimation(AppColors.yellow),
            ),
          ),
        ),
      ],
    );
  }

  Widget _coinChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          Image.asset(A.coin, width: 22, height: 22),
          const SizedBox(width: 6),
          Text('${engine.coins}',
              style: AppText.body(15, weight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _pauseButton() {
    return GestureDetector(
      onTap: () => engine.pause(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.panelLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Icon(Icons.pause_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buffRow() {
    final buffs = <Widget>[];
    if (engine.shieldActive) buffs.add(_buffIcon(A.shieldBuff));
    if (engine.boostActive) buffs.add(_buffIcon(A.powerUp));
    if (engine.magnetActive) buffs.add(_buffIcon(A.beckonsBuff));
    if (buffs.isEmpty) return const SizedBox(height: 40);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: buffs,
    );
  }

  Widget _buffIcon(String asset) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Image.asset(asset, width: 34, height: 34),
        ),
      );

  Widget _readyOverlay() {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) {
        if (engine.status != RaceStatus.ready) return const SizedBox.shrink();
        final label = engine.readyCountdown > 0 ? '${engine.readyCountdown}' : 'GO!';
        return Container(
          color: Colors.black.withValues(alpha: 0.35),
          alignment: Alignment.center,
          child: StrokeText(label,
              strokeWidth: 8, style: AppText.title(90, color: AppColors.yellow)),
        );
      },
    );
  }

  Widget _pauseOverlay() {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) {
        if (engine.status != RaceStatus.paused) return const SizedBox.shrink();
        return Container(
          color: Colors.black.withValues(alpha: 0.7),
          alignment: Alignment.center,
          child: Panel(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StrokeText('PAUSED', style: AppText.title(28)),
                const SizedBox(height: 18),
                SizedBox(
                  width: 220,
                  child: ChunkyButton(
                    label: 'RESUME',
                    icon: Icons.play_arrow_rounded,
                    onTap: () => engine.resume(),
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
        );
      },
    );
  }
}
