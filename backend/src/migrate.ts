import 'dotenv/config';
import { Pool } from 'pg';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
async function main() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(7450621)');
    await client.query(readFileSync(join(process.cwd(), 'src/schema.sql'), 'utf8'));
    await client.query('COMMIT');
    console.log('Database schema version 2 applied.');
  } catch (error) { await client.query('ROLLBACK'); throw error; }
  finally { client.release(); await pool.end(); }
}
main().catch(() => { console.error('Migration failed. Check database connection; no credentials were logged.'); process.exitCode = 1; });
