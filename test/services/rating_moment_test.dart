import 'package:flutter_test/flutter_test.dart';
import 'package:yalla/services/rating_moment.dart';

void main() {
  test('a mid-round success only counts and does not offer', () {
    final moment = RatingMoment.forAnswer(
      succeeded: true,
      roundCompleted: false,
      gameOver: false,
    );

    expect(moment.recordFailure, isFalse);
    expect(moment.offerOnRoundBoundary, isFalse);
    expect(moment.offerOnResults, isFalse);
  });

  test('a successful round offers on the boundary, not on the results screen', () {
    final moment = RatingMoment.forAnswer(
      succeeded: true,
      roundCompleted: true,
      gameOver: false,
    );

    expect(moment.recordFailure, isFalse);
    expect(moment.offerOnRoundBoundary, isTrue);
    expect(moment.offerOnResults, isFalse);
  });

  test('a winning finish offers once, on the results screen', () {
    final moment = RatingMoment.forAnswer(
      succeeded: true,
      roundCompleted: true,
      gameOver: true,
    );

    expect(moment.offerOnRoundBoundary, isFalse);
    expect(moment.offerOnResults, isTrue);
    expect(moment.recordFailure, isFalse);
  });

  test('a timeout records a failure and offers nothing', () {
    final moment = RatingMoment.forAnswer(
      succeeded: false,
      roundCompleted: true,
      gameOver: true,
    );

    expect(moment.recordFailure, isTrue);
    expect(moment.offerOnRoundBoundary, isFalse);
    expect(moment.offerOnResults, isFalse);
  });

  test('leaving a match is a failure', () {
    expect(RatingMoment.abandoned.recordFailure, isTrue);
    expect(RatingMoment.abandoned.offerOnRoundBoundary, isFalse);
    expect(RatingMoment.abandoned.offerOnResults, isFalse);
  });
}
