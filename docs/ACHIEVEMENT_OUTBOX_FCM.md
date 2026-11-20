# Achievement Outbox: Notifications and FCM

## Delivery contract

Achievement unlocks and their outbox effects are written atomically by the existing achievements producer. The Worker consumes one effect per event per scheduled invocation:

1. Coin rewards use the transactional economy ledger.
2. In-app notifications are created in `users/{uid}/notifications/{notificationId}` and increment `unreadNotificationsCount` in the same Firestore transaction.
3. FCM is sent only after its separate outbox effect is claimed. It never creates or increments an in-app notification.

The notification ID is deterministic: `achievement-{uid}-{achievementId}`. A transaction reads that exact document and creates it only if absent. A replay sees the existing document and completes without incrementing the unread counter again.

FCM is **at-least-once**, not exactly-once. If FCM accepts a message and the Worker crashes before the outbox effect is marked delivered, a retry can send a duplicate. Clients should use `notificationId` to collapse/deduplicate the presentation where possible. A user with no registered FCM tokens is treated as a completed no-op; the in-app notification remains available.

## Worker schedule

The Wrangler configuration schedules the outbox consumer once per minute. Each invocation scans a bounded batch and processes one next eligible effect for each event. Lease expiry and persisted exponential backoff provide recovery after interruption. The cron only becomes active when this branch is deployed; this implementation does not itself deploy or enable a production consumer.

## Required Google Cloud authorization

The configured `FIRESTORE_SERVICE_ACCOUNT_EMAIL` must have:

- Firestore access already used by the Worker (currently `roles/datastore.user`).
- The Firebase Cloud Messaging API enabled for project `pubget-aaf27`.
- Permission `cloudmessaging.messages.create`, normally granted by the project-level role `roles/firebasecloudmessaging.admin`.

The FCM access token is minted with the narrow combined OAuth scopes `https://www.googleapis.com/auth/datastore` and `https://www.googleapis.com/auth/firebase.messaging`. No service-account key is committed to the repository; the existing Worker secret binding remains the source of the private key.

## Verification still required before production

Automated tests cover notification idempotency, transactional counter updates, FCM request construction, missing tokens, and retryable HTTP failures. They do not prove the live service account has the required IAM permission or that the FCM API is enabled.

Before deployment, an operator must confirm the IAM role and API state in Google Cloud, then perform a controlled test with a real test account/device and inspect the outbox state plus received push. Do not send test messages to production users. A 403 from the FCM send endpoint is treated as a retryable delivery failure; it is not evidence that the permission is correct.

No PR merge, Worker deployment, production cron activation, or live FCM send is part of this change.
