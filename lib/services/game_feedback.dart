import 'package:game_kit/game_kit.dart';

/// Sound and vibration for the same game event.
///
/// Kit preferences mute each channel on their own. Success and completion
/// always fire both so one game does not end up haptic-only.
abstract final class GameFeedback {
  static void tap() {
    GameKit.sounds.lightTap();
    GameKit.haptics.lightTap();
  }

  static void success() {
    GameKit.sounds.validAction();
    GameKit.haptics.validAction();
  }

  static void failure() {
    GameKit.sounds.invalidAction();
    GameKit.haptics.invalidAction();
  }

  static void completion() {
    GameKit.sounds.milestoneSuccess();
    GameKit.haptics.milestoneSuccess();
  }
}
