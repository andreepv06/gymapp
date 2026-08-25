import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSessionSetDto } from './dto/create-session-set.dto';
import { UpdateSessionSetDto } from './dto/update-session-set.dto';

@Injectable()
export class SessionSetsService {
  constructor(private readonly prisma: PrismaService) {}

  private async assertSessionOwned(userId: string, sessionId: string) {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
    });
    if (!session) throw new NotFoundException('Sessione non trovata.');
    if (session.userId !== userId) throw new ForbiddenException();
  }

  findAllForSession(userId: string, sessionId: string) {
    return this.assertSessionOwned(userId, sessionId).then(() =>
      this.prisma.sessionSet.findMany({
        where: { sessionId },
        orderBy: { setNumber: 'asc' },
      }),
    );
  }

  async create(userId: string, sessionId: string, dto: CreateSessionSetDto) {
    await this.assertSessionOwned(userId, sessionId);

    const exercise = await this.prisma.exercise.findUnique({
      where: { id: dto.exerciseId },
    });
    if (!exercise || exercise.userId !== userId) {
      throw new ForbiddenException('Esercizio non valido per questo utente.');
    }
    if (dto.trainingModeId) {
      const mode = await this.prisma.trainingMode.findUnique({
        where: { id: dto.trainingModeId },
      });
      if (!mode || mode.userId !== userId) {
        throw new ForbiddenException('Modalità non valida per questo utente.');
      }
    }

    return this.prisma.sessionSet.create({ data: { sessionId, ...dto } });
  }

  private async findOwned(userId: string, id: string) {
    const set = await this.prisma.sessionSet.findUnique({
      where: { id },
      include: { session: true },
    });
    if (!set) throw new NotFoundException('Serie non trovata.');
    if (set.session.userId !== userId) throw new ForbiddenException();
    return set;
  }

  async update(userId: string, id: string, dto: UpdateSessionSetDto) {
    await this.findOwned(userId, id);
    return this.prisma.sessionSet.update({ where: { id }, data: dto });
  }

  async remove(userId: string, id: string) {
    await this.findOwned(userId, id);
    await this.prisma.sessionSet.delete({ where: { id } });
    return { success: true };
  }
}