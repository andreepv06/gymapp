import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSportSessionDto } from './dto/create-sport-session.dto';
import { UpdateSportSessionDto } from './dto/update-sport-session.dto';

@Injectable()
export class SportSessionsService {
  constructor(private readonly prisma: PrismaService) {}

  findAllForUser(userId: string) {
    return this.prisma.sportSession.findMany({
      where: { userId },
      orderBy: { date: 'desc' },
    });
  }

  private async findOwned(userId: string, id: string) {
    const session = await this.prisma.sportSession.findUnique({
      where: { id },
    });
    if (!session) throw new NotFoundException('Sessione sportiva non trovata.');
    if (session.userId !== userId) throw new ForbiddenException();
    return session;
  }

  findOne(userId: string, id: string) {
    return this.findOwned(userId, id);
  }

  create(userId: string, dto: CreateSportSessionDto) {
    return this.prisma.sportSession.create({
      data: {
        userId,
        sportType: dto.sportType,
        date: new Date(dto.date),
        durationSeconds: dto.durationSeconds,
        distanceKm: dto.distanceKm,
        notes: dto.notes,
      },
    });
  }

  async update(userId: string, id: string, dto: UpdateSportSessionDto) {
    await this.findOwned(userId, id);
    return this.prisma.sportSession.update({
      where: { id },
      data: {
        ...dto,
        date: dto.date ? new Date(dto.date) : undefined,
      },
    });
  }

  async remove(userId: string, id: string) {
    await this.findOwned(userId, id);
    await this.prisma.sportSession.delete({ where: { id } });
    return { success: true };
  }
}