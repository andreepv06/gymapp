import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GoalsService } from './goals.service';

@Injectable()
export class GoalCompletionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly goalsService: GoalsService,
  ) {}

  async findAllForGoal(userId: string, goalId: string) {
    await this.goalsService.assertOwned(userId, goalId);
    return this.prisma.goalCompletion.findMany({
      where: { goalId },
      orderBy: { date: 'asc' },
    });
  }

  // Upsert idempotente sulla data: stesso comportamento del "toggle"
  // già presente in V1 Flutter (GoalDatabase.setCompletion), ma qui
  // il client dichiara esplicitamente lo stato desiderato invece di
  // invertirlo — più sicuro in un'API stateless (nessuna race
  // condition su richieste duplicate).
  async setCompletion(
    userId: string,
    goalId: string,
    date: string,
    completed: boolean,
  ) {
    await this.goalsService.assertOwned(userId, goalId);
    const day = new Date(date);
    return this.prisma.goalCompletion.upsert({
      where: { goalId_date: { goalId, date: day } },
      create: { goalId, date: day, completed },
      update: { completed },
    });
  }
}