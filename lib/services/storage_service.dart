import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _coinsKey = 'coins';
  static const _purchasedKey = 'purchased_categories';
  static const _rentedPrefix = 'rented_';
  static const _localeKey = 'locale';
  static const _legacySoundKey = 'sound_enabled';
  static const _hapticsKey = 'haptics_enabled';
  static const _questionTimerKey = 'question_timer_seconds';
  static const _donationTotalKey = 'donation_total_amount';
  static const _ratingSuccessCountKey = 'rating_success_count';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  int getCoins() => _prefs.getInt(_coinsKey) ?? 50;

  Future<void> setCoins(int coins) => _prefs.setInt(_coinsKey, coins);

  List<String> getPurchasedCategories() =>
      _prefs.getStringList(_purchasedKey) ?? [];

  Future<void> setPurchasedCategories(List<String> categories) =>
      _prefs.setStringList(_purchasedKey, categories);

  DateTime? getRentedExpiry(String categoryKey) {
    final ms = _prefs.getInt('$_rentedPrefix$categoryKey');
    if (ms == null) return null;
    final expiry = DateTime.fromMillisecondsSinceEpoch(ms);
    if (expiry.isBefore(DateTime.now())) {
      _prefs.remove('$_rentedPrefix$categoryKey');
      return null;
    }
    return expiry;
  }

  Future<void> setRentedExpiry(String categoryKey, DateTime expiry) => _prefs
      .setInt('$_rentedPrefix$categoryKey', expiry.millisecondsSinceEpoch);

  String getLocale() => _prefs.getString(_localeKey) ?? 'ar';

  Future<void> setLocale(String locale) => _prefs.setString(_localeKey, locale);

  bool getHapticsEnabled() => _prefs.getBool(_hapticsKey) ?? true;

  Future<void> setHapticsEnabled(bool enabled) =>
      _prefs.setBool(_hapticsKey, enabled);

  /// Legacy [sound_enabled] value for one-time migration into GameKit preferences.
  bool? getLegacySoundEnabledOrNull() {
    if (!_prefs.containsKey(_legacySoundKey)) return null;
    return _prefs.getBool(_legacySoundKey);
  }

  /// Legacy [haptics_enabled] value for one-time migration into GameKit preferences.
  bool? getLegacyHapticsEnabledOrNull() {
    if (!_prefs.containsKey(_hapticsKey)) return null;
    return _prefs.getBool(_hapticsKey);
  }

  int getQuestionTimerSeconds() {
    const defaultSeconds = 5;
    const minSeconds = 3;
    const maxSeconds = 60;
    final v = _prefs.getInt(_questionTimerKey);
    if (v == null) return defaultSeconds;
    return v.clamp(minSeconds, maxSeconds);
  }

  Future<void> setQuestionTimerSeconds(int seconds) =>
      _prefs.setInt(_questionTimerKey, seconds);

  double getDonationTotalAmount() => _prefs.getDouble(_donationTotalKey) ?? 0;

  Future<void> addDonationAmount(double amount) async {
    final next = getDonationTotalAmount() + amount;
    await _prefs.setDouble(_donationTotalKey, next);
  }

  Future<void> clearDonationTotal() => _prefs.remove(_donationTotalKey);

  /// Cumulative correct-answer count for [GameKit.rating.levelSucceeded] (1-based
  /// “level” index). In-game [GameProvider.currentRound] is not suitable: it
  /// only goes up to [GameProvider.totalRounds] per match, so it never reaches
  /// [RatingConfig.minLevel] (e.g. 4) in short games.
  int get ratingSuccessCount => _prefs.getInt(_ratingSuccessCountKey) ?? 0;

  /// Returns the new total after incrementing (for passing to [GameKit.rating]).
  Future<int> incrementRatingSuccessCount() async {
    final next = ratingSuccessCount + 1;
    await _prefs.setInt(_ratingSuccessCountKey, next);
    return next;
  }
}
