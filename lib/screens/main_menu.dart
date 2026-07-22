import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/assets.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'world_map_screen.dart';
import 'garage_screen.dart';
import 'shop_screen.dart';
import 'upgrades_screen.dart';
import 'daily_screen.dart';
import 'tournaments_screen.dart';
import 'leaderboard_screen.dart';
import 'achievements_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with TickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();

  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..forward();

  final gs = GameState.instance;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playMenuMusic();
  }

  @override
  void dispose() {
    _spin.dispose();
    _intro.dispose();
    super.dispose();
  }

  void _go(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) {
      if (!mounted) return;
      AudioService.instance.playMenuMusic();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        image: A.kitchenBg,
        overlay: 0.5,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: gs,
            builder: (context, _) {
              return Column(
                children: [
                  _header(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: _hero()),
                          const SizedBox(width: 16),
                          Expanded(flex: 6, child: _menuGrid()),
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _go(const ProfileScreen()),
            child: Panel(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              radius: AppRadius.pill,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.blueGradient,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(A.mainHero, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(gs.playerName,
                          style: AppText.body(14, weight: FontWeight.w800)),
                      Text('Level ${gs.playerLevel}',
                          style: AppText.body(11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          CurrencyChip(value: gs.coins, isGem: false, onAdd: () => _go(const ShopScreen())),
          const SizedBox(width: 8),
          CurrencyChip(value: gs.gems, isGem: true, onAdd: () => _go(const ShopScreen())),
        ],
      ),
    );
  }

  Widget _hero() {
    final skin = Catalog.topById(gs.equippedTop);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ShimmerTitle(spin: _spin),
        const SizedBox(height: 4),
        Expanded(
          child: Center(
            child: RotationTransition(
              turns: _spin,
              child: TopSprite(skin: skin, size: 130),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: PulseGlow(
            color: AppColors.green,
            child: ChunkyButton(
              label: 'PLAY',
              icon: Icons.play_arrow_rounded,
              fontSize: 24,
              height: 64,
              onTap: () => _go(const WorldMapScreen()),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _menuGrid() {
    final items = <_MenuItem>[
      _MenuItem('Coop', Icons.home_rounded, AppColors.blueGradient, () => _go(const GarageScreen())),
      _MenuItem('Shop', Icons.storefront_rounded, AppColors.goldGradient, () => _go(const ShopScreen())),
      _MenuItem('Upgrades', Icons.upgrade_rounded, AppColors.greenGradient, () => _go(const UpgradesScreen())),
      _MenuItem('Daily', Icons.calendar_today_rounded, AppColors.redGradient, () => _go(const DailyScreen())),
      _MenuItem('Events', Icons.emoji_events_rounded, AppColors.goldGradient, () => _go(const TournamentsScreen())),
      _MenuItem('Ranks', Icons.leaderboard_rounded, AppColors.blueGradient, () => _go(const LeaderboardScreen())),
      _MenuItem('Awards', Icons.military_tech_rounded, AppColors.greenGradient, () => _go(const AchievementsScreen())),
      _MenuItem('Settings', Icons.settings_rounded, AppColors.blueGradient, () => _go(const SettingsScreen())),
    ];
    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.92,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (int i = 0; i < items.length; i++)
          _MenuTile(item: items[i], index: i, intro: _intro),
      ],
    );
  }
}

/// The shimmering "STRAWTOP RACEWAY" title. Decoupled from the top's
/// rotation so the spin stays perfectly smooth while the (comparatively
/// expensive, ShaderMask-based) gradient sweep only refreshes a few times a
/// second – the sweep is slow enough that this is visually seamless but far
/// lighter on the CPU/GPU.
class _ShimmerTitle extends StatefulWidget {
  const _ShimmerTitle({required this.spin});
  final Animation<double> spin;

  @override
  State<_ShimmerTitle> createState() => _ShimmerTitleState();
}

class _ShimmerTitleState extends State<_ShimmerTitle> {
  int _skip = 0;

  @override
  void initState() {
    super.initState();
    widget.spin.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.spin.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    _skip++;
    if (_skip % 4 != 0) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dx = math.sin(widget.spin.value * math.pi * 2);
    return Column(
      children: [
        GradientText('STRAWTOP',
            style: AppText.title(36),
            gradient: LinearGradient(
              begin: Alignment(-1 + dx, -1),
              end: Alignment(1 + dx, 1),
              colors: const [
                Color(0xFFFFE066),
                AppColors.yellow,
                Color(0xFFFFF6D0),
                AppColors.yellowDark,
              ],
            ),
            strokeWidth: 6),
        GradientText('RACEWAY',
            style: AppText.title(36),
            gradient: LinearGradient(
              begin: Alignment(-1 - dx, -1),
              end: Alignment(1 - dx, 1),
              colors: const [
                AppColors.pink,
                Color(0xFFFF8A5C),
                Color(0xFFFFE066),
                AppColors.pink,
              ],
            ),
            strokeWidth: 6),
      ],
    );
  }
}

class _MenuItem {
  _MenuItem(this.label, this.icon, this.gradient, this.onTap);
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item, required this.index, required this.intro});
  final _MenuItem item;
  final int index;
  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    final glow = (item.gradient as LinearGradient).colors.first;
    final tile = Pressable(
      onTap: item.onTap,
      child: Panel(
        padding: const EdgeInsets.all(8),
        glow: glow.withValues(alpha: 0.35),
        // Icon + label are laid out with MainAxisSize.min so the pair has an
        // intrinsic height, and Center + MainAxisAlignment.center vertically
        // centre them inside the (fixed) grid tile. A FittedBox wraps just
        // the label so long words like "Upgrades" or "Settings" scale down
        // to a single line instead of wrapping and pushing the column past
        // the tile's height (the old "OVERFLOWED BY 1" bug).
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: item.gradient,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: -3,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StrokeText(
                    item.label,
                    strokeWidth: 3,
                    style: AppText.title(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Staggered entrance: fade + rise, offset per tile.
    return AnimatedBuilder(
      animation: intro,
      builder: (_, child) {
        final start = (index * 0.06).clamp(0.0, 0.6);
        final v = Curves.easeOutBack
            .transform(((intro.value - start) / (1 - start)).clamp(0.0, 1.0));
        final o = ((intro.value - start) / (1 - start)).clamp(0.0, 1.0);
        return Opacity(
          opacity: o,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - v)),
            child: Transform.scale(scale: 0.8 + 0.2 * v, child: child),
          ),
        );
      },
      child: tile,
    );
  }
}
