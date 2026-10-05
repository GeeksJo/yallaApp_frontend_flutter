import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:yalla/l10n/app_localizations.dart';

import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTablet = ResponsiveLayout.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: TextStyle(
            fontFamily: AppFonts.family,
            fontSize: isTablet ? 30 : null,
            fontWeight: isTablet ? FontWeight.w700 : null,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.gradientBg,
        padding: EdgeInsets.symmetric(vertical: 16),
        child: GameKitSettingsBody(),
      ),
    );
  }
}
