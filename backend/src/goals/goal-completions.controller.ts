import { Body, Controller, Get, Param, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { GoalCompletionsService } from './goal-completions.service';
import { SetCompletionDto } from './dto/set-completion.dto';

@ApiTags('goal-completions')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('goals/:goalId/completions')
export class GoalCompletionsController {
  constructor(private readonly service: GoalCompletionsService) {}

  @Get()
  findAll(
    @CurrentUser() user: { id: string },
    @Param('goalId') goalId: string,
  ) {
    return this.service.findAllForGoal(user.id, goalId);
  }

  // Data in formato YYYY-MM-DD nella URL.
  @Put(':date')
  setCompletion(
    @CurrentUser() user: { id: string },
    @Param('goalId') goalId: string,
    @Param('date') date: string,
    @Body() dto: SetCompletionDto,
  ) {
    return this.service.setCompletion(user.id, goalId, date, dto.completed);
  }
}