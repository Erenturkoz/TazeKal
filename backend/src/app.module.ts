import { Module, ValidationPipe, INestApplication } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { JwtModule } from '@nestjs/jwt';
import { Pool } from 'pg';
import helmet from 'helmet';
import { configuration } from './config';
import { DATABASE, Store } from './store';
import { GoogleVerifier, SETTINGS } from './google';
import { AuthService } from './auth.service';
import { AuthController, ProfileController, HealthController, AuthGuard } from './http';
import { ProductsController, ProductsService } from './products';

@Module({
  imports: [JwtModule.register({}), ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }])],
  controllers: [AuthController, ProfileController, HealthController, ProductsController],
  providers: [{ provide: SETTINGS, useFactory: configuration },
    { provide: DATABASE, inject: [SETTINGS], useFactory: (config: ReturnType<typeof configuration>) => new Pool({ connectionString: config.databaseUrl, max: 10, connectionTimeoutMillis: 5000, statement_timeout: 5000 }) },
    Store, GoogleVerifier, AuthService, AuthGuard, ProductsService, { provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
export function configureHttp(app: INestApplication) {
  app.setGlobalPrefix('v1');
  app.use(helmet());
  app.use((_: unknown, res: { setHeader: (key: string, value: string) => void }, next: () => void) => { res.setHeader('Cache-Control', 'no-store'); next(); });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true,
    transformOptions: { enableImplicitConversion: false } }));
}
