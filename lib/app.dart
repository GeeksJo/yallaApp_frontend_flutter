import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:game_kit/game_kit.dart';
import 'package:yalla/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/locale_provider.dart';
import 'screens/home_screen.dart';
import 'services/app_navigator.dart';
import 'services/emergency_gate.dart';
import 'services/firebase_service.dart';
import 'services/game_kit_bootstrap.dart';
import 'theme/app_theme.dart';

class YallaApp extends StatefulWidget {
  const YallaApp({super.key});

  @override
  State<YallaApp> createState() => _YallaAppState();
}

class _YallaAppState extends State<YallaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshGameKitAfterResume());
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Yalla! - 5 seconds',
      debugShowCheckedModeBanner: false,
      locale: localeProvider.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GameKitLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(localeProvider.isArabic),
      builder: (context, child) {
        return HostEmergencyGate(
          refresh: FirebaseService.instance.refresh,
          recheck: FirebaseService.instance.revision,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeScreen(),
    );
  }
}
