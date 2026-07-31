import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension NavContext on BuildContext {
  /// Steps back one screen, falling back to [fallback] when there is nothing
  /// on the stack to pop.
  ///
  /// Some routes are reached with `go` (from the pause menu, or after a level
  /// is cleared), which flattens the stack. Popping blindly from those would
  /// close the app; going blindly from a pushed route would strand the player
  /// with no way back to the menu.
  void backTo(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}
