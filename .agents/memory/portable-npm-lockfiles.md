---
name: Portable npm lockfiles
description: Prevent Replit package-firewall registry URLs from leaking into lockfiles used by CI and external build systems.
---

Lockfiles committed for Firebase CI or other external build systems must not
contain `package-firewall.replit.internal` URLs.

**Why:** Updating Firebase CLI inside Replit rewrote many package resolutions to
the internal package-firewall host. Such a lockfile can install locally but fail
on GitHub Actions, Firebase build infrastructure, or another developer machine.

**How to apply:** After dependency changes, scan the lockfile for internal URLs.
If present, regenerate it without carrying prior resolution metadata, then
confirm a clean `npm ci` succeeds and the committed lockfile has no internal
host references.