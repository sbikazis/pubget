import 'package:flutter/material.dart';

import '../../app/app_router.dart';

/// # Pubget dismiss / back contract (forever)
///
/// Applies to **every** page, sheet, dialog, and overlay — including future UI:
///
/// 1. **≥2 ways to leave** the current surface without exiting the app or
///    skipping more than one step (e.g. back/close **and** drag or backdrop).
/// 2. **Bottom sheets** that rise from the bottom are always
///    drag-to-dismiss + backdrop-dismiss + drag handle (see [PubgetBottomSheet]).
/// 3. **Hardware / gesture back** pops exactly one layer:
///    local Navigator route/sheet → then app stack → at shell/login root it is
///    absorbed (does **not** exit the app).
///
/// Prefer [AppNavigation.popLayer], [AppBackButton], and [PubgetBottomSheet]
/// instead of raw `Navigator` / `showModalBottomSheet` / `SystemNavigator.pop`.
abstract final class PubgetDismiss {
  /// Pops the nearest dismissible layer (sheet, dialog, local route), then
  /// the app route stack. Never exits the process.
  static Future<bool> popLayer(BuildContext context) =>
      AppNavigation.popLayer(context);

  /// Whether any single-step dismiss is available (local or routed).
  static bool canPopLayer(BuildContext context) =>
      AppNavigation.canPop(context);
}
