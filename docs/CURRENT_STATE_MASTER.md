# PUBGET — CURRENT STATE MASTER DOCUMENT

Inspection target: production `main` at commit `8f34d212fc22940cdc004e8f0a5fdd94eeb7662e`.

This document describes what exists and what happens in the repository at that commit. Claims are taken from source that was opened and read. Runtime of live Firebase in Google Cloud is not exercised here except where unit/emulator tests ran locally.

---

## 0. Repository & Build State

### 0.1 Git identity at inspection

- Commit: `8f34d212fc22940cdc004e8f0a5fdd94eeb7662e`
- Subject: `feat: close social product group gaps (settings, unban, roleplay guard, public displayName)`
- Author date: 2026-09-04 12:06:17 UTC
- Branch used for this read: `cursor/current-state-master-45d1` created from `origin/main`
- `HEAD` at inspection start: identical to `origin/main` (`8f34d21`)
- Working tree at inspection start: clean (no local code edits)
- Remote tracking: `origin/main` at the same SHA

### 0.2 Flutter / Dart (this inspection environment)

- Flutter binary: `/home/ubuntu/sdk/flutter-3.32.8/flutter/bin/flutter`
- Flutter 3.32.8 (stable), framework `edada7c56e` (2025-07-25)
- Dart 3.8.1
- `pubspec.yaml` constraint: `sdk: '>=3.8.0 <4.0.0'`
- App version: `1.0.2+18` (`pubspec.yaml` lines 5, `settings_page.dart` default `appVersion`)

CI APK workflow (`.github/workflows/build.yml`) uses `subosito/flutter-action@v2` with `channel: 'stable'` and does not pin a Flutter version. Exact Flutter version used on a given GitHub Actions run is **UNVERIFIED**.

### 0.3 Declared dependencies (`pubspec.yaml`) and locked versions (`pubspec.lock`)

Direct dependencies and the versions actually locked:

| Package | pubspec | lock |
|---------|---------|------|
| firebase_core | 4.11.0 | 4.11.0 |
| firebase_auth | 6.5.1 | 6.5.1 |
| cloud_firestore | 6.4.1 | 6.4.1 |
| firebase_storage | 13.4.1 | 13.4.1 |
| cloud_functions | 6.3.1 | 6.3.1 |
| firebase_messaging | ^16.2.2 | 16.2.2 |
| google_sign_in | ^7.2.0 | 7.2.0 |
| provider | ^6.1.5+1 | 6.1.5+1 |
| image_picker | ^1.2.1 | 1.2.1 |
| video_player | ^2.10.0 | 2.10.1 |
| http | ^1.6.0 | 1.6.0 |
| share_plus | ^12.0.2 | 12.0.2 |
| shared_preferences | ^2.5.3 | 2.5.3 |
| web | ^1.1.1 | 1.1.1 |
| flutter_localizations | SDK | SDK |

These packages are imported from `lib/` (Firebase, Provider, Google Sign-In, image_picker, video_player, http, share_plus, shared_preferences, flutter_localizations). `web` is declared; Flutter web entry exists under `web/`. Firebase Web options are not configured (`firebase_bootstrap.dart` 47–50).

Dev: `flutter_test` (SDK), `flutter_lints` ^6.0.0 (lock 6.0.0).

### 0.4 Build targets

- Android application id / namespace: `com.sbikazis.pubget` (`android/app/build.gradle.kts` 20, 35)
- `minSdk = flutter.minSdkVersion` → Flutter 3.32.8 default **21** (`FlutterExtension.kt`)
- `compileSdk` / `targetSdk` = Flutter defaults **35**
- No `productFlavors` / `flavorDimensions` in the Android Gradle files
- Release signing: `signingConfigs.release` reads `android/key.properties` when that file exists (`build.gradle.kts` 14–17, 43–49). `android/key.properties` is not in the tree. CI writes it from secrets (`.github/workflows/build.yml` 27–33)
- Release minify + shrink resources + ProGuard (`build.gradle.kts` 52–61)
- Google Services plugin applied; `android/app/google-services.json` present
- Android also declares Firebase BOM 34.11.0, Analytics, desugar_jdk_libs 2.1.4, and Liftoff/Vungle AdMob mediation `com.google.ads.mediation:vungle:7.4.2.0` (`build.gradle.kts` 69–79). No Flutter AdMob/Vungle Dart package is in `pubspec.yaml`
- iOS project exists (`ios/`), bundle id `com.sbikazis.pubget`, `GoogleService-Info.plist` present, same Firebase project
- Web folder exists (`web/index.html`, `presentation.html`, legal HTML pages). `FirebaseBootstrap.initialize()` returns unavailable on web
- Hosting is configured in `firebase.json` (`public`: `build/web`)
- Functions: Node 20 (`functions/package.json` engines)

### 0.5 Firebase project wiring

- `.firebaserc` default project: `pubget-aaf27`
- Android `google-services.json`: `project_id` `pubget-aaf27`, `project_number` `452313838148`, `storage_bucket` `pubget-aaf27.firebasestorage.app`, `firebase_url` `https://pubget-aaf27-default-rtdb.firebaseio.com`
- iOS `GoogleService-Info.plist`: `PROJECT_ID` `pubget-aaf27`, same storage bucket and database URL
- No Dart import of Realtime Database was found under `lib/`
- Flutter callables use `FirebaseFunctions.instanceFor(region: 'us-central1')` (`pubget_app.dart` repository wiring)
- Storage object-finalized functions `processEditVideo` and `processGroupChatMedia` are declared with `region: "europe-west3"` (`functions/index.js` 254–261, 556–562)
- Google Sign-In server client id in Dart: `452313838148-6m1jvpqea9suqn6t14gv98r9h4gacsls.apps.googleusercontent.com` (`google_sign_in_config.dart` 7–8)
- A single Firebase project is wired. No second environment config file exists in the repo
- `firebase.json` emulators: Firestore 8080, Storage 9199, project mode `demo-pubget-security` for rules tests

### 0.6 Cloud Functions package

- `functions/package.json` main: `index.js`
- Dependencies: `firebase-admin` ^13.8.0, `firebase-functions` ^7.2.5, `ffmpeg-static` ^5.2.0, `sharp` ^0.35.4
- Test script lists 22 Node test files (unit). Root `package.json` `test:rules` runs 6 files under emulators (rules + four E2E files)

**Traceability:** `pubspec.yaml`, `pubspec.lock`, `android/app/build.gradle.kts`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `.firebaserc`, `firebase.json`, `functions/package.json`, `package.json`, `lib/app/firebase_bootstrap.dart`, `lib/app/pubget_app.dart`, `.github/workflows/build.yml`, `.github/workflows/deploy-functions.yml`

---

## 1. Authentication

### 1.1 Screens and routing

Registered domain pages (`lib/app/pubget_app.dart` 659–665): `/splash`, `/login`, `/register`, `/forgot-password`, `/terms`, `/onboarding`. Home page widget for the router is `SplashPage`.

`AuthRouteGuard.resolve` (`lib/features/authentication/auth_route_guard.dart` 65–93):

```
authBusy = !isInitialized || authState == initial || authState == loading

if guestOnlyPaths contains path AND isAuthenticated:
  if authBusy OR onboardingState == initial → '/splash'
  else → canEnterHome ? '/home' : '/onboarding'

if path not in protectedPaths → null (allow)
if authBusy → '/splash'
if !isAuthenticated → '/login'
if path != '/onboarding' AND onboardingState == initial → '/splash'
if path != '/onboarding' AND !canEnterHome → '/onboarding'
return null
```

`guestOnlyPaths`: `/login`, `/register`, `/forgot-password`  
`protectedPaths`: listed at `auth_route_guard.dart` 19–63 (includes `/onboarding` and product routes)  
`/terms` is neither guest-only nor protected; the guard returns `null` for it.

Pending-route storage: `AppRouterDelegate._guard` (`app_router.dart` 87–115) stores a protected deep link in `_pendingRoute` while redirected, except when signing out to `/login` after `_sessionHadProtectedAccess`.

Initial route (`pubget_app.dart` 647–654): in debug, `Uri.base`; in release, a `/design-system` request is replaced with `/splash`.

### 1.2 Splash (`lib/features/authentication/screens/splash_page.dart`)

When Firebase is not ready: title `Pubget could not start`, message `firebaseState.message` or `Pubget could not start Firebase on this device.` (`firebase_bootstrap.dart` 43–44).

When Firebase is ready, post-frame `_resolveRoute`:

1. `await auth.initialize()`
2. Auth error/offline → stay; title `Could not start Pubget`; retry clears failures
3. `user == null` → after ≥900 ms brand hold → `/login`
4. Else `onboarding.loadProfile(user.id)`; on failure title `Could not load your profile`
5. Else after brand hold → `onboarding.canEnterHome ? '/home' : '/onboarding'`

Loading copy: `PUBGET`, `Premium Anime Community`, `Preparing your experience…`.

### 1.3 Session restoration

`AuthProvider.initialize` (`auth_provider.dart` 32–47) subscribes to `AuthRepository.authStateChanges` and sets `_currentUser` from `currentUser`.

`FirebaseAuthRepository` (`firebase_auth_repository.dart` 29–33) maps `FirebaseAuth.instance.currentUser` and `authStateChanges()`.

If Firebase is not ready, `UnavailableAuthRepository` is used (`pubget_app.dart` 506–511): `currentUser` is null; sign-in methods return `UnknownError`.

Web: `FirebaseBootstrap.initialize` returns unavailable with `Firebase Web options are not configured for this project.` (`firebase_bootstrap.dart` 47–50).

Login copy: `You stay signed in on this device.` (`login_page.dart` 136–140). No extra Dart persistence API beyond Firebase Auth.

### 1.4 Login (`login_page.dart`)

Fields: email (`login-email`), password (`login-password`).

Validation (`auth_validators.dart` 6–18, `login_page.dart` 147–152):

- Email empty or regex fail → `Enter a valid email.`
- Password length < 6 → `Password must be at least 6 characters.`
- Email normalized with trim only

Offline: banner `You are offline` / `Reconnect before signing in.`; submit and Google disabled.

Auth failure banner: `Sign-in failed` + `auth.failure!.message`.

Submit: `AuthProvider.signInWithEmail` → `FirebaseAuth.signInWithEmailAndPassword`. Success navigates to `/splash`.

Footer: `New to Pubget? Create an account` → `/register`.  
`Forgot password?` stores draft email and goes to `/forgot-password`.

### 1.5 Register (`register_page.dart`)

Fields: email, password (helper `At least 6 characters.` plus strength meter), confirm password, terms checkbox `I agree to the terms`.

Validation:

- Same email/password rules as login
- Confirmation mismatch → `Passwords do not match.`
- Terms not accepted → snackbar `Accept the terms to continue.` (not a field error)

Google without terms: same snackbar, no API call (`register_page.dart` 227–230).

Success → `/splash`.

`AuthDraftStore.acceptedTerms` is in-memory only (`auth_draft_store.dart` 4–20). **INCOMPLETE/MOCK** as a durable terms record.

Terms body (`terms_copy.dart` 17–19): `These are draft community terms. Final legal copy and a privacy policy will replace this text before public launch.` **INCOMPLETE/MOCK**

### 1.6 Forgot password (`forgot_password_page.dart`)

Email field; `Send reset link` → `AuthProvider.sendPasswordResetEmail` → `FirebaseAuth.sendPasswordResetEmail`.

Success sets `_sent = true`; subtitle `If an account exists for that address, a reset link is on its way.`

Offline: `Reconnect to send a reset link.`  
Failure: snackbar with `failure.message`.

### 1.7 Terms (`terms_page.dart`)

Standalone page; back goes to `/register`. Body is `TermsCopy` without `onAccept`. Settings also links to `/terms`.

### 1.8 Google Sign-In (`firebase_auth_repository.dart` 78–182)

1. `_googleSignIn.initialize(serverClientId: …)`
2. `_googleSignIn.authenticate()`
3. Empty idToken → `UnknownError('Google sign-in did not return an ID token...')`
4. `signInWithCredential(GoogleAuthProvider.credential(idToken: …))`

Cancel/interrupted: `CancelledError()`. Provider (`auth_provider.dart` 105–108) does not set `_failure` on cancel. UI does not navigate and does not show an error banner.

Configuration errors → `Google sign-in configuration is unavailable on this build.`  
Other Google errors → `Google sign-in could not be completed.`

Sign-out: Firebase Auth sign-out plus `GoogleSignIn.signOut()`.

### 1.9 Mapped Firebase Auth messages (`firebase_auth_repository.dart` 140–191)

| Code | Message |
|------|---------|
| invalid-email | Enter a valid email address. |
| user-not-found | No account exists with this email. |
| wrong-password | Wrong password. |
| invalid-credential | The email or password is incorrect. |
| email-already-in-use | This email is already in use. |
| weak-password | Choose a stronger password. |
| user-disabled | This account is currently disabled. |
| network-request-failed | Network unavailable. Check your connection and try again. |
| too-many-requests | Too many attempts. Please try again later. |
| operation-not-allowed | This sign-in method is not enabled yet. |
| default | Unexpected authentication error. |

Stream error (`auth_provider.dart` 39–40): `We could not check your session.`

### 1.10 Firestore / Auth boundary

Email/password and Google identity live in Firebase Auth (not Firestore rules). Profile load after auth is `users/{uid}.get()`. Rules: `allow get: if self(uid); allow list: if false` (`firestore.rules` 362–366).

**Traceability:** `auth_route_guard.dart`, `splash_page.dart`, `login_page.dart`, `register_page.dart`, `forgot_password_page.dart`, `terms_page.dart`, `terms_copy.dart`, `auth_provider.dart`, `firebase_auth_repository.dart`, `auth_validators.dart`, `auth_draft_store.dart`, `google_sign_in_config.dart`, `firebase_bootstrap.dart`, `pubget_app.dart`, `app_router.dart`, `firestore.rules` 362–366

---

## 2. Onboarding

### 2.1 Entry

Splash and the route guard send an authenticated user with `!canEnterHome` to `/onboarding`. `/onboarding` itself is allowed while incomplete.

`canEnterHome` (`onboarding_provider.dart` 25–27):

```
_profile?.isProfileCompleted == true || _profile?.hasSkippedOnboarding == true
```

Null profile → false.

### 2.2 Steps (`onboarding_page.dart`)

Two steps (`total = 2`):

| Step | Title | Fields |
|------|-------|--------|
| 0 | Make Pubget yours | Avatar (optional gallery pick, maxWidth 1024, quality 82), Username, Display name. Subtitle: `Add a face and a name. Everything here is optional.` |
| 1 | What do you love? | Bio, interest chips: Action, Adventure, Comedy, Fantasy, Mystery, Romance |

Skip (app bar): `onboarding.skip` → success → `/home`.

Step 0 Continue: if username non-empty, requires ≥3 characters (`Use at least 3 characters.`); empty username is allowed. Then advances to step 1.

Step 1 `Save and continue`: `_save` → success → `/home`.

`isProfileCompleted` on save (`onboarding_page.dart` 188–196): `username.isNotEmpty`. Empty username → `isProfileCompleted: false` and `hasSkippedOnboarding: true` via provider (`onboarding_provider.dart` 64).

### 2.3 Firestore write

`OnboardingProvider.saveProfile` builds `PubgetUser` (`onboarding_provider.dart` 54–65) and calls `createUserProfile` or `updateUserProfile`.

`PubgetUser.toMap()` (`pubget_user.dart` 67–83): `email`, `username`, `displayName`, `avatarUrl`, `bio`, `favoriteAnimes`, `favoriteAnimeIds`, `profileVisibility` (default `public`), `activityVisibility` (default `public`), `whoCanMessageMe` (default `related`), `createdAt`, `isProfileCompleted`, `hasSkippedOnboarding`. `id` is removed before write.

Create: `users/{id}.set(data)` (`firebase_user_repository.dart` 25–32).  
Update: `set(merge: true)` removing `id` and `createdAt` (52–57).  
Avatar: Storage `users/$userId/avatar.jpg` (71–76).

Skip on `NetworkError` (`onboarding_provider.dart` 113–156): sets a local profile with `hasSkippedOnboarding: true`, `isProfileCompleted: false`, returns `Success` without a successful Firestore write.

Firestore create allowlist (`firestore.rules` 368–377) includes `nickname` and does not list `displayName`. Client create sends `displayName`. Update allowlist (`399–402`) also omits `displayName` and `whoCanMessageMe`. Whether a given production write is accepted is therefore **UNVERIFIED** at runtime; the client and rules field lists differ.

**Traceability:** `onboarding_page.dart`, `onboarding_provider.dart`, `pubget_user.dart`, `firebase_user_repository.dart`, `firestore.rules` 362–415, `storage.rules` 110–115

---

## 3. Home / Discovery

### 3.1 Screen

`HomePage` (`home_page.dart`): AppBar title `Discover`. Actions: coin chip → `/store`; notifications → `/notifications`; settings → `/settings`; avatar → `/profile` (own profile when `uid` omitted).

Body: `RefreshIndicator` + `CustomScrollView`. Optional home ad slot (`_HomeAdSlot`) when `economy.showAd(AdPlacement.homeFeed)` is true.

### 3.2 Section order

Canonical order (`home_provider.dart` 60–71):

1. `promotedGroups`
2. `risingGroups`
3. `recommendedGroups`
4. `communityActivity`
5. `recommendedPeople`
6. `editsPlaceholder`
7. `eventsPlaceholder`
8. `gamesPlaceholder`
9. `fanWorksPlaceholder`
10. `animePlaceholder`

`displayOrder` (`82–98`): sections that are placeholders, have content, or are initial/loading/refreshing/loadingMore stay in that order; empty loaded sections are moved to the tail.

Placeholder kinds (`270–277`): the last five kinds above. Their data is not loaded through `HomeProvider.ensureLoaded` for group/people queries; the widgets load their own providers.

### 3.3 Queries / ranking

**Promoted groups** (`firebase_home_repository.dart` 48–52): Firestore `groups` where `isPromoted == true` and `promotionExpiresAt > now`, `orderBy promotionExpiresAt desc, documentId desc`.

**Rising groups** (61–65): `risingEligible == true`, `orderBy risingScore desc, createdAt desc, documentId desc`.

Rising score writer: scheduled `refreshGroupActivityScores` every 1 hour (`index.js` 190–193) → `discoveryEngine.updateScores`. Eligibility (`discoveryEngine.js` 160–163): `membersCount >= 2 && <= 200 && ageDays <= 180 && risingScore > 0`. Formula (`ranking.js` 279–313): weighted velocity, uniqueGrowth, quality, response, regular, activity, minus spam/inactive/tooNewSolo penalties. Batch `GROUPS_PER_RUN = 75`.

**Community activity** (`firebase_home_repository.dart` 105–107): `orderBy lastMessageAt desc, documentId desc`. Client maps `lastMessageAt` to `Group.lastActivityAt`.

**Recommended groups / people / edits (discovery feed):** callable `getDiscoveryFeed` (`recommendationEngine.js` 292–313). Pool `POOL = 40`, default page `PAGE = 8`, client limit clamped 1–20. Scores then `applyDiversity`, `mixExploration` for edits. Cold start (`ranking.js` 339–344): `(animeIds.length + memberGroupIds.size + friendIds.size) < 2`. Blocked users excluded in `visibleToViewer` (`recommendationEngine.js` 130–138).

Home prefetch failure is swallowed (`home_provider.dart` 176 `onFailure: (_) {}`).

**Edits placeholder:** uses discovery `recommendedEdits` if non-empty; else `EditsProvider.load(limit: 4)` (`home_page.dart` 234–266).

**Events / games / fan works / anime strips:** `EventHomeStrip` uses `[...active, ...upcoming]`; `GameHomeStrip` `[...active, ...waiting]`; fan works first 8; anime trending section.

Promoted/rising/community Firestore queries do not apply the block filter used by `getDiscoveryFeed`.

### 3.4 Pagination, refresh, empty/error

Page size 8 (`home_provider.dart` 79). `hasMore` if returned length equals page size. UI: horizontal carousel + `Load more`.

Pull-to-refresh: `home.refresh` reloads feed and non-placeholder sections already loaded.

Initial: `home.load(uid)` plus optional `economy.load`. Lazy `ensureLoaded` when a section is still `initial`.

Empty: `PubgetEmptyState`; people CTA `/search`, others `/groups`.  
Error without content: `PubgetErrorState` + retry.  
Offline with content: section state `offline`; without content: `error`.

### 3.5 Inline search on Home

A `_SearchBar` calls `SearchProvider.searchChanged`. The page also gates on `_search.text.trim().isNotEmpty` without a `setState` listener on that controller (`home_page.dart` 120–125). Whether typed text shows inline results without another rebuild is **UNVERIFIED**. Dedicated `/search` exists.

**Traceability:** `home_page.dart`, `home_provider.dart`, `home_models.dart`, `firebase_home_repository.dart`, `recommendationEngine.js`, `ranking.js`, `discoveryEngine.js`, `index.js` 190–197

---

## 4. Navigation & Drawer

There is no app-wide `Drawer`. `AppShell` uses a bottom `NavigationBar` (`app_shell.dart` 47–88).

### 4.1 Tabs (`app_shell_tab.dart`)

| Tab | Path | Label | Child |
|-----|------|-------|-------|
| discover | `/home` | Discover | `HomePage` |
| groups | `/groups` | Groups | `GroupsHomePage` |
| private | `/private` | Private | `PrivateChatsListScreen` |
| edits | `/edits` | Edits | `EditFeedPage` |

These four paths share navigator key `app-shell` (`app_router.dart` 180–185).

### 4.2 Domain routes (`pubget_app.dart` 659–685)

`/splash`, `/login`, `/register`, `/forgot-password`, `/terms`, `/onboarding`, `/home`, `/search`, `/settings`, `/guide`, `/unknown`, `/profile/edit`, `/friend-requests`, `/notifications`, `/edits`, `/edits/upload`, `/groups`, `/groups/create`, `/private`, `/anime`, `/anime/library`, `/fan-works`, `/store`, `/inventory`, `/premium`, `/economy/history`.

### 4.3 Parameterized routes (`pubget_app.dart` 687–764)

`/profile` (`uid`), `/group`, `/group-invite` (`groupId`,`inviteId`), `/group-chat`, `/group-media`, `/group-members`, `/group-requests`, `/group-roleplay`, `/private-chat` (`chatId`,`uid`), `/event`, `/events` (optional `groupId`), `/events/create`, `/anime/details`, `/anime/browse`, `/anime/genre`, `/anime/season`, `/anime/library`, `/game`, `/mafia`, `/achievements` (`id`), `/games`, `/games/create`, `/fan-work` (`workId`, `view=manga|story`), `/fan-works/create`, `/store/item`.

URI segment forms (`app_router.dart` 256–286): `/event/{id}`, `/anime/{id}` (or browse/genre/season/library), `/game/{id}`, `/mafia/{id}`, `/fan-work/{id}`, `/group/{id}`, `/profile/{uid}`. Missing required ids → `/unknown`.

### 4.4 Group chat endDrawer (`group_chat_page.dart` 539–631)

Add members, copy group link, group information, events, games, media, members, edit group (founder), chat background (pushed page, not a named route), leave (non-founder), disband (founder).

### 4.5 Unused page

`PlaceholderHomePage` (`placeholder_home_page.dart`) is not registered in the router. **INCOMPLETE/MOCK**

Debug-only `/design-system` → `DesignSystemShowcasePage` when `kDebugMode`.

**Traceability:** `app_shell.dart`, `app_shell_tab.dart`, `app_router.dart`, `pubget_app.dart`, `home_page.dart`, `group_chat_page.dart`

---

## 5. Groups

### 5.1 Types and schema

Client (`group_models.dart` 1–3): `GroupType { public, animeRoleplay, openRoleplay }`, `JoinPolicy { open, approval, inviteOnly }`.

Server (`groupsDomain.js` 3–5): same three types; `ROLEPLAY_GROUP_TYPES = animeRoleplay, openRoleplay`.

Create write (`groupsDomain.js` 138–155): `name`, `searchName`, `description`, `imageUrl: ""`, `type`, `animeId`, `founderId`, `membersCount: 1`, `maxMembers` from `entitledMaxMembers` (custom limit or 100, clamped 2–500, lines 79–82), `joinPolicy`, `isSearchable`, `createdAt`, `chatBackgroundUrl: null`, `rules`, `activityScore: 0`, `risingEligible: false`. Also creates founder member + seven default role docs.

Member doc (`92–101`): `uid`, `role`, `customRoleId: null`, `roleplayCharacter: null`, `joinedAt`, `inviteCount: 0`, `lastActiveAt`.

### 5.2 Creation UI (`create_group_wizard_page.dart`)

Steps: Identity (name, description) → Type → Privacy/join → Rules → Review.

Client gates: name non-empty to leave step 0; `animeId` required when type is `animeRoleplay`.

Payload (`group_repository.dart` 25–34): name, description, type, animeId, joinPolicy, isSearchable, rules, `maxMembers` (wizard sends 100). Server ignores client `maxMembers`.

Server validation (`groupsDomain.js` 41–55): name ≤80, description ≤500, rules ≤4000, type/joinPolicy enums, `animeRoleplay` requires `animeId`.

Path: UI → `GroupProvider` → `httpsCallable('createGroup')`. Admin SDK write; client create rule is a different legacy schema (`firestore.rules` 485–505) that does not include `joinPolicy`/`rules`/`searchName`.

### 5.3 Group Details (`group_details_page.dart`)

If loaded, `isMember`, and `!isFounder` → post-frame redirect to `/group-chat?groupId=…` (40–49).

If `isMember`: Group events, Group games; Create event if `canManageEvents`; Create game if `membership?.canManageGames == true`.

If `!isMember`: `_JoinAction` — full → `Group is full`; `inviteOnly` → `Invitation required`; `approval` → `requestToJoin`; else `join`.

If `isFounder`: Manage members, Join requests, Roleplay characters when `group.type != GroupType.public`, Disband (two confirm dialogs).

`isFounder` is `membership?.role == GroupRole.founder` (`group_provider.dart` 34–36).

After join success, provider sets `_membership = GroupMember(uid: '', role: member)` (`group_provider.dart` 97–101). **INCOMPLETE/MOCK** membership uid.

### 5.4 Join system

| Policy | Server | Details UI |
|--------|--------|------------|
| open | `joinGroup` creates member | Join group |
| approval | `joinGroup` rejected; `requestToJoin` writes `requests/{uid}` pending | Request to join |
| inviteOnly | `joinGroup` requires valid `inviteId` | Invitation required empty state |

Ban: `permission-denied`. Full: `resource-exhausted`.

Invites: `createGroupInvite` (permission `invite`); 7-day expiry. Redeem: `GroupInvitePage` → `join(groupId, inviteId:)`. Invite use increments inviter `inviteCount` and may auto-rank unless `isManualRole` (`inviteRankForCount`: ≥50 captain, ≥20 sensei, ≥5 senpai).

Accept/reject: callables `acceptJoinRequest` / `rejectJoinRequest`; server requires `manageRequests`. Join-requests screen is linked from founder block on Details.

`updateGroupSettings` and `unbanMember` are exported (`index.js` 281–285). No `lib/` caller. **INCOMPLETE/MOCK** client UI.

### 5.5 Settings editable today

Server `updateGroupSettings` (`groupsDomain.js` 519–566): `name`, `description`, `rules`, `joinPolicy`, `isSearchable`; gate `manageSettings` (founder always). No settings form in `lib/`.

Legacy founder client update of `name, description, slogan, imageUrl, type, animeName, animeId, franchiseIds` remains in rules (`firestore.rules` 506–508).

Chat background: menu visible to members; server `updateBackground` requires `manageBackground`.

**Traceability:** `group_models.dart`, `create_group_wizard_page.dart`, `group_details_page.dart`, `group_provider.dart`, `firebase_group_repositories.dart`, `groupsDomain.js`, `index.js` 264–307, `firestore.rules` 480–658, `group_invite_page.dart`, `join_requests_page.dart`, `group_members_page.dart`

---

## 6. Roles & Permissions

### 6.1 Role list

Client `GroupRole` (`group_models.dart` 5): founder, shogun, commander, captain, sensei, senpai, member.

Server `ROLES` (`groupsDomain.js` 6–7): the same seven. Positions `ROLES.length - index`.

Firestore helper `groupModerator` (`firestore.rules` 52–55): roles `founder`, `sensei`, **`hakusho`**, `senpai`. `hakusho` is not in the client/server role enums.

### 6.2 Default permission map

Client (`group_models.dart` 21–53) and server `ROLE_PERMISSIONS` (`groupsDomain.js` 8–21) use the same names:

| Role | Permissions |
|------|-------------|
| founder | all (including manageRoles, manageBackground, manageSettings) |
| shogun | all |
| commander | manageMembers, manageMessages, deleteMessages, pin, manageEvents, manageGames, invite, manageRequests |
| captain | manageMessages, deleteMessages, pin, manageEvents, invite |
| sensei | manageMessages, deleteMessages, pin, invite |
| senpai | pin, invite |
| member | none |

Stored per group at `groups/{id}/roles/{roleId}` at create. Client loads `effectivePermissions` from that doc (`firebase_group_repositories.dart` 46–57).

`updateRolePermissions` is **founder-only** on the server (`groupsDomain.js` 414–415). UI: `role_permissions_page.dart` disables the founder row.

### 6.3 Mutation gates (observed)

| Mutation | Server | Client UI gate |
|----------|--------|----------------|
| changeRole | manageRoles; not founder target; not self; rank | Popup for non-founder; **always sends `GroupRole.senpai`** (`group_members_page.dart` 174) |
| kick/ban | manageMembers + rank | Popup without permission check |
| createInvite | invite | App bar always shows invite |
| accept/reject request | manageRequests | No UI permission check |
| transferOwnership | founder + confirmation token | Two dialogs |
| leaveGroup | founder blocked | Non-founder menu |
| disbandGroup | founder (`index.js` 708–709) | Founder UI |
| unban / updateGroupSettings | manageMembers / manageSettings | No client UI |

Founder cannot be assigned via `changeRole`; founder cannot leave; transfer demotes old founder to `member` and sets `founderId`.

**INCOMPLETE/MOCK:** change-role UI only assigns senpai.

**Traceability:** `group_models.dart`, `groupsDomain.js`, `group_members_page.dart`, `role_permissions_page.dart`, `index.js` 280–298, 676–788, `firestore.rules` 52–55

---

## 7. Roleplay

Catalog server (`groupsDomain.js` 22–27): `hero` The Hero, `rival` The Rival, `mentor` The Mentor, `trickster` The Trickster.

Client list is `_mockCharacters` with empty `avatarUrl` (`firebase_group_repositories.dart` 351–356). Availability = those keys not present in `groups/{id}/characters`. UI copy: `All mock characters may already be reserved.` (`roleplay_character_page.dart` 33–35). **INCOMPLETE/MOCK**

Reservation (`groupsDomain.js` 585–635): transaction; group type must be in `ROLEPLAY_GROUP_TYPES`; exclusive `reservedByUid`; writes `characters/{key}` and `members/{uid}.roleplayCharacter`. Switching keys deletes the previous reservation.

Release callable exists; no screen calls `releaseCharacter`. **INCOMPLETE/MOCK** UI.

Client shows Roleplay characters for founders when `type != public`. Server rejects reserve on public groups.

Message identity (`groupChat.js` 50–64): prefers `roleplayCharacter.name` / `avatarUrl`, else member `displayName` / `realUserName` / uid. Stored on the message as `senderName`, `senderAvatar`, `senderRole`. Private chat uses global user identity only.

**Traceability:** `groupsDomain.js` 22–27, 585–656, `firebase_group_repositories.dart` 331–356, `roleplay_character_page.dart`, `roleplay_provider.dart`, `groupChat.js` 50–64, `group_chat_page.dart` 220–225

---

## 8. Group Chat

### 8.1 Message types

Client enum (`chat_models.dart` 3–13): text, image, video, sticker, gif, audio, system, event, game.

Server user-sendable (`groupChat.js` 3–9): text, image, video, sticker, gif, audio. `system`, `event`, `game` rejected for user `sendMessage`.

| Type | Composer | Backend |
|------|----------|---------|
| text | Send button | `sendGroupMessage` |
| image | Attachments → Image (gallery) | upload + media pipeline (`image/*`) |
| video | Attachments → Video | pipeline `video/*` |
| sticker | menu → `_showPlaceholder()` snackbar `This action is prepared for a later Pubget prompt.` | type allowed; pipeline only image/video. **INCOMPLETE/MOCK** |
| audio | same placeholder | **INCOMPLETE/MOCK** send; bubble can render a static “Voice message” |
| gif | not in attachment menu; bubble can render gif | **INCOMPLETE/MOCK** send |
| emoji button | appends ` 😊` into the text field (`group_chat_page.dart` 468–471) | sent as text |
| system | render only | user send blocked |
| event | tap if `mediaId` set → event route | `eventsDomain.postEventChatActivity` writes `type: "event"`, `senderId: "system"` |
| game | bubble label `Game card` | no writer in `functions/src` except tests. **UNVERIFIED** production writers |

### 8.2 Actions (`group_chat_page.dart` 244–315)

Copy (if text), Reply → placeholder, React hardcoded `❤️` → `addReaction` (any member), Pin/Unpin → `pinGroupMessage` (server `pin`), Delete → `deleteGroupMessage` (sender or `deleteMessages`), Forward/Report → placeholder.

`editGroupMessage` exists on the repository; no composer/action UI. **INCOMPLETE/MOCK** UI.

Client does not hide pin/delete based on permissions.

### 8.3 Pagination / unread

Live: Firestore `limit 40`, `orderBy createdAt desc, id desc`. Older: `getOlderMessages` when scroll offset < 180 or “Load older messages”.

Delivery/read: client batches up to 50 ids; server sets `deliveredBy`/`readBy` and `members/{uid}.lastReadAt`. Group list unread from `lastReadAt` is not implemented in `lib/features/groups`.

`lastMessageAt` / `lastMessageText`: written by `sendMessage` transaction (`groupChat.js` 188–193). Rules still allow a member to update only those two fields (`firestore.rules` 514–518). Messages subcollection: client create/update/delete false.

Media page filters currently loaded chat messages only.

**Traceability:** `group_chat_page.dart`, `chat_message_bubble.dart`, `chat_models.dart`, `chat_provider.dart`, `firebase_chat_repository.dart`, `groupChat.js`, `groupMediaPipeline.js`, `eventsDomain.js` 661–688, `firestore.rules` 514–625

---

## 9. Private Chat

Conversation id (`socialGraph.js` 15–17): sorted pair `pairId` → `${lenA}:${userA}${lenB}:${userB}`. `startPrivateChat` uses that id (`privateChat.js` 232–233). Legacy friendship/respect docs also consulted.

Start gate (`privateChat.js` 187–195): not blocked; `fan || friend`; then `whoCanMessageMe`. Fan: either direction respect `>= FAN_THRESHOLD` (5). Policy `friends` without friendship → `This user only accepts messages from Friends.` Client Start Chat uses `canStartPrivateChat` (friend or respect ≥5) and does not check `whoCanMessageMe` (`social_models.dart` 72–85, `profile_page.dart` 480–481).

Block: `assertNotBlocked` on start and every send. Client hides Start Chat when blocked.

List: limit 20 + load more; hidden conversations filtered via `hiddenFor`. Unread: `lastMessageAt` vs `participants[uid].lastReadAt`.

Send: text + image/video (storage path `privateChats/{chatId}/media/...`). Actions: Copy, Delete. No reply/react/pin UI.

Firestore: `privateChats` and subcollections read if participant; all client writes false.

**Traceability:** `privateChat.js`, `socialGraph.js` 3–17, `firebase_private_chat_repository.dart`, `private_chat_screen.dart`, `private_chats_list_screen.dart`, `social_models.dart`, `firestore.rules` 661–675

---

## 10. Games (Guess Character, Anime Chain, Emoji Anime Guess)

### 10.1 Shared infrastructure

Types in `GAME_TYPES` (`gamesDomain.js` 21–26): `guessCharacter`, `animeChain`, `emojiAnimeGuess`, `mafia`. Registry marks trivia three `implemented: true`; **mafia `implemented: false`** (59). Client `GameTypeRegistry` marks mafia `implemented: true` (`game_type_registry.dart` 92–104).

Statuses: draft, waiting, active, paused, completed, cancelled (`gamesDomain.js` 64–77).

Engines (`gameEngines/index.js`): only the three trivia games.

Create requires `groupId` and `manageGames`. No auto-matchmaking. Join while `waiting`. Start when `participantsCount >= minPlayers`. Callables: `createGame`, `initializeGame`, `joinGame`, `leaveGame`, `startGame`, `pauseGame`, `resumeGame`, `submitGameAction`, `endGame`, `cancelGame`. Scheduler `processExpiredGames` every 1 minute.

Rewards (`afterComplete`, 393–431): `economy.grantDomainRewards` type `earn_game` for `winnerIds`; achievements `game_won` / `game_completed`. Server-authoritative. Daily cap bucket `"event"` amount 10, cap 3 (`economyConfig.js`).

`configuration.difficulty` is stored and shown in create UI; engines do not read it. **INCOMPLETE/MOCK**

Client `ScoringStrategyRegistry` returns `NoOpScoringStrategy` (`scoring.dart` 41–44). Scores live in server `publicState`.

Catalog: `gameCatalog.js` 16 anime entries (characters, emoji clues, studio/character relations).

Trigger: Group details / chat menu → `/games?groupId=` → `/games/create?groupId=` → type chips. Mafia branches to `MafiaProvider.create` → `/mafia/{id}` instead of `createGame`.

Reconnect: Firestore snapshots on `GameProvider.open`. `GameStrings.reconnecting` is unused. **INCOMPLETE/MOCK** dedicated reconnect UI.

Anti-abuse: auth, membership, `status === active`, idempotent `clientActionId`, `stateVersion` stale reject, deadline expiry.

### 10.2 Guess Character

Phases `publicState.phase`: `round` | `game_over`. 2 players. +1 per correct guess. Timer per round (`deadlineAt`). Default rounds 5, timer 20s (engine clamps rounds 3–8, timer 10–45s; domain normalize 3–10 / 10–60). Answer in `games/{id}/secret/round` (rules read false). Artwork via `characterArt.publicArtwork`.

### 10.3 Anime Chain

Phases `turn` | `game_over`. 2–8 players. Next title must share character or studio and not already appear. +1 per valid submit. Ends at `maxChain` (`roundCount` 5–16, default 8) or consecutive skips covering the table. Timeout skips current player.

### 10.4 Emoji Anime Guess

Phases `guess` | `game_over`. 2–4 players. Turns = players × `roundsPerPlayer` (1–3). +1 if normalized title matches secret. Timeout advances with no score.

**Traceability:** `gamesDomain.js`, `gameEngines/*.js`, `gameCatalog.js`, `game_create_page.dart`, `game_details_screen.dart`, `game_play_panels.dart`, `game_providers.dart`, `firebase_game_repository.dart`, `game_type_registry.dart`, `firestore.rules` 706–745, `index.js` 400–443

---

## 11. Mafia

Separate collection `mafia_games`, not `gamesDomain` engines.

### 11.1 Phases (`phaseFlow.js` 6–27)

Lobby order: `waiting` (120s), `starting` (10s).  
Play order: `night` (45s), `day` (20s), `discussion` (90s), `voting` (45s), `execution` (15s), then wrap.  
`nextPhase`: waiting→starting→night; finished/cancelled stay; unknown play phase → night.

Client enum matches (`mafia_models.dart` 3–13). Terminal: `finished`, `cancelled`.

### 11.2 Lobby

One running game per group (`mafiaDomain.js` 125–127, 156–160). Defaults min 4 max 8 (clamped 4–16). Auto-start when full → `starting`. Manual `startMafiaGame`. Expired waiting lobby cancelled (`lobbyManager.js`). Expired starting assigns roles (`roleAssigner.js`).

Client create/join/start/leave: callables. Rules also allow a constrained client `mafiaGameCreate` path (`firestore.rules` 102–141); the Flutter repository uses callables for those four actions.

### 11.3 Roles (`abilities/index.js`, `roleAssigner.js`)

Assigned: mafia, doctor, detective, citizen filler; sniper if advanced ≥9; silencer if advanced ≥10.  
Registered but never assigned: `good_boy`. **INCOMPLETE/MOCK** assignment.

Night resolution (`nightResolver.js`): mafia majority kill vs doctor save; sniper one bullet; silencer `canSpeak: false` (reset next night); detective writes `lastInvestigationResult` on private doc.

Votes (`voteResolver.js`): majority executes; tie/none skip.

Win (`winConditionChecker.js`): mafia count ≥ others → mafias; mafia 0 → citizens.

Roles live under `players/{uid}/private/data` (client read self only).

### 11.4 Server vs client

Night action, vote, and mafia chat are **client Firestore writes** gated by rules (`firebase_mafia_repository.dart` 52–97; `firestore.rules` 888–955). Phase advance, role assignment, night/vote resolution, rewards: schedulers / Admin SDK.

Heartbeat every 25s. Disconnect if `lastSeenAt` > 90s (`disconnectHandler.js`), scheduler every 1 minute. `leaveMafiaGame` callable exists; `MafiaGameScreen` does not call leave. **INCOMPLETE/MOCK** leave UI.

Rewards: `rewardDistributor.js` `earn_game` source `mafia`, idempotent `rewardsDistributed`. History: `mafia_history/{gameId}`, `users/{uid}/user_mafia_history`.

**Traceability:** `mafiaDomain.js`, `phaseFlow.js`, `phaseScheduler.js`, `lobbyManager.js`, `disconnectHandler.js`, `leaveGame.js`, `roleAssigner.js`, `nightResolver.js`, `voteResolver.js`, `winConditionChecker.js`, `rewardDistributor.js`, `abilities/*`, `firebase_mafia_repository.dart`, `mafia_provider.dart`, `mafia_game_screen.dart`, `firestore.rules` 57–167, 861–958, `index.js` 444–455, 960–963

---

## 12. Events

Types with code paths (`eventsDomain.js` 20–24): poll, multipleChoice, ranking, versus, theory, prediction, quiz, imageComparison, characterComparison, animeComparison, openDiscussion, challenge.

Statuses: draft, scheduled, active, ended, cancelled, archived (`26–37`).

Max duration: `MAX_DURATION_MS = 7 * 24 * 60 * 60 * 1000` (`12`, 135–137) message `Events cannot last longer than 7 days.` Client `EventLifecycle.maxDuration` is 7 days.

Group required on create. Callables: saveEventDraft, publishEvent, cancelEvent, endEvent, archiveEvent, deleteEventDraft, joinEvent, leaveEvent, submitEventResponse. Cron `processEventLifecycle` every 1 minute: scheduled→active at `startAt`; active→finalize `endedReason: "expired"` at `endAt`.

Results: votes / Borda ranking / quiz correctCounts (no winnerIds) / theory submissions / comparison winners / challenge verified vs self_report. Rewards `earn_event` for `winnerIds` when present.

Chat cards: `postEventChatActivity` as type `event`. Notifications `event_starting` (pushWorthy true) / `event_ended` (pushWorthy not set true in `notifyEventLifecycle`).

Trigger: `/events/create?groupId=` from group details when `canManageEvents`.

**Traceability:** `eventsDomain.js`, `event_models.dart`, `event_type_registry.dart`, `event_lifecycle.dart`, `event_builder_page.dart`, `event_details_screen.dart`, `event_list_screen.dart`, `firebase_event_repository.dart`, `index.js` 364–398, 552–555, `firestore.rules` 678–704

---

## 13. Edits (Video Feed)

Upload (`edit_upload_page.dart`, `editsDomain.js`, `editPipeline.js`):

1. Gallery video pick (client)
2. `startEditUpload` creates doc `status: uploading`, path `edits/{creatorId}/{editId}.mp4`; caption ≤1000, animeTag ≤128
3. Client Storage upload
4. Wait until status leaves `processing` (5 min timeout)
5. `processEditVideo` onObjectFinalized europe-west3: reject non-mp4 or size > 250MiB; duration ≤0 or >180s fails; ffmpeg scale max 1080, libx264 crf 25; thumbnail at 0.5s max 720px
6. Publish `status: published`, `score: 20 + creatorQuality`; `earn_publish`; achievement `edit_published`

No moderation step in `editPipeline.js` or `editsDomain.js`. **INCOMPLETE/MOCK** (absent)

Feed query: `status == published`, `orderBy score desc, createdAt desc` (`firebase_edits_repository.dart` 80–85). Discovery uses `scoreEdit` (`ranking.js` 142–165).

Interactions: view (`startEditPlayback` + `recordEditView`: not self, ≥10% of server elapsed, once per day, completion ≥90%), like, comment, reply, comment like, repost (30-day window), share signal weight 3, save signal weight 5. Negative signal has no feed UI. Respect is not an edits action. Delete callable exists; not on the feed UI.

Rules: `edits` documents and aggregates client-unwritable.

Storage create: owner, `video/mp4`, ≤100MiB (`storage.rules` 251–259); pipeline writes processed/thumbs with Admin SDK.

**Traceability:** `edit_feed_page.dart`, `edit_upload_page.dart`, `edit_comments_sheet.dart`, `edits_provider.dart`, `firebase_edits_repository.dart`, `editsDomain.js`, `editPipeline.js`, `ranking.js`, `firestore.rules` 764–775, `storage.rules` 251–270, `index.js` 218–262

---

## 14. Fan Works

Types (`fanWorksDomain.js` 3–11): manga, drawing, story, character, aiCharacter, worldbuilding, other.

Draft → `saveFanWorkDraft` (only draft editable). Publish → `status: published`, `visibility: public`, `moderationStatus: "approved"` with no human queue. Type-specific `publishValidationError` (291–359). `earn_publish` once.

Reports: reasons inappropriate, spam, copyright, harassment, other; sets `moderationStatus: flagged`. Removal request same flag. Public list requires published + approved + public.

Ownership: `creatorId`; archive/delete/revise creator-only. Media path `fan_works/{uid}/{workId}/`, MIME jpeg/png/webp/gif, max 10MB; roles cover, page, image, extra.

Client screens: feed, details, manga viewer, story reader, editor (`fan_work_screens.dart`).

**Traceability:** `fanWorksDomain.js`, `fan_work_models.dart`, `fan_work_lifecycle.dart`, `fan_work_screens.dart`, `fan_work_providers.dart`, `firebase_fan_work_repository.dart`, `firestore.rules` 777–826, `storage.rules` 272–296, `index.js` 460–515

---

## 15. Economy (Coins, Store, Premium)

### 15.1 Earning (server `economyConfig.js` + `applyReward`)

| Type | Amount | Daily cap | Sources in code |
|------|--------|-----------|-----------------|
| earn_event | 10 | 3 | `eventsDomain.js` grant on winners |
| earn_game | 10 | 3 (bucket `event`) | trivia `afterComplete`; mafia `rewardDistributor` |
| earn_publish | 10 | 1 | edit pipeline; fan work publish |
| earn_achievement | 5 | 9 | `achievementsDomain.js` |
| earn_referral_inviter | 70 | none in DAILY_CAPS | `economyDomain.js` |
| earn_referral_invited | 30 | none | `claimEconomyReward` source `"referral"` only (371–379) |

Duplicates rejected; max balance `1000000000`. Client cannot pass a trusted price. `admin_adjustment` / `refund` are in `REWARD_TYPES` with no callable found. **INCOMPLETE/MOCK** as user-facing paths.

Achievements catalog (`achievementsDomain.js` 3–106): first_group, first_edit, first_friend, first_fan, first_event_participation, first_event_win, first_game_win, creator_milestone, community_milestone, edit_milestone (five edits), creator_fan_milestone, autumn_2026_rally (season 2026-09-01 to 2026-11-30, reward 10). Callable `getAchievements`.

### 15.2 Spending

Only `purchaseStoreItem` deducts catalog `item.price` in coins. Rate 8/min. Premium-only items require active premium (`economyDomain.js` 532–534).

Catalog (`economyConfig.js` 66–165):

| id | type | price | premiumOnly | availability |
|----|------|-------|-------------|--------------|
| frame_sakura | frame | 80 | false | active |
| frame_gold | frame | 200 | true | active |
| badge_pioneer | badge | 50 | false | active |
| badge_sensei | badge | 120 | false | active |
| nameplate_neon | nameplate | 90 | false | active |
| theme_midnight | theme | 150 | true | active |
| badge_retired | badge | 10 | false | inactive |

Store UI tabs: Featured, Categories, Items, Owned, Premium (`economy_screens.dart` 59–65). Equip/unequip callables.

### 15.3 Premium

Active if `subscriptionType === "premium"` AND `premiumExpiresAt > now` (`economyDomain.js` 59–62). Grants `adFree` and premium catalog access. No Paddle/webhook string in `functions/`. `restorePremiumPurchases` returns `{ restored: false, deferred: true, reason: "payment_provider_not_configured" }` (355–368). Client: `Real payments are not connected in this build.` (`economy_types.dart` 45–46). Client cannot set `subscriptionType: premium` on update (rules).

### 15.4 Ads

Placements: `homeFeed`, `groupEntry`, `storeFooter` (`economy_types.dart` 22). Defaults: enabled, 2/day, 5 min cooldown, `premiumExcluded: true`. `storeFooter` override 1/day, 10 min (`ads_service.dart` 8–19). Only `homeFeed` is rendered (`home_page.dart` 182). UI is placeholder card `Sponsored` (`economy_widgets.dart` 144–161). **INCOMPLETE/MOCK** (no ad network SDK in Dart). Guide: `Coins cannot remove ads.` (`guide_page.dart` 196). `rewardedCoinsEnabled: false` from server (`economyDomain.js` 322–325). Android Gradle still includes a Vungle mediation artifact.

**Traceability:** `economyConfig.js`, `economyDomain.js`, `economy_screens.dart`, `economy_provider.dart`, `economy_types.dart`, `ads_service.dart`, `entitlement_service.dart`, `achievementsDomain.js`, `firestore.rules` 384–415, 461–469, `index.js` 516–550

---

## 16. Notifications

### 16.1 Types actually built

| type | Trigger | destination (as coded) | default push |
|------|---------|------------------------|--------------|
| group_message | `onNewGroupMessage` → `notificationTriggers.groupMessage` (skips `system`) | `/group-chat?groupId=` | yes (`PUSH_TYPES`) |
| join_request | `onJoinRequest` | `/group-requests?groupId=` | yes |
| request_accepted | `onJoinRequestDecision` when accepted | `/group?groupId=` | yes |
| friend_request | `onFriendRequest` if pending | `/friend-requests` | yes |
| private_message | `onNewPrivateMessage` | `/private-chat?chatId=` | yes |
| respect_received | `onRespectReceived` | `/profile?uid={fromUserId}` | yes |
| fan_work_liked / commented | fanWorksDomain | `/fan-work/{id}` | pushWorthy false |
| economy_reward / economy_purchase | economyDomain | `/store` | false |
| achievement_unlocked | achievementsDomain | `/achievements?id=` | false |
| game_invite / game_started / game_completed | gamesDomain | `/game/{id}` | invite/started pushWorthy true |
| game_invite (mafia) | mafiaDomain create | `/mafia/{id}` | true |
| event_starting / event_ended | eventsDomain `notifyEventLifecycle` | `/event/{id}` | starting true |
| group_disbanded | `disbandGroup` inline write | not via notificationBuilder; type `group_disbanded`, `refId` groupId | FCM not in that write |

Creation: `notificationBuilder.build` (idempotent per recipient+id) except disband which writes notification docs directly (`index.js` 768–778). Clients cannot create notifications (`firestore.rules` 418–421).

`index.js` also defines unexported `legacyOnNewGroupMessage` and `legacyOnJoinRequest` constants (814–950). They are not `exports.*`, so they are not deployed functions. The deployed group-message trigger is `exports.onNewGroupMessage` only.

FCM tokens: `registerFcmToken` / `unregisterFcmToken`; `users/{uid}/fcmTokens` client read/write false. Builder looks up `collectionGroup("fcmTokens")`.

### 16.2 Client inbox

Stream first 30 by `createdAt` desc. `loadMore` older 30. `_hasMore` initialized `true` (`notification_provider.dart` 27). After a page, `_hasMore = older.isNotEmpty` (80) — a short last page keeps hasMore true. `close()` does not reset `_hasMore`. Inbox `onRetry: () {}` (`notification_inbox_page.dart` 28, 35). Observed behavior: retry control does nothing; load-more may keep requesting when a short page returns.

Tap: `AppNavigation.go(item.destination)`.

Inbox title switch includes group_message, join_request, request_accepted, friend_request, respect_received, game_*, achievement_unlocked; other types fall through to `Notification`.

**Traceability:** `notificationBuilder.js`, `notificationTriggers.js`, `notificationCallables.js`, `notification_provider.dart`, `notification_inbox_page.dart`, `firebase_notification_repository.dart`, `index.js` 589–624, 608–631, 891–894, `firestore.rules` 418–427

---

## 17. Profile

Own profile (`profile_page.dart` 151–218): `displayName ?? username`, avatar, bio, Respect, Fans, Friends counts, anime taste, edits strip, fan works strip, buttons to edit / friend-requests / achievements / store / premium.

Others (261–297): **username** (not displayName), avatar, bio, Respect, Fans, give Respect 0–7, friend/block/chat.

Public projection fields (`publicProfile.js` 3–14): username, displayName, avatarUrl, bio, totalRespect, fansCount, equipped frame/badge/nameplate, favoriteAnimeIds. Client `PublicProfile` (`public_profile.dart` 1–43) has no `displayName` field, so others’ UI cannot show it from that model.

`profileVisibility` private → `public_profiles` deleted (`index.js` 78–80). `activityVisibility` stored; not used in the profile read UI. `whoCanMessageMe` enforced on private chat server.

Editable (`edit_profile_page.dart`): photo, bio, favorite anime IDs (comma list, max 50), profile/activity visibility, whoCanMessageMe. Save → callable `updateSocialProfile` (`avatarPrivacy.js` 53–66). Username/displayName are not on this form.

Avatar: client upload `users/{uid}/avatar.jpg` plus **direct Firestore** `avatarUrl` update (`firebase_profile_repository.dart` 88–96). `syncAvatarPrivacy` on `users/{uid}` write rotates/clears URL when visibility is private.

**Traceability:** `profile_page.dart`, `edit_profile_page.dart`, `public_profile.dart`, `publicProfile.js`, `avatarPrivacy.js`, `firebase_profile_repository.dart`, `index.js` 49–86, `firestore.rules` 362–478, `storage.rules` 110–115

---

## 18. Social Graph (Respect, Fans, Friends, Block)

Respect: 0–7 (`socialGraph.js` 3–4), cooldown 3000 ms, rejected if blocked. Fan when `value >= 5` (`FAN_THRESHOLD`). Achievement `fan_gained` on first fan. Client mirror `SocialSnapshot.fanThreshold = 5`.

Friends: `friendships/{pairId}` status pending | accepted | blocked. `sendFriendRequest` → pending; `respondToFriendRequest` accept → accepted; `removeFriend` deletes unless blocked.

Block checks present: respect, friend request, private chat start/send, discovery `visibleToViewer`, search `bindHiddenUsers`, profile UI.

Block checks absent in audited client queries: Home promoted/rising/community Firestore lists; edits feed query; fan works public feed (moderation filter only).

`fans/{fanId}`: read and write false.

**Traceability:** `socialGraph.js`, `social_provider.dart`, `social_models.dart`, `profile_page.dart`, `firebase_social_repository.dart`, `recommendationEngine.js` 130–138, `search_provider.dart`, `firestore.rules` 838–857, `index.js` 569–631

---

## 19. Settings

`SettingsPage` (`settings_page.dart`):

- Account: email display; Privacy and profile → `/profile/edit`; Send password reset (disabled without email); Sign out → `/login`
- Appearance: System / Light / Dark → SharedPreferences `pubget.settings.themeMode`
- Language: System / English / العربية → `pubget.settings.locale`
- Help: Guide `/guide`; Terms `/terms`
- About: version string `1.0.2+18`

Theme and locale applied in `MaterialApp.router` (`pubget_app.dart` 632–633).

Guide (`guide_page.dart`): static English `GuideTopic.all`; search filters title/body; some topics have routes (`/groups`, `/games`, `/achievements`, `/events`, `/edits`, `/friend-requests`, `/anime`, `/fan-works`, `/store`, `/premium`, `/profile/edit`). Chat, Roles, Roleplay, Respect/Fans, Moderation have no route.

**Traceability:** `settings_page.dart`, `settings_provider.dart`, `shared_preferences_settings_store.dart`, `guide_page.dart`, `pubget_app.dart` 280–288, 628–634

---

## 20. Search

`/search` `SearchPage` uses `SearchProvider`. Prefix `SearchQuery.prefix` min length 2, suffix `\uf8ff`.

Parallel (`firebase_home_repository.dart` 161–234):

- Groups: `isSearchable == true`, `searchName` range, limit 20
- People: `public_profiles.username` range, limit 20
- Events: status in active/scheduled/ended, `searchName` range, limit 20
- Fan works: published + approved, `searchTitle` range, limit 20
- Anime: `AnimeRepository.searchAnime` (Jikan HTTP) limit 8

Merge order in `SearchHit.fromDiscovery`: groups, people, events, anime, fan works. Blocked users filtered client-side.

`GroupsHomePage` also searches: fetches 50 searchable groups, filters name/description on the client (`firebase_group_repositories.dart` 61–76).

Home inline search: see §3.5.

Not queried by this global search: edits videos as a first-class hit type, private chats, games, mafia lobbies, store items.

**Traceability:** `search_page.dart`, `search_provider.dart`, `search_query.dart`, `search_hit.dart`, `firebase_home_repository.dart` 161–234, `jikan_anime_repository.dart`

---

## 21. Deep Links & Sharing

Canonical host `pubget-aaf27.web.app` (`pubget_links.dart` 10). Builders: `/event/{id}`, `/fan-work/{id}`, `/game/{id}`, `/mafia/{id}`, `/anime/{id}`, `/group/{id}`, `/profile/{id}`. Copy/share via clipboard / `share_plus`.

Router resolves those segment forms plus in-app query routes (`/group-chat?groupId=`, `/profile?uid=`, etc.).

Hosting (`firebase.json` 45–61): `/` → `presentation.html` (not the Flutter app); `/group/**`, `/g/**`, `**` → `index.html`. Flutter has no `/g/` parser branch. **UNVERIFIED** whether `/g/...` maps to a group in the web build.

Root marketing site is `presentation.html`. Unknown ids → `UnknownLinkPage`.

**Traceability:** `pubget_links.dart`, `app_router.dart` 235–317, `firebase.json`, `unknown_link_page.dart`, `web/presentation.html`

---

## 22. Architecture

### 22.1 Layering

App wiring (`pubget_app.dart`): Widgets → ChangeNotifier providers → repository interfaces → Firebase implementations (or `Unavailable*` when Firebase is not ready).

Domain mutations for groups, chat, economy, edits, fan works, events, trivia games, social graph, notifications (except disband’s direct writes) go through HTTPS callables / Admin SDK. Widgets still contain control flow: join membership stub, changeRole hardcoded senpai, chat placeholders, onboarding skip local success, notification retry no-op, home search controller vs provider.

Business rules also live in Cloud Functions modules listed in §23.

`LoggingAnalytics` is the Analytics implementation (`pubget_app.dart` 205).

Anime catalog is HTTP Jikan behind `CachedAnimeRepository`, not Firestore, except user lists via `animeListsDomain` callables.

### 22.2 Domain isolation (games / mafia / chat)

Trivia games use collection `games/{gameId}` and callables in `gamesDomain.js`. They do not import `ChatProvider` or `sendGroupMessage`. No production writer of `type: "game"` group messages was found in `functions/src`.

Events write group chat cards via Admin `postEventChatActivity` (`eventsDomain.js` 661–688) — coupling from events domain to `groups/{id}/messages`.

Mafia uses `mafia_games/{id}/chat` (separate from group chat). `mafiaDomain.js` imports `ROLE_PERMISSIONS` from `groupsDomain.js` (line 3) for `manageGames`. Client heartbeat/night/vote/chat write Firestore directly.

Group nested `groups/{groupId}/games/{gameId}` is **client-writable for `groupModerator`** (`firestore.rules` 627–629). That path is distinct from top-level `games/{gameId}` (client writes false). Whether the Flutter app writes the nested path is **UNVERIFIED** (no `lib/` match found in this pass).

**Traceability:** `pubget_app.dart`, `gamesDomain.js`, `eventsDomain.js` 661–688, `mafiaDomain.js` 1–3, `firebase_mafia_repository.dart`, `firestore.rules` 627–629, 706–721

---

## 23. Security

### 23.1 Firestore rules (collections)

Default: unmatched paths are denied. There is no catch-all allow. `_system/discoveryScheduler` has no match (scheduler uses Admin SDK).

| Path | Client read | Client write |
|------|-------------|--------------|
| users/{uid} | get self; list false | create self with free/zero counters; update presentation fields only (not coins, premium, respect, bans) |
| users/.../notifications, fcmTokens | notifications self / tokens false | false |
| users/.../stickers | self | self create/update/delete constrained |
| users/.../daily_rewards, transactions, rewards, inventory, user_mafia_history | self | false |
| users/.../anime_lists, character_favorites | self | false |
| users/.../economyRate | false | false |
| storeCatalog | signed-in | false |
| economyTransactions | own userId | false |
| public_profiles | signed-in if profileVisibility public | false |
| groups | signed-in if exists and not deletionPending | create legacy schema; update founder fields / membershipMutation / lastMessage* / mafia lobby markers; delete false |
| groups/.../members | signed-in + group exists | legacy founder/moderator/self lastReadAt |
| groups/.../requests | self or groupModerator | create self legacy shape; update false; delete self/moderator with notification helpers |
| invites, roles, transferConfirmations | invites/roles member; transfer false | false |
| bans | self or moderator | false |
| messages, media | member | false |
| groups/.../games | member | **create/update/delete if groupModerator** |
| groups/.../characters | member | legacy userId/characterName schema (not reservedByUid) |
| privateChats + messages/media | participant | false |
| events + participants/responses | creator or non-draft group member; responses extra rules | false |
| games + subcollections | creator or non-draft member | false; secret read/write false; private/{uid} read self |
| game_history, achievements | signed-in | false |
| user_achievements | self | false |
| edits + comments | signed-in | false; likes/viewers read self write false |
| fanWorks + subdocs | creator or published+approved | false |
| user_interactions/{uid}/interactions | self | **create self if userId == uid; update/delete false** |
| user_seen/{uid}/seen_edits | self | **create, update, delete self** |
| respects | participant get/list | false |
| fans | false | false |
| friendships | uid in userIds | false |
| social_rate_limits | false | false |
| promotions, physical_products | signed-in | false |
| mafia_games | group member | create/update via mafiaGameCreate / join/leave counters only; delete false |
| mafia players | group member | create defaults; heartbeat lastSeenAt/isDisconnected; private write false |
| night_actions | read false | create intent in night phase |
| votes | group member | create in voting phase |
| mafia chat | group member | create in day/discussion/voting with canSpeak |
| mafia_history | signed-in | false |

Sensitive fields on `users` (coinsBalance, subscriptionType, totalRespect, fansCount, isBanned, custom limits, hasClaimedReferral) are locked on update. Create may include them only at zero/free.

`lastMessageAt`/`lastMessageText` remain member-writable.

Mafia night/vote/chat are client-trusted as **intent documents**; resolution is server-side.

### 23.2 Storage rules

Authenticated-only named paths. Avatars 5MB images; group image/background owner 10MB; chat media image 10 / audio 25 / video 100 MB with `uploadedBy` metadata; originals immutable for structured media; edits mp4 owner 100MB create, thumbs write false; fan_works owner draft 10MB; catch-all unsupported paths denied (test “denies paths not explicitly supported”).

### 23.3 Callables (exports in `functions/index.js`)

HTTPS callables (region us-central1 unless noted): updateSocialProfile; getDiscoveryFeed; anime list/favorites set/remove/get; startEditUpload, repostEdit, deleteEdit, likeEdit, addEditComment, startEditPlayback, recordEditView, recordEditSignal, editCommentAction; createGroup, createGroupInvite, joinGroup, requestToJoin, leaveGroup, accept/rejectJoinRequest, changeRole, updateGroupSettings, unbanMember, updateRolePermissions, kickMember, banMember, transferOwnership, prepareOwnershipTransfer, reserve/releaseRoleplayCharacter; send/edit/delete/pin/react/markRead/markDelivered group messages, updateGroupChatBackground; start/send/delete/markRead/markDelivered/delete private chat; event draft/publish/cancel/end/archive/delete/join/leave/submit; create/initialize/join/leave/start/pause/resume/submit/end/cancel game; create/join/start/leave mafia; getAchievements; fan work draft/publish/revise/removal/archive/delete/media/like/bookmark/report/rate/comment/commentAction; getEconomy, getInventory, getEconomyTransactions, getPremiumEntitlement, restorePremiumPurchases, claimEconomyReward, purchaseStoreItem, equip/unequipCosmetic; giveRespect, send/respond/remove friend, block/unblock; markNotificationRead, markAllNotificationsRead, register/unregister FcmToken; disbandGroup.

Triggers: syncAvatarPrivacy, syncPublicProfile, processEditVideo (europe-west3), processGroupChatMedia (europe-west3), recalculateInviteRanks, onNewGroupMessage, onJoinRequest, onJoinRequestDecision, onFriendRequest, onRespectReceived, onNewPrivateMessage, refreshGroupActivityScores, processExpiredGames, processEventLifecycle, processExpiredLobbies, processPhaseTransitions, markDisconnectedPlayers.

Auth: HTTPS handlers checked in this audit use `request.auth` / `authUid` / `requireAuth` and throw `unauthenticated`. Input validation is per-domain (`groupInput`, `validateMessage`, economy catalog prices, etc.). Idempotency: notification builder id; economy duplicate tx; mafia `rewardsDistributed`; disband `alreadyDeleted`; game `clientActionId`. `restorePremiumPurchases` is a no-op restore. `claimEconomyReward` only `referral`.

**Traceability:** `firestore.rules` (entire file), `storage.rules` (entire file), `functions/index.js`

---

## 24. Offline / Reliability

`NetworkService` probes every 15s (`network_service.dart` 12–32). Many screens branch on `NetworkError` vs generic error.

**Send group message:** optimistic pending message; failure marks `ChatSendState.failed` with retry (`chat_provider.dart` 231–251) calling `sendMessage` with the same `messageId`. Duplicate clientAction-style id depends on server treating that id as upsert. **UNVERIFIED** exact server duplicate behavior beyond existing tests.

**Join group:** callable; on success local membership uid is `''`. Offline maps to `NetworkError` in group repositories. No queued join.

**Start game:** callable; no offline queue. Client resubscribes via Firestore when `open()` runs again.

**Onboarding skip:** NetworkError → local `hasSkippedOnboarding: true` without confirmed write; `canEnterHome` becomes true on device.

**Economy:** if already loaded and offline, shows cached snapshot (`economy_provider.dart` 73–77); purchases require connection.

**Edits upload:** waits on processing snapshot; 5 minute timeout then client-side failure.

**App restart:** Firebase Auth restores session; splash reloads profile; onboarding skip flags persist only if Firestore write succeeded (or local skip until process death). SharedPreferences holds theme/locale.

**Mafia:** heartbeat + disconnect scheduler; no special offline action queue; night/vote writes fail as Firestore errors.

**Traceability:** `network_service.dart`, `chat_provider.dart`, `group_provider.dart`, `onboarding_provider.dart` 113–156, `economy_provider.dart` 65–80, `firebase_edits_repository.dart` 62–67, `mafia_provider.dart`

---

## 25. Testing (current real coverage)

Run on this tree at `8f34d21` in this environment:

| Suite | Command | Result |
|-------|---------|--------|
| Flutter | `flutter test --reporter compact` | **294 passed, 0 failed** (final line `+294: All tests passed!`) |
| Functions unit | `cd functions && npm test` | **168 passed, 0 failed** (`# tests 168` `# pass 168`) |
| Rules + emulator E2E | `npm test` (root `test:rules`) | **62 passed, 0 failed** (`# tests 62` `# pass 62`), emulator script exit 0 |

Root `test:rules` concurrently executes: `firestore.rules.test.js`, `storage.rules.test.js`, `productEngines.e2e.test.js`, `productDiscovery.e2e.test.js`, `productDiscoveryLifecycle.e2e.test.js`, `socialGroups.e2e.test.js`.

Flutter `test/` files (68 dart files) cover: auth (screens, provider, validators, failures, route guard, splash, google config, firebase bootstrap), onboarding, settings, search, home display order / discovery error / feed models, groups permissions / provider, chat provider (1 test file), private chat screens, events models/providers/builder/screens/links, games engine/providers/screens, economy screens/providers, fan work models/screens/links, anime (repository, cache, pagination, search, security, screens, library, deep link, http, mapper, providers), app router, links, design system, accessibility, profile/social providers, product engine screens, guide, message delivery indicator, dummy provider.  

No Flutter widget tests named for: mafia play screen, group chat composer, edits feed playback, notification inbox `hasMore`/retry, roleplay reservation UI.

Functions unit files (22): socialGraph, avatarPrivacy, groupsDomain, groupChat, privateChat, eventsDomain, gamesDomain, gameEngines, characterArt, achievementsDomain, mafiaDomain, mafiaEngine, fanWorksDomain, groupMediaPipeline, notificationBuilder, discoveryEngine, editsDomain, economyDomain, mafiaLeaveGame, ranking, recommendationEngine, animeListsDomain.

**Traceability:** `/tmp/flutter-test.log`, `/tmp/functions-test.log`, `/tmp/rules-test.log`, `package.json`, `functions/package.json`, `test/**`, `functions/test/**`

---

## 26. Localization / RTL

`MaterialApp.router` `supportedLocales`: `en`, `ar` (`pubget_app.dart` 634). Delegates: Material, Widgets, Cupertino. No `.arb` / `lib/l10n` generated catalog exists.

Locale comes from `SettingsProvider` (`system` → null, `english` → `Locale('en')`, `arabic` → `Locale('ar')`). Choosing العربية applies Flutter’s Arabic Material localizations (system chrome, some widgets RTL). Feature copy is English string literals throughout `lib/`.

Examples of English (or mixed) UI that remain when locale is `ar`:

- Splash `Premium Anime Community` / `Preparing your experience…` (`splash_page.dart`)
- Login `Welcome back`, `Sign in`, `Forgot password?` (`login_page.dart`)
- Home AppBar `Discover` (`home_page.dart` 74)
- Settings section titles Account / Appearance / Language / Help / About; only the Arabic option label is `العربية` (`settings_page.dart` 161–164)
- Guide topics and bodies all English (`guide_page.dart`)
- Chat placeholder snackbar `This action is prepared for a later Pubget prompt.` (`group_chat_page.dart` 310–315)
- Economy `Sponsored`, `Real payments are not connected in this build.` (`economy_types.dart`)
- Notification titles `New group message`, etc. (`notification_inbox_page.dart` 138–148)

RTL toggle in debug design-system showcase (`design_system_showcase_page.dart` 42–43) is a local `Directionality` override, not the production settings locale.

Server-side Arabic appears in disband notifications (`index.js` 758–771 `تم تفكيك المجموعة`) and legacy unused FCM preview strings (`messagePreview` media labels).

**Traceability:** `pubget_app.dart` 628–638, `settings_store.dart`, `settings_page.dart`, `guide_page.dart`, `home_page.dart`, `splash_page.dart`, `group_chat_page.dart` 310–315, `notification_inbox_page.dart` 138–148

---

## 27. Known Incomplete / Mock / Placeholder Inventory

| Tag | Location | What is there |
|-----|----------|----------------|
| INCOMPLETE/MOCK | `terms_copy.dart` 17–19 | Draft terms text |
| INCOMPLETE/MOCK | `auth_draft_store.dart` | Terms acceptance in-memory only |
| INCOMPLETE/MOCK | `placeholder_home_page.dart` | Unregistered home placeholder |
| INCOMPLETE/MOCK | `firebase_group_repositories.dart` 351–356, `roleplay_character_page.dart` 35 | Four mock RP characters; UI says mock |
| INCOMPLETE/MOCK | `roleplay_provider` / screens | `releaseCharacter` not used |
| INCOMPLETE/MOCK | `group_chat_page.dart` 310–315, 459 | Sticker, audio, reply, forward, report → snackbar |
| INCOMPLETE/MOCK | gif send | Enum + bubble; no composer item |
| INCOMPLETE/MOCK | `editGroupMessage` | Repository + callable; no UI |
| INCOMPLETE/MOCK | `updateGroupSettings`, `unbanMember` | Server + tests; no `lib/` UI |
| INCOMPLETE/MOCK | `group_members_page.dart` 174 | Change role always senpai |
| INCOMPLETE/MOCK | `group_provider.dart` 97–101 | Join sets `uid: ''` |
| INCOMPLETE/MOCK | `gamesDomain.js` mafia `implemented: false` vs client `true` | Dual registry |
| INCOMPLETE/MOCK | game `difficulty` | Stored, unused by engines |
| INCOMPLETE/MOCK | `GameStrings.reconnecting` | Unused |
| INCOMPLETE/MOCK | mafia `good_boy` | Registered, never assigned |
| INCOMPLETE/MOCK | mafia leave | Callable + repo; no screen control |
| INCOMPLETE/MOCK | edit moderation | Absent in pipeline |
| INCOMPLETE/MOCK | `economy_widgets.dart` 144–161 | Sponsored ad placeholder |
| INCOMPLETE/MOCK | `restorePremiumPurchases` | deferred, provider not configured |
| INCOMPLETE/MOCK | `admin_adjustment` / `refund` | Enum only |
| INCOMPLETE/MOCK | Ad placements groupEntry, storeFooter | Configured, not placed |
| INCOMPLETE/MOCK | `notification_inbox_page.dart` 28, 35 | `onRetry: () {}` |
| INCOMPLETE/MOCK | Home section names `*Placeholder` | Real strips, still named placeholder in enum |
| INCOMPLETE/MOCK | `ScoringStrategyRegistry` | No-op client scoring |
| INCOMPLETE/MOCK | type `game` group cards | Render only |
| Observed | `notification_provider.dart` 27, 80, 135–147 | `hasMore` init true; last page if non-empty keeps true; `close` does not reset it |
| Observed | `firestore.rules` vs `PubgetUser.toMap` | create/update keys vs `displayName` / `whoCanMessageMe` |
| Unexported | `index.js` 814–950 | `legacyOnNewGroupMessage`, `legacyOnJoinRequest` not in `exports` |

No `TODO` / `FIXME` / `UnimplementedError` tokens in `lib/` or `functions/src` (grep). `lib_legacy` contains TODOs (see §28).

---

## 28. Legacy (`lib_legacy/`)

`lib_legacy/` is present (models, providers, features for home, groups, chat, mafia, edits, store, auth, stickers, etc.).

Grep of `lib/` for `lib_legacy`: **no matches**. `pubspec.yaml` does not list it as a package. Active `main.dart` imports `app/pubget_app.dart` only.

Status: **dormant / not referenced by the active app**. It remains in the repository as a parallel tree. `lib_legacy/core/mafia/mafia_role_registry.dart` contains `TODO(Stage 4)` comments for night actions. That code is not imported by `lib/features/mafia`.

**Traceability:** directory `lib_legacy/`, `lib/main.dart`, grep over `lib/`

---

CURRENT STATE MASTER DOCUMENT: COMPLETE
