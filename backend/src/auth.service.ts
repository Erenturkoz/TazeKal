import { BadRequestException, ConflictException, ForbiddenException, Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomBytes, randomUUID } from 'node:crypto';
import { checkPassword, hashPassword, tokenHash } from './crypto';
import { Store, UserRow } from './store';
import { GoogleVerifier, SETTINGS, Settings } from './google';

/** Bump when the Terms of Use / Privacy Policy text changes; the mobile app sends the version it displayed. */
export const TERMS_VERSION = '2026-11-16';
const TERMS_REQUIRED = 'Devam etmek için güncel Kullanım Koşulları ve Gizlilik Politikası\'nı kabul etmelisin.';
function requireCurrentTerms(version: string | undefined) {
  if (version !== TERMS_VERSION) throw new BadRequestException(TERMS_REQUIRED);
}
export function publicUser(user: UserRow) {
  return { id: user.id, email: user.email, displayName: user.display_name,
    emailVerified: user.email_verified, providers: [user.password_hash ? 'password' : null, user.google_sub ? 'google' : null].filter(Boolean),
    termsVersion: user.terms_version ?? null, createdAt: user.created_at };
}
@Injectable()
export class AuthService {
  private readonly dummy = hashPassword(randomBytes(32).toString('hex'));
  constructor(@Inject(Store) readonly store: Store, @Inject(JwtService) private readonly jwt: JwtService,
    @Inject(GoogleVerifier) private readonly google: GoogleVerifier, @Inject(SETTINGS) private readonly config: Settings) {}
  private access(userId: string, sessionId: string) {
    return this.jwt.signAsync({ sub: userId, sid: sessionId }, { secret: this.config.secret,
      algorithm: 'HS256', expiresIn: '15m', issuer: 'taze-kal-api', audience: 'taze-kal-mobile' });
  }
  private async issue(user: UserRow) {
    const id = randomUUID(), refreshToken = `${id}.${randomBytes(48).toString('base64url')}`;
    await this.store.createSession(id, user.id, tokenHash(refreshToken), new Date(Date.now() + 30 * 86400000));
    return { accessToken: await this.access(user.id, id), refreshToken, user: publicUser(user) };
  }
  async register(email: string, password: string, displayName: string, termsVersion: string) {
    requireCurrentTerms(termsVersion);
    try {
      const user = await this.store.createUser(randomUUID(), email.toLowerCase(), displayName, await hashPassword(password), null, TERMS_VERSION);
      return await this.issue(user);
    } catch (e) {
      if ((e as { code?: string }).code === '23505') throw new ConflictException('Bu e-posta ile kayıt yapılamadı. Giriş yapmayı deneyebilirsin.');
      throw e;
    }
  }
  async login(email: string, password: string) {
    const user = await this.store.byEmail(email.toLowerCase());
    const valid = await checkPassword(password, user?.password_hash ?? await this.dummy);
    if (!valid || !user?.password_hash) throw new UnauthorizedException('E-posta veya şifre hatalı.');
    return this.issue(user);
  }
  async googleLogin(idToken: string, termsVersion?: string) {
    const identity = await this.google.verify(idToken);
    let user = await this.store.byGoogle(identity.sub);
    if (!user) {
      if (await this.store.byEmail(identity.email)) throw new ConflictException('Bu e-posta kayıtlı. Önce e-posta ve şifrenle giriş yap, ardından profilinden Google hesabını bağla.');
      // Only a brand-new account needs consent; existing users keep signing in as before.
      requireCurrentTerms(termsVersion);
      try { user = await this.store.createUser(randomUUID(), identity.email, identity.name, null, identity.sub, TERMS_VERSION); }
      catch (e) {
        if ((e as { code?: string }).code !== '23505') throw e;
        user = await this.store.byGoogle(identity.sub);
        if (!user) throw new ConflictException('Hesap bağlantısı değişti. Tekrar giriş yap.');
      }
    }
    return this.issue(user);
  }
  async linkGoogle(userId: string, idToken: string) {
    const identity = await this.google.verify(idToken), user = await this.store.user(userId);
    if (!user || identity.email !== user.email) throw new ConflictException('Aynı e-posta adresine ait Google hesabını seç.');
    try {
      const linked = await this.store.linkGoogle(userId, identity.sub);
      if (!linked) throw new ConflictException('Bu hesaba farklı bir Google hesabı bağlı.');
      return publicUser(linked);
    } catch (e) {
      if ((e as { code?: string }).code === '23505') throw new ConflictException('Google hesabı başka bir profile bağlı.');
      throw e;
    }
  }
  /**
   * Permanently deletes the signed-in account after re-authentication. A stolen access token alone
   * cannot delete an account: password accounts confirm the password, Google-only accounts a fresh
   * Google ID token for the same Google subject. Wrong credentials return 403 (not 401) so clients
   * do not mistake them for an expired session.
   */
  async deleteAccount(userId: string, proof: { password?: string; idToken?: string }) {
    const user = await this.store.user(userId);
    if (!user) throw new UnauthorizedException('Oturum sona erdi. Tekrar giriş yap.');
    if (user.password_hash) {
      if (!proof.password || !await checkPassword(proof.password, user.password_hash)) throw new ForbiddenException('Şifre hatalı. Hesabın silinmedi.');
    } else if (user.google_sub) {
      if (!proof.idToken) throw new ForbiddenException('Hesabını silmek için Google hesabınla yeniden doğrula.');
      let sub: string;
      try { sub = (await this.google.verify(proof.idToken)).sub; }
      catch { throw new ForbiddenException('Google doğrulaması başarısız. Hesabın silinmedi.'); }
      if (sub !== user.google_sub) throw new ForbiddenException('Bu hesaba bağlı Google hesabını seç. Hesabın silinmedi.');
    } else {
      throw new ForbiddenException('Hesap doğrulanamadı.');
    }
    if (!await this.store.deleteUser(userId)) throw new UnauthorizedException('Oturum sona erdi. Tekrar giriş yap.');
  }
  async refresh(refreshToken: string) {
    const id = refreshToken.split('.')[0];
    if (!/^[0-9a-f-]{36}$/.test(id)) throw new UnauthorizedException('Oturum sona erdi.');
    const next = `${id}.${randomBytes(48).toString('base64url')}`;
    const session = await this.store.rotate(id, tokenHash(refreshToken), tokenHash(next));
    if (!session) throw new UnauthorizedException('Oturum sona erdi.');
    const user = await this.store.user(session.user_id);
    if (!user) throw new UnauthorizedException('Oturum sona erdi.');
    return { accessToken: await this.access(user.id, id), refreshToken: next, user: publicUser(user) };
  }
  async authenticate(token: string): Promise<{ userId: string; sessionId: string }> {
    try {
      const payload = await this.jwt.verifyAsync<{ sub: string; sid: string }>(token, { secret: this.config.secret,
        algorithms: ['HS256'], issuer: 'taze-kal-api', audience: 'taze-kal-mobile' });
      if (typeof payload.sub !== 'string' || typeof payload.sid !== 'string') throw new Error('Invalid claims');
      const session = await this.store.session(payload.sid);
      if (!session || session.user_id !== payload.sub || session.revoked_at || new Date(session.expires_at).getTime() <= Date.now()) throw new Error('Revoked');
      return { userId: payload.sub, sessionId: payload.sid };
    } catch { throw new UnauthorizedException('Oturum sona erdi. Tekrar giriş yap.'); }
  }
}
