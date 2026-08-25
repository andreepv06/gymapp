import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { WorkoutExercisesService } from './workout-exercises.service';
import { CreateWorkoutExerciseDto } from './dto/create-workout-exercise.dto';
import { UpdateWorkoutExerciseDto } from './dto/update-workout-exercise.dto';

@ApiTags('workout-exercises')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class WorkoutExercisesController {
  constructor(private readonly service: WorkoutExercisesService) {}

  @Get('workouts/:workoutId/exercises')
  findAll(
    @CurrentUser() user: { id: string },
    @Param('workoutId') workoutId: string,
  ) {
    return this.service.findAllForWorkout(user.id, workoutId);
  }

  @Post('workouts/:workoutId/exercises')
  create(
    @CurrentUser() user: { id: string },
    @Param('workoutId') workoutId: string,
    @Body() dto: CreateWorkoutExerciseDto,
  ) {
    return this.service.create(user.id, workoutId, dto);
  }

  @Patch('workout-exercises/:id')
  update(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: UpdateWorkoutExerciseDto,
  ) {
    return this.service.update(user.id, id, dto);
  }

  @Delete('workout-exercises/:id')
  remove(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.service.remove(user.id, id);
  }
}