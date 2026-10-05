import 'package:flutter/widgets.dart';

/// Whether an emergency screen is covering gameplay.
///
/// The question screen listens so the countdown bed stops while input and
/// tickers are frozen, then picks up again when the block clears.
class EmergencyBlockNotice extends InheritedNotifier<ValueNotifier<bool>> {
  const EmergencyBlockNotice({
    required ValueNotifier<bool> blocked,
    required super.child,
    super.key,
  }) : super(notifier: blocked);

  static bool blockedOf(BuildContext context) {
    final notice = context
        .dependOnInheritedWidgetOfExactType<EmergencyBlockNotice>();
    return notice?.notifier?.value ?? false;
  }
}
