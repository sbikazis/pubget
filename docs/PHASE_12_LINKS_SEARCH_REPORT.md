# Phase 12 — Deep links, search, sharing (الروابط والبحث)

Report for spec axis "Deep links · search · sharing", written against the
repository state at `main` = `293e4c1` (Phase 11 merged, PR #166).

Acceptance from the brief:

- deep-link tests
- search tests

Both are met; details and the two deferred items are at the bottom.

---

## 1. What the brief assumed vs. what was actually in the tree

I audited each of the four requirements before writing code, because a
spec-shaped list ages badly. Three of them were partially or fully done:

| Brief item | Reality on `main` |
|---|---|
| (1) Align links to §2.3 | `/profile?uid=`, `/reel/{id}`, `/fan-work/{id}`, `/hashtag?tag=`, `/audio/{id}`, `/group/{id}` already parsed. `/work/{id}` was **not** routed, `/store/{id}` was **not** routed, `/g/{id}` worked only in the browser. |
| (2) `/g/**` parser in the Flutter web entry | The Firebase Hosting rewrite for `/g/**` already existed in `firebase.json`; there was **no client shim**, so the app booted on `/g/<id>` and fell to the unknown-route page. |
| (3) Search filters / entities / fuzzy / history | None. One flat list, prefix-only backend matching, no filter, no history, no audio or hashtag entity. |
| (4) Share builders for edits + store | Reels had inline string building inside the screen; the Store had **no share at all**. No canonical `/store/{id}` link existed to share. |

So the work is smaller than the brief implies in one place and larger in
another: the parser needed two real routes, while search needed a genuine
feature build.

---

## 2. Findings worth recording

**`/g/{id}` was a fake success.** The hosting rewrite made the browser *serve*
the app, but nothing rewrote the URL, so Flutter's router received `/g/<id>`
and the member saw "this link is not available". Deep links on iOS/Android, and
in-app pushes of the same string, never touched the shim at all.

**A shared Store item was a dead link.** `PubgetLinks` had no store builder and
the router had no `/store/{id}` shape, so the only store URL the app could emit
(`/store/item?itemId=`) was internal-looking and unshareable.

**Search results leaked Arabic into the English UI.** `SearchHit` baked
`'شخصية'` and `'ريل'` into hits for characters and Reels, and those subtitles
were rendered verbatim. That is Phase 11 debt in a shared model, so it is fixed
here rather than deferred: hits now carry a stable English sentinel and the tile
localizes through `AppStrings.searchHitLabel`.

**Search forgot everything.** With no history, a member who looked up the same
anime every evening retyped it every evening.

---

## 3. Decisions

**Ranking reorders, it never drops.** The obvious implementation of client-side
fuzzy matching is "filter to matches". That is wrong here: discovery may match a
query on a field the *title* does not contain (a description, a creator's name).
Dropping those rows would make a real result look like it does not exist — the
same class of bug as the prefix-only matching this replaces. `SearchProvider`
therefore ranks the matched hits first and appends the unmatched ones in server
order.

**Arabic folding is explicit, not accidental.** `SearchRank.fold` strips
tashkeel and tatweel and folds `أ إ آ → ا`, `ى → ي`, `ة → ه`. A member types
`انمى` for `أنمى`; requiring the hamza would fail a search that a human would
call obvious.

**A hashtag query is a destination.** Typing `#onepiece` used to search for the
literal string. It now yields the tag feed as the first hit, because the member
has already told the app exactly where they want to go.

**Audio is searchable only when it is playable.** `SearchHit.audio` returns
`null` for an audio still extracting; linking to it would open a detail page
that cannot play.

**History is device-local and written on commit.** Recorded on submit, on
opening a result, and on re-running a recent term — never per keystroke, which
would fill the list with `f`, `fr`, `fri`. Nothing is sent anywhere.

**`/g/**` is handled in both places.** The web shim covers browsers; the router
also understands `/g/{id}` because in-app deep links and any platform that hands
the raw URL to the engine never run the shim.

---

## 4. Changes

### Deep links

- `lib/core/links/deep_link.dart` (new) — total, side-effect-free parser for
  every §2.3 shape plus the legacy shapes already in circulation
  (`/fan-work/{id}`, `/hashtag?tag=`, `/profile?uid=`, `/reels?highlight=`).
  It never throws and degrades malformed input to `unknown`. Legacy shapes are
  flagged so analytics can measure what is still out there before support is
  ever dropped.
- `lib/app/app_router.dart` — `/g/{id}` → `/group` and `/store/{id}` →
  `/store/item?itemId=`. `/store/item` itself is a registered route, not an id,
  so it deliberately falls through to the generic branch.
- `lib/core/links/pubget_links.dart` — canonical builders `workPath`, `work`,
  `hashtagTagPath`, `hashtagTag`, `storeItemPath`, `storeItem`, `groupShort`,
  plus `editShareText` / `storeShareText`.
- `web/index.html` — synchronous `replaceState` from `/g/<id>` (and
  `/group/<id>/`) to the canonical path before `flutter_bootstrap.js` runs, so
  there is exactly one route for the app to understand. Wrapped in `try/catch`:
  a malformed link must never stop the app from booting.

### Search

- `lib/features/search/search_rank.dart` (new) — tiered scoring (exact 1000 >
  prefix 800 > word-prefix 600 > substring 400 > in-order subsequence 200…1,
  penalised by gap and length) with Arabic folding.
- `lib/features/search/search_history.dart` (new) — `SearchHistory` over a
  `SearchHistoryStore`, capped at 8, de-duplicated case-insensitively, newest
  first. `load()` will not clobber an entry recorded while the stored list was
  still being read.
- `lib/features/search/data/shared_preferences_search_history_store.dart` (new)
  — `SharedPreferences` persistence, key `pubget.search.history.v1`; every
  failure degrades to "no history".
- `lib/features/search/search_hit.dart` — `audio` and `hashtag` kinds,
  `SearchHit.audio`, `SearchHit.hashtag`, public `dedupe`, and localized kind
  sentinels instead of hardcoded Arabic.
- `lib/features/search/search_provider.dart` — entity filter, ranked view,
  concurrent anime/audio lookups (they overlap with discovery instead of
  queueing), audio hits, hashtag destination, and history recording. Filtering
  is a view concern: it costs no network call.
- `lib/features/search/screens/search_page.dart` — filter chip row (only types
  actually present; the active chip clears on re-tap), recent-search list with
  per-row remove and clear-all, and a "no results of this type" state that does
  not claim the thing does not exist.
- `lib/features/search/l10n/search_copy.dart` — history and filter copy, EN/AR.
- `lib/core/l10n/app_strings.dart` — `audio` and `hashtag` hit labels.
- `lib/features/anime/screens/anime_search_page.dart` — exhaustive switch kept
  exhaustive for the two new kinds.

### Sharing

- `lib/features/edits/screens/edit_feed_page.dart` — uses
  `PubgetLinks.editShareText` instead of inline string building.
- `lib/features/economy/screens/economy_screens.dart` — the Store item page now
  has a share action emitting `/store/{id}` with text that names the Store, so a
  cosmetics link does not read as a payment request out of context.
- `PubgetLinks.share` accepts optional `text`; existing callers are unchanged.

---

## 5. Verification

```
flutter analyze                          → No issues found
flutter test --exclude-tags golden       → 1061 tests passed
```

`test/deep_link_test.dart` (new, 48 tests) covers: every canonical §2.3 shape,
legacy shapes still resolving, malformed input never throwing, builders emitting
canonical paths, every built path round-tripping through the parser, every
parsed link being routable, share text with and without a caption, fuzzy
matching (tiers, Arabic folding, one-letter typo, non-matches), and the recent
history contract (order, de-duplication, cap, sanitising a bad store, remove,
clear).

`test/search_provider_test.dart` gains four tests: filter narrows without a
refetch, `#tag` produces the tag feed first, only ready audio becomes an audio
hit, and committed searches land in history newest-first.

**Goldens are excluded deliberately.** `.github/workflows/ci.yml` excludes the
`golden` tag because the committed PNGs were rasterized on macOS and differ on
Linux. A local unfiltered `flutter test` therefore fails
`chat_message_bubble_golden_test.dart` with a 3 % pixel diff and renders glyphs
as boxes in this container; that is the documented environment limitation, not a
regression from this work. The failure artifacts it wrote were reverted, not
committed.

---

## 6. Deferred, and why

**`/profile/{username}` does not resolve handles to uids.** The parser flags
`needsUsernameResolution` and routes `/profile/{handle}` to
`/profile?uid=<handle>`. That is honest about the contract — the profile screen
is addressed by uid — but a handle link opened cold still lands on an empty
profile unless something resolves it. The `usernames/{normalized}` registry is
readable by clients (it is already used for group member lookups), so a resolver
is buildable; it belongs in the profile load path with a loading and a
not-found state, not bolted onto the route parser. Shipping it half-wired would
turn a missing feature into a wrong screen.

**Rich previews (OG/Twitter cards) are not implemented.** Hosting rewrites every
path to `index.html`, so a crawler receives the app shell and no per-link
metadata. Real previews need server-rendered HTML per entity — a hosting
function or prerender step, outside a Flutter-only change. The share text
carries enough context for chats apps in the meantime.
