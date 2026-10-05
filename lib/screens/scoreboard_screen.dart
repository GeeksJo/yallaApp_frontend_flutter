import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:provider/provider.dart';
import 'package:yalla/l10n/app_localizations.dart';

import '../models/player.dart';
import '../providers/game_provider.dart';
import '../services/game_feedback.dart';
import '../services/game_kit_bootstrap.dart';
import '../services/yalla_analytics.dart';
import '../theme/app_theme.dart';
import '../widgets/player_score_tile.dart';
import '../widgets/responsive_layout.dart';
import 'category_selection_screen.dart';
import 'home_screen.dart';

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({
    super.key,
    this.adsRoundFailed = false,
    this.ratingLevel,
    this.debugRankedPlayers,
  }) : assert(debugRankedPlayers == null || kDebugMode);

  /// When true, the match ended after a timed-out round (vs a successful tap).
  final bool adsRoundFailed;

  /// Cumulative correct-answer count. Set only when the match ended on a
  /// success, so the results screen can offer a rating after its ad.
  final int? ratingLevel;

  /// Debug-only: pre-sorted ranking list (highest score first). Skips GameKit work on open.
  final List<Player>? debugRankedPlayers;

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  bool _adShowing = false;

  @override
  void initState() {
    super.initState();
    if (widget.debugRankedPlayers != null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      GameFeedback.completion();
      try {
        await GameKit.notifications.onFirstDailyCompletion();
      } catch (_) {
        // A missing Firebase app or a plugin failure must not block results.
      }
      if (!mounted) return;
      setState(() => _adShowing = true);
      try {
        await GameKitAdBridge.presentRatingThenInterstitialAfterLevel(
          context: context,
          failed: widget.adsRoundFailed,
          ratingLevel: widget.ratingLevel,
          offerRating: widget.ratingLevel != null,
        );
      } finally {
        if (mounted) setState(() => _adShowing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final game = context.watch<GameProvider>();
    final ranked = widget.debugRankedPlayers ?? game.rankedPlayers;
    final isDraw = widget.debugRankedPlayers != null
        ? _isDrawFromRanked(ranked)
        : game.isDraw;
    int rankAt(int index) =>
        ranked.where((p) => p.score > ranked[index].score).length + 1;
    final isTablet = ResponsiveLayout.isTablet(context);
    final landscape = ResponsiveLayout.isLandscape(context);
    final maxW = ResponsiveLayout.maxWidthFor(
      context,
      phone: 560,
      tabletPortrait: 720,
      tabletLandscape: 900,
    );
    final hPad = ResponsiveLayout.tabletContentHorizontalInset(context);

    Widget headerBlock() {
      if (landscape) {
        return Padding(
          padding: EdgeInsets.fromLTRB(12, isTablet ? 12 : 8, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 14 : 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cardFill,
                  border: Border.all(
                    color: AppColors.cardBorder.withValues(alpha: 0.65),
                  ),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.coin,
                  size: isTablet ? 60 : 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scoreboard,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        color: AppColors.textPrimary,
                        fontSize: isTablet ? 40.0 : 22.0,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDraw ? l10n.draw : l10n.score,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        color: AppColors.textMuted,
                        fontSize: isTablet ? 20.0 : 12.0,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return Column(
        children: [
          SizedBox(height: isTablet ? 28 : 20),
          Container(
            padding: EdgeInsets.all(isTablet ? 18 : 14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardFill,
              border: Border.all(
                color: AppColors.cardBorder.withValues(alpha: 0.65),
              ),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: AppColors.coin,
              size: isTablet ? 66 : 36,
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Text(
            l10n.scoreboard,
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: AppColors.textPrimary,
              fontSize: isTablet ? 50.0 : 26.0,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isDraw ? l10n.draw : l10n.score,
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: AppColors.textMuted,
              fontSize: isTablet ? 25.0 : 13.0,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: isTablet ? 22 : 18),
        ],
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: AppDecorations.gradientBg,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: ResponsiveLayout(
                maxWidth: maxW,
                child: Column(
                  children: [
                    headerBlock(),
                    if (landscape) const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        padding: AppSpacing.screenH.copyWith(bottom: 8),
                        itemCount: ranked.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return PlayerScoreTile(
                            player: ranked[index],
                            rank: rankAt(index),
                            isWinner: !isDraw && rankAt(index) == 1,
                            isTablet: isTablet,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: AppSpacing.screenPadding.copyWith(top: 8),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: AppSpacing.buttonHeight(context),
                            child: ElevatedButton(
                              onPressed: () {
                                GameFeedback.tap();
                                unawaited(yallaSessionReplaySetup());
                                game.resetGame();
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  yallaPage(
                                    name: YallaRoute.categories,
                                    builder: (_) =>
                                        const CategorySelectionScreen(),
                                  ),
                                  (route) => route.isFirst,
                                );
                              },
                              style: AppButtonStyles.primary,
                              child: Text(
                                l10n.playAgain,
                                style: TextStyle(fontSize: isTablet ? 30 : 18),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _adShowing
                                ? null
                                : () {
                                    GameFeedback.tap();
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      yallaPage(
                                        name: YallaRoute.home,
                                        builder: (_) => const HomeScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  },
                            child: Text(
                              l10n.home,
                              style: TextStyle(
                                fontFamily: AppFonts.family,
                                color: AppColors.textSecondary,
                                fontSize: isTablet ? 30.0 : 15.0,
                                fontWeight: FontWeight.w600,
                              ),
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
        ),
      ),
    );
  }

  static bool _isDrawFromRanked(List<Player> ranked) {
    if (ranked.length < 2) return false;
    final topScore = ranked.first.score;
    return ranked.where((p) => p.score == topScore).length > 1;
  }
}
