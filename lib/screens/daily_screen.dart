import 'package:flutter/material.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
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
        overlay: 0.4,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: gs,
            builder: (context, _) => Column(
              children: [
                TopBar(
                    title: 'Daily Challenges',
                    onBack: () => Navigator.pop(context)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Panel(
                    padding: const EdgeInsets.all(12),
                    gradient: const LinearGradient(
                        colors: [AppColors.purple, AppColors.blueDark]),
                    child: Row(
                      children: [
                        const Icon(Icons.refresh_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'New challenges every day. Play races to complete them!',
                            style: AppText.body(12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: Catalog.dailyPool.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _card(Catalog.dailyPool[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(DailyChallenge c) {
    final progress = gs.dailyProgressFor(c);
    final done = gs.isDailyComplete(c);
    final claimed = gs.isDailyClaimed(c);
    return Panel(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(c.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title,
                    style: AppText.body(15, weight: FontWeight.w800)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress / c.goal,
                    minHeight: 8,
                    backgroundColor: Colors.black38,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.green),
                  ),
                ),
                const SizedBox(height: 4),
                Text('$progress / ${c.goal}',
                    style: AppText.body(11, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      color: AppColors.yellow, size: 16),
                  const SizedBox(width: 4),
                  Text('${c.rewardCoins}',
                      style: AppText.body(13, weight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 96,
                child: ChunkyButton(
                  label: claimed ? 'DONE' : 'CLAIM',
                  height: 34,
                  fontSize: 13,
                  enabled: done && !claimed,
                  gradient: AppColors.greenGradient,
                  onTap: () {
                    if (gs.claimDaily(c)) {
                      showToast(context, '+${c.rewardCoins} coins!');
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
