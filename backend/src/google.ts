import { Inject, Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { OAuth2Client } from 'google-auth-library';
export const SETTINGS = Symbol('SETTINGS');
export interface Settings { secret: string; databaseUrl: string; port: number; googleIds: string[]; origins: string[]; }
export interface GoogleIdentity { sub: string; email: string; name: string; }
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
      return { sub: payload.sub, email: payload.email.trim().toLowerCase(), name: (payload.name ?? 'Taze Kal kullanıcısı').slice(0, 80) };
    } catch { throw new UnauthorizedException('Google hesabı doğrulanamadı.'); }
  }
}
