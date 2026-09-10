# Pubget navigation & dismiss policy

**Applies to every page, sheet, dialog, and overlay — including future work.**

## Rules

1. **≥2 dismiss paths** for any opened surface, without exiting the app or jumping more than one step.
   - Pages: AppBar back **and** hardware/gesture back (both call `AppNavigation.popLayer`).
   - Sheets: drag down **and** tap barrier (plus close icon when there is a title row).
2. **Bottom sheets** that rise from the bottom must be closable by **dragging down**.
   - Always use `PubgetBottomSheet.show` / `PubgetBottomSheet.present`.
   - Do **not** call raw `showModalBottomSheet` or disable `enableDrag` / `isDismissible`.
3. **Hardware back** pops exactly one layer:
   1. Local navigator (sheet / dialog / `Navigator.push`)
   2. App route stack
   3. At shell / login roots → **absorb** (do not exit the app)

## APIs

| Need | Use |
|------|-----|
| Open a sheet | `PubgetBottomSheet.present` / `.show` |
| Page chrome | `PubgetPageScaffold` (or `AppBackButton.maybeOf`) |
| Programmatic back | `AppNavigation.popLayer` / `PubgetDismiss.popLayer` |
| Local `Navigator.push` page | `PubgetPageScaffold(localNavigator: true)` |

## Forbidden

- `SystemNavigator.pop` to leave nested UI
- `popRoute` / back that skips sheets and tears down the whole route
- Bottom sheets with `enableDrag: false` or `isDismissible: false`
- Surfaces with only one way out (e.g. backdrop-only dialogs with no drag/close)
