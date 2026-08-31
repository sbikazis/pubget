# Public profile security rollout

1. Deploy the `syncPublicProfile` function first.
2. Run `cd functions && npm run backfill:public-profiles` to inspect a dry run. Use Application Default Credentials; no credentials belong in this repository. Re-run as `npm run backfill:public-profiles -- --apply` only in the intended Firebase project. For resumable chunks pass `-- --max-pages N`, then continue with the printed `--start-after DOCUMENT_ID`.
3. Verify `users` and `public_profiles` counts and manually sample public documents. They must contain only identity/display fields and the derived `isPremium` badge; in particular verify that email, tokens, balances, referral/moderation/limit state, and subscription dates are absent.
4. Only after verification, deploy Firestore rules and the updated client together. Old clients that read other users from `users` will receive permission-denied after this step.

Never run the backfill against production without an approved rollout and project verification.