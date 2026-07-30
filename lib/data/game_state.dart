import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'catalog.dart';
import 'models.dart';

/// Single source of truth for all player progress. Persists to local storage
/// (SharedPreferences) so the whole game works fully offline.
class GameState extends ChangeNotifier {
  GameState._();
  static final GameState instance = GameState._();

  SharedPreferences? _prefs;
  static const String _key = 'strawtop_save_v1';

  /// The profile avatar photo lives under its own key so it never bloats the
  /// (frequently rewritten) main save blob. Kept as base64 of a small JPEG.
  static const String _avatarKey = 'strawtop_avatar_v1';

  // ---- Player wallet & profile --------------------------------------------
  int coins = 300;
  int gems = 20;
  String playerName = 'Racer';

  /// Decoded avatar photo bytes, or null when the player uses the default art.
  Uint8List? avatarPhoto;

  bool get hasAvatarPhoto => avatarPhoto != null && avatarPhoto!.isNotEmpty;

  // ---- Ownership -----------------------------------------------------------
  Set<String> ownedTops = {'rookie'};
  String equippedTop = 'rookie';

  /// topId -> {'speed':int,'stability':int,'power':int}
  Map<String, Map<String, int>> upgrades = {};

  // ---- Progression ---------------------------------------------------------
  /// levelId -> stars (1..3). Absence means not completed.
  Map<String, int> levelStars = {};

  /// levelId -> best distance/score for leaderboard.
  Map<String, int> levelBest = {};

  int totalRaces = 0;
  int totalWins = 0;
  int totalCoinsCollected = 0;

  // ---- Boosters (consumables) ---------------------------------------------
  int boosterShield = 0;
  int boosterBoost = 0;
  int boosterMagnet = 0;

  // ---- Settings ------------------------------------------------------------
  bool soundOn = true;
  bool musicOn = true;
  double musicVolume = 0.6;
  double sfxVolume = 0.9;

  // ---- Achievements & daily -----------------------------------------------
  Set<String> claimedAchievements = {};
  String dailyDate = '';
  Map<String, int> dailyProgress = {};
  Set<String> dailyClaimed = {};

  // ==========================================================================
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
    _loadAvatar();
    _ensureDaily();
  }

  void _loadAvatar() {
    final encoded = _prefs?.getString(_avatarKey);
    if (encoded == null || encoded.isEmpty) return;
    try {
      avatarPhoto = base64Decode(encoded);
    } catch (_) {
      avatarPhoto = null;
    }
  }

  /// Stores the chosen profile photo (already downscaled by the picker).
  Future<void> setAvatarPhoto(Uint8List bytes) async {
    avatarPhoto = bytes;
    notifyListeners();
    try {
      await _prefs?.setString(_avatarKey, base64Encode(bytes));
    } catch (_) {}
  }

  /// Drops the custom photo and falls back to the default racer art.
  Future<void> clearAvatarPhoto() async {
    avatarPhoto = null;
    notifyListeners();
    await _prefs?.remove(_avatarKey);
  }

  int get totalStars =>
      levelStars.values.fold(0, (sum, s) => sum + s);

  int get playerLevel => 1 + (totalStars ~/ 3) + (totalWins ~/ 5);

  int get ownedTopsCount => ownedTops.length;

  bool isTopOwned(String id) => ownedTops.contains(id);

  int upgradeLevel(String topId, String stat) =>
      upgrades[topId]?[stat] ?? 0;

  /// Effective stat (base + upgrades), clamped to 12.
  int effectiveStat(TopSkin top, String stat) {
    final base = switch (stat) {
      'speed' => top.baseSpeed,
      'stability' => top.baseStability,
      _ => top.basePower,
    };
    return (base + upgradeLevel(top.id, stat)).clamp(1, 12);
  }

  int upgradeCost(String topId, String stat) {
    final lvl = upgradeLevel(topId, stat);
    return 200 + lvl * 150;
  }

  static const int maxUpgrade = 5;

  // ---- Level unlocking -----------------------------------------------------
  bool isLevelUnlocked(GameLevel level) {
    final loc = Catalog.locationById(level.locationId);
    if (totalStars < loc.starGate) return false;
    if (level.index == 0) return true;
    final prevId = '${level.locationId}_${level.index - 1}';
    return levelStars.containsKey(prevId);
  }

  bool isLocationUnlocked(GameLocation loc) => totalStars >= loc.starGate;

  int starsFor(String levelId) => levelStars[levelId] ?? 0;

  // ---- Economy actions -----------------------------------------------------
  bool spend(Currency currency, int amount) {
    if (currency == Currency.coins) {
      if (coins < amount) return false;
      coins -= amount;
    } else {
      if (gems < amount) return false;
      gems -= amount;
    }
    _save();
    notifyListeners();
    return true;
  }

  void addCoins(int amount) {
    coins += amount;
    _save();
    notifyListeners();
  }

  void addGems(int amount) {
    gems += amount;
    _save();
    notifyListeners();
  }

  bool buyTop(TopSkin top) {
    if (ownedTops.contains(top.id)) return true;
    if (!spend(top.currency, top.price)) return false;
    ownedTops.add(top.id);
    _save();
    notifyListeners();
    return true;
  }

  void equipTop(String id) {
    if (!ownedTops.contains(id)) return;
    equippedTop = id;
    _save();
    notifyListeners();
  }

  bool buyUpgrade(String topId, String stat) {
    final lvl = upgradeLevel(topId, stat);
    if (lvl >= maxUpgrade) return false;
    final cost = upgradeCost(topId, stat);
    if (!spend(Currency.coins, cost)) return false;
    final map = upgrades.putIfAbsent(topId, () => {});
    map[stat] = lvl + 1;
    _save();
    notifyListeners();
    return true;
  }

  bool buyShopItem(ShopItem item) {
    if (!spend(item.currency, item.price)) return false;
    switch (item.kind) {
      case 'coins':
        coins += item.amount;
        break;
      case 'gems':
        gems += item.amount;
        break;
      case 'booster':
        if (item.id.contains('shield')) boosterShield++;
        if (item.id.contains('boost')) boosterBoost++;
        if (item.id.contains('magnet')) boosterMagnet++;
        break;
    }
    _save();
    notifyListeners();
    return true;
  }

  // ---- Race results --------------------------------------------------------
  /// Registers the outcome of a race and returns the coins actually granted.
  void recordRace({
    required String levelId,
    required bool finished,
    required int stars,
    required int coinsCollected,
    required int score,
  }) {
    totalRaces++;
    if (finished) totalWins++;
    totalCoinsCollected += coinsCollected;
    coins += coinsCollected;

    if (finished && stars > 0) {
      final prev = levelStars[levelId] ?? 0;
      if (stars > prev) levelStars[levelId] = stars;
    }
    final prevBest = levelBest[levelId] ?? 0;
    if (score > prevBest) levelBest[levelId] = score;

    _bumpDaily('races', 1);
    if (finished) _bumpDaily('wins', 1);
    _bumpDaily('coins', coinsCollected);

    _save();
    notifyListeners();
  }

  // ---- Achievements --------------------------------------------------------
  int achievementProgress(Achievement a) {
    switch (a.metric) {
      case 'races':
        return totalRaces;
      case 'wins':
        return totalWins;
      case 'coins':
        return totalCoinsCollected;
      case 'stars':
        return totalStars;
      case 'tops':
        return ownedTops.length;
      default:
        return 0;
    }
  }

  bool isAchievementComplete(Achievement a) =>
      achievementProgress(a) >= a.goal;

  bool isAchievementClaimed(Achievement a) =>
      claimedAchievements.contains(a.id);

  bool claimAchievement(Achievement a) {
    if (!isAchievementComplete(a) || isAchievementClaimed(a)) return false;
    claimedAchievements.add(a.id);
    gems += a.rewardGems;
    _save();
    notifyListeners();
    return true;
  }

  // ---- Daily challenges ----------------------------------------------------
  void _ensureDaily() {
    final today = _todayKey();
    if (dailyDate != today) {
      dailyDate = today;
      dailyProgress = {};
      dailyClaimed = {};
      _save();
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  void _bumpDaily(String metric, int amount) {
    for (final c in Catalog.dailyPool) {
      if (c.metric == metric) {
        dailyProgress[c.id] = (dailyProgress[c.id] ?? 0) + amount;
      }
    }
  }

  int dailyProgressFor(DailyChallenge c) =>
      (dailyProgress[c.id] ?? 0).clamp(0, c.goal);

  bool isDailyComplete(DailyChallenge c) =>
      (dailyProgress[c.id] ?? 0) >= c.goal;

  bool isDailyClaimed(DailyChallenge c) => dailyClaimed.contains(c.id);

  bool claimDaily(DailyChallenge c) {
    if (!isDailyComplete(c) || isDailyClaimed(c)) return false;
    dailyClaimed.add(c.id);
    coins += c.rewardCoins;
    _save();
    notifyListeners();
    return true;
  }

  // ---- Settings ------------------------------------------------------------
  void setSound(bool v) {
    soundOn = v;
    _save();
    notifyListeners();
  }

  void setMusic(bool v) {
    musicOn = v;
    _save();
    notifyListeners();
  }

  // Sliders call these on every drag tick, so persistence is intentionally
  // skipped here to avoid a SharedPreferences write (+ full-tree rebuild)
  // on every pixel of movement. Call [saveSettings] once the drag ends.
  void setMusicVolume(double v) {
    musicVolume = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setSfxVolume(double v) {
    sfxVolume = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Persist settings once a slider drag finishes.
  void saveSettings() => _save();

  void setName(String v) {
    playerName = v.trim().isEmpty ? 'Racer' : v.trim();
    _save();
    notifyListeners();
  }

  void resetProgress() {
    coins = 300;
    gems = 20;
    playerName = 'Racer';
    ownedTops = {'rookie'};
    equippedTop = 'rookie';
    upgrades = {};
    levelStars = {};
    levelBest = {};
    totalRaces = 0;
    totalWins = 0;
    totalCoinsCollected = 0;
    boosterShield = 0;
    boosterBoost = 0;
    boosterMagnet = 0;
    claimedAchievements = {};
    dailyProgress = {};
    dailyClaimed = {};
    avatarPhoto = null;
    _prefs?.remove(_avatarKey);
    _save();
    notifyListeners();
  }

  // ---- Persistence ---------------------------------------------------------
  void _load() {
    final raw = _prefs?.getString(_key);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      coins = m['coins'] ?? coins;
      gems = m['gems'] ?? gems;
      playerName = m['playerName'] ?? playerName;
      ownedTops = Set<String>.from(m['ownedTops'] ?? ['rookie']);
      equippedTop = m['equippedTop'] ?? 'rookie';
      upgrades = (m['upgrades'] as Map?)?.map((k, v) =>
              MapEntry(k as String, Map<String, int>.from(v as Map))) ??
          {};
      levelStars = Map<String, int>.from(m['levelStars'] ?? {});
      levelBest = Map<String, int>.from(m['levelBest'] ?? {});
      totalRaces = m['totalRaces'] ?? 0;
      totalWins = m['totalWins'] ?? 0;
      totalCoinsCollected = m['totalCoinsCollected'] ?? 0;
      boosterShield = m['boosterShield'] ?? 0;
      boosterBoost = m['boosterBoost'] ?? 0;
      boosterMagnet = m['boosterMagnet'] ?? 0;
      soundOn = m['soundOn'] ?? true;
      musicOn = m['musicOn'] ?? true;
      musicVolume = (m['musicVolume'] ?? 0.6).toDouble();
      sfxVolume = (m['sfxVolume'] ?? 0.9).toDouble();
      claimedAchievements = Set<String>.from(m['claimedAchievements'] ?? []);
      dailyDate = m['dailyDate'] ?? '';
      dailyProgress = Map<String, int>.from(m['dailyProgress'] ?? {});
      dailyClaimed = Set<String>.from(m['dailyClaimed'] ?? []);
    } catch (_) {
      // Corrupt save: start fresh rather than crashing.
    }
  }

  void _save() {
    final m = {
      'coins': coins,
      'gems': gems,
      'playerName': playerName,
      'ownedTops': ownedTops.toList(),
      'equippedTop': equippedTop,
      'upgrades': upgrades,
      'levelStars': levelStars,
      'levelBest': levelBest,
      'totalRaces': totalRaces,
      'totalWins': totalWins,
      'totalCoinsCollected': totalCoinsCollected,
      'boosterShield': boosterShield,
      'boosterBoost': boosterBoost,
      'boosterMagnet': boosterMagnet,
      'soundOn': soundOn,
      'musicOn': musicOn,
      'musicVolume': musicVolume,
      'sfxVolume': sfxVolume,
      'claimedAchievements': claimedAchievements.toList(),
      'dailyDate': dailyDate,
      'dailyProgress': dailyProgress,
      'dailyClaimed': dailyClaimed.toList(),
    };
    _prefs?.setString(_key, jsonEncode(m));
  }
}
