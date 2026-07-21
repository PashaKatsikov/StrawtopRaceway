import 'package:flutter/material.dart';
import '../data/assets.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen>
    with SingleTickerProviderStateMixin {
  final gs = GameState.instance;
  late String _selectedId = gs.equippedTop;
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

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
    final skin = Catalog.topById(_selectedId);
    return Scaffold(
      body: GameBackground(
        image: A.storeBg,
        overlay: 0.62,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: gs,
            builder: (context, _) => Column(
              children: [
                TopBar(title: 'Garage', onBack: () => Navigator.pop(context)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: _preview(skin)),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: _list()),
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

  Widget _preview(TopSkin skin) {
    final owned = gs.isTopOwned(skin.id);
    final equipped = gs.equippedTop == skin.id;
    return Panel(
      child: Column(
        children: [
          Row(
            children: [
              StrokeText(
                skin.name,
                style: AppText.title(22, color: skin.color),
              ),
            ],
          ),
          Text(
            skin.tagline,
            style: AppText.body(12, color: AppColors.textMuted),
          ),
          Expanded(
            child: Center(
              child: RotationTransition(
                turns: _spin,
                child: TopSprite(skin: skin, size: 120),
              ),
            ),
          ),
          StatBar(
            label: 'Speed',
            value: gs.effectiveStat(skin, 'speed'),
            color: AppColors.red,
            icon: Icons.speed_rounded,
          ),
          StatBar(
            label: 'Stability',
            value: gs.effectiveStat(skin, 'stability'),
            color: AppColors.blue,
            icon: Icons.shield_rounded,
          ),
          StatBar(
            label: 'Power',
            value: gs.effectiveStat(skin, 'power'),
            color: AppColors.green,
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 10),
          _actionButton(skin, owned, equipped),
        ],
      ),
    );
  }

  Widget _actionButton(TopSkin skin, bool owned, bool equipped) {
    if (equipped) {
      return const ChunkyButton(
        label: 'EQUIPPED',
        onTap: _noop,
        enabled: false,
        gradient: AppColors.greenGradient,
      );
    }
    if (owned) {
      return ChunkyButton(
        label: 'EQUIP',
        gradient: AppColors.greenGradient,
        onTap: () {
          gs.equipTop(skin.id);
          showToast(context, '${skin.name} equipped!');
        },
      );
    }
    final isGem = skin.currency == Currency.gems;
    return ChunkyButton(
      label: 'BUY  ${skin.price} ${isGem ? '\uD83D\uDC8E' : '\uD83E\uDE99'}',
      gradient: AppColors.goldGradient,
      lip: AppColors.yellowDark,
      onTap: () {
        if (gs.buyTop(skin)) {
          gs.equipTop(skin.id);
          showToast(context, 'Unlocked ${skin.name}!');
        } else {
          showToast(
            context,
            'Not enough ${isGem ? 'gems' : 'coins'}',
            good: false,
          );
        }
      },
    );
  }

  static void _noop() {}

  Widget _list() {
    return ListView.separated(
      itemCount: Catalog.tops.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final skin = Catalog.tops[i];
        final owned = gs.isTopOwned(skin.id);
        final equipped = gs.equippedTop == skin.id;
        final selected = _selectedId == skin.id;
        return RepaintBoundary(
          child: GestureDetector(
            onTap: () => setState(() => _selectedId = skin.id),
            child: Panel(
              padding: const EdgeInsets.all(10),
              borderColor: selected ? skin.color : null,
              color: selected ? AppColors.panelLight : AppColors.panel,
              child: Row(
                children: [
                  TopSprite(skin: skin, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skin.name,
                          style: AppText.body(14, weight: FontWeight.w800),
                        ),
                        Text(
                          equipped
                              ? 'Equipped'
                              : owned
                              ? 'Owned'
                              : '${skin.price} ${skin.currency == Currency.gems ? 'gems' : 'coins'}',
                          style: AppText.body(
                            11,
                            color: equipped
                                ? AppColors.green
                                : owned
                                ? AppColors.textMuted
                                : AppColors.yellow,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    equipped
                        ? Icons.check_circle_rounded
                        : owned
                        ? Icons.circle_outlined
                        : Icons.lock_rounded,
                    color: equipped ? AppColors.green : Colors.white38,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
