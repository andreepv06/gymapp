import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateGoalDto } from './dto/create-goal.dto';
import { UpdateGoalDto } from './dto/update-goal.dto';

@Injectable()
export class GoalsService {
  constructor(private readonly prisma: PrismaService) {}

  findAllForUser(userId: string) {
    return this.prisma.goal.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  private async findOwned(userId: string, id: string) {
    const goal = await this.prisma.goal.findUnique({ where: { id } });
    if (!goal) throw new NotFoundException('Obiettivo non trovato.');
    if (goal.userId !== userId) throw new ForbiddenException();
    return goal;
  }

  findOne(userId: string, id: string) {
    return this.findOwned(userId, id);
  }

  create(userId: string, dto: CreateGoalDto) {
    return this.prisma.goal.create({
      data: {
        userId,
        title: dto.title,
        description: dto.description,
        category: dto.category,
        scheduleType: dto.scheduleType,
        scheduleDaysOfWeek: dto.scheduleDaysOfWeek ?? [],
        scheduleStartDate: dto.scheduleStartDate
          ? new Date(dto.scheduleStartDate)
          : undefined,
        scheduleEndDate: dto.scheduleEndDate
          ? new Date(dto.scheduleEndDate)
          : undefined,
        scheduleCustomInterval: dto.scheduleCustomInterval,
        deadlineDate: dto.deadlineDate ? new Date(dto.deadlineDate) : undefined,
        colorIndex: dto.colorIndex ?? 0,
      },
    });
  }

  async update(userId: string, id: string, dto: UpdateGoalDto) {
    await this.findOwned(userId, id);
    return this.prisma.goal.update({
      where: { id },
      data: {
        ...dto,
        scheduleStartDate: dto.scheduleStartDate
          ? new Date(dto.scheduleStartDate)
          : undefined,
        scheduleEndDate: dto.scheduleEndDate
          ? new Date(dto.scheduleEndDate)
          : undefined,
        deadlineDate: dto.deadlineDate ? new Date(dto.deadlineDate) : undefined,
      },
    });
  }

  async remove(userId: string, id: string) {
    await this.findOwned(userId, id);
    await this.prisma.goal.delete({ where: { id } });
    return { success: true };
  }

  // Espone il findOwned al service dei completions, così l'ownership
  // dell'obiettivo padre viene verificata in un solo posto.
  async assertOwned(userId: string, goalId: string) {
    await this.findOwned(userId, goalId);
  }
}