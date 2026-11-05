import { Body, CanActivate, Controller, ExecutionContext, Get, HttpCode, Inject, Injectable, Patch, Post, Req, ServiceUnavailableException, UnauthorizedException, UseGuards } from '@nestjs/common';
import { IsEmail, IsString, Length, MaxLength, MinLength, Matches } from 'class-validator';
import { Transform } from 'class-transformer';
import { Throttle } from '@nestjs/throttler';
import { AuthService, publicUser } from './auth.service';
import { Store } from './store';

class EmailDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim().toLowerCase() : value)
  @IsEmail() @MaxLength(254) email!: string;
  @IsString() @MinLength(1) @MaxLength(128) password!: string;
}
class RegisterDto extends EmailDto {
  @MinLength(10) declare password: string;
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @Length(2, 80) @Matches(/\S/) displayName!: string;
}
class GoogleDto { @IsString() @Length(20, 10000) idToken!: string; }
class RefreshDto { @IsString() @Length(40, 300) refreshToken!: string; }
class ProfileDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @Length(2, 80) @Matches(/\S/) displayName!: string;
}
export interface AuthRequest { headers: { authorization?: string }; identity: { userId: string; sessionId: string }; }
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(@Inject(AuthService) private readonly auth: AuthService) {}
  async canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest<AuthRequest>();
    const parts = request.headers.authorization?.split(' ');
    if (!parts || parts.length !== 2 || parts[0] !== 'Bearer') throw new UnauthorizedException('Giriş yapmalısın.');
    request.identity = await this.auth.authenticate(parts[1]); return true;
  }
}
@Controller('auth')
export class AuthController {
  constructor(@Inject(AuthService) private readonly auth: AuthService) {}
  @Post('register') @Throttle({ default: { limit: 5, ttl: 60000 } })
  register(@Body() body: RegisterDto) { return this.auth.register(body.email, body.password, body.displayName); }
  @Post('login') @HttpCode(200) @Throttle({ default: { limit: 5, ttl: 60000 } })
  login(@Body() body: EmailDto) { return this.auth.login(body.email, body.password); }
  @Post('google') @HttpCode(200) @Throttle({ default: { limit: 10, ttl: 60000 } })
  google(@Body() body: GoogleDto) { return this.auth.googleLogin(body.idToken); }
  @Post('refresh') @HttpCode(200)
  refresh(@Body() body: RefreshDto) { return this.auth.refresh(body.refreshToken); }
  @Post('logout') @HttpCode(204) @UseGuards(AuthGuard)
  logout(@Req() req: AuthRequest) { return this.auth.store.revoke(req.identity.sessionId); }
  @Post('google/link') @HttpCode(200) @UseGuards(AuthGuard)
  link(@Req() req: AuthRequest, @Body() body: GoogleDto) { return this.auth.linkGoogle(req.identity.userId, body.idToken); }
}
@Controller('users/me') @UseGuards(AuthGuard)
export class ProfileController {
  constructor(@Inject(Store) private readonly store: Store) {}
  @Get() async me(@Req() req: AuthRequest) {
    const user = await this.store.user(req.identity.userId);
    if (!user) throw new UnauthorizedException(); return publicUser(user);
  }
  @Patch() async update(@Req() req: AuthRequest, @Body() body: ProfileDto) {
    return publicUser(await this.store.rename(req.identity.userId, body.displayName));
  }
}
@Controller('health')
export class HealthController {
  constructor(@Inject(Store) private readonly store: Store) {}
  @Get() health() { return { status: 'ok' }; }
  @Get('ready') async ready() {
    try {
      const result = await this.store.db.query('SELECT version FROM schema_migrations WHERE version=2');
      if (result.rowCount !== 1) throw new Error('Schema is not ready');
      return { status: 'ok', database: 'ready', schemaVersion: 2 };
    } catch { throw new ServiceUnavailableException('Veritabanı henüz hazır değil.'); }
  }
}
