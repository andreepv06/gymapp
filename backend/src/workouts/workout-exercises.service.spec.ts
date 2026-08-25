import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { WorkoutExercisesService } from './workout-exercises.service';
import { PrismaService } from '../prisma/prisma.service';

describe('WorkoutExercisesService', () => {
  let service: WorkoutExercisesService;
  const prismaMock = {
    workout: { findUnique: jest.fn() },
    exercise: { findUnique: jest.fn() },
    circuit: { findUnique: jest.fn() },
    trainingMode: { findUnique: jest.fn() },
    workoutExercise: { create: jest.fn(), findUnique: jest.fn() },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WorkoutExercisesService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();
    service = module.get(WorkoutExercisesService);
  });

  it('lancia NotFoundException se la scheda non esiste', async () => {
    prismaMock.workout.findUnique.mockResolvedValue(null);
    await expect(
      service.create('user-1', 'workout-x', { exerciseId: 'ex-1' } as any),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('lancia ForbiddenException se la scheda appartiene a un altro utente', async () => {
    prismaMock.workout.findUnique.mockResolvedValue({
      id: 'w1',
      userId: 'other-user',
    });
    await expect(
      service.create('user-1', 'w1', { exerciseId: 'ex-1' } as any),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('lancia ForbiddenException se l\'esercizio appartiene a un altro utente', async () => {
    prismaMock.workout.findUnique.mockResolvedValue({
      id: 'w1',
      userId: 'user-1',
    });
    prismaMock.exercise.findUnique.mockResolvedValue({
      id: 'ex-1',
      userId: 'other-user',
    });
    await expect(
      service.create('user-1', 'w1', { exerciseId: 'ex-1' } as any),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('crea correttamente quando scheda ed esercizio appartengono allo stesso utente', async () => {
    prismaMock.workout.findUnique.mockResolvedValue({
      id: 'w1',
      userId: 'user-1',
    });
    prismaMock.exercise.findUnique.mockResolvedValue({
      id: 'ex-1',
      userId: 'user-1',
    });
    prismaMock.workoutExercise.create.mockResolvedValue({ id: 'we-1' });

    const result = await service.create('user-1', 'w1', {
      exerciseId: 'ex-1',
    } as any);
    expect(result).toEqual({ id: 'we-1' });
    expect(prismaMock.workoutExercise.create).toHaveBeenCalledWith({
      data: { workoutId: 'w1', exerciseId: 'ex-1' },
    });
  });
});