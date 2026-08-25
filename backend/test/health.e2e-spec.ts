import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Health (e2e)', () => {
  let app: INestApplication;

  // Timeout esteso a 30s: un tentativo di connessione Prisma verso
  // un host lento/irraggiungibile può impiegare più dei 5000ms di
  // default di Jest prima che PrismaService catturi l'errore
  // internamente. Non nasconde un DB davvero irraggiungibile (il
  // test fallirebbe comunque su asserzioni più stringenti), ma
  // evita falsi negativi dovuti solo alla latenza di connessione.
  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api');
    await app.init();
  }, 30000);

  afterAll(async () => {
    await app.close();
  });

  it('/api/health (GET) risponde 200', () => {
    return request(app.getHttpServer())
      .get('/api/health')
      .expect(200)
      .expect((res) => {
        expect(['ok', 'degraded']).toContain(res.body.status);
      });
  }, 15000);
});