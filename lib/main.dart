import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/questions.dart';
import 'providers/coin_provider.dart';
import 'providers/game_provider.dart';
import 'providers/game_settings_provider.dart';
import 'providers/locale_provider.dart';
import 'services/game_kit_bootstrap.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
