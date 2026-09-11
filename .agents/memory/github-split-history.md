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

When publishing through the GitHub API, create the tree against the parent
commit's tree SHA, not the parent commit SHA, and verify every uploaded blob
against the local file bytes before updating the branch ref.

**Why:** GitHub accepts malformed or incorrectly based tree uploads, which can
create a branch that exists but silently omits or truncates the intended task
changes.

**How to apply:** Upload changed files with byte-length validation, use the
authoritative parent's tree SHA for `createTree`, update the ref only after the
commit is created, then fetch the ref and compare its tree to the local commit.