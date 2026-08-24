import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { HealthService, HealthStatus } from './health.service';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  @ApiOperation({ summary: "Verifica che l'API MarkFit sia attiva" })
  @ApiOkResponse({
    schema: {
      example: {
        status: 'ok',
        timestamp: '2026-08-24T10:00:00.000Z',
        uptimeSeconds: 42,
        database: 'connected',
      },
    },
  })
  async check(): Promise<HealthStatus> {
    return this.healthService.check();
  }
}