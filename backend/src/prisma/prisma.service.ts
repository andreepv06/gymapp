import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    super({
      log:
        process.env.NODE_ENV === 'development'
          ? ['warn', 'error']
          : ['error'],
    });
  }

  async onModuleInit() {
    try {
      await this.$connect();
      this.logger.log('Connessione a PostgreSQL stabilita.');
    } catch (err) {
      this.logger.error(
        'Impossibile connettersi al database. Verifica DATABASE_URL in .env.',
        err instanceof Error ? err.stack : String(err),
      );
    }
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}