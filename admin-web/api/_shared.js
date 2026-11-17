// HHK Admin Console API helpers. No secrets are persisted or logged.
export const TOKEN_RE = /^qr_[A-Za-z0-9_-]{32}$/;
export const CODE_RE = /^[A-Z0-9][A-Z0-9_-]{2,39}$/;

export function apiHeaders(res) {
  res.setHeader('Cache-Control','private, no-store, max-age=0');
  res.setHeader('X-Content-Type-Options','nosniff');
  res.setHeader('Referrer-Policy','no-referrer');
}

export function error(res, status, code) {
  return res.status(status).json({ok:false,code});
}

export function allowedOrigin(req) {
  const origin = req.headers?.origin;
  if (!origin) return true;
  try {
    const from = new URL(origin);
    return from.protocol === 'https:' && from.host === req.headers.host;
  } catch {
    return false;
  }
}

export function readBody(req) {
  let body = req.body;
  if (typeof body === 'string') body = JSON.parse(body);
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new Error('INVALID_BODY');
  }
  if (JSON.stringify(body).length > 16384) throw new Error('BODY_TOO_LARGE');
  return body;
}

export function checkedTokens(raw, maximum=100) {
  if (!Array.isArray(raw) || raw.length < 1 || raw.length > maximum ||
      raw.some(value => typeof value !== 'string' || !TOKEN_RE.test(value)) ||
      new Set(raw).size !== raw.length) {
    throw new Error('INVALID_TOKEN_LIST');
  }
  return raw;
}

export function checkedBatchCode(raw) {
  if (typeof raw !== 'string' || !CODE_RE.test(raw)) {
    throw new Error('INVALID_BATCH_CODE');
  }
  return raw;
}

export function csvForBatch(batchCode, tokens) {
  const code=checkedBatchCode(batchCode);
  const values=checkedTokens(tokens,100);
  const lines=['index,batch_code,qr_token'];
  values.forEach((token,i)=>lines.push([i+1,code,token].join(',')));
  return '\uFEFF'+lines.join('\r\n')+'\r\n';
}
