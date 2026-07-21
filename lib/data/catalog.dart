import 'package:flutter/material.dart';
import 'assets.dart';
import 'models.dart';
import '../theme/app_theme.dart';

/// All static game content lives here.
class Catalog {
  // ---- Chickens (playable skins) -------------------------------------------
  static const List<TopSkin> tops = [
    TopSkin(
      id: 'rookie',
      name: 'Lil\' Chick',
      asset: A.topDefault,
      price: 0,
      currency: Currency.coins,
      color: AppColors.red,
      baseSpeed: 4,
      baseStability: 5,
      basePower: 3,
      tagline: 'Every champ starts as a chick.',
    ),
    TopSkin(
      id: 'blaze',
      name: 'Firebeak',
      asset: A.topFire,
      price: 600,
      currency: Currency.coins,
      color: AppColors.yellowDark,
      baseSpeed: 7,
      baseStability: 4,
      basePower: 6,
      tagline: 'Spicy wings, no mercy.',
    ),
    TopSkin(
      id: 'frost',
      name: 'Frostfeather',
      asset: A.topIce,
      price: 900,
      currency: Currency.coins,
      color: AppColors.blue,
      baseSpeed: 5,
      baseStability: 8,
      basePower: 4,
      tagline: 'Cool, calm, unruffled.',
    ),
    TopSkin(
      id: 'voltage',
      name: 'Zap Rooster',
      asset: A.topDefault,
      price: 1400,
      currency: Currency.coins,
      color: AppColors.yellow,
      tint: Color(0xCCFFE14D),
      baseSpeed: 8,
      baseStability: 5,
      basePower: 5,
      tagline: 'Shockingly fast cluck.',
    ),
    TopSkin(
      id: 'venom',
      name: 'Toxic Hen',
      asset: A.topDefault,
      price: 1800,
      currency: Currency.coins,
      color: AppColors.green,
      tint: Color(0xCC49E06B),
      baseSpeed: 6,
      baseStability: 7,
      basePower: 7,
      tagline: 'Poultry in motion.',
    ),
    TopSkin(
      id: 'shadow',
      name: 'Shadow Hen',
      asset: A.topDefault,
      price: 60,
      currency: Currency.gems,
      color: AppColors.purple,
      tint: Color(0xCC9B5DE5),
      baseSpeed: 8,
      baseStability: 8,
      basePower: 8,
      tagline: 'Pecks from the dark.',
    ),
    TopSkin(
      id: 'champion',
      name: 'Golden Rooster',
      asset: A.topFire,
      price: 120,
      currency: Currency.gems,
      color: AppColors.yellow,
      tint: Color(0xCCFFD23F),
      baseSpeed: 9,
      baseStability: 9,
      basePower: 9,
      tagline: 'The legend of the coop.',
    ),
  ];

  static TopSkin topById(String id) =>
      tops.firstWhere((t) => t.id == id, orElse: () => tops.first);

  // ---- Locations -----------------------------------------------------------
  static const List<GameLocation> locations = [
    GameLocation(
      id: 'kitchen',
      name: 'Kitchen Table',
      background: A.kitchenBg,
      icon: A.locKitchen,
      color: AppColors.yellowDark,
      levelCount: 6,
      starGate: 0,
    ),
    GameLocation(
      id: 'school',
      name: 'School Desk',
      background: A.schoolBg,
      icon: A.locSchool,
      color: AppColors.blue,
      levelCount: 6,
      starGate: 8,
    ),
    GameLocation(
      id: 'playground',
      name: 'Playground',
      background: A.playgroundBg,
      icon: A.locPlayground,
      color: AppColors.green,
      levelCount: 6,
      starGate: 20,
    ),
  ];

  static GameLocation locationById(String id) =>
      locations.firstWhere((l) => l.id == id);

  // ---- Levels (generated) --------------------------------------------------
  static final List<GameLevel> levels = _buildLevels();

  static List<GameLevel> _buildLevels() {
    final list = <GameLevel>[];
    final names = [
      'Warm-Up',
      'First Flap',
      'Tight Turns',
      'Rush Hour',
      'Fox Alert',
      'Champion Run',
    ];
    for (final loc in locations) {
      for (int i = 0; i < loc.levelCount; i++) {
        list.add(GameLevel(
          id: '${loc.id}_$i',
          locationId: loc.id,
          index: i,
          name: names[i % names.length],
          distance: 2600 + i * 700.0 + locations.indexOf(loc) * 500,
          difficulty: (i + 1).clamp(1, 5),
          coinReward: 60 + i * 25 + locations.indexOf(loc) * 30,
          obstacleRate: 0.014 + i * 0.004 + locations.indexOf(loc) * 0.003,
          pickupRate: 0.020 + i * 0.001,
        ));
      }
    }
    return list;
  }

  static List<GameLevel> levelsFor(String locationId) =>
      levels.where((l) => l.locationId == locationId).toList();

  static GameLevel levelById(String id) =>
      levels.firstWhere((l) => l.id == id);

  static int get totalLevels => levels.length;

  // ---- Shop ----------------------------------------------------------------
  static const List<ShopItem> coinPacks = [
    ShopItem(
      id: 'coins_small',
      title: '500 Coins',
      subtitle: 'Starter stash',
      asset: A.coin,
      price: 10,
      currency: Currency.gems,
      kind: 'coins',
      amount: 500,
      gradient: AppColors.goldGradient,
    ),
    ShopItem(
      id: 'coins_big',
      title: '2000 Coins',
      subtitle: 'Best value',
      asset: A.coin,
      price: 30,
      currency: Currency.gems,
      kind: 'coins',
      amount: 2000,
      gradient: AppColors.goldGradient,
    ),
  ];

  static const List<ShopItem> boosters = [
    ShopItem(
      id: 'booster_shield',
      title: 'Shield Charge',
      subtitle: 'Start each race protected',
      asset: A.shieldBuff,
      price: 250,
      currency: Currency.coins,
      kind: 'booster',
      gradient: AppColors.blueGradient,
    ),
    ShopItem(
      id: 'booster_boost',
      title: 'Turbo Charge',
      subtitle: 'Extra launch speed',
      asset: A.powerUp,
      price: 250,
      currency: Currency.coins,
      kind: 'booster',
      gradient: AppColors.redGradient,
    ),
    ShopItem(
      id: 'booster_magnet',
      title: 'Coin Magnet',
      subtitle: 'Pull nearby coins',
      asset: A.beckonsBuff,
      price: 300,
      currency: Currency.coins,
      kind: 'booster',
      gradient: AppColors.greenGradient,
    ),
  ];

  // ---- Achievements --------------------------------------------------------
  static const List<Achievement> achievements = [
    Achievement(
        id: 'first_win',
        title: 'First Victory',
        description: 'Finish your first race',
        goal: 1,
        rewardGems: 10,
        metric: 'wins'),
    Achievement(
        id: 'coin_100',
        title: 'Coin Collector',
        description: 'Collect 100 coins in total',
        goal: 100,
        rewardGems: 10,
        metric: 'coins'),
    Achievement(
        id: 'coin_1000',
        title: 'Coin Tycoon',
        description: 'Collect 1000 coins in total',
        goal: 1000,
        rewardGems: 25,
        metric: 'coins'),
    Achievement(
        id: 'races_10',
        title: 'Getting Serious',
        description: 'Play 10 races',
        goal: 10,
        rewardGems: 15,
        metric: 'races'),
    Achievement(
        id: 'races_50',
        title: 'Track Regular',
        description: 'Play 50 races',
        goal: 50,
        rewardGems: 40,
        metric: 'races'),
    Achievement(
        id: 'stars_15',
        title: 'Rising Star',
        description: 'Earn 15 stars',
        goal: 15,
        rewardGems: 20,
        metric: 'stars'),
    Achievement(
        id: 'stars_40',
        title: 'Superstar',
        description: 'Earn 40 stars',
        goal: 40,
        rewardGems: 50,
        metric: 'stars'),
    Achievement(
        id: 'tops_3',
        title: 'Flock Starter',
        description: 'Own 3 chickens',
        goal: 3,
        rewardGems: 20,
        metric: 'tops'),
    Achievement(
        id: 'wins_25',
        title: 'Coop Legend',
        description: 'Win 25 races',
        goal: 25,
        rewardGems: 60,
        metric: 'wins'),
  ];

  // ---- Daily challenges ----------------------------------------------------
  static const List<DailyChallenge> dailyPool = [
    DailyChallenge(
        id: 'd_win2',
        title: 'Win 2 races',
        goal: 2,
        rewardCoins: 150,
        metric: 'wins',
        icon: Icons.emoji_events_rounded),
    DailyChallenge(
        id: 'd_coins80',
        title: 'Collect 80 coins',
        goal: 80,
        rewardCoins: 120,
        metric: 'coins',
        icon: Icons.monetization_on_rounded),
    DailyChallenge(
        id: 'd_play3',
        title: 'Play 3 races',
        goal: 3,
        rewardCoins: 100,
        metric: 'races',
        icon: Icons.sports_score_rounded),
  ];
}
