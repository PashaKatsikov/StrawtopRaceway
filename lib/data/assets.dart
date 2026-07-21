/// Central registry of every image asset used by the game.
class A {
  static const String _p = 'assets/';

  // Backgrounds
  static const String kitchenBg = '${_p}kitchen_bg.webp';
  static const String schoolBg = '${_p}school_bg.webp';
  static const String playgroundBg = '${_p}playgroung_bg.webp';
  static const String storeBg = '${_p}store_bg.webp';
  static const String loadingH = '${_p}Horizontal_Loading_Screen.webp';
  static const String loadingV = '${_p}Vertical_Loading_Screen.webp';

  // Spinning tops (skins)
  static const String topDefault = '${_p}spinning_top_default.webp';
  static const String topFire = '${_p}spinning_top_fire.webp';
  static const String topIce = '${_p}spinning_top_ice.webp';

  // Track pieces
  static const String directRoad = '${_p}direct_road.webp';
  static const String cornerRoad = '${_p}corner_road.webp';
  static const String finish = '${_p}finish.webp';

  // Obstacles
  static const String pencil = '${_p}pencil.webp';
  static const String eraser = '${_p}eraser.webp';
  static const String springboard = '${_p}springboard.webp';

  // Pickups / powerups
  static const String coin = '${_p}coin.webp';
  static const String star = '${_p}star.webp';
  static const String powerUp = '${_p}power-up.webp';
  static const String beckonsBuff = '${_p}beckons_buff.webp';
  static const String crashBuff = '${_p}crash_buff.webp';
  static const String iceBuff = '${_p}ice_buff.webp';
  static const String shieldBuff = '${_p}shield_buff.webp';

  // UI
  static const String buttonPlay = '${_p}button_play.webp';
  static const String barSpinning = '${_p}bar_spinning.webp';
  static const String timer = '${_p}timer.webp';
  static const String mainHero = '${_p}main_hero.webp';
  static const String icon = '${_p}icon.png';

  // Location icons
  static const String locKitchen = '${_p}location_icon_kitchen.webp';
  static const String locSchool = '${_p}location_icon_school.webp';
  static const String locPlayground = '${_p}location_icon_playground.webp';

  // Sprite sheet
  static const String effects = '${_p}effects.webp';

  /// Every asset that should be pre-warmed on the loading screen.
  static const List<String> preload = [
    kitchenBg, schoolBg, playgroundBg, storeBg,
    topDefault, topFire, topIce,
    directRoad, cornerRoad, finish,
    pencil, eraser, springboard,
    coin, star, powerUp, beckonsBuff, crashBuff, iceBuff, shieldBuff,
    buttonPlay, barSpinning, timer, mainHero, icon,
    locKitchen, locSchool, locPlayground, effects,
  ];
}
