import 'package:flutter/material.dart';
import 'package:yalla/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_back_button.dart';
import '../widgets/responsive_layout.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTablet = ResponsiveLayout.isTablet(context);

    final steps = [
      (Icons.people, l10n.howToPlayStep1),
      (Icons.category, l10n.howToPlayStep2),
      (Icons.timer, l10n.howToPlayStep3),
      (Icons.touch_app, l10n.howToPlayStep4),
      (Icons.alarm_off, l10n.howToPlayStep5),
      (Icons.emoji_events, l10n.howToPlayStep6),
    ];

    final maxW = ResponsiveLayout.maxWidthFor(
      context,
      phone: 600,
      tabletPortrait: 860,
      tabletLandscape: 1020,
    );
    final hPad = ResponsiveLayout.tabletContentHorizontalInset(context);

    final listPad = isTablet
        ? const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
        : AppSpacing.screenPadding;
    final stepBottom = isTablet ? 28.0 : 16.0;
    final cardPad = isTablet
        ? const EdgeInsets.symmetric(horizontal: 28, vertical: 24)
        : AppSpacing.cardPadding;
    final cardMinHeight = isTablet ? 108.0 : 0.0;
    final indexSize = isTablet ? 62.0 : 40.0;
    final indexFont = isTablet ? 26.0 : 18.0;
    final stepIcon = isTablet ? 44.0 : 28.0;
    final bodyFont = isTablet ? 22.0 : 15.0;
    final gapAfterIndex = isTablet ? 24.0 : 16.0;
    final gapBeforeText = isTablet ? 20.0 : 12.0;

    return Scaffold(
      appBar: AppBar(
        leading: const FeedbackBackButton(),
        title: Text(
          l10n.howToPlay,
          style: TextStyle(
            fontFamily: AppFonts.family,
            fontSize: isTablet ? 28 : 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.gradientBg,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: ResponsiveLayout(
            maxWidth: maxW,
            child: ListView.builder(
              padding: listPad,
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final (icon, text) = steps[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: stepBottom),
                  child: Container(
                    constraints: BoxConstraints(minHeight: cardMinHeight),
                    padding: cardPad,
                    decoration: AppDecorations.card,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: indexSize,
                          height: indexSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: indexFont,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: gapAfterIndex),
                        Icon(
                          icon,
                          color: AppColors.textSecondary,
                          size: stepIcon,
                        ),
                        SizedBox(width: gapBeforeText),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(
                              fontFamily: AppFonts.family,
                              color: AppColors.textPrimary,
                              fontSize: bodyFont,
                              height: isTablet ? 1.45 : 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
