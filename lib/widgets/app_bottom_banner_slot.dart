import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

/// Shared bottom banner slot for menu, setup, and gameplay screens.
///
/// [GameKitBannerSlot] owns no-fill collapse and only applies padding once an
/// actual banner is visible.
class AppBottomBannerSlot extends StatelessWidget {
  const AppBottomBannerSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: GameKitBannerSlot(padding: EdgeInsets.only(top: 10, bottom: 8)),
    );
  }
}
