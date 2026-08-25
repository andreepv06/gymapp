import { Module } from '@nestjs/common';
import { SportSessionsController } from './sport-sessions.controller';
import { SportSessionsService } from './sport-sessions.service';

@Module({
  controllers: [SportSessionsController],
  providers: [SportSessionsService],
})
export class SportSessionsModule {}