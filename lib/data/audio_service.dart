import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'game_state.dart';

/// Central audio manager.
///
/// * One background-music player – menu and game tracks never overlap because
///   switching the source stops the previous track.
/// * A small round-robin pool of players for short sound effects so several
///   can overlap without cutting each other off.
/// * Music pauses when the app goes to the background and resumes on return.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const String menuTrack = 'audio/music_menu.mp3';
  static const String gameTrack = 'audio/music_game.mp3';

  static const String sfxClick = 'audio/sfx_click.wav';
  static const String sfxCoin = 'audio/sfx_coin.wav';
  static const String sfxStar = 'audio/sfx_star.wav';
  static const String sfxHit = 'audio/sfx_hit.wav';
  static const String sfxPower = 'audio/sfx_power.wav';
  static const String sfxWin = 'audio/sfx_win.wav';
  static const String sfxLose = 'audio/sfx_lose.wav';
  static const String sfxGo = 'audio/sfx_go.wav';

  final AudioPlayer _music = AudioPlayer(playerId: 'bgm');
  final List<AudioPlayer> _sfxPool =
      List.generate(3, (i) => AudioPlayer(playerId: 'sfx$i'));
  int _sfxIndex = 0;

  String? _currentTrack; // desired track (menu or game), null = silent
  bool _initialised = false;
  bool _backgrounded = false;
  bool _switching = false; // guards against overlapping start calls
  Timer? _watchdog;
  final Map<String, int> _lastPlayed = {};

  GameState get _gs => GameState.instance;

  double get _musicVol => _gs.musicVolume;
  double get _sfxVol => _gs.sfxVolume;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    // CRITICAL: use "mix with others" everywhere. On Android this maps to
    // AndroidAudioFocus.none, so a sound effect (button click, coin pickup)
    // NEVER steals audio focus from the looping music player. Without this,
    // every click/coin paused the music and it never came back.
    final ctx = AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build();
    try {
      await AudioPlayer.global.setAudioContext(ctx);
    } catch (_) {}
    try {
      await _music.setAudioContext(ctx);
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicVol);
    } catch (_) {}
    for (final p in _sfxPool) {
      try {
        await p.setAudioContext(ctx);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setVolume(_sfxVol);
      } catch (_) {}
    }
    // Self-healing watchdog: whatever navigation the player does, this makes
    // sure the desired track is actually playing. Fixes the "go to settings
    // and back, music is gone" class of bugs once and for all.
    _watchdog ??= Timer.periodic(
        const Duration(milliseconds: 1200), (_) => _ensurePlaying());
  }

  void _ensurePlaying() {
    if (_backgrounded || _switching) return;
    final track = _currentTrack;
    if (track == null || !_gs.musicOn) return;
    final st = _music.state;
    if (st == PlayerState.playing) return;
    // Prefer a cheap resume over a full (heavy) restart of the track.
    if (st == PlayerState.paused) {
      _music.resume().catchError((_) {});
    } else {
      _startTrack(track);
    }
  }

  // ---- Music ---------------------------------------------------------------
  Future<void> playMenuMusic() => _playTrack(menuTrack);
  Future<void> playGameMusic() => _playTrack(gameTrack);

  Future<void> _playTrack(String track) async {
    await init();
    final switchingTrack = _currentTrack != track;
    _currentTrack = track;
    if (!_gs.musicOn || _backgrounded) return;
    // Start it if we're changing tracks or it isn't currently playing.
    if (switchingTrack || _music.state != PlayerState.playing) {
      await _startTrack(track);
    }
  }

  /// Cleanly (re)starts a track: stop the old one, then play. stop() and play()
  /// live in separate try/catch blocks so a throwing stop() (e.g. on a fresh
  /// player) can never swallow the play() call.
  Future<void> _startTrack(String track) async {
    if (_switching) return;
    _switching = true;
    try {
      await _music.stop();
    } catch (_) {}
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.play(AssetSource(track), volume: _musicVol);
    } catch (_) {}
    _switching = false;
  }

  Future<void> stopMusic() async {
    _currentTrack = null;
    try {
      await _music.stop();
    } catch (_) {}
  }

  Future<void> setMusicEnabled(bool on) async {
    await init();
    if (on) {
      if (_currentTrack != null && !_backgrounded) {
        await _startTrack(_currentTrack!);
      }
    } else {
      try {
        await _music.pause();
      } catch (_) {}
    }
  }

  /// Live-update the music volume from the settings slider.
  Future<void> setMusicVolume(double v) async {
    await init();
    try {
      await _music.setVolume(v);
    } catch (_) {}
  }

  // ---- Sound effects -------------------------------------------------------
  Future<void> sfx(String asset) async {
    if (!_gs.soundOn || _sfxVol <= 0.001 || _backgrounded) return;
    // Debounce identical effects so rapid pickups don't flood the platform.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastPlayed[asset] ?? 0) < 40) return;
    _lastPlayed[asset] = now;
    await init();
    final player = _sfxPool[_sfxIndex];
    _sfxIndex = (_sfxIndex + 1) % _sfxPool.length;
    try {
      await player.play(AssetSource(asset), volume: _sfxVol);
    } catch (_) {}
  }

  void click() => sfx(sfxClick);
  void coin() => sfx(sfxCoin);
  void star() => sfx(sfxStar);
  void hit() => sfx(sfxHit);
  void power() => sfx(sfxPower);
  void win() => sfx(sfxWin);
  void lose() => sfx(sfxLose);
  void go() => sfx(sfxGo);

  // ---- Lifecycle -----------------------------------------------------------
  Future<void> onBackground() async {
    _backgrounded = true;
    try {
      await _music.pause();
    } catch (_) {}
    for (final p in _sfxPool) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }

  Future<void> onForeground() async {
    _backgrounded = false;
    // The watchdog will re-assert playback, but kick it off immediately too.
    if (_gs.musicOn && _currentTrack != null) {
      await _startTrack(_currentTrack!);
    }
  }
}
