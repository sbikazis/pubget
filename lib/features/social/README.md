# Profile and Social Graph

This feature follows `UI → Provider → Repository → Firebase`.

## Data contracts

- `users/{uid}` is the private owner profile. Flutter may update presentation
  fields only: bio, avatar URL, favorite anime ID placeholders, and the basic
  profile/activity visibility values.
- `public_profiles/{uid}` is a server-maintained projection containing only
  `username`, `avatarUrl`, `bio`, `totalRespect`, and `fansCount`. A private
  source profile has no public projection.
- `respects/{fromUid}_{toUid}` stores one directed value from 0 through 7.
  A value of 5 or more counts as a fan.
- `friendships/{sortedUidA}_{sortedUidB}` is the single deterministic
  relationship document for a pair. Its status is `pending`, `accepted`, or
  `blocked`.

## Authority boundary

Flutter can read permitted social data but cannot write Respect, fans,
friendships, rate limits, public profiles, or social counters. Those mutations
run through callable Cloud Functions and Firestore transactions.

Favorite anime values are identifiers/text placeholders only. Groups, Chat,
the Anime domain, currencies, subscriptions, and premium state are not part of
this feature.