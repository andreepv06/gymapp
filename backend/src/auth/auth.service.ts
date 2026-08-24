import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';
import { PrismaService } from '../prisma/prisma.service';

const REFRESH_SALT_ROUNDS = 12;

interface AccessPayload {
  sub: string;
  role: string;
}

interface RefreshPayload {
  sub: string;
  jti: string;
}

// ─────────────────────────────────────────────────────────────
// Strategia refresh token: ad ogni login/refresh viene creata una
// riga RefreshToken (Prisma, tabella dedicata già in schema dalla
// Fase 1). Il JWT di refresh contiene "jti" = id di quella riga.
// Al momento del refresh: si verifica firma+scadenza del JWT, si
// recupera la riga tramite jti, si controlla che non sia revocata/
// scaduta, e si confronta l'hash bcrypt del token ricevuto con
// quello salvato — così un refresh token rubato dal database (senza
// il JWT originale) non è comunque riutilizzabile, e un JWT valido
// ma già revocato (logout, o già usato una volta: rotazione) viene
// rifiutato. Ogni refresh REVOCA il vecchio token e ne emette uno
// nuovo (rotazione), riducendo la finestra di replay.
// ─────────────────────────────────────────────────────────────
@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(identifier: string, password: string) {
    const user = await this.usersService.create(identifier, password);
    return this.issueTokens(user.id, user.role);
  }

  async login(identifier: string, password: string) {
    const user = await this.usersService.findByIdentifier(identifier);
    if (!user) {
      throw new UnauthorizedException('Credenziali non valide.');
    }
    const valid = await this.usersService.verifyPassword(
      password,
      user.passwordHash,
    );
    if (!valid) {
      throw new UnauthorizedException('Credenziali non valide.');
    }
    if (!user.isActive) {
      throw new UnauthorizedException('Account disabilitato.');
    }
    return this.issueTokens(user.id, user.role);
  }

  async refresh(refreshToken: string) {
    const payload = this.verifyRefreshToken(refreshToken);

    const stored = await this.prisma.refreshToken.findUnique({
      where: { id: payload.jti },
    });
    if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token non valido o scaduto.');
    }
    const matches = await bcrypt.compare(refreshToken, stored.tokenHash);
    if (!matches) {
      throw new UnauthorizedException('Refresh token non valido.');
    }

    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });

    const user = await this.usersService.findById(stored.userId);
    if (!user || !user.isActive) {
      throw new UnauthorizedException();
    }

    return this.issueTokens(user.id, user.role);
  }

  async logout(refreshToken: string) {
    let payload: RefreshPayload;
    try {
      payload = this.verifyRefreshToken(refreshToken);
    } catch {
      // Idempotente: un token già invalido/scaduto è comunque "già
      // sloggato" agli occhi del client, non è un errore da segnalare.
      return { success: true };
    }
    await this.prisma.refreshToken.updateMany({
      where: { id: payload.jti, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { success: true };
  }

  private verifyRefreshToken(token: string): RefreshPayload {
    try {
      return this.jwt.verify<RefreshPayload>(token, {
        secret: this.config.get<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Refresh token non valido o scaduto.');
    }
  }

  private async issueTokens(userId: string, role: string) {
    const accessToken = this.jwt.sign({
      sub: userId,
      role,
    } as AccessPayload);

    const refreshExpiresIn =
      this.config.get<string>('JWT_REFRESH_EXPIRES_IN') ?? '30d';
    const expiresAt = addDuration(new Date(), refreshExpiresIn);

    // Crea prima la riga (senza hash definitivo) per ottenere l'id
    // da usare come "jti" nel payload del JWT di refresh.
    const created = await this.prisma.refreshToken.create({
      data: { userId, tokenHash: 'pending', expiresAt },
    });

    const refreshToken = this.jwt.sign(
      { sub: userId, jti: created.id } as RefreshPayload,
      {
        secret: this.config.get<string>('JWT_REFRESH_SECRET'),
        expiresIn: refreshExpiresIn,
      },
    );

    const tokenHash = await bcrypt.hash(refreshToken, REFRESH_SALT_ROUNDS);
    await this.prisma.refreshToken.update({
      where: { id: created.id },
      data: { tokenHash },
    });

    return { accessToken, refreshToken };
  }
}

function addDuration(date: Date, duration: string): Date {
  const match = /^(\d+)([smhd])$/.exec(duration.trim());
  const result = new Date(date);
  if (!match) {
    result.setDate(result.getDate() + 30);
    return result;
  }
  const value = parseInt(match[1], 10);
  switch (match[2]) {
    case 's':
      result.setSeconds(result.getSeconds() + value);
      break;
    case 'm':
      result.setMinutes(result.getMinutes() + value);
      break;
    case 'h':
      result.setHours(result.getHours() + value);
      break;
    case 'd':
      result.setDate(result.getDate() + value);
      break;
  }
  return result;
}