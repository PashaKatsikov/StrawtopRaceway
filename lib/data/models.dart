import 'package:flutter/material.dart';

enum Currency { coins, gems }

/// A collectible / playable spinning top. Some tops reuse a base sprite with a
/// colour modulation to create distinct visual variants while staying < 40MB.
class TopSkin {
  const TopSkin({
    required this.id,
    required this.name,
    required this.asset,
    required this.price,
    required this.currency,
    required this.color,
    required this.baseSpeed,
    required this.baseStability,
    required this.basePower,
    this.tint,
    required this.tagline,
  });

  final String id;
  final String name;
  final String asset;
  final int price;
  final Currency currency;
  final Color color;

  /// 1..10 base stats, further improved by upgrades.
  final int baseSpeed;
  final int baseStability;
  final int basePower;

  /// Optional colour modulation applied to the sprite.
  final Color? tint;
  final String tagline;
}

class GameLocation {
  const GameLocation({
    required this.id,
    required this.name,
    required this.background,
    required this.icon,
    required this.color,
    required this.levelCount,
    required this.starGate,
  });

  final String id;
  final String name;
  final String background;
  final String icon;
  final Color color;
  final int levelCount;

  /// Total stars required across the game to unlock this location.
  final int starGate;
}

class GameLevel {
  const GameLevel({
    required this.id,
    required this.locationId,
    required this.index,
    required this.name,
    required this.distance,
    required this.difficulty,
    required this.coinReward,
    required this.obstacleRate,
    required this.pickupRate,
  });

  final String id;
  final String locationId;
  final int index;
  final String name;

  /// Track length in abstract units.
  final double distance;

  /// 1 (easy) .. 5 (hard).
  final int difficulty;
  final int coinReward;

  /// Spawn probability weights per scroll tick.
  final double obstacleRate;
  final double pickupRate;
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.price,
    required this.currency,
    required this.kind,
    this.amount = 0,
    this.gradient,
  });

  final String id;
  final String title;
  final String subtitle;
  final String asset;
  final int price;
  final Currency currency;

  /// 'coins', 'gems', 'booster'
  final String kind;
  final int amount;
  final Gradient? gradient;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.goal,
    required this.rewardGems,
    required this.metric,
  });

  final String id;
  final String title;
  final String description;
  final int goal;
  final int rewardGems;

  /// Which counter this achievement watches.
  /// 'races', 'coins', 'stars', 'wins', 'tops'
  final String metric;
}

class DailyChallenge {
  const DailyChallenge({
    required this.id,
    required this.title,
    required this.goal,
    required this.rewardCoins,
    required this.metric,
    required this.icon,
  });

  final String id;
  final String title;
  final int goal;
  final int rewardCoins;
  final String metric;
  final IconData icon;
}
