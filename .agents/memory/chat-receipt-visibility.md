---
name: Chat receipt visibility
description: The rule for deciding which loaded chat messages may be marked read.
---

Read receipts must be sent only for message bubbles whose rendered bounds intersect the active chat viewport. A provider can hold older history that is loaded but not visible, and marking that entire collection read violates the product behavior.

**Why:** Chat pagination keeps historical messages in memory while the user may be reading the newest or a different section; treating the loaded list as visible marks unread history prematurely.

**How to apply:** Keep message-row keys stable, inspect their render bounds after layout, and batch only the intersecting message IDs through the existing receipt provider path.