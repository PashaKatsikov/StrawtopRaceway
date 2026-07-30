import 'package:flutter/material.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/racer_avatar.dart';
import '../widgets/ui_kit.dart';
import 'avatar_photo_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AudioService.instance.playMenuMusic();
    final gs = GameState.instance;
    return Scaffold(
      body: GameBackground(
        overlay: 0.45,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: gs,
            builder: (context, _) {
              final skin = Catalog.topById(gs.equippedTop);
              return Column(
                children: [
                  TopBar(title: 'Profile', onBack: () => Navigator.pop(context)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Panel(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // Scale the avatar and top sprite down when
                                  // the available height is tight so the panel
                                  // content always fits without overflowing.
                                  final availH = constraints.maxHeight;
                                  final avatarSize = availH < 360 ? 72.0 : 96.0;
                                  final topSize   = availH < 360 ? 52.0 : 70.0;
                                  return SingleChildScrollView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          RacerAvatar(
                                            size: avatarSize,
                                            showBadge: true,
                                            onTap: () async {
                                              AudioService.instance.click();
                                              await AvatarPhotoSheet.present(
                                                  context);
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          StrokeText(gs.playerName,
                                              style: AppText.title(20)),
                                          Container(
                                            margin: const EdgeInsets.only(top: 6),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 4),
                                            decoration: BoxDecoration(
                                              gradient: AppColors.goldGradient,
                                              borderRadius: BorderRadius.circular(
                                                  AppRadius.pill),
                                            ),
                                            child: Text(
                                              'LEVEL ${gs.playerLevel}',
                                              style: AppText.body(13,
                                                  weight: FontWeight.w900,
                                                  color: AppColors.ink),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          TopSprite(skin: skin, size: topSize),
                                          Text(skin.name,
                                              style: AppText.body(13,
                                                  color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                Expanded(
                                  child: GridView.count(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 2.4,
                                    children: [
                                      _stat('Races', '${gs.totalRaces}',
                                          Icons.sports_score_rounded, AppColors.blue),
                                      _stat('Wins', '${gs.totalWins}',
                                          Icons.emoji_events_rounded, AppColors.yellow),
                                      _stat('Stars', '${gs.totalStars}',
                                          Icons.star_rounded, AppColors.yellowDark),
                                      _stat('Coins Earned',
                                          '${gs.totalCoinsCollected}',
                                          Icons.monetization_on_rounded, AppColors.green),
                                      _stat('Tops Owned', '${gs.ownedTopsCount}',
                                          Icons.category_rounded, AppColors.purple),
                                      _stat('Levels Done',
                                          '${gs.levelStars.length}/${Catalog.totalLevels}',
                                          Icons.flag_rounded, AppColors.red),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: AppText.title(18)),
              Text(label,
                  style: AppText.body(11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
