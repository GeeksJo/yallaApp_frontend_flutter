import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import '../services/storage_service.dart';

class CoinProvider extends ChangeNotifier {
  final StorageService _storage;
  late int _coins;
  late List<String> _purchased;

  static const int rentCost = 30;
  static const int buyCost = 100;
  static const int adReward = 20;
  static const Duration rentDuration = Duration(hours: 2);

  static const Duration _rewardedLoadCap = Duration(seconds: 5);
  static const Duration _rewardedShowCap = Duration(seconds: 30);

  CoinProvider(this._storage) {
    _coins = _storage.getCoins();
    _purchased = _storage.getPurchasedCategories();
  }

  int get coins => _coins;

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
  Future<AdGrantOutcome> watchAdForCoins() async {
    unawaited(GameKit.ads.preloadAds());
    final AdGrantOutcome outcome = await GameKit.ads.requestAdGrant(
      placement: 'free_coins',
      // Coins are spendable on anything, so they draw on the currency window.
      cooldownGroup: AdGrantCooldownGroup.currency,
    );
    if (outcome.isGranted) {
      await addCoins(adReward);
    }
    return outcome;
  }

  bool get isAdReady =>
      GameKit.ads.canShowRewarded(RewardedReason.hint) &&
      GameKit.ads.isRewardedReady;
}
