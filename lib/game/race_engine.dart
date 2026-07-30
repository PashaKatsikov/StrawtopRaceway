import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/models.dart';

enum EntityType { pencil, eraser, spring, coin, star, powerup }
enum PowerKind { shield, boost, magnet }
enum RaceStatus { ready, running, finished, failed, paused }
enum RaceSound { coin, star, power, hit, go }

class Entity {
  Entity(this.type, this.x, this.y, this.size, {this.power});
  final EntityType type;
  double x;
  double y;
  final double size;
  final PowerKind? power;
  bool dead = false;
}

/// Frame-driven simulation of a single race. Pure screen-space scroller so it
/// stays lightweight and framerate independent.
class RaceEngine extends ChangeNotifier {
  RaceEngine({
    required this.level,
    required this.eventBonus,
    required this.background,
  }) {
    final gs = GameState.instance;
    _skin = Catalog.topById(gs.equippedTop);
    _speedStat = gs.effectiveStat(_skin, 'speed');
    _stabilityStat = gs.effectiveStat(_skin, 'stability');
    _powerStat = gs.effectiveStat(_skin, 'power');
  }

  final GameLevel level;
  final bool eventBonus;
  final String background;
  final math.Random _rng = math.Random();

  /// Fired for gameplay sound cues (wired to [AudioService] by the screen).
  void Function(RaceSound)? onSound;

  late final TopSkin _skin;
  TopSkin get skin => _skin;
  late final int _speedStat;
  late final int _stabilityStat;
  late final int _powerStat;

  Size size = Size.zero;

  // ---- Runtime state -------------------------------------------------------
  RaceStatus status = RaceStatus.ready;
  double topX = 0; // px
  double _targetX = 0;
  double get topYFactor => 0.8;

  double distance = 0;
  double energy = 100;
  int coins = 0;
  int starsPicked = 0;
  int _coinsSpawned = 0;
  int _coinsCollected = 0;

  double _baseSpeed = 0;
  double _boostTimer = 0;
  double _shieldTimer = 0;
  double _magnetTimer = 0;
  bool shieldPermanentUntilHit = false;

  double _distSinceObstacle = 0;
  double _distSinceCoin = 0;
  double _hitFlash = 0;
  double _spinTurns = 0;

  final List<Entity> entities = [];
  final List<Puff> puffs = [];

  int readyCountdown = 3;
  double _readyTimer = 0;

  double get progress => (distance / level.distance).clamp(0.0, 1.0);
  double get spinTurns => _spinTurns;
  double get hitFlash => _hitFlash;
  bool get shieldActive => _shieldTimer > 0 || shieldPermanentUntilHit;
  bool get boostActive => _boostTimer > 0;
  bool get magnetActive => _magnetTimer > 0;

  // ---- Play field ----------------------------------------------------------
  // The board is a centred strip laid over the location art, so the kitchen /
  // school / playground scenery stays visible in the gutters on both sides.
  // The board is the whole game: the racer, every obstacle and every pickup
  // live strictly inside the wooden lane between the two rope rails, and
  // nothing is ever driven or spawned out over the scenery.

  /// Rail thickness as a share of the board width. Matches the proportions of
  /// the board sprite (see the source crops in RacePainter) so the simulated
  /// lane lines up exactly with the wood that is actually drawn.
  static const double _railFactor = 0.156;

  /// Share of the screen the board claims when there is width to spare.
  static const double _boardShare = 0.55;

  /// Floor for the wooden lane. On a narrow (portrait) screen [_boardShare]
  /// alone would leave a lane too tight to get past the widest obstacle, so
  /// the board grows and the gutters shrink instead.
  static const double _minLaneWidth = 230;

  double get trackWidth {
    final laneShare = 1 - 2 * _railFactor;
    return math.min(
      size.width,
      math.max(size.width * _boardShare, _minLaneWidth / laneShare),
    );
  }

  double get trackLeft => (size.width - trackWidth) / 2;
  double get topRadius => 33;

  /// Visual side-barrier thickness; the drivable lane is inset by this each side.
  double get railW => trackWidth * _railFactor;
  double get innerLeft => trackLeft + railW;
  double get innerRight => trackLeft + trackWidth - railW;
  double get innerWidth => innerRight - innerLeft;

  /// Half-width of the *rendered* top sprite (see `_paintTop` in RacePainter:
  /// the sprite is drawn at width = topRadius * 2.4, i.e. 20% wider than the
  /// collision circle on each side).
  double get _spriteHalfWidth => topRadius * 1.2;

  /// Extra safety margin, in pixels, so the visible chicken sprite stays
  /// COMFORTABLY inside the wooden lane and never touches the blue side
  /// rails – not even at the extremes of the drag. Tuned so the sprite has
  /// a small (~10 px) breathing room on each side of the wood/rail seam.
  static const double _laneSafetyPx = 10.0;

  /// Left/right screen-space bounds the top's centre may occupy so its
  /// rendered sprite stays fully within the drivable wooden lane and doesn't
  /// overlap the blue rails.
  double get _steerMin => innerLeft + _spriteHalfWidth + _laneSafetyPx;
  double get _steerMax => innerRight - _spriteHalfWidth - _laneSafetyPx;

  void start() {
    _baseSpeed = 210 + _speedStat * 20.0;
    final gs = GameState.instance;
    // Consume owned boosters as a pre-race advantage.
    if (gs.boosterShield > 0) {
      gs.boosterShield--;
      shieldPermanentUntilHit = true;
    }
    if (gs.boosterBoost > 0) {
      gs.boosterBoost--;
      _boostTimer = 3;
    }
    if (gs.boosterMagnet > 0) {
      gs.boosterMagnet--;
      _magnetTimer = 6;
    }
    status = RaceStatus.ready;
  }

  void setTargetX(double px) {
    // Guard against being called before the first paint sizes the engine.
    if (size == Size.zero) {
      _targetX = px;
      return;
    }
    _targetX = px.clamp(_steerMin, _steerMax);
  }

  void nudge(double dx) {
    setTargetX(_targetX + dx);
  }

  void pause() {
    if (status == RaceStatus.running) status = RaceStatus.paused;
    notifyListeners();
  }

  void resume() {
    if (status == RaceStatus.paused) status = RaceStatus.running;
    notifyListeners();
  }

  void update(double dt) {
    if (size == Size.zero) return;
    dt = dt.clamp(0.0, 0.05);

    if (status == RaceStatus.ready) {
      if (topX == 0) {
        topX = size.width / 2;
        _targetX = topX;
      }
      _readyTimer += dt;
      if (_readyTimer >= 0.8) {
        _readyTimer = 0;
        readyCountdown--;
        if (readyCountdown <= 0) {
          status = RaceStatus.running;
          onSound?.call(RaceSound.go);
        }
      }
      _spinTurns += dt * 2;
      notifyListeners();
      return;
    }

    if (status != RaceStatus.running) return;

    // Timers.
    if (_boostTimer > 0) _boostTimer -= dt;
    if (_shieldTimer > 0) _shieldTimer -= dt;
    if (_magnetTimer > 0) _magnetTimer -= dt;
    if (_hitFlash > 0) _hitFlash -= dt;

    // Speed & movement.
    double speed = _baseSpeed;
    if (_boostTimer > 0) speed *= 1.7;
    speed *= (0.6 + energy / 250); // low energy = slower
    distance += speed * dt;
    _spinTurns += dt * (2 + speed / 120);

    // Energy drain (stability slows the drain).
    energy -= dt * (2.2 - _stabilityStat * 0.11).clamp(0.6, 2.2);
    energy = energy.clamp(0, 100);
    if (energy <= 0) {
      status = RaceStatus.failed;
      notifyListeners();
      return;
    }

    // Steer easing, then hard-clamp so the top's rendered sprite can never
    // leave the wooden lane (i.e. no overlap onto the side rails).
    topX += (_targetX - topX) * math.min(1.0, dt * 11);
    topX = topX.clamp(_steerMin, _steerMax);

    // Dust puffs behind the top.
    if (_rng.nextDouble() < dt * 22) {
      puffs.add(Puff(
        (topX + (_rng.nextDouble() - 0.5) * 20)
            .clamp(innerLeft + 12, innerRight - 12),
        size.height * topYFactor + 18,
      ));
    }
    for (final p in puffs) {
      p.life -= dt * 1.6;
      p.y += speed * dt * 0.4;
      p.scale += dt * 0.6;
    }
    puffs.removeWhere((p) => p.life <= 0);

    // Scroll & spawn.
    _distSinceObstacle += speed * dt;
    _distSinceCoin += speed * dt;
    _spawnLogic(speed);

    final topScreenY = size.height * topYFactor;
    for (final e in entities) {
      e.y += speed * dt;
      // Magnet pulls coins.
      if (_magnetTimer > 0 &&
          (e.type == EntityType.coin) &&
          (e.y - topScreenY).abs() < 220) {
        e.x += (topX - e.x) * math.min(1.0, dt * 4);
      }
      if (!e.dead && _collides(e, topScreenY)) {
        _handleHit(e);
      }
    }
    entities.removeWhere((e) => e.dead || e.y > size.height + 80);

    if (distance >= level.distance) {
      status = RaceStatus.finished;
      // Clear anything still on the board so nothing lingers past the finish.
      entities.clear();
      puffs.clear();
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  bool _collides(Entity e, double topScreenY) {
    final dy = (e.y - topScreenY).abs();
    if (dy > (e.size / 2 + topRadius) * 0.8) return false;
    final dx = (e.x - topX).abs();
    return dx < (e.size / 2 + topRadius) * 0.75;
  }

  void _handleHit(Entity e) {
    switch (e.type) {
      case EntityType.coin:
        e.dead = true;
        coins += eventBonus ? 2 : 1;
        _coinsCollected++;
        onSound?.call(RaceSound.coin);
        break;
      case EntityType.star:
        e.dead = true;
        starsPicked++;
        energy = math.min(100, energy + 12);
        onSound?.call(RaceSound.star);
        break;
      case EntityType.powerup:
        e.dead = true;
        _applyPower(e.power ?? PowerKind.boost);
        onSound?.call(RaceSound.power);
        break;
      case EntityType.spring:
        e.dead = true;
        _boostTimer = math.max(_boostTimer, 1.6);
        energy = math.min(100, energy + 4);
        onSound?.call(RaceSound.power);
        break;
      case EntityType.pencil:
      case EntityType.eraser:
        e.dead = true;
        if (shieldActive) {
          if (shieldPermanentUntilHit) shieldPermanentUntilHit = false;
          _shieldTimer = 0;
        } else {
          final dmg = (e.type == EntityType.pencil ? 22 : 15) -
              _powerStat * 0.6;
          energy = (energy - dmg).clamp(0, 100);
          _boostTimer = 0;
          _hitFlash = 0.35;
          onSound?.call(RaceSound.hit);
        }
        break;
    }
  }

  void _applyPower(PowerKind k) {
    switch (k) {
      case PowerKind.shield:
        _shieldTimer = 8;
        break;
      case PowerKind.boost:
        _boostTimer = 3;
        break;
      case PowerKind.magnet:
        _magnetTimer = 6;
        break;
    }
  }

  void _spawnLogic(double speed) {
    // Stop spawning once the finish line is within a screen: anything spawned at
    // the top edge from here on would land beyond the finish, which is wrong.
    final remaining = level.distance - distance;
    if (remaining <= size.height * topYFactor + 90) return;
    // Obstacles spaced by distance so there is always a clear line through.
    final obstacleGap = (300 - level.difficulty * 22).clamp(150, 300) +
        _rng.nextInt(120);
    if (_distSinceObstacle >= obstacleGap) {
      _distSinceObstacle = 0;
      _spawnObstacle();
    }
    // Coins in gentle arcs.
    if (_distSinceCoin >= 170) {
      _distSinceCoin = 0;
      _spawnPickups();
    }
  }

  /// Screen X for a spawn at [t] (0 = hard left, 1 = hard right) that keeps a
  /// sprite [spriteWidth] wide completely inside the wooden lane, so nothing
  /// ever overhangs a rope rail or lands out on the scenery.
  double _laneX(double t, double spriteWidth) {
    final margin = spriteWidth / 2 + 4;
    final lo = innerLeft + margin;
    final hi = innerRight - margin;
    if (hi <= lo) return innerLeft + innerWidth / 2;
    return lo + t.clamp(0.0, 1.0) * (hi - lo);
  }

  void _spawnObstacle() {
    final t = _rng.nextDouble();
    final roll = _rng.nextDouble();
    final EntityType type;
    if (roll < 0.18) {
      type = EntityType.spring;
    } else if (roll < 0.6) {
      type = EntityType.pencil;
    } else {
      type = EntityType.eraser;
    }
    final span = type == EntityType.pencil ? 86.0 : 68.0;
    entities.add(Entity(type, _laneX(t, span), -70, span));
  }

  void _spawnPickups() {
    final roll = _rng.nextDouble();
    if (roll < 0.12) {
      // Power-up.
      final kind = PowerKind.values[_rng.nextInt(PowerKind.values.length)];
      entities.add(Entity(
          EntityType.powerup, _laneX(_rng.nextDouble(), 62), -70, 62,
          power: kind));
      return;
    }
    if (roll < 0.22) {
      entities.add(
          Entity(EntityType.star, _laneX(_rng.nextDouble(), 56), -70, 56));
      return;
    }
    // A short arc of coins.
    final baseT = _rng.nextDouble();
    final count = 3 + _rng.nextInt(3);
    for (int i = 0; i < count; i++) {
      final t = (baseT + i * 0.06) % 1.0;
      entities.add(Entity(EntityType.coin, _laneX(t, 42), -70 - i * 52.0, 42));
      _coinsSpawned++;
    }
  }

  // ---- Result --------------------------------------------------------------
  int computeStars() {
    if (status != RaceStatus.finished) return 0;
    int s = 1;
    final ratio = _coinsSpawned == 0 ? 0 : _coinsCollected / _coinsSpawned;
    if (energy >= 40) s++;
    if (ratio >= 0.55) s++;
    return s.clamp(1, 3);
  }

  int computeScore() =>
      (coins * 10 + distance ~/ 6 + starsPicked * 25 + energy.round());

  int coinReward() {
    final base = level.coinReward ~/ 2 + coins * 3;
    return eventBonus ? base * 2 : base;
  }
}

class Puff {
  Puff(this.x, this.y);
  double x;
  double y;
  double life = 1.0;
  double scale = 0.6;
}
