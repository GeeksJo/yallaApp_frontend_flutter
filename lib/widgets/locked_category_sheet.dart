import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:yalla/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/coin_provider.dart';
import '../theme/app_theme.dart';
import 'responsive_layout.dart';

class LockedCategorySheet extends StatelessWidget {
  final GameCategory category;

  const LockedCategorySheet({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final coinProvider = context.watch<CoinProvider>();
    final isTablet = ResponsiveLayout.isTablet(context);
    final sheetPad = isTablet
        ? const EdgeInsets.symmetric(horizontal: 28, vertical: 28)
        : AppSpacing.screenPadding;
    final titleSize = isTablet ? 26.0 : 22.0;
    final iconTop = isTablet ? 56.0 : 48.0;
    final coinsSize = isTablet ? 17.0 : 14.0;
    final coinIcon = isTablet ? 22.0 : 18.0;

    return Container(
      padding: sheetPad,
      decoration: AppDecorations.bottomSheet,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: isTablet ? 24 : 20),
          Icon(category.icon, color: category.color, size: iconTop),
          SizedBox(height: isTablet ? 10 : 8),
          Text(
            category.name(Localizations.localeOf(context).languageCode),
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: AppColors.textPrimary,
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isTablet ? 6 : 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.monetization_on, color: AppColors.coin, size: coinIcon),
              const SizedBox(width: 4),
              Text(
                '${coinProvider.coins} ${l10n.coins}',
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textSecondary,
                  fontSize: coinsSize,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 28 : 24),
          _buildOption(
            context,
            isTablet: isTablet,
            icon: Icons.timer,
            label: l10n.rentFor2Hours,
            cost: '${CoinProvider.rentCost}',
            enabled: coinProvider.coins >= CoinProvider.rentCost,
            onTap: () async {
              final success = await coinProvider.rentCategory(category.key);
              if (context.mounted) {
                Navigator.pop(context, success);
              }
            },
          ),
          SizedBox(height: isTablet ? 14 : 12),
          _buildOption(
            context,
            isTablet: isTablet,
            icon: Icons.star,
            label: l10n.buyForever,
            cost: '${CoinProvider.buyCost}',
            enabled: coinProvider.coins >= CoinProvider.buyCost,
            onTap: () async {
              final success = await coinProvider.buyCategory(category.key);
              if (context.mounted) {
                Navigator.pop(context, success);
              }
            },
          ),
          SizedBox(height: isTablet ? 14 : 12),
          _buildOption(
            context,
            isTablet: isTablet,
            icon: Icons.play_circle_fill,
            label: '${l10n.watchAd} - ${l10n.earnCoins}',
            cost: '+${CoinProvider.adReward}',
            // Always tappable now: the chain decides what to do, and a
            // readiness gate here just meant a permanently dead button
            // whenever inventory had not warmed yet.
            enabled: true,
            isAd: true,
            onTap: () async {
              final AdGrantOutcome outcome =
                  await coinProvider.watchAdForCoins();
              if (!context.mounted) return;
              // The kit owns the copy, so each of the three non-granting
              // outcomes says something true. The old code discarded the
              // result entirely, so a failed watch was completely silent.
              final AdGrantNotice? notice = outcome.notice(
                GameKitLocalizations.of(context),
              );
              if (notice != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(notice.message)),
                );
              }
            },
          ),
          SizedBox(height: isTablet ? 20 : 16),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required bool isTablet,
    required IconData icon,
    required String label,
    required String cost,
    required bool enabled,
    required VoidCallback onTap,
    bool isAd = false,
  }) {
    final optPadH = isTablet ? 20.0 : 16.0;
    final optPadV = isTablet ? 18.0 : 14.0;
    final leadIcon = isTablet ? 28.0 : 24.0;
    final labelSize = isTablet ? 18.0 : 15.0;
    final trailIcon = isTablet ? 22.0 : 18.0;
    final costSize = isTablet ? 18.0 : 15.0;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: optPadH, vertical: optPadV),
        decoration: BoxDecoration(
          color: enabled ? AppColors.cardFill : AppColors.textPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(isTablet ? AppRadius.lg : AppRadius.md),
          border: Border.all(
            color: enabled ? AppColors.cardBorder : AppColors.cardFill,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled ? AppColors.textPrimary : AppColors.textHint,
              size: leadIcon,
            ),
            SizedBox(width: isTablet ? 14 : 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  color: enabled ? AppColors.textPrimary : AppColors.textHint,
                  fontSize: labelSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAd ? Icons.play_arrow : Icons.monetization_on,
                  color: isAd
                      ? (enabled ? AppColors.correct : AppColors.textHint)
                      : AppColors.coin,
                  size: trailIcon,
                ),
                const SizedBox(width: 4),
                Text(
                  cost,
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    color: enabled ? AppColors.textPrimary : AppColors.textHint,
                    fontWeight: FontWeight.bold,
                    fontSize: costSize,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
