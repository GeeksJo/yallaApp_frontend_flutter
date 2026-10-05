import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla/services/game_kit_bootstrap.dart';
import 'package:yalla/services/yalla_analytics.dart';

class _RecordingSink implements GameAnalyticsSink {
  final events = <String>[];

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    events.add(name);
  }

  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}
}

void main() {
  late _RecordingSink sink;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GameAnalytics.resetForTest();
    GameSessionTracker.resetForTest();
    sink = _RecordingSink();
    GameAnalytics.setSink(sink);
  });

  tearDown(() {
    GameAnalytics.resetForTest();
    GameSessionTracker.resetForTest();
  });

  test('game identity and screen names stay stable', () {
    expect(yallaAnalyticsGameName, 'yalla');
    expect(yallaShareConfig.analyticsGameName, yallaAnalyticsGameName);
    expect(yallaScreenNames[YallaRoute.home], 'Home Screen');
    expect(
      yallaScreenNames[YallaRoute.categories],
      'Category Selection Screen',
    );
    expect(yallaScreenNames[YallaRoute.stageStart], 'Stage Start Screen');
    expect(yallaScreenNames[YallaRoute.question], 'Question Screen');
    expect(yallaScreenNames[YallaRoute.scoreboard], 'Scoreboard Screen');
    expect(yallaScreenNames.values, everyElement(isNot(contains('/'))));
  });

  test('a session starts only on the first turn of round 1', () {
    expect(yallaSessionShouldStart(round: 1, playerIndex: 0), isTrue);
    expect(yallaSessionShouldStart(round: 1, playerIndex: 1), isFalse);
    expect(yallaSessionShouldStart(round: 2, playerIndex: 0), isFalse);
  });

  test('each play boundary logs one event', () async {
    await yallaSessionStarted(const ['animals', 'food']);
    await pumpEventQueue();
    expect(GameSessionTracker.activeGame, yallaAnalyticsGameName);
    expect(
      sink.events.where((name) => name == GameAnalyticsKeys.gameStarted),
      hasLength(1),
    );
    expect(
      sink.events.where((name) => name == GameAnalyticsKeys.categorySelected),
      hasLength(2),
    );

    await yallaSessionStarted(const ['animals']);
    await pumpEventQueue();
    expect(
      sink.events.where((name) => name == GameAnalyticsKeys.gameStarted),
      hasLength(1),
    );

    await yallaSessionCompleted();
    await pumpEventQueue();
    expect(GameSessionTracker.activeGame, isNull);
    expect(
      sink.events.where((name) => name == GameAnalyticsKeys.gameCompleted),
      hasLength(1),
    );

    await yallaSessionReplaySetup();
    await pumpEventQueue();
    expect(GameSessionTracker.activeGame, isNull);
    expect(
      sink.events.where((name) => name == GameAnalyticsKeys.gameReplayed),
      hasLength(1),
    );

    await yallaSessionStarted(const ['sports']);
    await yallaSessionCompleted();
    await yallaSessionCompleted();
    await pumpEventQueue();
    expect(
      sink.events.where((name) => name == GameAnalyticsKeys.gameCompleted),
      hasLength(2),
    );

    await yallaSessionStarted(const ['sports']);
    yallaSessionAbandoned();
    yallaSessionAbandoned();
    await pumpEventQueue();
    expect(
      sink.events.where((name) => name == GameAnalyticsKeys.gameAbandoned),
      hasLength(1),
    );
    expect(GameSessionTracker.activeGame, isNull);
  });
}
