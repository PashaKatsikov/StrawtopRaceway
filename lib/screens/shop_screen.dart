import 'package:flutter/material.dart';
import '../data/assets.dart';
import '../data/audio_service.dart';
import '../data/catalog.dart';
import '../data/game_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
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
        image: A.storeBg,
        overlay: 0.6,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: gs,
            builder: (context, _) => Column(
              children: [
                TopBar(title: 'Shop', onBack: () => Navigator.pop(context)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Boosters', Icons.rocket_launch_rounded),
                        const SizedBox(height: 10),
                        _grid(Catalog.boosters),
                        const SizedBox(height: 18),
                        _sectionTitle('Coin Packs', Icons.savings_rounded),
                        const SizedBox(height: 10),
                        _grid(Catalog.coinPacks),
                        const SizedBox(height: 18),
                        _sectionTitle('Free Gems', Icons.card_giftcard_rounded),
                        const SizedBox(height: 10),
                        _freeGems(),
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

  Widget _sectionTitle(String t, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.yellow, size: 22),
        const SizedBox(width: 8),
        StrokeText(t, style: AppText.title(20)),
      ],
    );
  }

  Widget _grid(List<ShopItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.98,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _itemCard(items[i]),
    );
  }

  Widget _itemCard(ShopItem item) {
    final isGem = item.currency == Currency.gems;
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(child: Image.asset(item.asset, fit: BoxFit.contain)),
          const SizedBox(height: 4),
          Text(item.title,
              textAlign: TextAlign.center,
              style: AppText.body(14, weight: FontWeight.w800)),
          Text(item.subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(10, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ChunkyButton(
              label: '${item.price} ${isGem ? '\uD83D\uDC8E' : '\uD83E\uDE99'}',
              height: 40,
              fontSize: 14,
              gradient: isGem ? AppColors.blueGradient : AppColors.goldGradient,
              lip: isGem ? AppColors.blueDark : AppColors.yellowDark,
              onTap: () {
                if (gs.buyShopItem(item)) {
                  showToast(context, 'Purchased ${item.title}!');
                } else {
                  showToast(context, 'Not enough ${isGem ? 'gems' : 'coins'}',
                      good: false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _freeGems() {
    return Panel(
      gradient: const LinearGradient(
        colors: [AppColors.purple, AppColors.blueDark],
      ),
      child: Row(
        children: [
          Image.asset(A.iceBuff, width: 54, height: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Gem Gift',
                    style: AppText.body(15, weight: FontWeight.w800)),
                Text('Complete daily challenges to earn gems for free.',
                    style: AppText.body(11, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
