import 'dotenv/config';

// Express "trust proxy" accepts a hop count or a list of trusted addresses/subnets.
// `true` is rejected because it lets any client spoof X-Forwarded-For and bypass rate limits.
export function parseTrustProxy(raw: string | undefined): number | string[] | false {
  const value = (raw ?? '').trim();
  if (!value || value === 'false' || value === '0') return false;
  if (/^\d{1,2}$/.test(value)) return Number(value);
  if (value === 'true') throw new Error('TRUST_PROXY=true is unsafe; use a hop count (e.g. 1) or trusted addresses (e.g. loopback).');
  return value.split(',').map(v => v.trim()).filter(Boolean);
}

export function configuration() {
  const secret = process.env.JWT_SECRET ?? '';
  if (secret.length < 32 || secret.startsWith('replace-')) throw new Error('JWT_SECRET must be a random secret of at least 32 characters.');
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) throw new Error('DATABASE_URL is required.');
  return { secret, databaseUrl, port: Number(process.env.PORT ?? 3000),
    trustProxy: parseTrustProxy(process.env.TRUST_PROXY),
    googleIds: (process.env.GOOGLE_CLIENT_IDS ?? '').split(',').map(v => v.trim()).filter(Boolean),
    origins: (process.env.CORS_ORIGINS ?? '').split(',').map(v => v.trim()).filter(Boolean) };
}
