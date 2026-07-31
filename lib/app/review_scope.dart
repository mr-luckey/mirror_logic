import 'package:flutter/material.dart';
import 'package:mirror_logic/infrastructure/review/review_service.dart';

/// Publishes the review service to the widget tree.
///
/// Nullable lookup, matching [AdsScope]: a screen pumped in a widget test has
/// no Play Store under it, and being asked for a rating is optional everywhere
/// it happens, so "no service" collapses into the same quiet branch as "not
/// eligible yet".
class ReviewScope extends StatelessWidget {
  const ReviewScope({super.key, required this.review, required this.child});

  final ReviewService review;
  final Widget child;

  static ReviewService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ReviewProvider>()?.review;

  @override
  Widget build(BuildContext context) =>
      _ReviewProvider(review: review, child: child);
}

class _ReviewProvider extends InheritedWidget {
  const _ReviewProvider({required this.review, required super.child});

  final ReviewService review;

  @override
  bool updateShouldNotify(_ReviewProvider oldWidget) =>
      review != oldWidget.review;
}

extension ReviewContext on BuildContext {
  /// The app-wide review service, or null outside [ReviewScope].
  ReviewService? get review => ReviewScope.maybeOf(this);
}
