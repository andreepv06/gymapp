import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCircuitDto } from './dto/create-circuit.dto';

@Injectable()
export class CircuitsService {
  constructor(private readonly prisma: PrismaService) {}

  private async assertWorkoutOwned(userId: string, workoutId: string) {
    const workout = await this.prisma.workout.findUnique({
      where: { id: workoutId },
    });
    if (!workout) throw new NotFoundException('Scheda non trovata.');
    if (workout.userId !== userId) throw new ForbiddenException();
  }

  findAllForWorkout(userId: string, workoutId: string) {
    return this.assertWorkoutOwned(userId, workoutId).then(() =>
      this.prisma.circuit.findMany({
        where: { workoutId },
        orderBy: { sortOrder: 'asc' },
        include: { workoutExercises: true },
      }),
    );
  }

  async create(userId: string, workoutId: string, dto: CreateCircuitDto) {
    await this.assertWorkoutOwned(userId, workoutId);
    return this.prisma.circuit.create({ data: { workoutId, ...dto } });
  }

  private async findOwned(userId: string, id: string) {
    const circuit = await this.prisma.circuit.findUnique({
      where: { id },
      include: { workout: true },
    });
    if (!circuit) throw new NotFoundException('Circuito non trovato.');
    if (circuit.workout.userId !== userId) throw new ForbiddenException();
    return circuit;
  }

  async remove(userId: string, id: string) {
    await this.findOwned(userId, id);
    // onDelete: Cascade su WorkoutExercise.circuitId in schema:
    // eliminando il circuito, Prisma/Postgres eliminano anche i
    // WorkoutExercise annidati — comportamento voluto e coerente
    // con la V1 (eliminare un circuito elimina i suoi esercizi).
    await this.prisma.circuit.delete({ where: { id } });
    return { success: true };
  }
}