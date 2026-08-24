import { Test, TestingModule } from '@nestjs/testing';
import { HealthController } from './health.controller';
import { HealthService } from './health.service';
import { PrismaService } from '../../prisma/prisma.service';

describe('HealthController', () => {
  let controller: HealthController;

  const prismaMock = {
    $queryRaw: jest.fn().mockRejectedValue(new Error('no db in unit test')),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        HealthService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();

    controller = module.get<HealthController>(HealthController);
  });

  it('dovrebbe essere definito', () => {
    expect(controller).toBeDefined();
  });

  it('dovrebbe restituire "degraded" se il DB non è raggiungibile', async () => {
    const result = await controller.check();
    expect(result.status).toBe('degraded');
    expect(result.database).toBe('unreachable');
  });
});