import { Inject, Injectable, OnModuleDestroy } from '@nestjs/common';
import { Pool } from 'pg';

export const DATABASE = Symbol('DATABASE');
export interface UserRow { id: string; email: string; display_name: string; password_hash: string | null;
  google_sub: string | null; email_verified: boolean; created_at: Date; }
export interface SessionRow { id: string; user_id: string; refresh_hash: string; expires_at: Date; revoked_at: Date | null; }

@Injectable()
export class Store implements OnModuleDestroy {
  constructor(@Inject(DATABASE) readonly db: Pool) {}
  async onModuleDestroy() { await this.db.end(); }
  async user(id: string): Promise<UserRow | undefined> { return (await this.db.query('SELECT * FROM users WHERE id=$1', [id])).rows[0]; }
  async byEmail(email: string): Promise<UserRow | undefined> { return (await this.db.query('SELECT * FROM users WHERE email=$1', [email])).rows[0]; }
  async byGoogle(sub: string): Promise<UserRow | undefined> { return (await this.db.query('SELECT * FROM users WHERE google_sub=$1', [sub])).rows[0]; }
  async createUser(id: string, email: string, name: string, hash: string | null, sub: string | null): Promise<UserRow> {
    return (await this.db.query('INSERT INTO users(id,email,display_name,password_hash,google_sub,email_verified) VALUES($1,$2,$3,$4,$5,$6) RETURNING *',
      [id, email, name, hash, sub, sub !== null])).rows[0];
  }
  async rename(id: string, name: string): Promise<UserRow> {
    return (await this.db.query('UPDATE users SET display_name=$2 WHERE id=$1 RETURNING *', [id, name])).rows[0];
  }
  async linkGoogle(id: string, sub: string): Promise<UserRow> {
    return (await this.db.query('UPDATE users SET google_sub=$2, email_verified=true WHERE id=$1 AND (google_sub IS NULL OR google_sub=$2) RETURNING *', [id, sub])).rows[0];
  }
  async createSession(id: string, userId: string, hash: string, expires: Date) {
    await this.db.query('INSERT INTO sessions(id,user_id,refresh_hash,expires_at) VALUES($1,$2,$3,$4)', [id, userId, hash, expires]);
  }
  async session(id: string): Promise<SessionRow | undefined> { return (await this.db.query('SELECT * FROM sessions WHERE id=$1', [id])).rows[0]; }
  async rotate(id: string, oldHash: string, newHash: string): Promise<SessionRow | undefined> {
    return (await this.db.query('UPDATE sessions SET refresh_hash=$3 WHERE id=$1 AND refresh_hash=$2 AND revoked_at IS NULL AND expires_at>now() RETURNING *', [id, oldHash, newHash])).rows[0];
  }
  async revoke(id: string) { await this.db.query('UPDATE sessions SET revoked_at=now() WHERE id=$1', [id]); }
}
