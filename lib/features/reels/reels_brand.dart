/// Axis 15 — routes and hard limits for the short-video surface.
///
/// The display name deliberately does NOT live here. It is owned by
/// `AppStrings.productReelsName` so there is exactly one source of truth for
/// the product name (see `AppStrings`).
abstract final class ReelsBrand {
  static const route = '/reels';
  static const legacyRoute = '/edits';
  static const maxDurationSeconds = 60;
}
