# Comprehensive Pubget Forensic Audit

## Scope and mandate

This document is an audit-only baseline created under the product authority of `docs/PUBGET_MASTER_SPEC.md` and the operating constraints in `docs/PUBGET_OPERATING_PROMPT.md`.

The explicit constraints for this pass were:
- audit only; no production-code changes
- no implementation of fixes
- no Phase 06 or Phase 07 work
- establish the exact baseline before any future remediation work
- treat the master spec as the final product authority

This audit is therefore focused on evidence, traceability, and risk classification. It does not propose code changes and does not begin any build phase.

---

## 1. Audit authority and evidence sources

Primary authority consulted:
- `docs/PUBGET_MASTER_SPEC.md`
- `docs/PUBGET_OPERATING_PROMPT.md`
- `docs/PUBGET_GAP_ANALYSIS_AND_ROADMAP.md`

Additional repo evidence reviewed:
- `lib/app/pubget_app.dart`
- `lib/app/app_router.dart`
- `lib/features/authentication/providers/auth_provider.dart`
- `lib/features/groups/repositories/firebase_group_repositories.dart`
- `lib/features/home/providers/home_provider.dart`
- `lib/features/home/screens/home_page.dart`
- `lib/features/search/screens/search_page.dart`
- `functions/index.js`
- `firestore.rules`
- `storage.rules`

Verification performed in this audit cycle:
- `node --check functions/index.js` — no syntax complaint was emitted by Node in the terminal session
- `flutter test test/pubget_user_test.dart -r expanded` — output reported: `All tests passed!`

Important limitation:
- The broader Flutter suite was interrupted during an earlier session (`SIGINT` during a wider test run), so this audit does not claim repository-wide green status.
- This document therefore distinguishes between verified local evidence and broader unverified repo claims.

---

## 2. Executive summary

Pubget is a large, domain-rich Flutter + Firebase product with real architectural intent and substantial implementation scaffolding. The codebase shows a serious product-engineering foundation:
- feature domains are separated by directory and provider boundaries
- app composition is centralized in `lib/app/pubget_app.dart`
- auth, settings, routing, group flows, and home feed infrastructure are present
- Firebase security rules and storage permissions exist as meaningful guardrails

However, the product is not yet in a clean, spec-aligned “production baseline” state. The current evidence supports a clear distinction between:
- real implemented systems
- placeholder/mock surfaces
- partially implemented domains
- features that appear functional but are not fully spec-compliant or verified

The strongest audit signals are not random; they cluster in four areas:
1. mock or placeholder data being surfaced as if it were real product content
2. backend registration or domain wiring risk in Firebase Functions
3. UI strings and discovery surfaces that do not follow the product’s localization and production-quality standards
4. product surfaces that are visibly incomplete relative to the master spec’s strict “no fake data / no placeholders / no dead buttons” rule

---

## 3. Confirmed risk findings by priority

### Priority 1 — high risk / product integrity issues

#### 3.1 Mock roleplay content is being treated as real data
Evidence:
- `lib/features/groups/repositories/firebase_group_repositories.dart`
- the repository includes a static mock roster for roleplay characters

Risk:
- This violates the master spec rule: “No fake data” and “server is truth.”
- It creates the perception that roleplay inventory is implemented when the data is not grounded in actual server-backed state.
- The app may expose a scripted list that users mistake for a functional system.

Assessment:
- This is a concrete product integrity issue and not merely a visual polish problem.

#### 3.2 The Firebase Functions entrypoint contains a backend registration risk
Evidence:
- `functions/index.js`
- the file initializes multiple domains and also re-declares `mafiaDomain`, which is exactly the kind of risk called out in the gap analysis

Risk:
- This can produce erroneous backend registration behavior or fail initialization before the service is operational.
- It is a direct contradiction to the master spec’s “server is truth” and “no duplicate/unsafe backend registration” principle.

Assessment:
- This is a backend integrity issue and should be treated as a blocking operational risk until validated under a full backend deploy/test cycle.

#### 3.3 Discovery/Home still contains placeholder sections that contradict the spec
Evidence:
- `lib/features/home/providers/home_provider.dart`
- `_sectionOrder` explicitly includes placeholder categories such as `editsPlaceholder`, `eventsPlaceholder`, `gamesPlaceholder`, `fanWorksPlaceholder`, and `animePlaceholder`

Risk:
- The master spec is explicit that placeholders, fake data, and “coming soon” surfaces are not permitted in production surfaces.
- This creates an app surface that looks richer than it actually is, without the product-level data layer to support it.

Assessment:
- This is a direct compliance issue with the master spec’s quality standard.

### Priority 2 — medium risk / product credibility and UX issues

#### 3.4 Search page is only partially aligned with the required global search model
Evidence:
- `lib/features/search/screens/search_page.dart`
- the page contains literal strings such as `Search`, `Search Pubget`, and `Nothing found`
- the search UX is also tied to a limited support surface and does not reflect the full entity matrix required by the spec

Risk:
- The app does not yet present a fully spec-aligned internationalized search experience.
- Hardcoded strings are a direct violation of the localization requirement in the master spec.

Assessment:
- This is not a crash risk but a product quality and i18n issue.

#### 3.5 Home and search flows show a “looks complete but is not fully production-safe” pattern
Evidence:
- `lib/features/home/screens/home_page.dart`
- `lib/features/search/screens/search_page.dart`
- `lib/features/home/providers/home_provider.dart`

Risk:
- These areas appear feature-complete from a quick glance, but the underlying data model still contains placeholders and non-production sections.
- This is exactly the pattern the master spec warns against: surfaces that look rich but are not fully backed by real, verified behavior.

Assessment:
- This belongs in the “appears implemented but not fully verified” bucket.

### Priority 3 — lower risk / architecture and polish issues

#### 3.6 The app’s architecture suggests a better base than the current product readiness
Evidence:
- `lib/app/pubget_app.dart`
- `lib/app/app_router.dart`
- provider-based structure and domain segmentation are present

Risk:
- The architecture is a strength, but it does not automatically guarantee product readiness.
- Strong structure can conceal incomplete or mock content without triggering immediate technical failure.

Assessment:
- This is a latent risk: the system is organized, but the implementation quality is uneven across domains.

#### 3.7 Firebase rules are important but this audit did not validate every security assertion end-to-end
Evidence:
- `firestore.rules`
- `storage.rules`

Risk:
- These files are clearly substantial and more advanced than a scaffold, but this audit was intentionally limited and did not conduct a full rule-by-rule production security certification.

Assessment:
- Security posture appears more developed than the UI/product completeness; however, no full production assurance claim is made here.

---

## 4. Positive findings that remain valid

These are not “green lights” for production, but they are objective strengths in the repo and should be preserved.

### 4.1 Real architectural intent exists
The app has a structured composition layer with central app wiring and explicit provider registration. This is a strong sign that the product was designed with a domain-based architecture in mind.

### 4.2 Auth/session infrastructure is concrete
`lib/features/authentication/providers/auth_provider.dart` indicates a real auth lifecycle with initialization, sign-in, sign-up, sign-out, and state handling.

### 4.3 Firebase rules are not casual placeholders
The presence of rule logic around group membership, member restrictions, and storage permissions suggests meaningful server-side protection is already being considered.

### 4.4 The targeted test evidence is genuinely positive
The specific test command executed in this audit:
- `flutter test test/pubget_user_test.dart -r expanded`
returned:
- `All tests passed!`

This is a valid local signal that at least one targeted model-level regression path is working, but it does not cover the entire app and cannot be used to claim full release readiness.

---

## 5. Product baseline against the master spec

### 5.1 Spec compliance: what is clearly present
- real app shell and provider composition
- auth flow scaffolding
- structured domain folders for groups, home, search, routing, settings
- production-oriented Firebase rules
- a real provider-based app architecture

### 5.2 Spec compliance: what is not satisfied in the current evidence
The following are material mismatches with the master spec:
- no placeholder-free home surface
- mock roleplay inventory is present in a repo that should be server-backed
- localized, centrally managed text is not consistently followed across main screens
- backend registration and domain health is not yet sufficiently verified
- full global search as defined in the spec is not evidenced in the user-facing implementation

### 5.3 Core loop status
The app clearly has a discovery-first user loop and a multi-domain social structure, but the loop is still not fully trustworthy in production because some of its content surfaces are placeholder-backed or non-server-backed.

---

## 6. Risk classification summary

| Area | Status | Assessment |
|---|---|---|
| Group roleplay data | High risk | Mock content is present in production repository logic |
| Backend Functions registration | High risk | Duplicate/unsafe registration risk in Functions entrypoint |
| Discovery/Home placeholders | High risk | Direct conflict with “no fake data / no placeholders” rules |
| Localization | Medium risk | Hardcoded English strings in key interface paths |
| Search coverage | Medium risk | Partial compliance with global search spec |
| App architecture | Positive but incomplete | Strong structure, uneven implementation quality |
| Firebase rules | Positive but unverified | Existing rules show meaningful intent; not full-assured |
| Targeted test evidence | Positive | Verified for one focused model test path |

---

## 7. Audit conclusion

The primary conclusion is that Pubget is not in a clean, spec-compliant baseline for production release, even though the repo shows substantial foundational work.

The evidence is strongest around three facts:
1. the product architecture is genuinely substantial and domain-aware
2. the master spec is being used as a meaningful product authority
3. several concrete issues remain that are inconsistent with the product’s own stated quality rule: no fake data, no placeholders, no dead UI, and no server-side truth violations

The most important audit finding is this: the project is not just “unfinished”; it is partially filled with systems that visually appear more complete than the underlying data and backend guarantees actually support.

This is exactly the sort of product-state drift that should be captured before any Phase 06 or Phase 07 work begins.

---

## 8. Final audit status

Status: AUDIT COMPLETE — BASELINE ESTABLISHED

Scope completed:
- master spec authority confirmed
- operating prompt constraints honored
- repo-level evidence reviewed
- concrete product integrity risks documented
- no production code changes made
- no Phase 06 / Phase 07 execution started

This file is the formal forensic baseline for subsequent implementation work.
