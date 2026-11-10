import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla/l10n/app_localizations.dart';
import 'package:yalla/models/category.dart';
import 'package:yalla/providers/coin_provider.dart';
import 'package:yalla/services/storage_service.dart';
import 'package:yalla/services/yalla_analytics.dart';
import 'package:yalla/widgets/locked_category_sheet.dart';

class _RecordingSink implements GameAnalyticsSink {
  final events = <(String, Map<String, Object>?)>[];

  List<String> get names => [for (final e in events) e.$1];

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    events.add((name, parameters));
  }

  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}
}

const _offered = GameAnalyticsKeys.adRewardedOffered;
const _declined = GameAnalyticsKeys.adRewardedDeclined;

void main() {
  late _RecordingSink sink;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GameAnalytics.resetForTest();
    sink = _RecordingSink();
    GameAnalytics.setSink(sink);
  });

  tearDown(GameAnalytics.resetForTest);

  group('YallaRewardedOffer', () {
    test(
      'a sheet closed without watching is one offer and one decline',
      () async {
        final offer = YallaRewardedOffer(offered: true)..shown();
        offer.shown();
        offer.closed();
        offer.closed();
        await pumpEventQueue();

        expect(sink.names, [_offered, _declined]);
        expect(sink.events.first.$2?['placement'], yallaFreeCoinsPlacement);
        expect(sink.events.last.$2?['placement'], yallaFreeCoinsPlacement);
      },
    );

    test('a finished watch is not a decline', () async {
      final offer = YallaRewardedOffer(offered: true)..shown();
      offer.watchTapped();
      offer.watchFinished(AdGrantOutcome.grantedRewarded);
      offer.closed();
      await pumpEventQueue();

      expect(sink.names, [_offered]);
    });

    test(
      'an ad closed early declines once, closing the sheet adds nothing',
      () async {
        final offer = YallaRewardedOffer(offered: true)..shown();
        offer.watchTapped();
        offer.watchFinished(AdGrantOutcome.skipped);
        offer.watchTapped();
        offer.watchFinished(AdGrantOutcome.skipped);
        offer.closed();
        await pumpEventQueue();

        expect(sink.names, [_offered, _declined]);
      },
    );

    test('no fill after a tap is not a decline', () async {
      final offer = YallaRewardedOffer(offered: true)..shown();
      offer.watchTapped();
      offer.watchFinished(AdGrantOutcome.noneAvailable);
      offer.closed();
      await pumpEventQueue();

      expect(sink.names, [_offered]);
    });

    test('Remove Ads buyers are never offered or declined', () async {
      final offer = YallaRewardedOffer(offered: false)..shown();
      offer.closed();
      await pumpEventQueue();

      expect(sink.names, isEmpty);
    });
  });

  testWidgets('the locked sheet offers on open and declines on dismiss', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = StorageService();
    await storage.init();
    final coins = CoinProvider(
      storage,
      coinGrantRequester: (_) async => AdGrantOutcome.grantedFree,
    );
    const category = GameCategory(
      key: 'animals',
      nameEn: 'Animals',
      nameAr: 'حيوانات',
      icon: Icons.pets,
      color: Colors.green,
      lockedByDefault: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                builder: (_) => ChangeNotifierProvider.value(
                  value: coins,
                  child: const LockedCategorySheet(
                    category: category,
                    offerRewardedAd: true,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Animals'), findsOneWidget);
    expect(sink.names, [_offered]);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Animals'), findsNothing);
    expect(sink.names, [_offered, _declined]);
  });
}
