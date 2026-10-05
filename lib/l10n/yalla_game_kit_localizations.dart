import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:game_kit/l10n/game_kit_localizations_ar.dart';
import 'package:game_kit/l10n/game_kit_localizations_en.dart';
import 'package:game_kit/game_kit.dart';

/// Kit strings, with this app's existing share sentences.
///
/// The kit's default share line is a generic "check out {app name}". These
/// subclasses keep every other kit string and substitute the Arabic and
/// English lines already shipped in the app.
class YallaGameKitLocalizationsEn extends GameKitLocalizationsEn {
  YallaGameKitLocalizationsEn() : super('en');

  @override
  String shareAppMessage(String appName) => 'Play Yalla! - 5 seconds with me!';
}

class YallaGameKitLocalizationsAr extends GameKitLocalizationsAr {
  YallaGameKitLocalizationsAr() : super('ar');

  @override
  String shareAppMessage(String appName) => 'العب يلا! - ٥ ثوانٍ معي!';
}

class YallaGameKitLocalizationsDelegate
    extends LocalizationsDelegate<GameKitLocalizations> {
  const YallaGameKitLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final code = locale.languageCode;
    return code == 'en' || code == 'ar';
  }

  @override
  Future<GameKitLocalizations> load(Locale locale) {
    final GameKitLocalizations strings = locale.languageCode == 'ar'
        ? YallaGameKitLocalizationsAr()
        : YallaGameKitLocalizationsEn();
    return SynchronousFuture<GameKitLocalizations>(strings);
  }

  @override
  bool shouldReload(YallaGameKitLocalizationsDelegate old) => false;
}
