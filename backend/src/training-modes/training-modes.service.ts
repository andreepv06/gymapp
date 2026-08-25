import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTrainingModeDto } from './dto/create-training-mode.dto';

@Injectable()
export class TrainingModesService {
  constructor(private readonly prisma: PrismaService) {}

  // Tutte le modalità, incluse quelle soft-eliminate: necessario
  // perché lo storico (SessionSet.trainingModeId) deve poter
  // continuare a risolvere anche una modalità non più disponibile
  // per nuovi utilizzi (stesso principio già presente in V1 Flutter).
  findAllForUser(userId: string) {
    return this.prisma.trainingMode.findMany({
      where: { userId },
      include: { sets: { orderBy: { order: 'asc' } } },
      orderBy: { name: 'asc' },
    });
  }

  findAvailableForUser(userId: string) {
    return this.prisma.trainingMode.findMany({
      where: { userId, isDeleted: false },
      include: { sets: { orderBy: { order: 'asc' } } },
      orderBy: { name: 'asc' },
    });
  }

  private async findOwned(userId: string, id: string) {
    const mode = await this.prisma.trainingMode.findUnique({
      where: { id },
      include: { sets: { orderBy: { order: 'asc' } } },
    });
    if (!mode) throw new NotFoundException('Modalità non trovata.');
    if (mode.userId !== userId) throw new ForbiddenException();
    return mode;
  }

  findOne(userId: string, id: string) {
    return this.findOwned(userId, id);
  }

  async create(userId: string, dto: CreateTrainingModeDto, origin = 'custom') {
    return this.prisma.trainingMode.create({
      data: {
        userId,
        name: dto.name,
        category: dto.category,
        origin,
        sets: {
          create: dto.sets.map((s) => ({
            order: s.order,
            fixedReps: s.fixedReps,
            minReps: s.minReps,
            maxReps: s.maxReps,
          })),
        },
      },
      include: { sets: { orderBy: { order: 'asc' } } },
    });
  }

  // Versionamento (Parte 10/11 del sistema V1): modificare la
  // struttura di una modalità NON altera mai la riga esistente.
  // Crea sempre una nuova TrainingMode (con parentModeId → quella
  // vecchia) e soft-elimina l'originale, così ogni SessionSet che
  // referenzia la vecchia riga continua a risolverla esattamente
  // come era al momento dell'esecuzione storica.
  async createNewVersion(userId: string, id: string, dto: CreateTrainingModeDto) {
    const old = await this.findOwned(userId, id);
    const wasDefault = old.isDefault;

    const created = await this.create(userId, dto, old.origin);
    await this.prisma.trainingMode.update({
      where: { id: created.id },
      data: { parentModeId: old.id },
    });

    if (wasDefault) {
      await this.setDefault(userId, created.id);
    }
    await this.prisma.trainingMode.update({
      where: { id: old.id },
      data: { isDeleted: true },
    });

    return this.findOwned(userId, created.id);
  }

  async setDefault(userId: string, id: string) {
    const mode = await this.findOwned(userId, id);
    if (mode.isDeleted) {
      throw new BadRequestException(
        'Non è possibile impostare come predefinita una modalità eliminata.',
      );
    }
    await this.prisma.$transaction([
      this.prisma.trainingMode.updateMany({
        where: { userId, isDefault: true },
        data: { isDefault: false },
      }),
      this.prisma.trainingMode.update({
        where: { id },
        data: { isDefault: true },
      }),
    ]);
    return this.findOwned(userId, id);
  }

  async softDelete(userId: string, id: string) {
    const mode = await this.findOwned(userId, id);
    if (mode.isDefault) {
      throw new BadRequestException(
        'Impossibile eliminare la modalità predefinita: impostane prima un\'altra come predefinita.',
      );
    }
    await this.prisma.trainingMode.update({
      where: { id },
      data: { isDeleted: true },
    });
    return { success: true };
  }
}