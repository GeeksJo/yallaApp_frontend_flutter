import 'package:flutter/material.dart';

import '../services/game_feedback.dart';

/// App-bar back control with the same tap cue as the other buttons.
class FeedbackBackButton extends StatelessWidget {
  const FeedbackBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BackButton(
      onPressed: () {
        GameFeedback.tap();
        Navigator.maybePop(context);
      },
    );
  }
}
