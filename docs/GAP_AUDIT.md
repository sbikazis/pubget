# PUBGET — PRODUCT COMPLIANCE & GAP AUDIT

Spec of record: `docs/PUBGET_1_0_SPEC.md` (Prompt 01 paste, unmodified).
Current state of record: `docs/CURRENT_STATE_MASTER.md` at commit
`8f34d212fc22940cdc004e8f0a5fdd94eeb7662e` (PR #21). Claims below treat that
document as fact. Re-checks against live code are noted when used.

This audit does **not** change product code. Classifications use only the
Prompt 01 tags. Scope is `Systemic` or `Local`.

Evidence abbreviations: **CSM** = `docs/CURRENT_STATE_MASTER.md`.

---

## 0 — الرؤية الكبرى (Vision)

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Pubget is one anime-community world (groups + chat + content + games + events + friends + identity), not a pile of separate apps | Domains exist as separate modules (auth, home, groups, chat, private, social, edits, events, games, mafia, anime, fan works, economy, search, settings) wired in `pubget_app.dart` (CSM §3–22) | 🟡 PARTIAL | Systemic | The map of domains is present. Cross-domain loops (first 10 minutes, chat game cards, RP catalogs, ads, Arabic copy) are incomplete, so it does not yet *feel* like one world. |
| User builds friends, groups, interests, favorite anime, creations, memories, achievements, social standing — a daily return reason | Social graph, achievements catalog, home discovery, and notifications exist (CSM §3, §16, §18, §15.1) | 🟡 PARTIAL | Systemic | Building blocks exist; retention/discovery/creator/group/economy loops are only partially closed (see §§106–110). |

---

## 1 — مبادئ Pubget الأساسية (Core principles)

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| 1.1 Quality before feature count; every feature useful, clear, fast, beautiful, stable, extensible | Many screens ship with named placeholders / INCOMPLETE/MOCK inventory (CSM §27) | 🟠 MAJOR GAP | Systemic | Volume of domains is high; a large share is UI-only or server-without-UI. Fails the “serves a real usage loop” test for chat richness, ads, RP, group settings. |
| 1.2 Speed/fluidity: Optimistic / Cached / Lazy / Paginated / Debounced / Background as appropriate | Chat paginates 40; home page size 8; economy caches when offline; NetworkService 15s probe (CSM §3.4, §8.3, §24) | 🟡 PARTIAL | Systemic | Pagination/caching exist in core paths. No adaptive media quality. Several retries are no-ops. Group unread-from-`lastReadAt` not implemented (CSM §8.3). |
| 1.3 No neglected logic states (success/loading/empty/error/offline/session/permission/deleted/left/expired/conflict/retry) | Production-state coverage is uneven; notification retry is `onRetry: () {}`; join stores `uid: ''`; chat sticker/audio/reply are snackbars (CSM §5.3, §8.2, §16.2, §24, §27) | 🟠 MAJOR GAP | Systemic | Spec §1.3 is an explicit non-negotiable. No-op retry and stub membership are neglected states, not polish. |
| 1.4 Minimum taps; important spaces nearby; no buried nested menus | Bottom nav has 4 tabs; no app-wide Drawer; many domains only via AppBar / group endDrawer / settings (CSM §4) | 🟠 MAJOR GAP | Systemic | Spec §8 wants five tabs including My Groups **and** Joined. Store, Premium, Guide, Anime, Fan Works are extra hops. |

---

## 2 — هوية Pubget (Identity)

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| 2.1 Personality: Anime, Premium, Social, Dynamic, Youthful, Immersive, Professional | Design system + Royal Purple/Gold + splash copy “Premium Anime Community” (CSM §1.2, §22.1; `lib/core/README.md` in live tree) | 🔵 IMPROVE | Systemic | Tokens and copy aim at the identity. Placeholders (“Sponsored”, “later Pubget prompt”) and draft terms undercut Premium/Professional. |
| 2.2 Royal Purple + Gold; Dark + Light; unified system not per-screen invention | Settings theme System/Light/Dark; design-system widgets; debug `/design-system` (CSM §19, §4.5) | 🟡 PARTIAL | Systemic | Unified widgets exist. Spec still wants every screen on that system; CSM does not prove visual QA across all domains. |
| 2.3 Arabic + English; real RTL **and** translated UI, not chrome-only | `supportedLocales` en/ar; no `.arb` / `lib/l10n`; feature copy is English literals; RTL Material chrome applies (CSM §26) | 🟠 MAJOR GAP | Systemic | Locked decision (§122). Choosing العربية flips direction, not product copy. |

---

## 3 — بنية التطبيق الرئيسية (App structure)

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Interconnected system listing Auth through Migration | Route table and function exports cover most named domains (CSM §4.2–4.3, §23.3) | 🟡 PARTIAL | Systemic | Names exist. Moderation, migration, real analytics, app-wide drawer, and several contracts are missing or stubbed. |
| Permissions, Background Notifications, Analytics/Ranking, Security, Reliability, Offline/Retry, Moderation, Migration as first-class | Ranking/discovery server-side (CSM §3.3; `docs/DISCOVERY.md`); FCM tokens + some push types (CSM §16); LoggingAnalytics (CSM §22.1); no data-migration pipeline (CSM §28) | 🟡 PARTIAL | Systemic | Ranking is real. Analytics is a logging stub. Migration is absent. Moderation is mostly absent except Fan Work reports. |

No single CSM section maps 1:1 to spec §3; evidence is the union of CSM §1–28.

---

## 4 — Authentication

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Login: email, password, Google, Create Account, Forgot Password + validation, loading, error mapping, network, session restore | Login/register/forgot/Google implemented; Firebase error map; offline banners; Auth session restore (CSM §1.3–1.9) | 🟡 PARTIAL | Local | Core flow matches. Google cancel is silent (no banner). |
| Register: email, password, confirm, Google, login link, full validation | Confirm + terms checkbox; mismatch and terms snackbar (CSM §1.5) | 🟡 PARTIAL | Local | Terms acceptance is in-memory only (`auth_draft_store.dart`). Terms copy is draft (CSM §1.5, §27). |
| First launch: Splash → Firebase → unauth Login / incomplete Onboarding / complete Home; no weird interstitial | `AuthRouteGuard` + Splash resolve (CSM §1.1–1.2) | 🟡 PARTIAL | Local | Path matches. `/terms` is unguarded. Debug `/design-system` exists. Onboarding skip can enter Home without a confirmed Firestore write (CSM §2.3, §24). |

---

## 5 — Onboarding

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Not a form; build a world; minimum Username, Profile image, Basic identity, Anime interests; later expansion without forcing everything | Two optional steps: avatar/username/displayName then bio + six genre chips; Skip → Home (CSM §2.1–2.2) | 🟡 PARTIAL | Local | Skip and optional fields match “don’t force everything.” Interests are genre labels, not anime/character identity. Username/displayName are not on later edit-profile form (CSM §17). |
| Profile create/update persists identity fields | `PubgetUser.toMap()` sends `displayName` / `whoCanMessageMe`; Firestore create/update allowlists omit them (CSM §2.3, §23.1, §27) | 🔴 CRITICAL | Systemic | Client/rules contract break. Onboarding and privacy fields may be dropped or fail writes. This is logic + security, not polish. |

---

## 6 — أول عشر دقائق (First 10 minutes)

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Help user join an active group, see strong Edits, join Event/Game, find people, start Friends/Fans/Interests, pick anime/characters — so they do not close the app | Home shows promoted/rising/recommended groups, people, edits/events/games/fan-works/anime strips (CSM §3.1–3.3) | 🟠 MAJOR GAP | Systemic | Surfaces exist as a feed, not as a first-session guided loop. No CSM counterpart for a dedicated first-10-minutes journey. Cold start still returns types (`docs/DISCOVERY.md`), but there is no onboarding-to-join-to-watch-to-play script. |

---

## 7 — Home

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| 7.1 Discovery feed (not a static dashboard); promoted/rising/recommended groups, edits, events, anime, fan works, people, etc. | Canonical sections 1–10 including those families (CSM §3.2) | 🟡 PARTIAL | Local | Most listed families have a strip. Missing as named Home modules: Anime of the Week, Popular discussions, Community highlights as specified; several strips are still enum-named `*Placeholder` (CSM §27). |
| 7.2 No fixed order; session can differ; rank by interests/activity/freshness/relevance/social/membership/velocity/quality/promoted; do not kill a whole type when interest drops | `displayOrder` only moves empty loaded sections to the tail; ranking inside `getDiscoveryFeed` + rising scores (CSM §3.2–3.3; `docs/DISCOVERY.md` diversity/cold start) | 🟡 PARTIAL | Local | Intra-section ranking is real and diversity-aware. Inter-section order is canonical, not per-session. Promoted/rising/community queries do **not** apply the discovery block filter (CSM §3.3). |
| 7.3 Small/new groups get Rising/Discovery, not only paid | `risingEligible` 2–200 members, age ≤180, score >0; hourly `refreshGroupActivityScores` (CSM §3.3) | 🟢 PASS | Local | Matches the locked “small groups get discovery” decision. Remaining issue is block-filter inconsistency (row above), not absence of Rising. |

---

## 8 — Main Navigation

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Tabs: Discover, My Groups, Joined, Private, Edits + rest via Home/Drawer/contextual | Bottom `NavigationBar`: Discover, Groups, Private, Edits (CSM §4.1) | 🟠 MAJOR GAP | Systemic | Four tabs, not five. **Joined** is not a first-class tab. Spec §8 is explicit. |

---

## 9 — Drawer

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Real control surface: My Profile, Private Chats, My Groups, Joined, Suggested Groups, Dragon Store, Premium, Settings, Guide, … | No app-wide Drawer. Home AppBar: coins, notifications, settings, avatar. Group chat has an **endDrawer** menu (CSM §4, §4.4) | ⚪ MISSING | Systemic | Group endDrawer is not the spec Drawer. Store/Premium/Guide are reachable only by extra routes. |

---

## 10–21 — Groups, roles, permissions, roleplay

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Three types remain: Public, Anime Roleplay, Open Roleplay; extensible | `GroupType { public, animeRoleplay, openRoleplay }` client + server (CSM §5.1) | 🟢 PASS | Local | Locked decision honored. |
| Creation: name, image, description, type, anime, rules, join mode, capacity, RP settings, permissions, privacy, discovery; easy for a normal user | Wizard: identity → type → privacy/join → rules → review; `animeId` required for anime RP; server ignores client `maxMembers`; no image in listed wizard steps (CSM §5.2) | 🟡 PARTIAL | Local | Usable create path. Image, capacity, RP settings, permission presets, post-create settings form are missing or unused. |
| Access: non-member → Details; founder → founder Details; member → Chat directly | Post-frame redirect member && !founder → `/group-chat` (CSM §5.3) | 🟢 PASS | Local | Matches spec friction rule. |
| Details: image, name, description, anime, members, status, join/request/chat/share/rules/info/media/events/management by permission | Details + join actions + founder manage/disband; settings/unban have **no Flutter UI** (CSM §5.3–5.5) | 🟠 MAJOR GAP | Local | `updateGroupSettings` / `unbanMember` exist server-side with zero `lib/` callers (CSM §5.4, §27). Founders cannot edit the group in-app. |
| Roles group-scoped: Founder, Shogun, Commander, Captain, Sensei, Senpai, Member | Same seven on client and server (CSM §6.1) | 🟢 PASS | Local | Founder/Shogun remain admin core. |
| `groupModerator` rules helper includes `hakusho`, which is not in the role enum | CSM §6.1, `firestore.rules` 52–55 | 🟡 PARTIAL | Systemic | Dead token in an OR list; it does not grant a real role. Still a rules/product mismatch that must be deleted or mapped. Not a write hole by itself. |
| Founder sensitive ops need confirmation + permission validation | Disband two dialogs; transfer two dialogs + token (CSM §5.3, §6.3) | 🟡 PARTIAL | Local | Disband/transfer confirmed. Other sensitive mutations (kick/ban) lack client permission checks (CSM §6.3). |
| Clear per-role permissions | Shared `ROLE_PERMISSIONS` map; stored at `groups/{id}/roles/{roleId}` (CSM §6.2) | 🟢 PASS | Local | Permission model exists. UI to change a member’s role does not send the picked role (next row). |
| Members list: searchable/filterable, rank/activity sort; role change fast, clear, gated, confirmed | Change-role popup **always sends `GroupRole.senpai`** regardless of pick (CSM §6.3, §27) | 🔴 CRITICAL | Local | This breaks the role system’s logic. The UI lies. Spec: role change must be understood and permission-protected. |
| Join success must leave a real membership | After join, `_membership = GroupMember(uid: '', role: member)` (CSM §5.3, §27) | 🟠 MAJOR GAP | Local | Stub uid can break founder/member checks and post-join UI. Neglected success state (§1.3). |
| Avatar tap → Profile everywhere | Home avatar → `/profile` (CSM §3.1). No CSM audit that chat/members/comments/edits/notifications/search avatars all navigate | 🟡 PARTIAL | Systemic | No clean 1:1 CSM section for the global avatar rule. Home/profile path exists; global rule is unverified. |
| Join: Open, Request, Invite | `open` / `approval` / `inviteOnly` + invite redeem (CSM §5.4) | 🟢 PASS | Local | Server and details UI match. |
| Roleplay join: see characters, search, suggestions, self-pick, not assigned | Four hardcoded mocks `hero/rival/mentor/trickster`; empty avatars; copy “All mock characters may already be reserved.”; `releaseCharacter` unused (CSM §7, §27) | 🟠 MAJOR GAP | Local | Locked “specialized RP join” is a mock. No anime-specific catalog. |

---

## 22–29 — Group Chat

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Rich social chat, not text-only | User-sendable: text, image, video. Sticker/audio/GIF/reply/forward/report are snackbar placeholders (CSM §8.1–8.2, §27) | 🟠 MAJOR GAP | Local | Pillar domain (spec §122). Media send exists; the rich layer is fake. |
| Header: avatar, name, back, menu; long name marquee | Group chat scaffold + endDrawer three-dot (CSM §4.4, §8). Marquee not documented in CSM | 🟡 PARTIAL | Local | Menu exists. Marquee/scrolling title has no CSM evidence. |
| Per-group background; default Pubget background; change by permission | Menu “chat background”; server `updateBackground` requires `manageBackground` (CSM §5.5, §4.4) | 🟡 PARTIAL | Local | Path exists. Default-on-first-entry and quality of the picker are not evidenced as complete. |
| WhatsApp-like bubble: avatar, name, role badge/color, text, time, delivery 🔴🟡🟢 | Delivery/read batched to `deliveredBy`/`readBy`; `message delivery indicator` tests exist (CSM §8.3, §25) | 🟡 PARTIAL | Local | Status plumbing exists. Full WhatsApp parity (role color on every bubble, failed/sent/read UX) is not claimed complete by CSM. |
| Message types: text, image, video, sticker, GIF, audio, replies, system, game/event cards | Enum includes them. Composer implements text/image/video; event cards from events domain; game cards render-only, no production writer (CSM §8.1, §22.2, §27) | 🟠 MAJOR GAP | Local | See placeholders. Game→chat contract is unfulfilled in production. |
| Actions: reply, copy, delete, pin, edit, react, forward where logical | Copy/react/pin/delete real; reply/forward/report placeholder; `editGroupMessage` no UI (CSM §8.2) | 🟠 MAJOR GAP | Local | Pin/delete not hidden by permission on the client (CSM §8.2). |
| Stickers: picker, saved/recent/categories, future custom | Snackbar only; rules allow `users/.../stickers` (CSM §8.1, §23.1) | ⚪ MISSING | Local | Storage path is not a product. |
| Performance: paginated, cached, incremental; no thousands of messages | Live limit 40 + load older (CSM §8.3) | 🟡 PARTIAL | Local | Pagination exists. Group-list unread from `lastReadAt` not implemented in `lib/features/groups` (CSM §8.3). |
| `lastMessageAt` / `lastMessageText` server-written on send but still member-writable in rules | CSM §8.3, §23.1 | 🔴 CRITICAL | Systemic | Spec §85–96: do not trust the client. Any member can spoof preview/activity used by Home community activity (CSM §3.3). |

---

## 30–37 — Games in chat / Mafia

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Games do not own Chat; flow Game → menu → create → announcement card → waiting → private room → engine → results → chat card | Group details/chat menu → `/games`; results/rewards server-side; **no production writer** of group `type: "game"` cards (CSM §10.1, §22.2) | 🟠 MAJOR GAP | Local | Isolation is good. The chat announcement/results contract is missing. |
| Each game independent, state-driven, recoverable, no chat internals mutation | Trivia on `games/{id}` callables; snapshots on `open()` (CSM §10.1, §22.2) | 🟡 PARTIAL | Local | Architecture matches. `difficulty` stored unused; reconnect string unused (CSM §10.1, §27). |
| Guess Character 1v1: waiting, rounds, timer, score, result, anti-abuse, replayability | 2 players, timer, secret round, artwork (CSM §10.2) | 🟡 PARTIAL | Local | No auto-matchmaking (CSM §10.1). Engine is real. |
| Anime Chain: turns, timeout, score, cancel, recovery | 2–8, turn/game_over, timeout skip (CSM §10.3) | 🟡 PARTIAL | Local | Core loop exists. |
| Emoji Anime Guess 2–4: 3–4 emojis, guess, rotate, timer, anti-spam, end state | 2–4, guess/game_over, timeout advances (CSM §10.4) | 🟡 PARTIAL | Local | Core loop exists. Catalog is 16 anime (CSM §10.1). |
| Mafia independent, server-authoritative, phase/timer/reconnect/disconnect/role/action/anti-cheat; full phase list; per-role logic | Separate `mafia_games`; schedulers; private roles; heartbeat 25s / disconnect 90s (CSM §11) | 🟡 PARTIAL | Local | Substantial engine. Night/vote/mafia-chat are **client intent writes** gated by rules (CSM §11.4) — acceptable if resolution stays server-side, but not fully “action-safe” in the strictest reading. |
| Mafia UX: waiting room, role presentation, banners, timers, sheets, voting, results, suspense, history | `MafiaGameScreen` exists; no leave-game UI despite callable (CSM §11.4, §27) | 🟠 MAJOR GAP | Local | Leave is a real game action, not a nice-to-have. |
| `good_boy` registered but never assigned | CSM §11.3, §27 | 🟡 PARTIAL | Local | Dead role in the registry. Does not break live assignment of mafia/doctor/detective/citizen. |
| Client registry `mafia implemented: true` vs server `implemented: false` | CSM §10.1, §27 | 🟠 MAJOR GAP | Local | Dual contract. Dedicated `/mafia` path works; `createGame` catalog would hide/reject Mafia. Product logic is inconsistent. |

---

## 38–41 — Events

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Not just Poll; types Poll, Comparison, Theory, Quiz, Challenge, Prediction, Ranking, Discussion, … | poll, multipleChoice, ranking, versus, theory, prediction, quiz, comparisons, openDiscussion, challenge (CSM §12) | 🟡 PARTIAL | Local | Broad type set. “Community question” as a named type is not listed. |
| Max duration 7 days (configurable within range) | `MAX_DURATION_MS` 7 days client + server (CSM §12) | 🟢 PASS | Local | Locked decision. |
| Launch in group; notifications, activity, results, rewards, chat cards; Event domain independent of Chat | Callables + cron; `postEventChatActivity`; `earn_event`; `event_starting` / `event_ended` (CSM §12, §16.1) | 🟡 PARTIAL | Local | Domain isolation via Admin chat card is the specified contract. `event_ended` pushWorthy not set true (CSM §12). |

---

## 42–49 — Edits

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Video-only platform: upload, validation, processing, compression, thumbnail, metadata, **moderation**, publish | Pipeline ffmpeg/thumbnail/duration/size; publish + `earn_publish`; **no moderation step** (CSM §13, §27) | 🟠 MAJOR GAP | Local | Pipeline is real except moderation, which the spec lists as a required stage, not a later extra. |
| Ranking feed; no content-killing; diversity | `orderBy score`; `scoreEdit` + `mixExploration` 20% tail (CSM §13; `docs/DISCOVERY.md`) | 🟡 PARTIAL | Local | Ranking + diversity exist. Feed query itself is score/createdAt, not the full discovery mix unless Home uses `recommendedEdits`. |
| TikTok-level interaction + Pubget identity | Feed + upload pages exist (CSM §13) | 🔵 IMPROVE | Local | CSM does not claim TikTok-level motion/interaction quality. |
| View, Like, Comment, Reply, Share, Save, Creator profile, Respect | View/like/comment/reply/share/save signals; Respect is **not** an edits action; delete not on feed UI (CSM §13) | 🟡 PARTIAL | Local | Respect gap vs spec list. |
| Comments: replies, likes, stickers, sort, pagination, loading, empty, moderation | Comment/reply/like exist; stickers/moderation in comments not evidenced (CSM §13) | 🟡 PARTIAL | Local | Social comments exist; not a full spec comments space. |
| Views anti-cheat: not +1 per open; qualified rules | `recordEditView`: not self, ≥10% elapsed, once/day, completion ≥90% (CSM §13; `docs/DISCOVERY.md`) | 🟢 PASS | Local | Clear view contract. |

---

## 50–52 — Creator / Fan / Respect / Friends

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| No Follow-as-core; Respect → Fan at 5+; see creator’s new work | `FAN_THRESHOLD` 5; `fans/{fanId}` rules read/write false; achievement `fan_gained` (CSM §18) | 🟡 PARTIAL | Local | Relationship write is server-side. Fan feed of “creator’s new work” as a dedicated surface is not documented in CSM §18. |
| Respect: grant, accumulate, display, unlock private chat; anti-spam/farm/abuse | 0–7, 3000 ms cooldown, block check (CSM §18, §9) | 🟡 PARTIAL | Local | Core mechanic exists. Farming beyond cooldown/block is thin. |
| Full Friends system, not only Fans | pending/accepted/blocked friendships; requests screen (CSM §18, §16.1) | 🟡 PARTIAL | Local | Friends exist. Home promoted/rising/community and edits/fan-work feeds omit some block filters (CSM §18). |

---

## 53–54 — Private Chat

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Independent of group chat: list, last message, unread, delivery, media, replies | Separate `privateChats`; list + load more; unread vs `lastReadAt`; text/image/video; copy/delete; **no reply/react/pin** (CSM §9) | 🟡 PARTIAL | Local | Independent domain: yes. Richness: no. |
| Open chat per Respect/Friends rules; **clear UX**, not a dead button | Server: fan\|\|friend then `whoCanMessageMe`. Client Start Chat uses friend or respect ≥5 and **does not check `whoCanMessageMe`** (CSM §9) | 🟡 PARTIAL | Local | Server still enforces. User can tap Start Chat and get a confusing rejection. Spec explicitly forbids an unclear control. Not 🔴 because the security boundary holds. |

---

## 55–58 — Notifications

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Central inbox for join, roles, group events, disband, likes, comments, replies, view milestones, new edits, respect, fans, friends, messages, events, games, premium, store | Built types listed in CSM §16.1; missing as first-class: role changes, likes/comments/views milestones, new edits, premium, many store events | 🟡 PARTIAL | Local | Core social/group/game/event/economy subset exists. |
| Each notification routes to the right place | `destination` + `AppNavigation.go` (CSM §16.1–16.2) | 🟡 PARTIAL | Local | Built types route. Inbox title switch falls through to generic `Notification` for others (CSM §16.2). Disband write is not via `notificationBuilder` (CSM §16.1). |
| Unread red badges by context (Groups, Joined, Private, Notifications, …) | Private unread computed; group-list unread from `lastReadAt` **not implemented** (CSM §8.3, §9) | 🟠 MAJOR GAP | Systemic | Spec unread system is cross-shell. Shell has no Joined tab and no documented Groups badge. |
| Android push, tap routing, deep links, session-safe | FCM register; PUSH_TYPES subset; pending-route on guarded deep links (CSM §1.1, §16.1, §21) | 🟡 PARTIAL | Local | Push exists for some types. `event_ended` and several economy types are not pushWorthy. |
| Inbox retry and pagination must work | `onRetry: () {}`; `_hasMore` starts true and a short last page can stay true; `close()` does not reset (CSM §16.2, §27) | 🟠 MAJOR GAP | Local | Neglected error/pagination states (§1.3). Not a security issue. |

---

## 59–60 — Anime Hub

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Independent anime-list-like hub: releases, info, ratings, characters, genres, seasons, recommendations, lists, favorites, user ratings, interests | Jikan HTTP + `CachedAnimeRepository`; list/favorite callables; browse/genre/season/library routes (CSM §4.3, §20, §22.1) | 🟡 PARTIAL | Local | Hub exists as a domain. Depth vs MyAnimeList-class (ratings, character interests as first-class discovery fuel) is not fully evidenced. |
| Profile anime identity feeds Discovery | `favoriteAnimeIds` on profile; ranking uses anime overlap (CSM §17; `docs/DISCOVERY.md`) | 🟡 PARTIAL | Local | Wired for IDs. Onboarding interests are genres, not titles (CSM §2.2). |

---

## 61–63 — Fan Works

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Types: Manga, Drawing, Story, Character, AI character, Worldbuilding, … | manga, drawing, story, character, aiCharacter, worldbuilding, other (CSM §14) | 🟢 PASS | Local | Type set matches. |
| Publish, browse, rate, like, comment, reply, share, save, open creator | Screens + callables for like/bookmark/rate/comment/report (CSM §14, §23.3) | 🟡 PARTIAL | Local | Core loop exists. |
| Ownership metadata, attribution, timestamps, reporting, moderation, user rights | `creatorId`; report sets `moderationStatus: flagged`; **publish sets `approved` with no human queue** (CSM §14) | 🟡 PARTIAL | Local | Report flag exists. Auto-approve is not moderation. |

---

## 64–72 — Economy, Store, Premium, Ads

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Coins from participation, events, games, creation, contribution, referrals, achievements, milestones; anti-farm | Server `applyReward` table + daily caps + duplicate rejection (CSM §15.1) | 🟡 PARTIAL | Local | Real ledger. Referral claim is the only `claimEconomyReward` source. `admin_adjustment`/`refund` are enum-only (CSM §15.1, §27). |
| Enough sinks if sources expand; store must not be empty | 7 catalog rows, one `inactive` (CSM §15.2) | 🟡 PARTIAL | Local | Not empty. Thin vs spec cosmetics/extensions ambition. |
| Store: (1) technical extensions (2) physical deferred (3) luxury/cosmetics | Catalog is frames/badges/nameplates/themes; `physical_products` readable signed-in (CSM §15.2, §23.1) | 🟡 PARTIAL | Local | Cosmetics exist. Technical extensions (capacity/limits) not in the listed catalog. Physical collection exists but spec says defer — do not build UI that complicates 1.0 (see §111). |
| Ads are the income source; **no coins-remove-ads**; real placements, frequency, premium behavior, loading/failure, fallback, no duplicate ads | Guide: “Coins cannot remove ads.” `rewardedCoinsEnabled: false`. Premium `adFree`. UI: one static Home `Sponsored` card. No Dart ad SDK. Vungle artifact in Gradle only. Other placements configured but not placed (CSM §0.4, §15.3–15.4, §27) | 🟠 MAJOR GAP | Local | Coins-remove-ads is **not** in the active app (no ⚫). Ads **product** is a placeholder. Premium-adFree is allowed as “premium behavior,” not coin-removal. |
| Premium: real membership — badge, limits, exclusive cosmetics, extra features, less friction | `subscriptionType === premium` && expiry; premium catalog; `adFree` (CSM §15.3) | 🟡 PARTIAL | Local | Entitlement model exists. |
| No Play Billing yet; architecture ready for subscriptions + digital purchases | No Paddle/webhook; `restorePremiumPurchases` permanent no-op `{ deferred: true, reason: payment_provider_not_configured }` (CSM §15.3, §27) | 🟡 PARTIAL | Local | Spec §112 says billing is unused **now**. Stub restore is honest, not a fake payment. “Architecture-ready” is only partial (no provider interface beyond the no-op). |

---

## 73–76 — Settings, Guide, Search

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Settings: account (info, email, password, profile, privacy, security, logout), appearance, language, notification categories, privacy | Email display, password reset, sign out, theme, locale, link to profile/privacy, Guide, Terms, version (CSM §19) | 🟡 PARTIAL | Local | No notification category toggles, no security center, username not editable here. |
| Guide covering Groups, Chat, Games, Events, Edits, Respect, Fans, Friends, Coins, Store, Premium, Anime, Fan Works, Settings | Static English `GuideTopic.all`; some topics have routes; Chat/Roles/Roleplay/Respect/Moderation have **no route** (CSM §19) | 🟡 PARTIAL | Local | Exists as a screen. Not bilingual; several pillars unlinked. |
| General search (users, groups, events, anime, fan works, edits when contracted) + contextual (members, anime, characters, stickers, …) | Global `/search`: groups, people, events, fan works, anime. Not: edits, private chats, games, mafia, store. Group home has a local name filter (CSM §20) | 🟡 PARTIAL | Local | Solid general search minus edits. Contextual search family is mostly missing. Home inline search vs controller listener is UNVERIFIED (CSM §3.5). |

---

## 77–84 — Deep Links, Sharing, Profile, Social Graph, invitations, group menu, media

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Shareable canonical links for group, profile, edit, fan work, event, anime, game, store, …; copy + native share; no private leakage | Builders for event/fan-work/game/mafia/anime/group/profile; clipboard + `share_plus` (CSM §21) | 🟡 PARTIAL | Local | Edit and store canonical builders not listed. Host `/` is marketing `presentation.html`. `/g/` hosting rewrite has no Flutter parser (CSM §21). |
| Profile: avatar, username, premium, bio, stats, respect, fans, friends, anime, characters, ratings, edits, fan works, groups, achievements, activity; user-controlled visibility | Own vs other layouts; public projection; `profileVisibility` / `activityVisibility` / `whoCanMessageMe` (CSM §17) | 🟡 PARTIAL | Local | `activityVisibility` stored, unused in profile read UI. Others’ UI cannot show `displayName` from `PublicProfile` model (CSM §17). Direct client `avatarUrl` Firestore write (CSM §17). |
| Social graph: Respect → Fan → Friend + privacy, blocking, anti-abuse, relationship state | Implemented with block checks on several paths; gaps on some feeds (CSM §18) | 🟡 PARTIAL | Systemic | Model matches. Feed-level block holes remain. |
| Invite from Chat → private chats → pick people → rich welcome (name, description, link) | Chat endDrawer “Add members”; `createGroupInvite` 7-day (CSM §4.4, §5.4) | 🟡 PARTIAL | Local | Invite exists. “Luxurious welcome message from private chats” flow is not documented as specified. |
| Group menu: add members, copy link, info, media, members, edit, leave, dismantle (authorized), events, settings, … | EndDrawer covers add/copy/info/events/games/media/members/edit(founder)/background/leave/disband (CSM §4.4) | 🟡 PARTIAL | Local | Settings entry missing (no UI). Games included (good). Shogun dismantle vs founder-only disband (CSM §6.3 founder-only). |
| Group media: images/videos/stickers, paginated | Media page filters **currently loaded chat messages only** (CSM §8.3) | 🟠 MAJOR GAP | Local | Not a media library; it is a slice of the open chat window. |

---

## 85–96 — Offline, performance, UI, accessibility, security, storage, anti-abuse, moderation

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Every screen knows No-Internet: cache, retry, banner, queue, degradation | `NetworkService`; many screens map `NetworkError`; chat optimistic send + retry; economy cached snapshot; no join/game queue (CSM §24) | 🟡 PARTIAL | Systemic | Pattern exists, not universal. Notification retry is a no-op. Onboarding skip pretends success offline (CSM §24). |
| Device performance + adaptive media quality | Pagination/caching in places; adaptive quality not documented (CSM §3, §8.3, §24) | 🟡 PARTIAL | Systemic | No CSM claim of adaptive bitrate or rebuild discipline across the app. |
| Unified Design System (buttons, cards, fields, dialogs, sheets, snackbars, empty/error/loading, avatars, badges, …) | `lib/core/widgets/pubget_*`; debug showcase (CSM §4.5, §25) | 🟡 PARTIAL | Systemic | System exists. Placeholders and English snackbars are not on-system empty/error patterns. |
| Visual quality / meaningful motion / accessibility (scaling, targets, contrast, RTL, sizes, keyboard, motion) | Accessibility tests exist; RTL chrome without translated copy (CSM §25–26) | 🔵 IMPROVE | Systemic | Technical a11y tests ≠ bilingual, visually QA’d product. |
| Sensitive coins/rewards/premium/roles/permissions/game results/economy/ownership **server-authoritative** | Most mutations are callables; exceptions: `lastMessage*`, Mafia night/vote/chat client writes, nested `groups/.../games` moderator-writable, `user_seen` client-writable, avatarUrl client update, `PubgetUser.toMap` vs allowlist (CSM §23) | 🔴 CRITICAL | Systemic | Multiple trust-boundary leaks. Spec: backend must prevent the wrong request, not hope the client omits it. |
| Storage validated, size/type limited, access-controlled, organized, moderated where needed | Named Storage rules with size/MIME (CSM §23.2) | 🟡 PARTIAL | Systemic | Limits exist. Edits/chat moderation of blobs is pipeline/absent (CSM §13). |
| Anti-abuse: spam, respect farm, coin farm, fake views/likes, malicious upload, message/game/referral abuse | Caps, cooldowns, qualified views, idempotent economy ids, game `clientActionId` (CSM §10.1, §13, §15, §18) | 🟡 PARTIAL | Systemic | Partial. Message abuse / report is a placeholder (CSM §8.2). |
| Moderation structure: report, moderation, blocking, removal, restrictions | Block + Fan Work report flag; group chat report placeholder; edits none (CSM §8.2, §13, §14, §18) | 🟠 MAJOR GAP | Systemic | Blocking exists. Content moderation is not a platform. |

---

## 97–101 — Architecture, domain isolation, legacy, migration

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| UI → Provider → Repository → Firebase/API; no business logic in widgets | Wiring matches (CSM §22.1). Widgets still own join stub, hardcoded senpai, chat placeholders, onboarding skip success, notification retry no-op | 🟡 PARTIAL | Systemic | Direction is right. Several product bugs live in widget/provider shortcuts. |
| Domain isolation; Mafia/Games/Events talk to Chat via contracts, not internals | Trivia does not import ChatProvider; Events Admin-write chat cards; Mafia has its own chat collection; no production game cards (CSM §22.2) | 🟡 PARTIAL | Systemic | Isolation mostly holds. Missing game cards. Nested `groups/{id}/games` client-writable for `groupModerator` is a stray path (CSM §22.2, §23.1). |
| Keep useful legacy data, not legacy architecture; extract/map/validate/migrate/verify | No Old→New migration pipeline documented (CSM §28) | ⚪ MISSING | Systemic | Spec §101. Production still uses `pubget-aaf27` (CSM §0.5) without a documented mapping layer. |
| `lib_legacy/` kept, not imported by new architecture | Grep `lib/` → no `lib_legacy` matches; dormant tree (CSM §28) | 🟢 PASS | Systemic | Isolation honored. Do not delete in this audit. |
| Each data type: Old Schema → Mapping → New Schema | Not present (CSM §28) | ⚪ MISSING | Systemic | Same as migration row. |

---

## 102–105 — Testing, production states, analytics

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Unit, integration, security/rules, regression, real-device | Flutter 294 / functions 168 / rules+E2E 62 all pass at `8f34d21` (CSM §25). No named Flutter tests for mafia play, group chat composer, edits playback, notification hasMore/retry, RP reservation UI | 🟡 PARTIAL | Systemic | Strong automated base. Real-device verification UNVERIFIED. Critical UI bugs are untested. |
| Every screen: loading/success/empty/error/offline/unauthorized/forbidden/deleted/expired/retry/partial | Scattered; several retries/no-ops (CSM §24, §27) | 🟠 MAJOR GAP | Systemic | Spec production-states requirement is not met app-wide. |
| Analytics: opens, completion, engagement, retention, … without privacy violation | `LoggingAnalytics` only (CSM §22.1) | 🟠 MAJOR GAP | Systemic | Not a measurement system. |

---

## 106–110 — Loops and exclusions

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Retention loop (friend activity, new edit/event, group discussion, anime, fan work, game, respect, notification, achievement) without spam | Partial notification set + home strips (CSM §3, §16) | 🟠 MAJOR GAP | Systemic | Pieces exist; not a designed loop. Missing several notification types. |
| Discovery loop: see → interact → discover → join → participate → create → respect/fans/friends → coins → spend → return | Ranking + social + economy exist as separate engines (CSM §3, §15, §18) | 🟠 MAJOR GAP | Systemic | Spend catalog thin; RP/chat richness/ads/first-session gaps break the loop. |
| Creator loop: publish → discovery → views → social → respect → fans → more creation | Edits/fan works publish + ranking + respect on profiles (CSM §13–14, §18) | 🟡 PARTIAL | Systemic | No Respect on Edits (CSM §13). Auto-approve fan works. |
| Group loop: discover → join → chat → friends → events → games → identity | Join + chat + events + games paths exist (CSM §5, §8, §10, §12) | 🟡 PARTIAL | Systemic | Broken by chat placeholders, stub join uid, missing settings/unban, game cards. |
| Economy loop: contribute → earn → spend cosmetics/extensions → more participation; **no pay-to-win** | Earn table + cosmetics; Guide pay-to-win language (CSM §15; `guide_page.dart` cited in CSM §15.4) | 🟡 PARTIAL | Systemic | No pay-to-win in active economy. Extensions catalog missing. |
| 110. We will not do: pay-to-win, gambling, loot boxes, crypto, P2P money, coins-remove-ads | Active `lib/`: Guide forbids coins-remove-ads; `rewardedCoinsEnabled: false`; Premium `adFree` is membership, not coin spend (CSM §15.4). No loot-box/crypto/P2P in CSM | 🟢 PASS | Systemic | No ⚫ in the **active** app. Do not revive coins-remove-ads. If `lib_legacy` still contains old ad/coin experiments, keep it dormant (CSM §28). |

---

## 111–115 — Current constraints and experience quality

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Physical store deferred; architecture may allow later | `physical_products` rules allow signed-in read; no CSM of a shipping 1.0 physical checkout (CSM §23.1) | 🟢 PASS | Local | Do not expand physical UI in 1.0. Collection can stay. |
| Google Play Billing unused; economy addable later | No billing SDK in `pubspec.yaml` (CSM §0.3); restore no-op (CSM §15.3) | 🟢 PASS | Local | Matches the lock. “Addable later” still needs a real provider seam (🟡 under §64–72). |
| Android is the current platform; don’t load unused platform complexity; architecture extensible | Android id `com.sbikazis.pubget`; iOS + web folders exist; web Firebase unavailable (CSM §0.4) | 🟡 PARTIAL | Systemic | Android is the product target. iOS/web trees add complexity the spec asked not to load. |
| Experience: fast, instant transitions, clear messages, no dead screens, everything has a reason | Placeholder snackbars and dead retry are dead/lying screens (CSM §8.2, §16.2, §27) | 🟠 MAJOR GAP | Systemic | Directly violates “no dead screens” and §1.3. |

---

## 116–119 — Design/dev quality rules and visual references

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Beautiful + Fast + Logical + Useful (not pretty-useless or ugly-functional) | Design system + many functional-but-placeholder surfaces (CSM §4.5, §27) | 🔵 IMPROVE | Systemic | Applies to every later prompt. Current product is closer to functional-with-holes. |
| Don’t add features that fail value/retention/usability/discovery/economy/community/complexity tests | Wide domain coverage already shipped (CSM §3–21) | 🔵 IMPROVE | Systemic | Process rule for **future** prompts. This audit must sequence repair of pillars before new types. |
| Prefer fewer clear features over many complex ones | Dual Mafia registry, mock RP, unused difficulty, unused reconnect string (CSM §27) | 🟠 MAJOR GAP | Systemic | Extra surface area without completing Chat/Home/Groups pillars. |
| Myth: integration Anime → Profile → Group → Chat → Event → Edit → Respect → Friend → Fan → Coins | Partial wiring via discovery + social + economy (CSM §3, §18, §15) | 🟠 MAJOR GAP | Systemic | Same as loops. |
| Learn from WhatsApp/TikTok/Instagram/Discord/MAL; do not copy identity | Chat/edits/home/anime exist as separate takes (CSM §8, §13, §3, §20) | 🔵 IMPROVE | Systemic | No CSM evidence of visual QA against those bars. |

---

## 120 — Rebuild priority tiers

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Tier 1 Core: Performance, Architecture, Home, Groups, Chat, Social graph, Edits | All exist at PARTIAL/MAJOR/CRITICAL mix (this document) | 🟠 MAJOR GAP | Systemic | Tier 1 is not PASS. Sequence next prompts here first. |
| Tier 2 Engagement: Events, Games, Mafia, Notifications, Friends/Fans/Respect | Events/games/mafia/social present; notification/mafia/game-card gaps | 🟡 PARTIAL | Systemic | Do not expand types until Tier 1 holes that block loops are closed. |
| Tier 3 Content: Anime Hub, Fan Works, Search, Discovery | Present at PARTIAL | 🟡 PARTIAL | Systemic | Discovery ranking is one of the stronger subsystems. |
| Tier 4 Economy: Coins, Store, Premium, Ads | Coins/store/premium PARTIAL; ads MAJOR | 🟠 MAJOR GAP | Local | Ads and payment seam are Tier 4; do not block Tier 1. |
| Tier 5 Platform: Settings, Deep Links, Sharing, Security, Migration, Analytics, Hardening | Settings/links PARTIAL; security CRITICAL; migration MISSING; analytics MAJOR | 🔴 CRITICAL | Systemic | Security hardening is Tier 5 in the spec list but several holes are **already in production rules**. Treat rules fixes as a prerequisite, not a late polish. |

---

## 121 — القرار النهائي (this audit)

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| After locking the spec, run a compliance/gap audit with the seven tags + Systemic/Local — do not randomly fix screens | This file; spec at `docs/PUBGET_1_0_SPEC.md`; no product code in this prompt | 🟢 PASS | Systemic | Prompt 01 obligation. Do not start Prompt 18-style implementation in the same pass. |

---

## 122 — Locked product decisions (checklist)

| Locked decision | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Anime social platform; quality first; speed non-negotiable | Placeholders + no-op retries (CSM §27, §16.2) | 🟠 MAJOR GAP | Systemic | Decisions are documented; the app does not yet honor speed/quality as non-negotiable. |
| Groups + Chat + Edits + Events are pillars | All four have domains; Chat richness and Edits moderation lag (CSM §8, §12, §13) | 🟠 MAJOR GAP | Systemic | Pillars exist as modules, not as finished products. |
| Home dynamic; small groups get discovery | Rising + ranked feed (CSM §3.3) | 🟡 PARTIAL | Local | Rising PASS; Home order still canonical. |
| Three group types stay; RP specialized join | Types PASS; RP mock (CSM §5.1, §7) | 🟠 MAJOR GAP | Local | Type lock held; RP join lock not. |
| Chat is rich; Games isolated; Mafia highly organized | Chat placeholders; games isolated; Mafia engine real but dual registry / no leave (CSM §8, §10–11) | 🟠 MAJOR GAP | Local | |
| Respect basis; 5 → Fan; full Friends | Implemented (CSM §18) | 🟡 PARTIAL | Local | |
| Edits video-only; Events ≤7 days | Video pipeline + 7-day cap (CSM §12–13) | 🟢 PASS | Local | Moderation still open on Edits. |
| Anime Hub + Fan Works inside the app | Both routed (CSM §4.2–4.3, §14, §20) | 🟡 PARTIAL | Local | |
| Wide economy; coins as fuel; digital store + cosmetics/extensions; physical deferred | Thin cosmetics catalog; extensions missing (CSM §15) | 🟡 PARTIAL | Local | |
| Ads are income; not removable with coins; Premium independent | No coins-remove-ads; ads placeholder; premium entitlement (CSM §15.3–15.4) | 🟠 MAJOR GAP | Local | Ads gap, not a REMOVE finding. |
| Search where needed; Deep Links; Sharing; Privacy controls | Partial (CSM §17, §20–21) | 🟡 PARTIAL | Systemic | |
| Arabic + English; Android now; offline/error/retry per domain | RTL-only Arabic; Android primary; retry holes (CSM §0.4, §24, §26) | 🟠 MAJOR GAP | Systemic | |
| Migrate useful old data; drop untranslatable; no random legacy rewrite; **no Prompt 18 before this audit** | `lib_legacy` dormant; no migration; this audit is the gate (CSM §28) | 🟡 PARTIAL | Systemic | Process lock for Prompt 18 is honored here. Data migration still MISSING. |

---

## 123 — Six correctness lenses

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Tests passing ≠ Pubget 1.0. Judge Technical / Product / UX / Visual / Business / Production | CSM §25: 294+168+62 pass. CSM §27: long mock inventory. This audit: product/UX/business/production incomplete | 🟠 MAJOR GAP | Systemic | Technical Correctness is the only lens near PASS. Spec §123 is the release bar for later prompts, not a claim that the current app is done. |
| Semi-final: no known/intentional gap in-scope, no fake features, no hidden missing backend, automated tests where possible, critical paths really tested | Placeholders are **announced** (snackbar/copy) which is better than silent fakes, but they are still fake features (CSM §27). Several critical paths untested (CSM §25) | 🟠 MAJOR GAP | Systemic | Honest placeholders still fail “no fake features.” |

---

## Localization / RTL (spec §2.3, §122 — explicit coverage)

| Requirement | Current State (evidence) | Classification | Scope | Notes |
|---|---|---|---|---|
| Full Arabic + English product copy and two-direction layout | No `.arb`; English literals when locale is `ar` (CSM §26) | 🟠 MAJOR GAP | Systemic | Must appear in the audit as its own gap, not only under Identity. |

---

## Known-findings completeness check (Prompt 01 list)

Each item is classified on its own, not bulk-tagged CRITICAL.

| Finding | Classification | Why |
|---|---|---|
| Mafia dual registry (server `implemented: false`, client `true`) | 🟠 MAJOR GAP | Logic/contract split. Dedicated Mafia path works; catalog/createGame would not. Breaks product consistency, not the night resolver. |
| `lastMessageAt` / `lastMessageText` still member-writable | 🔴 CRITICAL | Security + Home activity integrity. Server already writes them; client write is leftover trust. |
| Private Start-Chat skips `whoCanMessageMe` (server still enforces) | 🟡 PARTIAL | UX/logic gap. Not a bypass. Spec wants a clear control, not a surprising failure. |
| `PubgetUser.toMap()` sends `displayName` / `whoCanMessageMe`; rules omit them | 🔴 CRITICAL | Create/update allowlist mismatch. Can drop identity/privacy fields or fail onboarding writes. |
| Roleplay catalog four mocks; no anime catalog; no release UI | 🟠 MAJOR GAP | Locked specialized RP join is unimplemented. Honest mock copy does not make it PASS. |
| Sticker, audio, GIF, reply, forward, report = later-prompt snackbar | 🟠 MAJOR GAP | Chat pillar is incomplete. Intentional placeholder, still a major product gap. |
| `updateGroupSettings` / `unbanMember` server-only, no Flutter UI | 🟠 MAJOR GAP | Founder cannot operate the group in-app. Server readiness is not a product. |
| Change-role UI always sends `senpai` | 🔴 CRITICAL | Breaks role/permission logic. The control is false. |
| Join success stores `uid: ''` | 🟠 MAJOR GAP | Corrupts local membership state after a real server success. |
| Mafia `good_boy` never assigned | 🟡 PARTIAL | Dead registry entry. Live roles still assign. |
| No Mafia leave-game UI | 🟠 MAJOR GAP | Callable exists; player cannot leave. Conflicts with disconnect-safe UX. |
| Edits pipeline has no moderation | 🟠 MAJOR GAP | Required publish stage missing. Not a rules bypass of coins, but a pillar hole. |
| No payment provider; `restorePremiumPurchases` no-op | 🟡 PARTIAL | Spec currently forbids requiring Play Billing. Honest deferred restore. Needs a real seam before monetize prompts. |
| Ads = static Sponsored card; Vungle Gradle leftover; no Dart SDK | 🟠 MAJOR GAP | Ads are a locked income source and are fake. Gradle artifact is leftover, not a working mediation. |
| Notification retry no-op; `hasMore` can stick true | 🟠 MAJOR GAP | Broken production states on a central surface. |
| No `.arb`; English literals with Arabic locale | 🟠 MAJOR GAP | Locked bilingual product. RTL-only is insufficient. |
| `groupModerator` references `hakusho` | 🟡 PARTIAL | Stale role token. Clean up in a rules pass; not by itself a privilege escalation. |

Coins-remove-ads remnant in **active** `lib/`: **not found**. Classification: no ⚫ row. Keep it forbidden.

---

## Systemic Issues (fix once, benefits many screens)

- **Firestore/Storage trust pass (🔴):** `lastMessageAt`/`lastMessageText` member writes; `PubgetUser` vs allowlist (`displayName`, `whoCanMessageMe`); `hakusho` helper; nested `groups/{id}/games` moderator client writes; review avatarUrl client update and `user_seen` / `user_interactions` client creates (CSM §23). One rules + client-DTO prompt.
- **Neglected states kit (🟠):** shared retry that actually retries; forbid `onRetry: () {}`; membership objects must carry real uids; no snackbar-as-feature. Benefits inbox, groups, chat, onboarding skip.
- **Shell IA (🟠/⚪):** five-tab spec (Discover / My Groups / Joined / Private / Edits) + app-wide Drawer (Profile, chats, groups, store, premium, settings, guide). One navigation prompt, not per-screen.
- **Bilingual copy (🟠):** `.arb` (or equivalent) + RTL layout already partly present. Every screen inherits.
- **Placeholder action component (🟠):** replace “later Pubget prompt” snackbars with either real actions or a single honest “coming in a later release” pattern that is not mistaken for a working control — then implement Chat richness in a dedicated prompt.
- **Unread engine across shell (🟠):** `lastReadAt` already stored for groups; wire badges for Groups/Private/Notifications (and Joined once it exists).
- **Block filter on non-discovery lists (🟡→systemic):** promoted/rising/community, edits feed, fan-works public list (CSM §18).
- **Production-state / analytics / migration absences (🟠/⚪):** LoggingAnalytics stub; no Old→New migration; uneven empty/error/offline.
- **Widget-layer product bugs (🟡 architecture):** join stub, hardcoded senpai, skip-offline success — symptoms of business shortcuts in UI/providers; fix with domain-layer contracts once, then screens consume them.
- **iOS/web extra surface (🟡):** spec is Android-now; keep other folders from driving 1.0 scope.

## Local Issues (fix per screen/feature)

- **Change-role always senpai (🔴)** — `group_members_page.dart`.
- **Join membership `uid: ''` (🟠)** — `group_provider.dart`.
- **Group settings + unban UI (🟠)** — wire existing callables.
- **Roleplay catalog + release character (🟠)** — replace `_mockCharacters`.
- **Chat composer: sticker/GIF/audio/reply/edit/forward/report (🟠)** and game activity cards (🟠).
- **Group media library (🟠)** — not “messages currently in RAM.”
- **Mafia registry alignment + leave UI (🟠); `good_boy` assign or remove (🟡).**
- **Edits moderation step (🟠); Respect on edits (🟡).**
- **Private chat `whoCanMessageMe` preflight + copy (🟡).**
- **Notification inbox retry/`hasMore` (🟠); missing types (🟡).**
- **Ads SDK + placements (🟠)** — after product decisions on network and premium-adFree vs “reduced friction.”
- **Premium provider seam (🟡)** — keep no-op until authorized; don’t fake charges.
- **Home session-varying order + block filters (🟡).**
- **Profile `displayName` on others; `activityVisibility` actually applied (🟡).**
- **Search: edits + contextual member/character/sticker (🟡).**
- **Deep link `/g/` + missing edit/store canonical URLs (🟡).**
- **Terms durable record + legal copy (🟡).**
- **Game `difficulty` unused; reconnect UI unused (🟡)** — implement or remove.

---

## Recommended prompt sequence (proposal only — do not execute)

Authorization stops (like Prompt 20) are called out. No implementation in this pass.

1. **Rules & DTO trust pass**  
   Closes: 🔴 `lastMessage*` writes, 🔴 `PubgetUser`/allowlist, 🟡 `hakusho`, nested group-games write, avatarUrl client write review.  
   Auth needed: none beyond “lock fields to server-only.”

2. **Groups truthfulness (roles, join, settings, unban)**  
   Closes: 🔴 always-senpai, 🟠 join `uid: ''`, 🟠 settings/unban UI, founder permission checks on kick/ban.  
   Auth needed: may Shogun dismantle, or founder-only as today?

3. **App shell: five tabs + Drawer**  
   Closes: 🟠 nav, ⚪ Drawer, part of 🟠 unread badges.  
   Auth needed: confirm labels (My Groups vs Joined vs single Groups) — spec text is explicit; confirm before dropping a tab.

4. **Group Chat richness slice 1 (reply, edit, delivery UX, drop fake actions or implement report)**  
   Closes: part of 🟠 chat placeholders; sets pattern for stickers/audio/GIF.  
   Auth needed: which of sticker/GIF/audio/voice ship in 1.0 vs later (spec wants them; cost is high).

5. **Chat media + stickers (if authorized in 4)**  
   Closes: ⚪ stickers, 🟠 GIF/audio, 🟠 group media library.

6. **Games ↔ Chat contract + Mafia product finish**  
   Closes: 🟠 no game cards, 🟠 dual registry, 🟠 leave UI, 🟡 `good_boy`.  
   Auth needed: is `good_boy` a real role or dead code? Confirm Mafia in the generic create-game menu.

7. **Edits moderation + Respect on edits**  
   Closes: 🟠 no moderation, 🟡 missing Respect action.  
   Auth needed: human queue vs automated policy vs “flag + hide” only for 1.0.

8. **Notifications unread + inbox repair + missing types**  
   Closes: 🟠 retry/hasMore, 🟠 shell badges, 🟡 missing event types.

9. **First 10 minutes + Home session mix + block filters**  
   Closes: 🟠 first-session, 🟡 Home order, systemic block holes.

10. **Bilingual `.arb` pass**  
    Closes: 🟠 Arabic copy.  
    Auth needed: who supplies Arabic strings (engineering transliteration is not the spec).

11. **Private chat `whoCanMessageMe` UX + richer thread (reply)**  
    Closes: 🟡 start-chat confusion.

12. **Roleplay real catalog**  
    Closes: 🟠 mock RP.  
    Auth needed: source of anime-specific characters (manual catalog vs Anime Hub characters).

13. **Search/deep-link/profile displayName polish**  
    Closes: remaining 🟡 platform items in Tier 5 except security (already in 1).

14. **Ads 1.0 (real network, frequency, premium behavior)**  
    Closes: 🟠 Sponsored placeholder.  
    Auth needed: ad network (Vungle leftover vs AdMob vs other); is Premium fully `adFree` or only reduced frequency (spec allows premium behavior; current code is full adFree).

15. **Premium provider seam (still no live billing until credentials exist)**  
    Closes: 🟡 restore no-op honesty while adding a replaceable provider.  
    Auth needed: Paddle vs Play Billing vs wait. Spec says no Play Billing **yet**.

16. **Analytics + data migration design**  
    Closes: 🟠 LoggingAnalytics, ⚪ Old→New mapping.  
    Auth needed: which legacy collections are translatable vs droppable (spec allows dropping untranslatable data).

**Do not** start a Prompt 18-style feature expansion before (1)–(2) and a Chat/Home/Groups slice. Spec §122: no Prompt 18 before this audit — this file is that audit.

---

## Files

- Spec of record: `docs/PUBGET_1_0_SPEC.md`
- Audit: `docs/GAP_AUDIT.md`
- Current state (unchanged): `docs/CURRENT_STATE_MASTER.md`
- Product code: unchanged

```
GAP AUDIT: COMPLETE
```
