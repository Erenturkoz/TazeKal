import 'dotenv/config';

export function configuration() {
  const secret = process.env.JWT_SECRET ?? '';
  if (secret.length < 32 || secret.startsWith('replace-')) throw new Error('JWT_SECRET must be a random secret of at least 32 characters.');
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) throw new Error('DATABASE_URL is required.');
  return { secret, databaseUrl, port: Number(process.env.PORT ?? 3000),
    googleIds: (process.env.GOOGLE_CLIENT_IDS ?? '').split(',').map(v => v.trim()).filter(Boolean),
    origins: (process.env.CORS_ORIGINS ?? '').split(',').map(v => v.trim()).filter(Boolean) };
}
