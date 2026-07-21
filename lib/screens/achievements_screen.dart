import 'package:flutter/material.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final gs = GameState.instance;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playMenuMusic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        overlay: 0.42,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: gs,
            builder: (context, _) => Column(
              children: [
                TopBar(title: 'Achievements', onBack: () => Navigator.pop(context)),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: Catalog.achievements.length,
                    itemBuilder: (_, i) => _card(Catalog.achievements[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Achievement a) {
    final progress = gs.achievementProgress(a).clamp(0, a.goal);
    final done = gs.isAchievementComplete(a);
    final claimed = gs.isAchievementClaimed(a);
    return Panel(
      padding: const EdgeInsets.all(12),
      borderColor: done ? AppColors.yellow.withValues(alpha: 0.7) : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient:
                  done ? AppColors.goldGradient : null,
              color: done ? null : AppColors.ink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              done ? Icons.emoji_events_rounded : Icons.lock_rounded,
              color: done ? Colors.white : Colors.white38,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: AppText.body(14, weight: FontWeight.w800)),
                Text(a.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(10, color: AppColors.textMuted)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress / a.goal,
                    minHeight: 6,
                    backgroundColor: Colors.black38,
                    valueColor: const AlwaysStoppedAnimation(AppColors.green),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('$progress/${a.goal}',
                        style: AppText.body(10, color: AppColors.textMuted)),
                    const Spacer(),
                    if (claimed)
                      const Text('Claimed',
                          style: TextStyle(
                              color: AppColors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w800))
                    else if (done)
                      GestureDetector(
                        onTap: () {
                          if (gs.claimAchievement(a)) {
                            showToast(context, '+${a.rewardGems} gems!');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppColors.greenGradient,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text('Claim +${a.rewardGems}\uD83D\uDC8E',
                              style:
                                  AppText.body(11, weight: FontWeight.w800)),
                        ),
                      )
                    else
                      Text('+${a.rewardGems}\uD83D\uDC8E',
                          style: AppText.body(11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
