# PUBGET 1.0 — Live rebuild matrix

Spec of record: `docs/PUBGET_1_0_SPEC.md` (**LOCKED**, 2026-09-06).
Compared against the live tree on `cursor/pubget-1-rebuild-45d1`
(includes language + page-back work not yet on every historical audit).

This is the official FIX / REBUILD / DELETE / KEEP / BLOCKED list.
`docs/GAP_AUDIT.md` remains historical evidence from PR #21 and must not
override this matrix when they disagree.

Actions:

| Action | Meaning |
|---|---|
| **KEEP** | Working and spec-aligned. Reuse. Do not rewrite. |
| **FIX** | Logic, states, copy, or wiring is wrong. Keep architecture. |
| **REBUILD** | Visual/UX must be redesigned. Keep real backend and contracts. |
| **DELETE** | Must leave the new product. Do not revive. |
| **BLOCKED** | Cannot honestly finish in this phase without a new backend, a product decision, or a forbidden prompt. |

---

## Locked decisions that stay

| Spec | Decision | Action |
|---|---|---|
| §11 | Three group types remain | KEEP |
| §15 | Founder / Shogun stay admin core; roles are group-scoped | KEEP |
| §50–52 | Respect → Fans at 5+; Friends is separate | KEEP |
| §69 / §110 | Ads are income. Coins cannot remove ads | KEEP / DELETE leftovers |
| §97–98 | UI → Provider → Repository → Firebase; domain isolation | KEEP |
| §100 | `lib_legacy/` is inspect-only | KEEP |
| §111–113 | Physical store deferred; no Play Billing yet; Android first | KEEP |
| §122 | No Prompt 18; no random legacy rewrite | KEEP |

---

## Live classification

| Spec | Current live evidence | Action | Notes |
|---|---|---|---|
| §0–1 Vision + principles | Domains exist and are wired. Many feature bodies still English; Home is a feed of strips, not a command center. | REBUILD (experience) | Do not invent missing loops. |
| §2 Identity | Royal Purple + Gold tokens, dark/light, design-system widgets. Screens still look like generic Material in places. | REBUILD | Strengthen the same system. Do not invent a second visual language. |
| §2.3 Language | Arabic default; login/settings/shell use `AppStrings`. Feature bodies still English. | FIX | Expand catalog. Do not fake complete Arabic. |
| §4 Auth | Splash → Firebase → Login / Onboarding / Home. Email, Google, forgot, validation, session restore. | KEEP + REBUILD chrome | Do not change the route guard. |
| §5 Onboarding | Avatar, username, display name, genre chips, skip. Interests are genres, not anime/character identity. | FIX later | Do not force a longer form in this phase. |
| §6 First 10 minutes | No dedicated guided journey. Home strips exist. | BLOCKED as Prompt 09 | Surface real destinations only. Do not start Prompt 09. |
| §7 Home | Real discovery sections + ranking + rising groups. English titles. Cards are thin. No hero / “what now”. | REBUILD | Keep `HomeProvider` and ranking. |
| §7.3 Rising groups | Server rising score + client strip | KEEP | |
| §8 Navigation | Five tabs: Discover / Groups / Joined / Private / Edits | KEEP | GAP_AUDIT “four tabs” is stale. |
| §9 Drawer | Real drawer with required destinations + unread | REBUILD chrome | Rename Store → Dragon Store. |
| §10–14 Groups | Types, create wizard, member→chat, details/chat/members chrome rebuilt on this branch. Settings/unban stay existing pages. | KEEP logic / REBUILD chrome | Do not invent settings backends. |
| §19 Avatar → Profile | Group chat + members avatars now open `/profile?uid=`. Other surfaces later. | FIX incrementally | |
| §22–29 Chat | Working group chat + delivery colors + pagination. Header/menu/role badge rebuilt. Bubble richness still incomplete. | KEEP backend / REBUILD chrome | Do not rewrite chat internals here. |
| §30–37 Games / Mafia | Isolated domains, contracts, emoji guess type exists | KEEP | No new game modes. |
| §38–41 Events | Independent domain, 7-day cap, home strip | KEEP | |
| §42–49 Edits | Video feed, upload, moderation, respect | KEEP | Feed UI still not TikTok-level. Later REBUILD. |
| §53–54 Private chat | Independent list + unread | KEEP | |
| §55–58 Notifications | Inbox retry/pagination + UnreadEngine + FCM path | KEEP / FIX types later | |
| §59–63 Anime Hub / Fan Works | Real hubs and feeds | KEEP / REBUILD tiles | |
| §64–72 Economy | Coins, store, premium, `adFree` as premium behavior. No coin-remove-ads in active `lib/`. Ad UI is a placeholder card. | KEEP economy / FIX ads honesty | Do not add an ad SDK without a network decision. |
| §73–75 Settings / Guide / Search | Real settings, guide, unified search | KEEP / FIX copy | |
| §76–77 Deep links / share | Canonical URLs exist | KEEP | |
| §78–80 Profile / social graph | Profile, respect, fans, friends | REBUILD identity chrome | Do not change relationship rules. |
| §85–91 Offline, performance, design system, a11y | Partial | FIX / REBUILD | |
| §92–96 Security / moderation | Server authority on coins/roles/games. Moderation still thin. | KEEP rules / BLOCKED expansion | Do not weaken rules. |
| §99–101 Migration | No old→new pipeline | BLOCKED | Destructive migration needs an explicit stop. |
| §102 Testing | Large Flutter suite; emulator/e2e uneven | FIX as we touch domains | |
| §104 Analytics | Logging stub | BLOCKED | Do not invent a tracker. |
| §106–109 Loops | Partially closed | REBUILD surfaces only | |

---

## DELETE

| Item | Why | Status |
|---|---|---|
| Coins-remove-ads | Spec §69 / §110 | Absent in active `lib/`. `lib_legacy` must stay dormant. |
| Physical store complexity | Spec §111 | Not in active product. |
| Fake recommendation / fake social proof | Spec §16 of rebuild prompt + §7 | Do not add. |
| Dead `hakusho` token in rules | Product/rules mismatch | Documented only. Rules change is a later FIX, not this visual phase. |

---

## This phase (honest scope)

Home command chrome, official Torii logo, promoted/suggested/events/fan
works Home cards, and Explore/Groups/+/Private/Clips live on this
branch. Joined stays in the drawer. Group Details/Chat/Members already
landed via PR #37.

In scope now:

1. Rebuild Group Details identity (hero, localized type/policy, founder
   actions, member Open chat, visitor join). Keep member→chat redirect.
2. Rebuild Group Chat header (avatar → details, marquee, three-dot menu)
   and §83 menu items. Canonical group links via `PubgetLinks`.
3. Avatar tap on chat/members → `/profile?uid=`. Do not invent names.
4. Localize the chrome we touch. Keep English defaults that tests pin
   (`Send message`, `Banned users`, `Change role`, `Kick`, `Ban`,
   `Transfer ownership`, `Report submitted`, `Message forwarded`).
5. Double-confirm disband. Confirm leave. Do not rewrite `ChatProvider`.

Out of scope / not 10/10 yet:

- Full Definition of Done from the rebuild prompt
- Prompt 09 first-10-minutes script
- Prompt 18
- Real ad network
- Play Billing
- Complete Arabic product copy
- TikTok-level chat/Edits visual rewrite
- Data migration
- Production APK certification of the whole product
