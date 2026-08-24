import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateWorkoutDto } from './dto/create-workout.dto';
import { UpdateWorkoutDto } from './dto/update-workout.dto';

@Injectable()
export class WorkoutsService {
  constructor(private readonly prisma: PrismaService) {}

  create(userId: string, dto: CreateWorkoutDto) {
    return this.prisma.workout.create({ data: { userId, ...dto } });
  }

  findAllForUser(userId: string) {
    return this.prisma.workout.findMany({
      where: { userId },
      orderBy: { name: 'asc' },
    });
  }

  private async findOwned(userId: string, id: string) {
    const workout = await this.prisma.workout.findUnique({ where: { id } });
    if (!workout) throw new NotFoundException('Scheda non trovata.');
    if (workout.userId !== userId) throw new ForbiddenException();
    return workout;
  }

  findOne(userId: string, id: string) {
    return this.findOwned(userId, id);
  }

  async update(userId: string, id: string, dto: UpdateWorkoutDto) {
    await this.findOwned(userId, id);
    return this.prisma.workout.update({ where: { id }, data: dto });
  }

  async remove(userId: string, id: string) {
    await this.findOwned(userId, id);
    await this.prisma.workout.delete({ where: { id } });
    return { success: true };
  }
}