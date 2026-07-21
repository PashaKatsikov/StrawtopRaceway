import 'package:flutter/material.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'level_select_screen.dart';

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  final gs = GameState.instance;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playMenuMusic();
  }

  int _locationStars(GameLocation loc) {
    int total = 0;
    for (final lvl in Catalog.levelsFor(loc.id)) {
      total += gs.starsFor(lvl.id);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        overlay: 0.4,
        child: SafeArea(
          child: Column(
            children: [
              TopBar(title: 'Choose World', onBack: () => Navigator.pop(context)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: Catalog.locations
                        .map((loc) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: _locationCard(loc),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationCard(GameLocation loc) {
    final unlocked = gs.isLocationUnlocked(loc);
    final maxStars = loc.levelCount * 3;
    final stars = _locationStars(loc);
    return GestureDetector(
      onTap: () {
        AudioService.instance.click();
        if (!unlocked) {
          showToast(context, 'Reach ${loc.starGate} stars to unlock', good: false);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LevelSelectScreen(location: loc)),
        ).then((_) => setState(() {}));
      },
      child: Panel(
        padding: EdgeInsets.zero,
        borderColor: loc.color.withValues(alpha: 0.8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg - 2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(loc.background, fit: BoxFit.cover),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(loc.icon, height: 74),
                    const Spacer(),
                    StrokeText(loc.name, style: AppText.title(18)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.yellow, size: 18),
                        const SizedBox(width: 4),
                        Text('$stars / $maxStars',
                            style: AppText.body(13, weight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: maxStars == 0 ? 0 : stars / maxStars,
                        minHeight: 7,
                        backgroundColor: Colors.black45,
                        valueColor: AlwaysStoppedAnimation(loc.color),
                      ),
                    ),
                  ],
                ),
              ),
              if (!unlocked)
                Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded, color: Colors.white, size: 40),
                      const SizedBox(height: 8),
                      Text('${loc.starGate}\u2605 to unlock',
                          style: AppText.body(14, weight: FontWeight.w800)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
