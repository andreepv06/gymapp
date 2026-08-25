import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateWorkoutExerciseDto } from './dto/create-workout-exercise.dto';
import { UpdateWorkoutExerciseDto } from './dto/update-workout-exercise.dto';

@Injectable()
export class WorkoutExercisesService {
  constructor(private readonly prisma: PrismaService) {}

  // Verifica che la scheda appartenga all'utente E che, se
  // indicati, esercizio/circuito/modalità appartengano ALLO STESSO
  // utente: mai fidarsi di id passati dal client anche per le
  // relazioni annidate (Parte 15 del master prompt).
  private async assertWorkoutOwned(userId: string, workoutId: string) {
    const workout = await this.prisma.workout.findUnique({
      where: { id: workoutId },
    });
    if (!workout) throw new NotFoundException('Scheda non trovata.');
    if (workout.userId !== userId) throw new ForbiddenException();
    return workout;
  }

  private async assertRelatedOwnership(
    userId: string,
    dto: { exerciseId?: string; circuitId?: string; trainingModeId?: string },
  ) {
    if (dto.exerciseId) {
      const ex = await this.prisma.exercise.findUnique({
        where: { id: dto.exerciseId },
      });
      if (!ex || ex.userId !== userId) {
        throw new ForbiddenException('Esercizio non valido per questo utente.');
      }
    }
    if (dto.circuitId) {
      const circuit = await this.prisma.circuit.findUnique({
        where: { id: dto.circuitId },
        include: { workout: true },
      });
      if (!circuit || circuit.workout.userId !== userId) {
        throw new ForbiddenException('Circuito non valido per questo utente.');
      }
    }
    if (dto.trainingModeId) {
      const mode = await this.prisma.trainingMode.findUnique({
        where: { id: dto.trainingModeId },
      });
      if (!mode || mode.userId !== userId) {
        throw new ForbiddenException('Modalità non valida per questo utente.');
      }
    }
  }

  findAllForWorkout(userId: string, workoutId: string) {
    return this.assertWorkoutOwned(userId, workoutId).then(() =>
      this.prisma.workoutExercise.findMany({
        where: { workoutId },
        orderBy: { sortOrder: 'asc' },
        include: { exercise: true, trainingMode: true },
      }),
    );
  }

  async create(
    userId: string,
    workoutId: string,
    dto: CreateWorkoutExerciseDto,
  ) {
    await this.assertWorkoutOwned(userId, workoutId);
    await this.assertRelatedOwnership(userId, dto);
    return this.prisma.workoutExercise.create({
      data: { workoutId, ...dto },
    });
  }

  private async findOwnedEntry(userId: string, id: string) {
    const entry = await this.prisma.workoutExercise.findUnique({
      where: { id },
      include: { workout: true },
    });
    if (!entry) throw new NotFoundException('Esercizio scheda non trovato.');
    if (entry.workout.userId !== userId) throw new ForbiddenException();
    return entry;
  }

  async update(userId: string, id: string, dto: UpdateWorkoutExerciseDto) {
    await this.findOwnedEntry(userId, id);
    await this.assertRelatedOwnership(userId, dto);
    return this.prisma.workoutExercise.update({ where: { id }, data: dto });
  }

  async remove(userId: string, id: string) {
    await this.findOwnedEntry(userId, id);
    await this.prisma.workoutExercise.delete({ where: { id } });
    return { success: true };
  }
}