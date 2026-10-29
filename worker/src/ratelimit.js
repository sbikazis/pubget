// Fixed-window rate limiting keyed by `{action}:{uid}`.
//
// LIMITATION: this store lives in the isolate's memory. Cloudflare may run
// several isolates for the same worker, so the effective limit is
// (configured limit × number of warm isolates). It stops a single abusive
// client, not a distributed one. For a strict global limit, back this with a
// Durable Object or KV namespace — the interface below is the seam for that.

export function createRateLimiter({ now = Date.now } = {}) {
  const buckets = new Map();

  function prune(seconds) {
    for (const [key, entry] of buckets) {
      if (entry.resetAt <= seconds) buckets.delete(key);
    }
  }

  return {
    /**
     * @returns {{ allowed: boolean, retryAfterSeconds: number, remaining: number }}
     */
    check(key, limit, windowSeconds) {
      const seconds = Math.floor(now() / 1000);
      prune(seconds);
      let entry = buckets.get(key);
      if (!entry || entry.resetAt <= seconds) {
        entry = { count: 0, resetAt: seconds + windowSeconds };
        buckets.set(key, entry);
      }
      if (entry.count >= limit) {
        return {
          allowed: false,
          retryAfterSeconds: Math.max(1, entry.resetAt - seconds),
          remaining: 0,
        };
      }
      entry.count += 1;
      return {
        allowed: true,
        retryAfterSeconds: 0,
        remaining: limit - entry.count,
      };
    },
    reset() {
      buckets.clear();
    },
  };
}

export const RATE_LIMITS = {
  presign: { limit: 10, windowSeconds: 60 },
  upload: { limit: 20, windowSeconds: 3600 },
  list: { limit: 60, windowSeconds: 60 },
};
