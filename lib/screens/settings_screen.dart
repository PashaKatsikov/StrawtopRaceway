import 'package:flutter/material.dart';
import '../data/audio_service.dart';
import '../data/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'webview_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final gs = GameState.instance;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playMenuMusic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        overlay: 0.45,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: gs,
            builder: (context, _) => Column(
              children: [
                TopBar(title: 'Settings', onBack: () => Navigator.pop(context)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Panel(
                                child: Column(
                                  children: [
                                    _toggle('Music', Icons.music_note_rounded,
                                        gs.musicOn, (v) {
                                      gs.setMusic(v);
                                      AudioService.instance.setMusicEnabled(v);
                                    }),
                                    _slider(
                                      Icons.library_music_rounded,
                                      gs.musicVolume,
                                      gs.musicOn,
                                      (v) {
                                        gs.setMusicVolume(v);
                                        AudioService.instance.setMusicVolume(v);
                                      },
                                      onChangeEnd: (_) => gs.saveSettings(),
                                    ),
                                    const Divider(color: Colors.white12),
                                    _toggle('Sound Effects',
                                        Icons.volume_up_rounded, gs.soundOn,
                                        gs.setSound),
                                    _slider(
                                      Icons.graphic_eq_rounded,
                                      gs.sfxVolume,
                                      gs.soundOn,
                                      (v) => gs.setSfxVolume(v),
                                      onChangeEnd: (_) {
                                        gs.saveSettings();
                                        AudioService.instance.click();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Panel(
                                child: Column(
                                  children: [
                                    _nameEditor(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            children: [
                              Panel(
                                child: Column(
                                  children: [
                                    _link('Privacy Policy', Icons.privacy_tip_rounded,
                                        () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const WebViewPage(
                                            title: 'Privacy Policy',
                                            url: LegalContent.privacyUrl,
                                            fallbackHtml:
                                                LegalContent.privacyHtml,
                                          ),
                                        ),
                                      );
                                    }),
                                    const Divider(color: Colors.white12),
                                    _link('Support', Icons.support_agent_rounded,
                                        () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const WebViewPage(
                                            title: 'Support',
                                            url: LegalContent.supportUrl,
                                            fallbackHtml:
                                                LegalContent.supportHtml,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Panel(
                                child: Column(
                                  children: [
                                    _link('Reset Progress',
                                        Icons.restart_alt_rounded, _confirmReset,
                                        danger: true),
                                    const Divider(color: Colors.white12),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text('Version 1.0.0',
                                          style: AppText.body(12,
                                              color: AppColors.textMuted)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: AppText.body(15, weight: FontWeight.w700)),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.green,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _slider(IconData icon, double value, bool enabled,
      ValueChanged<double> onChanged,
      {ValueChanged<double>? onChangeEnd}) {
    return Row(
      children: [
        Icon(icon,
            size: 20,
            color: enabled ? AppColors.blue : Colors.white24),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.green,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: AppColors.green.withValues(alpha: 0.2),
              trackHeight: 5,
            ),
            child: Slider(
              value: value,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text('${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: AppText.body(13, color: AppColors.textMuted)),
        ),
      ],
    );
  }

  Widget _link(String label, IconData icon, VoidCallback onTap,
      {bool danger = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, color: danger ? AppColors.red : AppColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppText.body(15,
                      weight: FontWeight.w700,
                      color: danger ? AppColors.red : AppColors.textLight)),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _nameEditor() {
    final controller = TextEditingController(text: gs.playerName);
    return Row(
      children: [
        const Icon(Icons.person_rounded, color: AppColors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            style: AppText.body(15, weight: FontWeight.w700),
            maxLength: 14,
            decoration: const InputDecoration(
              counterText: '',
              labelText: 'Racer name',
              labelStyle: TextStyle(color: AppColors.textMuted),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.blue)),
            ),
            onSubmitted: (v) {
              gs.setName(v);
              showToast(context, 'Name saved');
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check_rounded, color: AppColors.green),
          onPressed: () {
            gs.setName(controller.text);
            showToast(context, 'Name saved');
          },
        ),
      ],
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Reset progress?',
            style: AppText.body(18, weight: FontWeight.w800)),
        content: Text('This will erase all coins, tops and stars.',
            style: AppText.body(14, color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppText.body(14)),
          ),
          TextButton(
            onPressed: () {
              gs.resetProgress();
              Navigator.pop(context);
              showToast(context, 'Progress reset');
            },
            child: Text('Reset',
                style: AppText.body(14, color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}
