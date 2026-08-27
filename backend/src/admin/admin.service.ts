import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  // Nessuna password/hash esposto (Parte 17 del master prompt:
  // "Mai visualizzare password"). Solo campi non sensibili.
  async listUsers() {
    return this.prisma.user.findMany({
      select: {
        id: true,
        identifier: true,
        role: true,
        isActive: true,
        emailVerified: true,
        createdAt: true,
        profile: { select: { displayName: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}