---
name: Mafia terminal locking
description: Durable rule for scheduler-owned Mafia state transitions.
---

Scheduled game state machines must guard terminal states both when claiming an expired phase and after resolving an action. A resolver can change the game to `GAME_OVER` while the scheduler still holds an older phase snapshot, so checking only the pre-resolution phase is insufficient.

**Why:** A stale scheduler invocation can otherwise advance a finished game into a new phase after rewards, archive, and winner state have already been committed.

**How to apply:** Keep terminal-state checks in the claim transaction and immediately after night/vote resolution; include every persisted terminal spelling used by the domain.