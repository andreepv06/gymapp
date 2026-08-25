import { Module } from '@nestjs/common';
import { WorkoutsController } from './workouts.controller';
import { WorkoutsService } from './workouts.service';
import { WorkoutExercisesController } from './workout-exercises.controller';
import { WorkoutExercisesService } from './workout-exercises.service';
import { CircuitsController } from './circuits.controller';
import { CircuitsService } from './circuits.service';

@Module({
  controllers: [
    WorkoutsController,
    WorkoutExercisesController,
    CircuitsController,
  ],
  providers: [WorkoutsService, WorkoutExercisesService, CircuitsService],
})
export class WorkoutsModule {}