/// When the sustained countdown bed may play.
///
/// Rounds of 5 seconds or less stay quiet. Longer rounds use the bed only in
/// the last 3 seconds, and never while the turn is paused, covered, or away.
class CountdownUrgencyPolicy {
  const CountdownUrgencyPolicy._();

  static const urgencyWindowSeconds = 3;
  static const minimumRoundSeconds = 5;

  static bool shouldPlay({
    required bool answered,
    required bool paused,
    required bool introComplete,
    required bool emergencyBlocked,
    required bool inBackground,
    required int answerSeconds,
    required double remainingSeconds,
  }) {
    if (answered ||
        paused ||
        !introComplete ||
        emergencyBlocked ||
        inBackground) {
      return false;
    }
    if (answerSeconds <= minimumRoundSeconds) return false;
    return remainingSeconds <= urgencyWindowSeconds;
  }
}
