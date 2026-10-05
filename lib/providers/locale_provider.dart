import 'package:flutter/material.dart';
import '../services/game_kit_bootstrap.dart';
import '../services/storage_service.dart';

class LocaleProvider extends ChangeNotifier {
  final StorageService _storage;
  final void Function(Locale locale) _onPresentationLocaleChanged;
  late Locale _locale;

  LocaleProvider(
    this._storage, {
    void Function(Locale locale)? onPresentationLocaleChanged,
  }) : _onPresentationLocaleChanged =
           onPresentationLocaleChanged ?? updateGameKitPresentationLocale {
    _locale = Locale(_storage.getLocale());
  }

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  Future<void> setLocale(Locale locale) async {
    if (locale == _locale) return;
    _locale = locale;
    await _storage.setLocale(locale.languageCode);
    _onPresentationLocaleChanged(locale);
    notifyListeners();
  }

  Future<void> toggleLocale() async {
    final newLocale = isArabic ? const Locale('en') : const Locale('ar');
    await setLocale(newLocale);
  }
}
