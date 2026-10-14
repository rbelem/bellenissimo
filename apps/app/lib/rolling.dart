import 'package:flutter/material.dart';

/// In-place roll: when the text changes, the old figure slides up and
/// away while the new one slides in from below — never a jump-cut. Under
/// Reduce Motion the swap is an instant cut.
Widget rollIn(BuildContext context, String text, Widget child) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return KeyedSubtree(key: ValueKey(text), child: child);
  }
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 180),
    switchInCurve: Curves.easeOutExpo,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: KeyedSubtree(key: ValueKey(text), child: child),
  );
}
