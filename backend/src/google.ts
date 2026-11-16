import { Inject, Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { OAuth2Client } from 'google-auth-library';
export const SETTINGS = Symbol('SETTINGS');
export interface Settings { secret: string; databaseUrl: string; port: number; trustProxy?: number | string[] | false; googleIds: string[]; origins: string[]; }
export interface GoogleIdentity { sub: string; email: string; name: string; }
/** Google display names are user-controlled: drop control characters and fall back when too short for our profile rules. */
export function googleName(raw: string | undefined) {
  const name = Array.from((raw ?? '').replace(/\p{Cc}/gu, '').trim()).slice(0, 80).join('').trim();
  return name.length >= 2 ? name : 'Taze Kal kullanıcısı';
}
@Injectable()
export class GoogleVerifier {
  private readonly client = new OAuth2Client();
  constructor(@Inject(SETTINGS) private readonly config: Settings) {}
  async verify(idToken: string): Promise<GoogleIdentity> {
    if (!this.config.googleIds.length) throw new ServiceUnavailableException('Google girişi henüz yapılandırılmadı.');
    try {
      const ticket = await this.client.verifyIdToken({ idToken, audience: this.config.googleIds });
      const payload = ticket.getPayload();
      if (!payload?.sub || !payload.email || payload.email_verified !== true) throw new Error('Invalid identity');
      return { sub: payload.sub, email: payload.email.trim().toLowerCase(), name: googleName(payload.name) };
    } catch { throw new UnauthorizedException('Google hesabı doğrulanamadı.'); }
  }
}
