import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CircuitsService } from './circuits.service';
import { CreateCircuitDto } from './dto/create-circuit.dto';

@ApiTags('circuits')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class CircuitsController {
  constructor(private readonly service: CircuitsService) {}

  @Get('workouts/:workoutId/circuits')
  findAll(
    @CurrentUser() user: { id: string },
    @Param('workoutId') workoutId: string,
  ) {
    return this.service.findAllForWorkout(user.id, workoutId);
  }

  @Post('workouts/:workoutId/circuits')
  create(
    @CurrentUser() user: { id: string },
    @Param('workoutId') workoutId: string,
    @Body() dto: CreateCircuitDto,
  ) {
    return this.service.create(user.id, workoutId, dto);
  }

  @Delete('circuits/:id')
  remove(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.service.remove(user.id, id);
  }
}