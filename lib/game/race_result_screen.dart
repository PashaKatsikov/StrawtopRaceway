import 'package:flutter/material.dart';
import '../data/assets.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'race_screen.dart';

class RaceResultScreen extends StatefulWidget {
  const RaceResultScreen({
    super.key,
    required this.level,
    required this.finished,
    required this.stars,
    required this.coins,
    required this.score,
    required this.eventBonus,
  });

  final GameLevel level;
  final bool finished;
  final int stars;
  final int coins;
  final int score;
  final bool eventBonus;

  @override
  State<RaceResultScreen> createState() => _RaceResultScreenState();
}

class _RaceResultScreenState extends State<RaceResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  int _gemBonus = 0;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playMenuMusic();
    if (widget.finished && widget.eventBonus) {
      _gemBonus = 15;
      GameState.instance.addGems(_gemBonus);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  GameLevel? _nextLevel() {
    final next = '${widget.level.locationId}_${widget.level.index + 1}';
    try {
      final lvl = Catalog.levelById(next);
      return lvl;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Catalog.locationById(widget.level.locationId);
    final next = _nextLevel();
    return Scaffold(
      body: GameBackground(
        image: loc.background,
        overlay: 0.66,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Panel(
                padding: const EdgeInsets.all(20),
                glow: widget.finished ? AppColors.yellow : AppColors.red,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: widget.finished
                      ? [AppColors.navyLight, AppColors.navy]
                      : [AppColors.redDark, AppColors.navy],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GradientText(
                      widget.finished ? 'FINISH!' : 'CRASHED!',
                      strokeWidth: 6,
                      style: AppText.title(36),
                      gradient: widget.finished
                          ? AppColors.goldGradient
                          : AppColors.redGradient,
                    ),
                    const SizedBox(height: 4),
                    Text(widget.level.name,
                        style: AppText.body(14, color: AppColors.textMuted)),
                    const SizedBox(height: 14),
                    if (widget.finished) _stars() else _sadTop(),
                    const SizedBox(height: 16),
                    _rewardRow(),
                    const SizedBox(height: 20),
                    _buttons(next),
                  ],
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final anim = CurvedAnimation(
          parent: _c,
          curve: Interval((i * 0.25).clamp(0.0, 1.0), 1.0,
              curve: Curves.elasticOut),
        );
        final filled = i < widget.stars;
        return ScaleTransition(
          scale: anim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              decoration: filled
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.yellow.withValues(alpha: 0.6),
                          blurRadius: 18,
                          spreadRadius: -2,
                        ),
                      ],
                    )
                  : null,
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 64,
                color: filled ? AppColors.yellow : Colors.white24,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _sadTop() {
    return const Icon(Icons.sentiment_dissatisfied_rounded,
        size: 64, color: Colors.white54);
  }

  Widget _rewardRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _reward(A.coin, '+${widget.coins}'),
        const SizedBox(width: 20),
        _reward(A.star, '${widget.score}', label: 'score'),
        if (_gemBonus > 0) ...[
          const SizedBox(width: 20),
          _reward(A.iceBuff, '+$_gemBonus'),
        ],
      ],
    );
  }

  Widget _reward(String asset, String value, {String? label}) {
    return Column(
      children: [
        Image.asset(asset, width: 40, height: 40),
        const SizedBox(height: 2),
        Text(value, style: AppText.body(16, weight: FontWeight.w900)),
        if (label != null)
          Text(label, style: AppText.body(10, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _buttons(GameLevel? next) {
    final gs = GameState.instance;
    final canNext = widget.finished && next != null && gs.isLevelUnlocked(next);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _smallBtn(Icons.home_rounded, AppColors.blueGradient, () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }),
        const SizedBox(width: 12),
        _smallBtn(Icons.replay_rounded, AppColors.goldGradient, () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RaceScreen(level: widget.level, eventBonus: widget.eventBonus),
            ),
          );
        }),
        if (canNext) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: PulseGlow(
              color: AppColors.green,
              child: ChunkyButton(
                label: 'NEXT',
                icon: Icons.arrow_forward_rounded,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RaceScreen(level: next),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _smallBtn(IconData icon, Gradient gradient, VoidCallback onTap) {
    final glow = (gradient as LinearGradient).colors.first;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: -3,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
