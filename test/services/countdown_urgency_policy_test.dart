import 'package:flutter_test/flutter_test.dart';
import 'package:yalla/services/countdown_urgency_policy.dart';

void main() {
  bool play({
    bool answered = false,
    bool paused = false,
    bool introComplete = true,
    bool emergencyBlocked = false,
    bool inBackground = false,
    int answerSeconds = 10,
    double remainingSeconds = 2,
  }) {
    return CountdownUrgencyPolicy.shouldPlay(
      answered: answered,
      paused: paused,
      introComplete: introComplete,
      emergencyBlocked: emergencyBlocked,
      inBackground: inBackground,
      answerSeconds: answerSeconds,
      remainingSeconds: remainingSeconds,
    );
  }

  test('plays only in the last three seconds of a longer round', () {
    expect(play(remainingSeconds: 3), isTrue);
    expect(play(remainingSeconds: 3.1), isFalse);
    expect(play(answerSeconds: 5, remainingSeconds: 2), isFalse);
    expect(play(answerSeconds: 3, remainingSeconds: 1), isFalse);
  });

  test('stays silent on pause, background, emergency block, and exit', () {
    expect(play(paused: true), isFalse);
    expect(play(inBackground: true), isFalse);
    expect(play(emergencyBlocked: true), isFalse);
    expect(play(answered: true), isFalse);
    expect(play(introComplete: false), isFalse);
  });
}
