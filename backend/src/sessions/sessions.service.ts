import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSessionDto } from './dto/create-session.dto';
import { UpdateSessionDto } from './dto/update-session.dto';

@Injectable()
export class SessionsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateSessionDto) {
    // Se viene indicata una scheda, deve appartenere allo stesso
    // utente autenticato: mai collegare una sessione a una scheda
    // di un altro utente, indipendentemente da cosa invia il client.
    if (dto.workoutId) {
      const workout = await this.prisma.workout.findUnique({
        where: { id: dto.workoutId },
      });
      if (!workout || workout.userId !== userId) {
        throw new ForbiddenException('Scheda non valida per questo utente.');
      }
    }
    return this.prisma.session.create({
      data: {
        userId,
        workoutId: dto.workoutId,
        workoutName: dto.workoutName,
        date: new Date(dto.date),
        durationSeconds: dto.durationSeconds,
      },
    });
  }

  findAllForUser(userId: string) {
    return this.prisma.session.findMany({
      where: { userId },
      orderBy: { date: 'desc' },
      include: { sessionSets: true },
    });
  }

  private async findOwned(userId: string, id: string) {
    const session = await this.prisma.session.findUnique({
      where: { id },
      include: { sessionSets: true },
    });
    if (!session) throw new NotFoundException('Sessione non trovata.');
    if (session.userId !== userId) throw new ForbiddenException();
    return session;
  }

  findOne(userId: string, id: string) {
    return this.findOwned(userId, id);
  }

  async update(userId: string, id: string, dto: UpdateSessionDto) {
    await this.findOwned(userId, id);
    return this.prisma.session.update({
      where: { id },
      data: {
        ...(dto.date ? { date: new Date(dto.date) } : {}),
        ...(dto.durationSeconds !== undefined
          ? { durationSeconds: dto.durationSeconds }
          : {}),
      },
    });
  }

  async remove(userId: string, id: string) {
    await this.findOwned(userId, id);
    await this.prisma.session.delete({ where: { id } });
    return { success: true };
  }
}