# Authentication and onboarding

This domain follows `UI → Provider → Repository → Firebase`.

- `PubgetUser` is the new profile schema. It intentionally contains no coins,
  premium, subscription, or economy fields.
- The Firestore document ID is the user ID. `toMap()` includes `id` for portable
  serialization, while the Firebase repository removes it before document
  writes.
- Authentication identity and profile completion are separate states.
  `AuthProvider` owns the Firebase Auth session; `OnboardingProvider` owns the
  Firestore profile.
- Anime interests are stored as simple strings until the Anime domain exists.
- Avatar selection uses `image_picker`; bytes are uploaded by `UserRepository`
  through Firebase Storage. Widgets never access Storage directly.
- The Terms page contains temporary placeholder text and must be replaced by
  approved legal copy before public launch.
- Firebase Web remains unavailable until verified Firebase Web options are
  supplied. The app presents a visible unavailable state instead of inventing
  configuration values.

Direct dependencies added for this domain are `firebase_auth`,
`cloud_firestore`, `firebase_storage`, `google_sign_in`, and `image_picker`.