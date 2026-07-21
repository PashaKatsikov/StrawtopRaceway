import 'package:flutter/material.dart';
import '../data/assets.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../game/race_screen.dart';

/// Weekly event: a rotating featured track with a bonus reward.
class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  final gs = GameState.instance;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playMenuMusic();
  }

  @override
  Widget build(BuildContext context) {
    // Pick a "featured" level deterministically from the week number.
    final week = DateTime.now().difference(DateTime(2026)).inDays ~/ 7;
    final level = Catalog.levels[week % Catalog.levels.length];
    final loc = Catalog.locationById(level.locationId);
    final daysLeft = 7 - (DateTime.now().weekday % 7);

    return Scaffold(
      body: GameBackground(
        image: loc.background,
        overlay: 0.6,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: gs,
            builder: (context, _) => Column(
              children: [
                TopBar(
                    title: 'Weekly Event',
                    onBack: () => Navigator.pop(context)),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Panel(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.purple, AppColors.navy],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(A.finish, height: 48),
                                const SizedBox(width: 10),
                                StrokeText('CHAMPIONS CUP',
                                    style: AppText.title(24,
                                        color: AppColors.yellow)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Featured: ${loc.name} \u2022 ${level.name}',
                                style: AppText.body(14,
                                    color: AppColors.textLight)),
                            const SizedBox(height: 4),
                            Text('Ends in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                                style: AppText.body(12,
                                    color: AppColors.textMuted)),
                            const SizedBox(height: 16),
                            _rewardRow(),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: 240,
                              child: ChunkyButton(
                                label: 'ENTER RACE',
                                icon: Icons.emoji_events_rounded,
                                gradient: AppColors.goldGradient,
                                lip: AppColors.yellowDark,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RaceScreen(
                                          level: level, eventBonus: true),
                                    ),
                                  ).then((_) => setState(() {}));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rewardRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _reward(A.coin, '2x Coins'),
        const SizedBox(width: 24),
        _reward(A.iceBuff, '+15 Gems'),
      ],
    );
  }

  Widget _reward(String asset, String label) {
    return Column(
      children: [
        Image.asset(asset, width: 48, height: 48),
        const SizedBox(height: 4),
        Text(label, style: AppText.body(12, weight: FontWeight.w800)),
      ],
    );
  }
}
