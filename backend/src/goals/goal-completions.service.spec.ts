import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException } from '@nestjs/common';
import { GoalCompletionsService } from './goal-completions.service';
import { GoalsService } from './goals.service';
import { PrismaService } from '../prisma/prisma.service';

describe('GoalCompletionsService', () => {
  let service: GoalCompletionsService;

  const prismaMock = {
    goal: { findUnique: jest.fn() },
    goalCompletion: { upsert: jest.fn(), findMany: jest.fn() },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        GoalCompletionsService,
        GoalsService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();
    service = module.get(GoalCompletionsService);
  });

  it('lancia ForbiddenException se il goal appartiene a un altro utente', async () => {
    prismaMock.goal.findUnique.mockResolvedValue({
      id: 'g1',
      userId: 'other-user',
    });
    await expect(
      service.setCompletion('user-1', 'g1', '2026-08-24', true),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('effettua upsert idempotente sulla stessa data', async () => {
    prismaMock.goal.findUnique.mockResolvedValue({ id: 'g1', userId: 'user-1' });
    prismaMock.goalCompletion.upsert.mockResolvedValue({
      goalId: 'g1',
      completed: true,
    });

    const result = await service.setCompletion('user-1', 'g1', '2026-08-24', true);

    expect(result.completed).toBe(true);
    expect(prismaMock.goalCompletion.upsert).toHaveBeenCalledWith({
      where: {
        goalId_date: { goalId: 'g1', date: new Date('2026-08-24') },
      },
      create: { goalId: 'g1', date: new Date('2026-08-24'), completed: true },
      update: { completed: true },
    });
  });
});