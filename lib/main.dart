import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/questions.dart';
import 'services/firebase_service.dart';
import 'providers/coin_provider.dart';
import 'providers/game_provider.dart';
import 'providers/game_settings_provider.dart';
import 'providers/locale_provider.dart';
import 'services/game_kit_bootstrap.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Before GameKit: the ads kill switch is read out of Remote Config while
  // building the kit's AdsConfig, so Firebase has to be up first. This never
  // throws - see FirebaseService.initialize.
  await FirebaseService.instance.initialize();

  // Host [DEFAULT] Firebase only — see game_kit HOST_ATT_AND_CRASHLYTICS_PROMPT.md.
  if (FirebaseService.instance.hasDefaultFirebaseApp) {
    await GameKitIosAppTracking.deferFirebaseAnalyticsCollection();
    // Flutter will not accept a background-handler registration from inside
    // GameKit.initialize; it has to happen here in main, before runApp.
    FirebaseMessaging.onBackgroundMessage(
      gameKitFirebaseMessagingBackgroundHandler,
    );
    await GameKitCrashlytics.install();
  }

  final storage = StorageService();
  await storage.init();

  await initializeGameKit(storage);

  final questionBank = QuestionBank();
  await questionBank.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider(create: (_) => LocaleProvider(storage)),
        ChangeNotifierProvider(create: (_) => GameSettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => CoinProvider(storage)),
        ChangeNotifierProvider(create: (_) => GameProvider(questionBank)),
      ],
      child: const YallaApp(),
    ),
  );
}
