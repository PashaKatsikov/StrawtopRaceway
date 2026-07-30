import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/audio_service.dart';
import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Lets the player set the racer-profile avatar from the camera or the photo
/// library. The image is downscaled by the picker so the stored copy stays
/// small, then handed to [GameState.setAvatarPhoto].
///
/// This is the only place the app touches the camera / photo library, and it
/// is exactly what the `NSCameraUsageDescription` /
/// `NSPhotoLibraryUsageDescription` strings describe.
class AvatarPhotoSheet {
  const AvatarPhotoSheet._();

  static const double _maxEdge = 512;
  static const int _quality = 82;

  /// Opens the chooser. Returns true when the avatar was changed or removed.
  static Future<bool> present(BuildContext context) async {
    final choice = await showModalBottomSheet<_AvatarChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _AvatarSheet(),
    );
    if (choice == null || !context.mounted) return false;

    switch (choice) {
      case _AvatarChoice.camera:
        return _capture(context, ImageSource.camera);
      case _AvatarChoice.library:
        return _capture(context, ImageSource.gallery);
      case _AvatarChoice.remove:
        await GameState.instance.clearAvatarPhoto();
        return true;
    }
  }

  static Future<bool> _capture(BuildContext context, ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: _maxEdge,
        maxHeight: _maxEdge,
        imageQuality: _quality,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked == null) return false;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return false;
      await GameState.instance.setAvatarPhoto(bytes);
      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? "Couldn't open the camera"
                  : "Couldn't open your photo library",
            ),
          ),
        );
      }
      return false;
    }
  }
}

enum _AvatarChoice { camera, library, remove }

class _AvatarSheet extends StatelessWidget {
  const _AvatarSheet();

  @override
  Widget build(BuildContext context) {
    final hasPhoto = GameState.instance.hasAvatarPhoto;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 46,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  StrokeText('PROFILE PHOTO', style: AppText.title(22)),
                  const SizedBox(height: 4),
                  Text(
                    'Give your racer a face',
                    style: AppText.body(14, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 18),
                  ChunkyButton(
                    label: 'Take a photo',
                    icon: Icons.photo_camera_rounded,
                    gradient: AppColors.blueGradient,
                    lip: const Color(0xFF1B4E8C),
                    onTap: () =>
                        Navigator.of(context).pop(_AvatarChoice.camera),
                  ),
                  const SizedBox(height: 12),
                  ChunkyButton(
                    label: 'Choose from library',
                    icon: Icons.photo_library_rounded,
                    gradient: AppColors.goldGradient,
                    lip: AppColors.yellowDark,
                    onTap: () =>
                        Navigator.of(context).pop(_AvatarChoice.library),
                  ),
                  if (hasPhoto) ...<Widget>[
                    const SizedBox(height: 12),
                    ChunkyButton(
                      label: 'Remove photo',
                      icon: Icons.delete_outline_rounded,
                      gradient: AppColors.redGradient,
                      lip: const Color(0xFF8C1B1B),
                      onTap: () =>
                          Navigator.of(context).pop(_AvatarChoice.remove),
                    ),
                  ],
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      AudioService.instance.click();
                      Navigator.of(context).pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Cancel',
                        style: AppText.body(15, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
