import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateExerciseDto } from './dto/create-exercise.dto';
import { UpdateExerciseDto } from './dto/update-exercise.dto';

@Injectable()
export class ExercisesService {
  constructor(private readonly prisma: PrismaService) {}

  create(userId: string, dto: CreateExerciseDto) {
    return this.prisma.exercise.create({ data: { userId, ...dto } });
  }

  findAllForUser(userId: string) {
    return this.prisma.exercise.findMany({
      where: { userId },
      orderBy: { name: 'asc' },
    });
  }

  // Ownership SEMPRE verificata lato backend: l'id nella URL non
  // basta da solo, deve appartenere all'utente autenticato dal
  // token — mai fidarsi di un id passato dal client (Parte 15 del
  // master prompt architetturale).
  private async findOwned(userId: string, id: string) {
    const exercise = await this.prisma.exercise.findUnique({ where: { id } });
    if (!exercise) throw new NotFoundException('Esercizio non trovato.');
    if (exercise.userId !== userId) throw new ForbiddenException();
    return exercise;
  }

  findOne(userId: string, id: string) {
    return this.findOwned(userId, id);
  }

  async update(userId: string, id: string, dto: UpdateExerciseDto) {
    await this.findOwned(userId, id);
    return this.prisma.exercise.update({ where: { id }, data: dto });
  }

  async remove(userId: string, id: string) {
    await this.findOwned(userId, id);
    await this.prisma.exercise.delete({ where: { id } });
    return { success: true };
  }
}