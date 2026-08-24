import { Injectable, ConflictException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';

const SALT_ROUNDS = 12;

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findByIdentifier(identifier: string) {
    return this.prisma.user.findUnique({ where: { identifier } });
  }

  async findById(id: string) {
    return this.prisma.user.findUnique({ where: { id } });
  }

  // Password sempre hashata con bcrypt prima di toccare il database
  // — mai salvata in chiaro (a differenza della V1 locale, non
  // toccata da questo backend).
  async create(identifier: string, plainPassword: string) {
    const existing = await this.findByIdentifier(identifier);
    if (existing) {
      throw new ConflictException('Identifier già registrato.');
    }
    const passwordHash = await bcrypt.hash(plainPassword, SALT_ROUNDS);
    return this.prisma.user.create({
      data: { identifier, passwordHash },
    });
  }

  async verifyPassword(plainPassword: string, passwordHash: string) {
    return bcrypt.compare(plainPassword, passwordHash);
  }
}