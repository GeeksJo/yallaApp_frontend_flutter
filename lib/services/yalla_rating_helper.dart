import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import 'app_navigator.dart';

/// Shows the kit soft rating prompt when policy allows.
///
/// Returns true when the dialog was shown (caller should skip interstitials on
/// the same beat). Uses the root navigator for [showDialog].
Future<bool> presentYallaRatingPromptIfEligible({
  BuildContext? context,
  required int level,
}) async {
  final hostContext =
      context ?? appNavigatorKey.currentContext;
  if (hostContext == null || !hostContext.mounted) {
    return false;
  }

  var shouldShow = false;
  final softSub = GameKit.rating.onShouldShowSoftPrompt.listen((_) {
    shouldShow = true;
  });
  final feedbackSub = GameKit.rating.onShouldShowFeedbackForm.listen((_) {
    unawaited(GameAnalytics.logFeedbackEmailOpened());
  });
  try {
    await GameKit.rating.levelSucceeded(
      level: level,
      gameName: 'Yalla! - 5 seconds',
    );
  } finally {
    await softSub.cancel();
    await feedbackSub.cancel();
  }

  if (!shouldShow) return false;

  final dialogContext =
      appNavigatorKey.currentContext ?? hostContext;
  if (!dialogContext.mounted) return false;

  final l10n =
      Localizations.of<GameKitLocalizations>(
        dialogContext,
        GameKitLocalizations,
      ) ??
      lookupGameKitLocalizations(GameKit.locale);
  final host = GameKitSettingsDialogs.dialogHostingContext(dialogContext);
  final ui = GameKit.settingsUi;
  final colors = ui == null
      ? null
      : GameKitSettingsDialogColors.fromConfig(
          seedColor: ui.seedColor,
          dialog: ui.dialog,
          removeAdsIconAssetPath: ui.removeAdsIconAssetPath,
        );

  final bool? positive = await showDialog<bool>(
    context: host,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: colors?.alertSurface,
        shape: colors == null
            ? null
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colors.alertOutline),
              ),
        title: Text(
          l10n.ratingEnjoyingTitle,
          style: TextStyle(
            fontFamily: ui?.fontFamily,
            fontWeight: FontWeight.w800,
            color: colors?.alertTitle,
          ),
        ),
        content: Text(
          l10n.ratingEnjoyingBody,
          style: TextStyle(
            fontFamily: ui?.fontFamily,
            color: colors?.alertBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.ratingNotReally,
              style: TextStyle(
                fontFamily: ui?.fontFamily,
                color: colors?.alertBody,
              ),
            ),
          ),
          FilledButton(
            style: colors == null
                ? null
                : FilledButton.styleFrom(backgroundColor: colors.seed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ratingNow),
          ),
        ],
      );
    },
  );

  if (positive == null) {
    await GameKit.rating.respond(RatingResponse.dismissed);
    return true;
  }

  if (positive) {
    await GameKit.rating.respond(RatingResponse.positive);
    return true;
  }

  await GameKit.rating.respond(RatingResponse.negative);
  await GameKitRatingPrompt.openFeedbackMailto();
  return true;
}

/// Kit counts a session on cold start; after the first success, bump once so
/// engaged first-day players can reach session ≥ 2 for the soft prompt.
Future<void> bumpRatingSessionAfterFirstSuccess(int successLevel) async {
  if (successLevel != 1) return;
  await GameKit.rating.registerSessionLaunch();
}
