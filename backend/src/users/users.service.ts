import { Injectable, ConflictException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

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

  async create(identifier: string, plainPassword: string) {
    const existing = await this.findByIdentifier(identifier);
    if (existing) {
      throw new ConflictException('Identifier già registrato.');
    }
    const passwordHash = await bcrypt.hash(plainPassword, SALT_ROUNDS);
    return this.prisma.user.create({ data: { identifier, passwordHash } });
  }

  async verifyPassword(plainPassword: string, passwordHash: string) {
    return bcrypt.compare(plainPassword, passwordHash);
  }

  // ── Profilo (GET/PATCH /users/me) ──────────────────────────
  // Non restituisce mai passwordHash al client.
  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) return null;
    const { passwordHash, ...safeUser } = user;
    return safeUser;
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const data: {
      displayName?: string;
      firstName?: string;
      lastName?: string;
      birthDate?: Date;
      birthPlace?: string;
      phone?: string;
      bio?: string;
      avatarUrl?: string;
    } = {
      displayName: dto.displayName,
      firstName: dto.firstName,
      lastName: dto.lastName,
      birthPlace: dto.birthPlace,
      phone: dto.phone,
      bio: dto.bio,
      avatarUrl: dto.avatarUrl,
    };
    if (dto.birthDate) {
      data.birthDate = new Date(dto.birthDate);
    }

    return this.prisma.userProfile.upsert({
      where: { userId },
      create: { userId, ...data },
      update: data,
    });
  }
}