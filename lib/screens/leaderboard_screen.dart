import 'package:flutter/material.dart';
import '../data/audio_service.dart';
import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  static const List<String> _bots = [
    'CluckKing', 'TurboTina', 'BeakMax', 'WingWizz', 'EggGus',
    'AceOfEggs', 'ZippyZoe', 'RoosterRon', 'NovaNina', 'CluckNorris',
    'CometCleo', 'DizzyDan',
  ];

  @override
  Widget build(BuildContext context) {
    AudioService.instance.playMenuMusic();
    final gs = GameState.instance;
    final rating = gs.totalStars * 100 + gs.totalWins * 60 + gs.coins ~/ 8;

    // Deterministic bot ratings around the player's, so ranking feels alive.
    final entries = <_Entry>[];
    for (int i = 0; i < _bots.length; i++) {
      final base = 400 + (i * 137 % 900) + (i.isEven ? 250 : 0);
      entries.add(_Entry(_bots[i], base));
    }
    entries.add(_Entry(gs.playerName, rating, isPlayer: true));
    entries.sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      body: GameBackground(
        overlay: 0.42,
        child: SafeArea(
          child: Column(
            children: [
              TopBar(title: 'Leaderboard', onBack: () => Navigator.pop(context)),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _row(i + 1, entries[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(int rank, _Entry e) {
    final medal = switch (rank) {
      1 => AppColors.yellow,
      2 => const Color(0xFFC0C7D6),
      3 => const Color(0xFFCD7F32),
      _ => AppColors.panelLight,
    };
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: e.isPlayer ? AppColors.blueDark : AppColors.panel,
      borderColor: e.isPlayer ? AppColors.blue : null,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal,
              shape: BoxShape.circle,
            ),
            child: StrokeText('$rank',
                strokeWidth: 2.5, style: AppText.title(15, color: AppColors.ink)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              e.isPlayer ? '${e.name} (You)' : e.name,
              style: AppText.body(15,
                  weight: FontWeight.w800,
                  color: e.isPlayer ? AppColors.yellow : AppColors.textLight),
            ),
          ),
          const Icon(Icons.star_rounded, color: AppColors.yellow, size: 18),
          const SizedBox(width: 4),
          Text('${e.score}',
              style: AppText.body(15, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Entry {
  _Entry(this.name, this.score, {this.isPlayer = false});
  final String name;
  final int score;
  final bool isPlayer;
}
