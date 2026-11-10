import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

/// Stable GA4 `game_name`. Same value as share analytics.
const yallaAnalyticsGameName = 'yalla';

/// Placement shared by the coin-ad offer and `requestAdGrant`.
const yallaFreeCoinsPlacement = 'free_coins';

/// Rewarded-offer analytics for one opening of the locked-category sheet.
///
/// One `ad_rewarded_offered` when the sheet shows the watch-ad option, and at
/// most one `ad_rewarded_declined`: the ad was closed early, or the sheet
/// closed without the player tapping watch. Nothing is logged when
/// [offered] is false (Remove Ads: the chain grants without an ad). The kit
/// logs `ad_grant` / `ad_rewarded_completed` for the watch itself.
class YallaRewardedOffer {
  YallaRewardedOffer({
    required this.offered,
    this.placement = yallaFreeCoinsPlacement,
  });

  final bool offered;
  final String placement;
  bool _shown = false;
  bool _watchTapped = false;
  bool _declined = false;

  void shown() {
    if (!offered || _shown) return;
    _shown = true;
    unawaited(GameAnalytics.logAdRewardedOffered(placement));
  }

  void watchTapped() => _watchTapped = true;

  void watchFinished(AdGrantOutcome outcome) {
    if (outcome == AdGrantOutcome.skipped) _decline();
  }

  void closed() {
    if (!_watchTapped) _decline();
  }

  void _decline() {
    if (!_shown || _declined) return;
    _declined = true;
    unawaited(GameAnalytics.logAdRewardedDeclined(placement));
  }
}

abstract final class YallaRoute {
  static const home = '/';
  static const settings = '/settings';
  static const howToPlay = '/how-to-play';
  static const playerSetup = '/player-setup';
  static const categories = '/categories';
  static const stageStart = '/stage-start';
  static const question = '/question';
  static const pass = '/pass';
  static const scoreboard = '/scoreboard';
}

/// Readable `screen_view` names. Setup screens stay out of the play session.
const yallaScreenNames = <String, String>{
  YallaRoute.home: 'Home Screen',
  YallaRoute.settings: 'Settings Screen',
  YallaRoute.howToPlay: 'How To Play Screen',
  YallaRoute.playerSetup: 'Player Setup Screen',
  YallaRoute.categories: 'Category Selection Screen',
  YallaRoute.stageStart: 'Stage Start Screen',
  YallaRoute.question: 'Question Screen',
  YallaRoute.pass: 'Pass Screen',
  YallaRoute.scoreboard: 'Scoreboard Screen',
};

MaterialPageRoute<T> yallaPage<T>({
  required String name,
  required WidgetBuilder builder,
}) {
  return MaterialPageRoute<T>(
    settings: RouteSettings(name: name),
    builder: builder,
  );
}

/// The first turn of round 1. Later turns and setup screens are not a new game.
bool yallaSessionShouldStart({required int round, required int playerIndex}) {
  return round == 1 && playerIndex == 0;
}

Future<void> yallaSessionStarted(Iterable<String> categoryIds) {
  if (GameSessionTracker.activeGame != null) return Future<void>.value();
  return GameSessionTracker.onStarted(
    yallaAnalyticsGameName,
    categoryIds: categoryIds,
  );
}

Future<void> yallaSessionCompleted() {
  return GameSessionTracker.onCompleted(yallaAnalyticsGameName);
}

void yallaSessionAbandoned() {
  GameSessionTracker.onAbandoned();
}

/// Play Again returns to category setup. The next session starts on the
/// first answer, not on this tap.
Future<void> yallaSessionReplaySetup() {
  return GameSessionTracker.logReplayedOnly(yallaAnalyticsGameName);
}
