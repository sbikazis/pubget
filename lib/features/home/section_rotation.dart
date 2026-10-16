import 'dart:math';

/// §5.2.3 — smart rotation of Home's discovery sections between visits.
///
/// The rule is deliberately narrow. Only the order changes: the same sections
/// stay on the same page, in the same design, with the same data. Rotation never
/// removes a section and never reorders within a single build, because a list
/// that reshuffles while the user is scrolling reads as a bug.
///
/// The shuffle is seeded rather than random so one build produces one stable
/// order, and two different seeds produce two different orders.
extension HomeSectionRotation<T> on List<T> {
  /// Returns a rotated copy. The input list is left untouched.
  List<T> rotate(int seed) {
    if (length < 2) return List<T>.of(this);
    final rotated = List<T>.of(this)..shuffle(Random(seed));
    return rotated;
  }
}
