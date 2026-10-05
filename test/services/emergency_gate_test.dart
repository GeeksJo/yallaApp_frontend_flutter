import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:yalla/const/remote_config_keys.dart';
import 'package:yalla/services/emergency_gate.dart';

void main() {
  testWidgets('shows the game when no emergency key is active', (tester) async {
    await tester.pumpWidget(_app(remoteConfig: FakeGameKitRemoteConfig()));
    await tester.pump();

    expect(find.text('game'), findsOneWidget);
    expect(find.text('Ready for Launch?'), findsNothing);
  });

  testWidgets('blocks with force update when min version is higher', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        remoteConfig: FakeGameKitRemoteConfig(
          strings: <String, String>{
            RemoteConfigKeys.minRequiredVersion: '1.0.10',
            RemoteConfigKeys.androidStoreUrl: 'https://example.com/update',
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('game'), findsNothing);
    expect(find.text('Ready for Launch?'), findsOneWidget);
  });

  testWidgets('app moved takes priority over force update', (tester) async {
    await tester.pumpWidget(
      _app(
        remoteConfig: FakeGameKitRemoteConfig(
          strings: <String, String>{
            RemoteConfigKeys.showAppMoved: 'true',
            RemoteConfigKeys.newAndroidStoreUrl: 'https://example.com/new',
            RemoteConfigKeys.minRequiredVersion: '1.0.10',
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('game'), findsNothing);
    expect(
      find.text('The app has moved to a new store listing'),
      findsOneWidget,
    );
    expect(find.text('Ready for Launch?'), findsNothing);
  });

  testWidgets('re-evaluates when the RC listenable changes', (tester) async {
    final remoteConfig = _MutableRemoteConfig();
    final recheck = ValueNotifier<int>(0);

    await tester.pumpWidget(_app(remoteConfig: remoteConfig, recheck: recheck));
    await tester.pump();

    expect(find.text('game'), findsOneWidget);

    remoteConfig.set(RemoteConfigKeys.showAppMoved, '1');
    recheck.value += 1;
    await tester.pump();
    await tester.pump();

    expect(find.text('game'), findsNothing);
    expect(
      find.text('The app has moved to a new store listing'),
      findsOneWidget,
    );
  });
}

Widget _app({required GameKitRemoteConfig remoteConfig, Listenable? recheck}) {
  return MaterialApp(
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GameKitLocalizations.delegate,
    ],
    home: HostEmergencyGate(
      remoteConfig: remoteConfig,
      recheck: recheck,
      loadCurrentVersion: () async => '1.0.9',
      child: const Text('game', textDirection: TextDirection.ltr),
    ),
  );
}

class _MutableRemoteConfig extends GameKitRemoteConfig {
  final Map<String, String> _strings = <String, String>{};

  @override
  bool get isReady => true;

  @override
  String getString(String key, {String defaultValue = ''}) {
    return _strings[key] ?? defaultValue;
  }

  @override
  int getInt(String key, {required int defaultValue}) => defaultValue;

  void set(String key, String value) {
    _strings[key] = value;
  }
}
