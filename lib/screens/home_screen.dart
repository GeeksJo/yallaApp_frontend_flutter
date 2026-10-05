import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:yalla/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../providers/locale_provider.dart';
import '../providers/game_provider.dart';
import '../services/game_feedback.dart';
import '../services/yalla_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_banner_slot.dart';
import '../widgets/app_cross_promo.dart';
import '../widgets/responsive_layout.dart';
import 'category_selection_screen.dart';
import 'settings_screen.dart';
import 'how_to_play_screen.dart';
import 'player_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  bool _useLandscapeSplit(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ResponsiveLayout.isLandscape(context) && size.width >= 560;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = context.watch<LocaleProvider>().isArabic;
    final isTablet = ResponsiveLayout.isTablet(context);
    final split = _useLandscapeSplit(context);
    final screenW = MediaQuery.sizeOf(context).width;
    // Tablet portrait: avoid stacking global tablet inset + narrow maxWidth - that
    // letterboxes the UI. Use a small outer gutter and let content span nearly full width.
    final outerHorizontal = !isTablet ? 16.0 : (split ? 20.0 : 12.0);
    final maxW = !isTablet
        ? 600.0
        : (split
              ? 960.0
              : (screenW - 2 * outerHorizontal).clamp(720.0, 1000.0));
    final titleSize = split
        ? (isTablet ? 64.0 : 44.0)
        : (isTablet ? 122.0 : 64.0);
    final gifSize = split
        ? (isTablet ? 235.0 : 160.0)
        : (isTablet ? 380.0 : 220.0);
    final modeButtonGap = isTablet ? 16.0 : 12.0;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.gradientBg,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: outerHorizontal),
                  child: ResponsiveLayout(
                    maxWidth: maxW,
                    child: Stack(
                      children: [
                        Positioned(
                          top: -120,
                          right: -120,
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -140,
                          left: -120,
                          child: Container(
                            width: 320,
                            height: 320,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.10),
                            ),
                          ),
                        ),
                        if (split)
                          _HomeLandscapeBody(
                            l10n: l10n,
                            isArabic: isArabic,
                            isTablet: isTablet,
                            titleSize: titleSize,
                            gifSize: gifSize,
                            modeButtonGap: modeButtonGap,
                            isRtl: isRtl,
                          )
                        else
                          _HomePortraitScrollBody(
                            l10n: l10n,
                            isArabic: isArabic,
                            isTablet: isTablet,
                            titleSize: titleSize,
                            gifSize: gifSize,
                            modeButtonGap: modeButtonGap,
                            isRtl: isRtl,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const AppBottomBannerSlot(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePortraitScrollBody extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isArabic;
  final bool isTablet;
  final double titleSize;
  final double gifSize;
  final double modeButtonGap;
  final bool isRtl;

  const _HomePortraitScrollBody({
    required this.l10n,
    required this.isArabic,
    required this.isTablet,
    required this.titleSize,
    required this.gifSize,
    required this.modeButtonGap,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = isTablet ? 12.0 : 20.0;
    final afterSettings = isTablet ? 0.0 : 20.0;
    final afterGif = isTablet ? 2.0 : 5.0;
    final afterModeLabel = isTablet ? 2.0 : 5.0;
    final beforeFooter = isTablet ? 16.0 : 14.0;
    final settingsV = isTablet ? 10.0 : 8.0;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.only(bottom: isTablet ? 0 : 24),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(10, settingsV, 10, settingsV),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SettingsTopChip(
                        onTap: () => Navigator.push(
                          context,
                          yallaPage(
                            name: YallaRoute.settings,
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                      GameKitRemoveAdsIconButton(height: 40, width: 40),
                    ],
                  ),
                ),
                SizedBox(height: afterSettings),
                Padding(
                  padding: isTablet
                      ? EdgeInsets.symmetric(vertical: 100)
                      : const EdgeInsets.all(0.0),
                  child: Column(
                    children: [
                      Text(
                        l10n.appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      ),
                      Image.asset(
                        'assets/images/yalla.png',
                        width: gifSize,
                        height: gifSize,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(height: afterGif),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: Align(
                          alignment: isRtl
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text(
                            isArabic ? 'اختر نمط اللعب' : 'Choose game mode',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: isTablet ? 26 : 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: afterModeLabel),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: _HomeModeButtons(
                          l10n: l10n,
                          isArabic: isArabic,
                          isTablet: isTablet,
                          modeButtonGap: modeButtonGap,
                          isRtl: isRtl,
                          forceColumn: false,
                        ),
                      ),
                      SizedBox(height: beforeFooter),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: _HomeFooterActions(
                          l10n: l10n,
                          isArabic: isArabic,
                          isRtl: isRtl,
                          isTablet: isTablet,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeLandscapeBody extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isArabic;
  final bool isTablet;
  final double titleSize;
  final double gifSize;
  final double modeButtonGap;
  final bool isRtl;

  const _HomeLandscapeBody({
    required this.l10n,
    required this.isArabic,
    required this.isTablet,
    required this.titleSize,
    required this.gifSize,
    required this.modeButtonGap,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                4,
                isTablet ? 10 : 8,
                12,
                isTablet ? 6 : 24,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _SettingsTopChip(
                        onTap: () => Navigator.push(
                          context,
                          yallaPage(
                            name: YallaRoute.settings,
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isTablet ? 4 : 12),
                  Text(
                    l10n.appName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    'assets/images/yalla.png',
                    width: gifSize,
                    height: gifSize,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: isTablet
                  ? EdgeInsets.symmetric(vertical: 100, horizontal: 12)
                  : EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: isRtl
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Text(
                      isArabic ? 'اختر نمط اللعب' : 'Choose game mode',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: isTablet ? 26 : 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: isTablet ? 10 : 10),
                  _HomeModeButtons(
                    l10n: l10n,
                    isArabic: isArabic,
                    isTablet: isTablet,
                    modeButtonGap: modeButtonGap,
                    isRtl: isRtl,
                    forceColumn: true,
                  ),
                  SizedBox(height: isTablet ? 10 : 10),
                  _HomeFooterActions(
                    l10n: l10n,
                    isArabic: isArabic,
                    isRtl: isRtl,
                    isTablet: isTablet,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeModeButtons extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isArabic;
  final bool isTablet;
  final double modeButtonGap;
  final bool isRtl;
  final bool forceColumn;

  const _HomeModeButtons({
    required this.l10n,
    required this.isArabic,
    required this.isTablet,
    required this.modeButtonGap,
    required this.isRtl,
    required this.forceColumn,
  });

  @override
  Widget build(BuildContext context) {
    final useRow = isTablet && !forceColumn;
    if (useRow) {
      return Row(
        children: [
          Expanded(
            child: _ModeButton(
              icon: Icons.people,
              label: l10n.oneVsOne,
              subtitle: isArabic
                  ? 'شخصين • قلب الشاشة'
                  : '2 players • screen flip',
              isPrimary: true,
              isRtl: isRtl,
              onTap: () {
                context.read<GameProvider>().setMode(GameMode.oneVsOne);
                context.read<GameProvider>().setPlayers(
                  isArabic
                      ? const ['أنا', 'أنت']
                      : const ['Player 1', 'Player 2'],
                );
                Navigator.push(
                  context,
                  yallaPage(
                    name: YallaRoute.categories,
                    builder: (_) => const CategorySelectionScreen(),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: modeButtonGap),
          Expanded(
            child: _ModeButton(
              icon: Icons.groups,
              label: l10n.freeForAll,
              subtitle: isArabic
                  ? '٣+ لاعبين • مرّر الهاتف'
                  : '3+ players • pass phone',
              isPrimary: false,
              isRtl: isRtl,
              onTap: () {
                context.read<GameProvider>().setMode(GameMode.freeForAll);
                Navigator.push(
                  context,
                  yallaPage(
                    name: YallaRoute.playerSetup,
                    builder: (_) => const PlayerSetupScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _ModeButton(
          icon: Icons.people,
          label: l10n.oneVsOne,
          subtitle: isArabic ? 'شخصين • قلب الشاشة' : '2 players • screen flip',
          isPrimary: true,
          isRtl: isRtl,
          onTap: () {
            context.read<GameProvider>().setMode(GameMode.oneVsOne);
            context.read<GameProvider>().setPlayers(
              isArabic
                  ? const ['لاعب ١', 'لاعب ٢']
                  : const ['Player 1', 'Player 2'],
            );
            Navigator.push(
              context,
              yallaPage(
                name: YallaRoute.categories,
                builder: (_) => const CategorySelectionScreen(),
              ),
            );
          },
        ),
        SizedBox(height: modeButtonGap),
        _ModeButton(
          icon: Icons.groups,
          label: l10n.freeForAll,
          subtitle: isArabic
              ? '٣+ لاعبين • مرّر الهاتف'
              : '3+ players • pass phone',
          isPrimary: false,
          isRtl: isRtl,
          onTap: () {
            context.read<GameProvider>().setMode(GameMode.freeForAll);
            Navigator.push(
              context,
              yallaPage(
                name: YallaRoute.playerSetup,
                builder: (_) => const PlayerSetupScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HomeFooterActions extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isArabic;
  final bool isRtl;
  final bool isTablet;

  const _HomeFooterActions({
    required this.l10n,
    required this.isArabic,
    required this.isRtl,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final helpLabelSize = isTablet ? 27.0 : 15.0;
    final helpIconSize = isTablet ? 36.0 : 22.0;
    final gapMoreToHelp = isTablet ? 4.0 : 10.0;

    return Column(
      children: [
        StreamBuilder<bool>(
          initialData: GameKit.crossPromo.hasNewGame,
          stream: GameKit.crossPromo.hasNewGameChanges,
          builder: (context, snap) {
            final showBadge = snap.data ?? false;
            return _MoreGamesPillButton(
              label: l10n.moreGames,
              showBadge: showBadge,
              onTap: () => showAppCrossPromoSheet(context),
              isRtl: isRtl,
            );
          },
        ),
        SizedBox(height: gapMoreToHelp),
        TextButton.icon(
          onPressed: () {
            GameFeedback.tap();
            Navigator.push(
              context,
              yallaPage(
                name: YallaRoute.howToPlay,
                builder: (_) => const HowToPlayScreen(),
              ),
            );
          },
          icon: Icon(
            Icons.help_outline,
            color: AppColors.textSecondary,
            size: helpIconSize,
          ),
          label: Text(
            isArabic ? 'طريقة اللعب' : 'How to play',
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: helpLabelSize,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 22 : 16,
              vertical: isTablet ? 16 : 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTopChip extends StatelessWidget {
  final VoidCallback onTap;

  const _SettingsTopChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveLayout.isTablet(context);
    final iconSize = isTablet ? 36.0 : 22.0;
    final hPad = isTablet ? 22.0 : 10.0;
    final vPad = isTablet ? 16.0 : 8.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () {
              GameFeedback.tap();
              onTap();
            },
            child: Ink(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Icon(
                Icons.settings,
                color: AppColors.textSecondary,
                size: iconSize,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isPrimary;
  final bool isRtl;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isPrimary,
    required this.isRtl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveLayout.isTablet(context);
    const navy = Color(0xFF0C2A77);
    const coral = Color(0xFFFF5E57);
    const magenta = Color(0xFFB0387A);
    const ice = Color(0xFFD9E3FF);
    const ice2 = Color(0xFFC9D7FF);
    const arrowYellow = Color(0xFFF7C64A);

    final fg = navy;
    final sub = navy.withValues(alpha: 0.70);
    final pillBorder = navy.withValues(alpha: 0.18);
    final chevronIcon = isRtl
        ? Icons.chevron_right_rounded
        : Icons.chevron_left_rounded;

    return InkWell(
      onTap: () {
        GameFeedback.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.xl),
      splashColor: Colors.white.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 17 : 18,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPrimary
                ? [ice.withValues(alpha: 0.96), ice2.withValues(alpha: 0.90)]
                : [ice.withValues(alpha: 0.82), ice2.withValues(alpha: 0.74)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: pillBorder),
          boxShadow: [
            BoxShadow(
              color: navy.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
            if (isPrimary)
              BoxShadow(
                color: arrowYellow.withValues(alpha: 0.14),
                blurRadius: 26,
                offset: const Offset(0, 0),
              ),
            if (!isPrimary)
              BoxShadow(
                color: magenta.withValues(alpha: 0.10),
                blurRadius: 22,
                offset: const Offset(0, 0),
              ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border(
            bottom: BorderSide(color: isPrimary ? coral : magenta, width: 3),
          ),
        ),
        child: Row(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Container(
              width: isTablet ? 56 : 46,
              height: isTablet ? 56 : 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: navy.withValues(alpha: 0.20)),
              ),
              child: Icon(icon, color: fg, size: isTablet ? 32 : 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      color: fg,
                      fontSize: isTablet ? 25.0 : 16.5,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      color: sub,
                      fontSize: isTablet ? 17.5 : 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: isTablet ? 46 : 38,
              height: isTablet ? 46 : 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppRadius.round(context)),
                border: Border.all(color: navy.withValues(alpha: 0.18)),
              ),
              child: Icon(
                chevronIcon,
                size: isTablet ? 28 : 24,
                color: fg.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreGamesPillButton extends StatelessWidget {
  final String label;
  final bool showBadge;
  final VoidCallback onTap;
  final bool isRtl;

  const _MoreGamesPillButton({
    required this.label,
    required this.showBadge,
    required this.onTap,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveLayout.isTablet(context);
    // Palette inspired by `assets/images/yalla.png` (logo)
    const ink = Color(0xFF1E2A33);
    const dynamiteRed = Color(0xFFE31B23);
    const cream = Color(0xFFF5F1E6);
    const cream2 = Color(0xFFE9E4D7);
    const accentBlue = Color(0xFF3BA6F2);

    final chevronIcon = isRtl
        ? Icons.chevron_right_rounded
        : Icons.chevron_left_rounded;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () {
            GameFeedback.tap();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.xl),
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 17 : 18,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cream.withValues(alpha: 0.96),
                  cream2.withValues(alpha: 0.92),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: ink.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: ink.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),

                BoxShadow(
                  color: accentBlue.withValues(alpha: 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border(bottom: BorderSide(color: dynamiteRed, width: 3)),
            ),
            child: Stack(
              children: [
                Row(
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    Container(
                      width: isTablet ? 56 : 46,
                      height: isTablet ? 56 : 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: ink.withValues(alpha: 0.14)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isTablet ? 9 : 8),
                        child: Image.asset(
                          'assets/images/game_controller.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.family,
                          color: ink,
                          fontSize: isTablet ? 25.0 : 16.5,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                    Container(
                      width: isTablet ? 46 : 38,
                      height: isTablet ? 46 : 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(
                          AppRadius.round(context),
                        ),
                        border: Border.all(color: ink.withValues(alpha: 0.14)),
                      ),
                      child: Icon(
                        chevronIcon,
                        size: isTablet ? 28 : 24,
                        color: ink.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (showBadge)
          Positioned(
            top: -6,
            right: isRtl ? null : 10,
            left: isRtl ? 10 : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: dynamiteRed,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                'NEW',
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: isTablet ? 13.5 : 12,
                  letterSpacing: 0.6,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
