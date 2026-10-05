import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import '../services/storage_service.dart';

typedef CoinGrantRequester =
    Future<AdGrantOutcome> Function(BuildContext context);

class CoinProvider extends ChangeNotifier {
  CoinProvider(this._storage, {CoinGrantRequester? coinGrantRequester})
    : _coinGrantRequester = coinGrantRequester ?? _requestCoinGrant {
    _coins = _storage.getCoins();
    _purchased = _storage.getPurchasedCategories();
  }

  final StorageService _storage;
  final CoinGrantRequester _coinGrantRequester;
  late int _coins;
  late List<String> _purchased;
  bool _coinGrantInFlight = false;

  static const int rentCost = 30;
  static const int buyCost = 100;
  static const int adReward = 20;
  static const Duration rentDuration = Duration(hours: 2);

  int get coins => _coins;

  bool get isCoinGrantInFlight => _coinGrantInFlight;

  bool isCategoryUnlocked(String categoryKey) {
    if (_purchased.contains(categoryKey)) return true;
    final expiry = _storage.getRentedExpiry(categoryKey);
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  Future<bool> rentCategory(String categoryKey) async {
    if (_coins < rentCost) return false;
    _coins -= rentCost;
    await _storage.setCoins(_coins);
    final expiry = DateTime.now().add(rentDuration);
    await _storage.setRentedExpiry(categoryKey, expiry);
    notifyListeners();
    return true;
  }

  Future<bool> buyCategory(String categoryKey) async {
    if (_coins < buyCost) return false;
    _coins -= buyCost;
    await _storage.setCoins(_coins);
    _purchased.add(categoryKey);
    await _storage.setPurchasedCategories(_purchased);
    notifyListeners();
    return true;
  }

  Future<void> addCoins(int amount) async {
    _coins += amount;
    await _storage.setCoins(_coins);
    notifyListeners();
  }

  /// Runs the kit's grant chain for free coins and returns the outcome.
  ///
  /// Was a hand-rolled load-then-show that returned a bare `bool`, so every
  /// failure looked identical: no network, no fill, and the player closing the
  /// video all produced `false` and - because the caller discarded it - no
  /// message at all. The chain handles the tiers, the offline gate and the
  /// capped free grant; the outcome tells the caller which message to show.
  Future<AdGrantOutcome> watchAdForCoins(BuildContext context) async {
    if (_coinGrantInFlight) {
      return AdGrantOutcome.noneAvailable;
    }

    _coinGrantInFlight = true;
    notifyListeners();

    try {
      final outcome = await _coinGrantRequester(context);
      if (outcome.isGranted) {
        await addCoins(adReward);
      }
      return outcome;
    } catch (_) {
      // A crash inside the chain must not become free coins. It is not proof
      // that the player is offline, so use the neutral "try later" outcome.
      return AdGrantOutcome.noneAvailable;
    } finally {
      _coinGrantInFlight = false;
      notifyListeners();
    }
  }

  bool get isAdReady =>
      GameKit.ads.canShowRewarded(RewardedReason.hint) &&
      GameKit.ads.isRewardedReady;

  static Future<AdGrantOutcome> _requestCoinGrant(BuildContext context) {
    unawaited(GameKit.ads.preloadAds());
    return GameKit.ads.requestAdGrant(
      placement: 'free_coins',
      // Coins are spendable on anything, so they draw on the currency window.
      cooldownGroup: AdGrantCooldownGroup.currency,
      context: context,
    );
  }
}
