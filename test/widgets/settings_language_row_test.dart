import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla/l10n/app_localizations.dart';
import 'package:yalla/providers/locale_provider.dart';
import 'package:yalla/services/game_kit_bootstrap.dart';
import 'package:yalla/services/storage_service.dart';
import 'package:yalla/widgets/settings_language_row.dart';

void main() {
  testWidgets(
    'language row switches the about blurb and has no vibration switch',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'locale': 'ar'});
      final storage = StorageService();
      await storage.init();
      final seen = <Locale>[];
      final provider = LocaleProvider(
        storage,
        onPresentationLocaleChanged: seen.add,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<LocaleProvider>.value(
          value: provider,
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(body: SettingsLanguageRow()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Haptics'), findsNothing);
      expect(find.text('الاهتزاز'), findsNothing);
      expect(find.text('English'), findsOneWidget);

      await tester.tap(find.text('العربية'));
      await tester.pump();
      expect(seen, isEmpty);

      await tester.tap(find.text('English'));
      await tester.pump();

      expect(seen, <Locale>[const Locale('en')]);
      final about = buildYallaGameKitSettingsUiConfig(seen.single);
      expect(about.aboutDescription, contains('answer time'));
      expect(about.aboutDescription, isNot(contains('30')));

      final arabic = buildYallaGameKitSettingsUiConfig(const Locale('ar'));
      expect(arabic.aboutDescription, contains('وقت الإجابة'));
      expect(arabic.aboutDescription, isNot(about.aboutDescription));
    },
  );
}
