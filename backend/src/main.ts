import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { json } from 'express';
import { AppModule, configureHttp } from './app.module';
import { configuration } from './config';
async function main() {
  const config = configuration();
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bodyParser: false });
  // Behind a reverse proxy every request would otherwise share the proxy's IP and one rate-limit bucket.
  if (config.trustProxy !== false) app.set('trust proxy', config.trustProxy);
  app.use(json({ limit: '128kb' }));
  configureHttp(app);
  app.enableCors({ origin: config.origins, methods: ['GET', 'POST', 'PATCH', 'DELETE'], allowedHeaders: ['Content-Type', 'Authorization'] });
  app.enableShutdownHooks();
  await app.listen(config.port, '0.0.0.0');
}
main().catch((error: unknown) => {
  // Config errors carry no secret values; other errors stay generic so connection strings are not logged.
  const message = error instanceof Error && /^(JWT_SECRET|DATABASE_URL|TRUST_PROXY)/.test(error.message) ? ` ${error.message}` : '';
  console.error(`API başlatılamadı. Ortam değişkenlerini ve PostgreSQL bağlantısını kontrol et.${message}`); process.exitCode = 1;
});
