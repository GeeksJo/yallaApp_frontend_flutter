/// When a match event may be handed to the kit rating prompt.
///
/// The kit owns session, lifetime, dismissal, and post-ad gates. This only
/// picks the moment: a successful round that is still in progress, or the
/// results screen after a successful finish. A timeout or a quit records a
/// failure so the next win is treated as a recovery.
class RatingMoment {
  const RatingMoment._({
    required this.recordFailure,
    required this.offerOnRoundBoundary,
    required this.offerOnResults,
  });

  final bool recordFailure;

  /// Successful round that does not end the match. Offer after the fullscreen
  /// ad, before the next turn.
  final bool offerOnRoundBoundary;

  /// Match finished on a success. Offer on the results screen, after its ad.
  final bool offerOnResults;

  static const abandoned = RatingMoment._(
    recordFailure: true,
    offerOnRoundBoundary: false,
    offerOnResults: false,
  );

  static RatingMoment forAnswer({
    required bool succeeded,
    required bool roundCompleted,
    required bool gameOver,
  }) {
    if (!succeeded) {
      return const RatingMoment._(
        recordFailure: true,
        offerOnRoundBoundary: false,
        offerOnResults: false,
      );
    }
    return RatingMoment._(
      recordFailure: false,
      offerOnRoundBoundary: roundCompleted && !gameOver,
      offerOnResults: gameOver,
    );
  }
}
