import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ExerciseNotesService {
  constructor(private readonly prisma: PrismaService) {}

  private async assertExerciseOwned(userId: string, exerciseId: string) {
    const exercise = await this.prisma.exercise.findUnique({
      where: { id: exerciseId },
    });
    if (!exercise) throw new NotFoundException('Esercizio non trovato.');
    if (exercise.userId !== userId) throw new ForbiddenException();
  }

  async findOne(userId: string, exerciseId: string) {
    await this.assertExerciseOwned(userId, exerciseId);
    return this.prisma.exerciseNote.findUnique({ where: { exerciseId } });
  }

  async upsert(userId: string, exerciseId: string, note: string) {
    await this.assertExerciseOwned(userId, exerciseId);
    return this.prisma.exerciseNote.upsert({
      where: { exerciseId },
      create: { exerciseId, note },
      update: { note },
    });
  }

  async remove(userId: string, exerciseId: string) {
    await this.assertExerciseOwned(userId, exerciseId);
    await this.prisma.exerciseNote
      .delete({ where: { exerciseId } })
      .catch(() => null); // idempotente: nessuna nota da eliminare non è un errore
    return { success: true };
  }
}