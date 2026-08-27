import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { RolesGuard } from './roles.guard';
import { ROLES_KEY } from '../common/decorators/roles.decorator';

describe('RolesGuard', () => {
  function buildContext(userRole?: Role): ExecutionContext {
    return {
      switchToHttp: () => ({
        getRequest: () => ({ user: userRole ? { role: userRole } : undefined }),
      }),
      getHandler: () => ({}),
      getClass: () => ({}),
    } as unknown as ExecutionContext;
  }

  it('consente l\'accesso se nessun ruolo è richiesto', () => {
    const reflector = { getAllAndOverride: () => undefined } as unknown as Reflector;
    const guard = new RolesGuard(reflector);
    expect(guard.canActivate(buildContext(Role.USER))).toBe(true);
  });

  it('nega l\'accesso a USER su una rotta ADMIN-only', () => {
    const reflector = {
      getAllAndOverride: () => [Role.ADMIN],
    } as unknown as Reflector;
    const guard = new RolesGuard(reflector);
    expect(guard.canActivate(buildContext(Role.USER))).toBe(false);
  });

  it('consente l\'accesso ad ADMIN su una rotta ADMIN-only', () => {
    const reflector = {
      getAllAndOverride: () => [Role.ADMIN],
    } as unknown as Reflector;
    const guard = new RolesGuard(reflector);
    expect(guard.canActivate(buildContext(Role.ADMIN))).toBe(true);
  });
});