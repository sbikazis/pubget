// HTTP helpers: JSON responses, CORS, and configuration reading.

export function json(body, { status = 200, headers = {} } = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...headers },
  });
}

export function errorResponse(status, message, extra = {}) {
  return json({ error: message, ...extra }, { status });
}

function originAllowed(origin, allowedOrigins) {
  if (!origin) return false;
  return allowedOrigins
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean)
    .includes(origin);
}

/** CORS headers for a cross-origin browser call, or an empty object. */
export function corsHeaders(request, env) {
  const origin = request.headers.get('Origin');
  const allowed = env?.ALLOWED_ORIGINS || '';
  if (!originAllowed(origin, allowed)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Max-Age': '600',
    Vary: 'Origin',
  };
}

export function preflight(request, env) {
  return new Response(null, { status: 204, headers: corsHeaders(request, env) });
}

export function readConfig(env) {
  const int = (value, fallback) => {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
  };
  return {
    projectId: env?.FIREBASE_PROJECT_ID || 'pubget-aaf27',
    publicBaseUrl: (env?.PUBLIC_BASE_URL || '').replace(/\/+$/, ''),
    accountId: env?.R2_ACCOUNT_ID || '',
    bucket: 'pubget-media',
    accessKeyId: env?.R2_ACCESS_KEY_ID || '',
    secretAccessKey: env?.R2_SECRET_ACCESS_KEY || '',
    presignPerMinute: int(env?.PRESIGN_PER_MINUTE, 10),
    uploadsPerHour: int(env?.UPLOADS_PER_HOUR, 20),
    listPerMinute: int(env?.LIST_PER_MINUTE, 60),
  };
}

/** True when the R2 S3 credentials needed for presigning are present. */
export function presignConfigured(config) {
  return Boolean(config.accountId && config.accessKeyId && config.secretAccessKey);
}
