import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';


/// Shared bottom banner slot for menu, setup, and gameplay screens.
///
/// Gates on [GameKit.ads.bannersEnabled] and applies
/// consistent spacing above the banner.
class AppBottomBannerSlot extends StatelessWidget {
  const AppBottomBannerSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: GameKit.ads.bannersEnabled,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const Center(child: GameKitBannerSlot()),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
