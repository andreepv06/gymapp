import { Module } from '@nestjs/common';
import { GoalsController } from './goals.controller';
import { GoalsService } from './goals.service';
import { GoalCompletionsController } from './goal-completions.controller';
import { GoalCompletionsService } from './goal-completions.service';

@Module({
  controllers: [GoalsController, GoalCompletionsController],
  providers: [GoalsService, GoalCompletionsService],
})
export class GoalsModule {}