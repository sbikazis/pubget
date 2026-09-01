---
name: GitHub split history
description: Safe publishing when the local Git graph and GitHub main were updated through different channels.
---

Do not assume the local `main` parent is the current GitHub `main` parent.
Compare the live remote ref before publishing, and never force-push across a
split history. When Git credentials are unavailable, publish only the verified
task diff on top of the live remote base through the connected GitHub API.

**Why:** This project has had commits created through GitHub's API that were not
present in the local object database, while local organizational commits also
existed only in the workspace.

**How to apply:** Before any push, compare the local parent with the live GitHub
branch ref. If they differ, identify the exact task diff and preserve the remote
tree as the base rather than attempting a force push.