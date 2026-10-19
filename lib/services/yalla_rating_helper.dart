import 'package:flutter/widgets.dart';
import 'package:game_kit/game_kit.dart';

import 'app_navigator.dart';

/// Asks the OS for its native review sheet when kit policy allows.
///
/// No question goes first: Google Play forbids pre-questions such as "Do you
/// like the app?", and a "Not really" branch that skips the store is review
/// gating. The OS decides whether the sheet shows.
///
/// Returns true when a review was requested (caller should skip interstitials
/// on the same beat).
Future<bool> presentYallaRatingPromptIfEligible({
  BuildContext? context,
  required int level,
}) async {
  final hostContext = context ?? appNavigatorKey.currentContext;
  if (hostContext == null || !hostContext.mounted) {
    return false;
  }

  return GameKitRatingPrompt.presentIfEligible(
    hostContext,
    level: level,
    gameName: 'Yalla! - 5 seconds',
  );
}

/// Kit counts a session on cold start; after the first success, bump once so
/// engaged first-day players can reach session ≥ 2 for the rating prompt.
Future<void> bumpRatingSessionAfterFirstSuccess(int successLevel) async {
  if (successLevel != 1) return;
  await GameKit.rating.registerSessionLaunch();
}
