import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla/l10n/app_localizations.dart';

import '../providers/locale_provider.dart';
import '../services/game_feedback.dart';
import '../theme/app_theme.dart';
import 'responsive_layout.dart';

/// Host language row. Sound and vibration stay on the kit settings body.
class SettingsLanguageRow extends StatelessWidget {
  const SettingsLanguageRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = context.watch<LocaleProvider>();
    final isTablet = ResponsiveLayout.isTablet(context);

    return DecoratedBox(
      decoration: AppDecorations.cardWithBorder,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 14 : 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.language,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textPrimary,
                  fontSize: isTablet ? 22 : 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _LocaleChoice(
              label: l10n.arabic,
              selected: locale.isArabic,
              onTap: () => locale.setLocale(const Locale('ar')),
            ),
            const SizedBox(width: 8),
            _LocaleChoice(
              label: l10n.english,
              selected: !locale.isArabic,
              onTap: () => locale.setLocale(const Locale('en')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocaleChoice extends StatelessWidget {
  const _LocaleChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveLayout.isTablet(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.textPrimary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(
            color: selected ? AppColors.textPrimary : AppColors.cardBorder,
          ),
        ),
        child: InkWell(
          onTap: () {
            GameFeedback.tap();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 18 : 14),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: isTablet ? 18 : 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
