import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/**
 * Estrae l'utente autenticato (popolato da JwtStrategy) dalla request.
 * Uso: metodo(@CurrentUser() user: { id: string; role: string }) { ... }
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    return request.user;
  },
);