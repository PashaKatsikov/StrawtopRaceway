import 'package:flutter/material.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../game/race_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key, required this.location});
  final GameLocation location;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final gs = GameState.instance;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playMenuMusic();
  }

  @override
  Widget build(BuildContext context) {
    final levels = Catalog.levelsFor(widget.location.id);
    return Scaffold(
      body: GameBackground(
        image: widget.location.background,
        overlay: 0.62,
        child: SafeArea(
          child: Column(
            children: [
              TopBar(
                  title: widget.location.name,
                  onBack: () => Navigator.pop(context)),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.55,
                  ),
                  itemCount: levels.length,
                  itemBuilder: (_, i) => _levelCard(levels[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelCard(GameLevel level) {
    final unlocked = gs.isLevelUnlocked(level);
    final stars = gs.starsFor(level.id);
    return GestureDetector(
      onTap: () {
        AudioService.instance.click();
        if (!unlocked) {
          showToast(context, 'Complete the previous race first', good: false);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RaceScreen(level: level)),
        ).then((_) => setState(() {}));
      },
      child: Panel(
        gradient: unlocked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.location.color.withValues(alpha: 0.85),
                  AppColors.panel,
                ],
              )
            : null,
        color: AppColors.panel.withValues(alpha: 0.7),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: StrokeText('${level.index + 1}',
                          strokeWidth: 3, style: AppText.title(18)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(level.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(13, weight: FontWeight.w800)),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    _diffDots(level.difficulty),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on_rounded,
                            color: AppColors.yellow, size: 14),
                        const SizedBox(width: 3),
                        Text('${level.coinReward}',
                            style: AppText.body(11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(child: StarsRow(count: stars, size: 20)),
              ],
            ),
            if (!unlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Colors.white70, size: 30),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _diffDots(int diff) {
    return Row(
      children: List.generate(
        5,
        (i) => Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < diff ? AppColors.red : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }
}
