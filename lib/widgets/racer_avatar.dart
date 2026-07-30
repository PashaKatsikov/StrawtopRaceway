import 'package:flutter/material.dart';

import '../data/assets.dart';
import '../data/game_state.dart';
import '../theme/app_theme.dart';

/// Circular racer portrait. Shows the player's own profile photo once one has
/// been picked, and falls back to the default hero art otherwise. Used by both
/// the main-menu header and the profile screen so the two never drift apart.
class RacerAvatar extends StatelessWidget {
  const RacerAvatar({
    super.key,
    required this.size,
    this.showBadge = false,
    this.borderWidth = 3,
    this.onTap,
  });

  final double size;

  /// Draws the little camera badge that hints the photo can be changed.
  final bool showBadge;

  final double borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Listens to the store itself rather than relying on the caller: a const
    // instance of this widget is skipped by the element update short-circuit,
    // so a parent rebuild alone would leave a stale portrait on screen.
    return AnimatedBuilder(
      animation: GameState.instance,
      builder: (context, _) => _portrait(),
    );
  }

  Widget _portrait() {
    final photo = GameState.instance.avatarPhoto;
    final badge = (size * 0.34).clamp(24.0, 34.0);

    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.blueGradient,
        border: borderWidth > 0
            ? Border.all(color: Colors.white, width: borderWidth)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: photo != null
          ? Image.memory(
              photo,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  Image.asset(A.mainHero, fit: BoxFit.cover),
            )
          : Image.asset(A.mainHero, fit: BoxFit.cover),
    );

    final content = showBadge
        ? SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                circle,
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: badge,
                    height: badge,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.goldGradient,
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      color: Colors.white,
                      size: badge * 0.56,
                    ),
                  ),
                ),
              ],
            ),
          )
        : circle;

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
