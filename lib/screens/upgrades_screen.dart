import 'package:flutter/material.dart';
import '../data/assets.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class UpgradesScreen extends StatefulWidget {
  const UpgradesScreen({super.key});

  @override
  State<UpgradesScreen> createState() => _UpgradesScreenState();
}

class _UpgradesScreenState extends State<UpgradesScreen>
    with SingleTickerProviderStateMixin {
  final gs = GameState.instance;
  late String _selectedId = gs.equippedTop;
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))
        ..repeat();

  @override
  void initState() {
    super.initState();
    AudioService.instance.playMenuMusic();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only owned tops can be upgraded.
    final owned = Catalog.tops.where((t) => gs.isTopOwned(t.id)).toList();
    if (!owned.any((t) => t.id == _selectedId)) {
      _selectedId = owned.first.id;
    }
    final skin = Catalog.topById(_selectedId);
    return Scaffold(
      body: GameBackground(
        overlay: 0.45,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: gs,
            builder: (context, _) => Column(
              children: [
                TopBar(title: 'Upgrades', onBack: () => Navigator.pop(context)),
                _topSelector(owned),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(flex: 4, child: _preview(skin)),
                        const SizedBox(width: 14),
                        Expanded(flex: 6, child: _upgradePanel(skin)),
                      ],
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

  Widget _topSelector(List<TopSkin> owned) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: owned.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final skin = owned[i];
          final sel = skin.id == _selectedId;
          return GestureDetector(
            onTap: () => setState(() => _selectedId = skin.id),
            child: Container(
              width: 58,
              decoration: BoxDecoration(
                color: sel ? AppColors.panelLight : AppColors.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: sel ? skin.color : Colors.white24, width: 2),
              ),
              child: TopSprite(skin: skin, size: 42),
            ),
          );
        },
      ),
    );
  }

  Widget _preview(TopSkin skin) {
    return Panel(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StrokeText(skin.name, style: AppText.title(20, color: skin.color)),
          const SizedBox(height: 8),
          RotationTransition(
            turns: _spin,
            child: TopSprite(skin: skin, size: 110),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(A.coin, width: 22, height: 22),
              const SizedBox(width: 6),
              Text('${gs.coins}',
                  style: AppText.body(16, weight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _upgradePanel(TopSkin skin) {
    return Panel(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _upgradeRow(
                skin, 'speed', 'Speed', AppColors.red, Icons.speed_rounded),
            const Divider(color: Colors.white12, height: 16),
            _upgradeRow(skin, 'stability', 'Stability', AppColors.blue,
                Icons.shield_rounded),
            const Divider(color: Colors.white12, height: 16),
            _upgradeRow(
                skin, 'power', 'Power', AppColors.green, Icons.bolt_rounded),
          ],
        ),
      ),
    );
  }

  Widget _upgradeRow(
      TopSkin skin, String stat, String label, Color color, IconData icon) {
    final lvl = gs.upgradeLevel(skin.id, stat);
    final maxed = lvl >= GameState.maxUpgrade;
    final cost = gs.upgradeCost(skin.id, stat);
    return Column(
      children: [
        StatBar(
            label: label,
            value: gs.effectiveStat(skin, stat),
            color: color,
            icon: icon),
        const SizedBox(height: 6),
        Row(
          children: [
            Row(
              children: List.generate(
                GameState.maxUpgrade,
                (i) => Container(
                  margin: const EdgeInsets.only(right: 3),
                  width: 14,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < lvl ? color : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 130,
              child: ChunkyButton(
                label: maxed ? 'MAX' : '$cost \uD83E\uDE99',
                height: 34,
                fontSize: 14,
                enabled: !maxed,
                gradient: AppColors.greenGradient,
                onTap: () {
                  if (gs.buyUpgrade(skin.id, stat)) {
                    showToast(context, '$label upgraded!');
                  } else {
                    showToast(context, 'Not enough coins', good: false);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
