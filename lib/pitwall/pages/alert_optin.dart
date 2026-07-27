import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../config/track_config.dart';
import '../infra/pit_vault.dart';
import '../infra/pulse_hub.dart';
import 'pit_button.dart';

/// Push opt-in promo shown before the WebView on first entry into gray mode.
class AlertOptin extends StatefulWidget {
  const AlertOptin({
    super.key,
    required this.vault,
    required this.pulse,
    required this.nextBuilder,
  });

  final PitVault vault;
  final PulseHub pulse;
  final WidgetBuilder nextBuilder;

  @override
  State<AlertOptin> createState() => _AlertOptinState();
}

class _AlertOptinState extends State<AlertOptin> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The splash locks orientation right before routing here — re-enable both.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final granted = await widget.pulse.askPermission();
    if (!granted) await _snooze();
    _continue();
  }

  Future<void> _skip() async {
    if (_working) return;
    setState(() => _working = true);
    await _snooze();
    _continue();
  }

  Future<void> _snooze() {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        TrackConfig.pushSnoozeSeconds;
    return widget.vault.snoozePushInvite(until);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: widget.nextBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final btnWidth = landscape
        ? (media.size.width * 0.42).clamp(300.0, 520.0)
        : (media.size.width * 0.80).clamp(280.0, 440.0);

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: GameBackground(
        overlay: 0,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 28,
              vertical: landscape ? 12 : 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: landscape ? 92 : 116,
                  height: landscape ? 92 : 116,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink, width: 3),
                    boxShadow: AppShadow.glow(AppColors.yellow, strength: 0.55),
                  ),
                  child: Icon(Icons.notifications_active_rounded,
                      color: Colors.white, size: landscape ? 48 : 60),
                ),
                SizedBox(height: landscape ? 16 : 24),
                StrokeText(
                  'ALLOW NOTIFICATIONS ABOUT\nBONUSES AND PROMOS',
                  style: AppText.title(landscape ? 22 : 25),
                  strokeWidth: 4,
                ),
                const SizedBox(height: 12),
                Text(
                  'Stay tuned for special offers and rewards',
                  textAlign: TextAlign.center,
                  style: AppText.body(16, color: AppColors.textMuted),
                ),
                SizedBox(height: landscape ? 20 : 30),
                PitButton(
                  width: btnWidth,
                  label: 'Accept',
                  icon: Icons.check_rounded,
                  gradient: AppColors.greenGradient,
                  lip: AppColors.greenDark,
                  height: landscape ? 62 : 70,
                  fontSize: landscape ? 22 : 24,
                  busy: _working,
                  onTap: _accept,
                ),
                SizedBox(height: landscape ? 12 : 16),
                PitButton(
                  width: btnWidth * 0.9,
                  label: 'Skip',
                  gradient: AppColors.sunsetGradient,
                  lip: AppColors.redDark,
                  height: landscape ? 56 : 62,
                  fontSize: landscape ? 20 : 22,
                  onTap: _working ? () {} : _skip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
