import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { json } from 'express';
import { AppModule, configureHttp } from './app.module';
import { configuration } from './config';
async function main() {
  const config = configuration();
  const app = await NestFactory.create(AppModule, { bodyParser: false });
  app.use(json({ limit: '128kb' }));
  configureHttp(app);
  app.enableCors({ origin: config.origins, methods: ['GET', 'POST', 'PATCH'], allowedHeaders: ['Content-Type', 'Authorization'] });
  app.enableShutdownHooks();
  await app.listen(config.port, '0.0.0.0');
}
main().catch(() => { console.error('API başlatılamadı. Ortam değişkenlerini ve PostgreSQL bağlantısını kontrol et.'); process.exitCode = 1; });
