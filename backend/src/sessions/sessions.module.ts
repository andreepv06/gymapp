import { Module } from '@nestjs/common';
import { SessionsController } from './sessions.controller';
import { SessionsService } from './sessions.service';
import { SessionSetsController } from './session-sets.controller';
import { SessionSetsService } from './session-sets.service';

@Module({
  controllers: [SessionsController, SessionSetsController],
  providers: [SessionsService, SessionSetsService],
})
export class SessionsModule {}