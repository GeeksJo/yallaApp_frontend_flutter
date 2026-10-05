import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla/providers/coin_provider.dart';
import 'package:yalla/services/storage_service.dart';

void main() {
  testWidgets('coin grant credits once and guards overlapping taps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'coins': 10});
    final storage = StorageService();
    await storage.init();

    final grant = Completer<AdGrantOutcome>();
    var calls = 0;
    late BuildContext capturedContext;
    final provider = CoinProvider(
      storage,
      coinGrantRequester: (context) {
        calls += 1;
        capturedContext = context;
        return grant.future;
      },
    );

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox.shrink();
        },
      ),
    );

    final first = provider.watchAdForCoins(capturedContext);
    final second = await provider.watchAdForCoins(capturedContext);

    expect(second, AdGrantOutcome.noneAvailable);
    expect(calls, 1);
    expect(provider.isCoinGrantInFlight, isTrue);

    grant.complete(AdGrantOutcome.grantedFree);
    expect(await first, AdGrantOutcome.grantedFree);
    expect(provider.coins, 30);
    expect(storage.getCoins(), 30);
    expect(provider.isCoinGrantInFlight, isFalse);
  });

  testWidgets('coin grant failures do not credit coins', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'coins': 10});
    final storage = StorageService();
    await storage.init();

    late BuildContext capturedContext;
    final provider = CoinProvider(
      storage,
      coinGrantRequester: (_) async => throw StateError('boom'),
    );

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox.shrink();
        },
      ),
    );

    final outcome = await provider.watchAdForCoins(capturedContext);

    expect(outcome, AdGrantOutcome.noneAvailable);
    expect(provider.coins, 10);
    expect(storage.getCoins(), 10);
    expect(provider.isCoinGrantInFlight, isFalse);
  });
}
